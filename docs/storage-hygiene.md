---
id: storage-hygiene
title: "Storage Hygiene — Docker, Colima, and LLM Models"
purpose: Runbook for reclaiming disk on the 256GB primary drive via Docker pruning, fstrim, and model management.
links:
  - id: llama-cpp
    rel: related
  - id: readme
    rel: parent
---

# Storage Hygiene — Docker, Colima, and LLM Models

256GB primary disk. Storage discipline is not optional.

Two primary consumers to manage:
1. **Docker / Colima** — build cache, unused images, volumes
2. **LLM models** — GGUF files (4–5GB each; keep only one active)

---

## Docker / Colima

### Why fstrim matters

`docker system prune` frees blocks **inside the Colima VM** disk image.
Without `fstrim`, the `.qcow2` / `.vz` image on the macOS host filesystem
does NOT shrink — freed blocks stay allocated. `fstrim` signals the VM to
discard those blocks and return them to macOS.

**Always run `docker-reclaim -f` instead of raw `docker system prune`.**

### Commands

```sh
docker-df              # show what Docker consumes (alias for docker system df)
docker-reclaim         # dry run: shows current usage and what would be freed
docker-reclaim -f      # execute: prune + fstrim (actually reclaims host disk)
```

### What `docker-reclaim -f` does

1. `docker system prune -f` — stopped containers, unused networks, dangling images
2. `docker builder prune -af` — build cache (often largest: 7GB+ common)
3. `docker image prune -af` — all unused images (not just dangling)
4. `docker volume prune -f` — unused volumes
5. `colima prune -f` — unused Colima instances/snapshots
6. `colima ssh -- sudo fstrim -av` — TRIM VM disk; shrinks host disk image

### Expected reclaim on a typical dev machine

| Source | Typical size |
|---|---|
| Build cache | 5–10GB |
| Unused images | 3–8GB |
| Stopped containers | 0–1GB |
| Unused volumes | 1–5GB |
| **Total** | **10–20GB+** |

### Maintenance cadence

- Run `docker-df` weekly to monitor growth.
- Run `docker-reclaim -f` monthly, or when primary disk drops below 30GB free.
- Before and after major builds: prune build cache.

### Colima status

```sh
colima-status          # alias for colima status (CPU, memory, disk, runtime)
colima status          # same
```

### Virtual Disk Allocation vs Physical APFS Storage (The "128GB Ghost")

On a 256GB Mac, inspecting `~/.colima` with standard GUI disk analyzers (e.g., DaisyDisk, GrandPerspective) or `ls -lh` can cause panic by reporting **~128 GB** of disk consumption:

- `~/.colima/_lima/_disks/colima/datadisk`: **100 GB** apparent size
- `~/.colima/_lima/colima/disk`: **20 GB** apparent size
- Total apparent / logical directory size: **~128 GB**

#### Why this is an illusion: APFS Sparse Files

Colima/Lima provisions virtual disks with a *capacity ceiling* (the maximum virtual size the guest Linux VM can expand into). Under macOS APFS, these images are created as **sparse files**:

- The file header advertises a 100 GB logical capacity to the guest VM.
- Physical APFS storage blocks are only allocated on the host SSD when the guest OS actually writes new data.
- Unwritten blocks / holes consume **zero bytes** on the host.

To prove actual physical footprint on disk, inspect physical block allocation (`ls -ls`) or use `du -sh`:

```sh
# Compare apparent size (-lh) vs actual block allocation (-ls)
ls -lh ~/.colima/_lima/_disks/colima/datadisk
# Logical: 100G

ls -ls ~/.colima/_lima/_disks/colima/datadisk
# Allocated: 15949096 blocks * 512 bytes = ~7.6 GB

du -sh ~/.colima
# Real SSD usage: ~11 GB

zdots-storage
# Reports true multi-bucket consumption: Docker/Colima: ~11 GB [ok]
```

#### Reconciling Ghost Metrics & "100+ GB Freed or Halved" Illusions

Operators managing tight storage on 256GB Apple Silicon machines routinely encounter phantom metrics that make it appear as though 100+ GB was suddenly wiped or freed. Two distinct macOS APFS architectural layers produce this:

##### 1. DaisyDisk & Apple Foundation Purgeable Space API (The "111.9 GB Available" Illusion)

DaisyDisk and macOS *System Settings → Storage* do not show raw physical free space by default. DaisyDisk queries Apple Foundation's native `volumeAvailableCapacityForImportantUsageKey`:

$$\begin{aligned}
\text{Raw Physical Free Space} &\quad \mathbf{20.43\text{ GB}} \\
+ \text{APFS Purgeable Space} &\quad \mathbf{91.39\text{ GB}} \\
\hline
\mathbf{\text{DaisyDisk "Available" Metric}} &\quad \mathbf{111.82\text{ GB (rounds to 111.9 GB)}}
\end{aligned}$$

**What is the 91.4 GB of "Purgeable Space"?**
It is **not** unallocated space. It is physical disk space currently occupied by files that macOS knows it can silently evict if an application requests space for an essential installation:
- **CloudStorage & DriveFS Virtual Assets:** Files in `~/Library/Application Support/Google/DriveFS` and `~/Library/CloudStorage` marked `compressed,dataless`. Because canonical copies exist in the cloud, macOS classifies local chunks as purgeable.
- **Local APFS Snapshots & Caches:** Time Machine local deltas, OS update staging caches, and temporary swap pages.

Seeing DaisyDisk report **111.9 GB** in green on a 245 GB drive does **not** mean half the drive's data was wiped; it means the system has 20.4 GB of real free space plus 91.4 GB of evictable caches.

##### 2. The macOS Catalina+ System/Data Volume Split (The "41% Capacity" Illusion)

Since macOS Catalina, APFS split the startup disk into two volumes within the same container:
- **`/` (`disk3s1s1`)**: A cryptographically sealed, read-only system snapshot containing **only macOS** (~13 GB).
- **`/System/Volumes/Data` (`disk3s5`)**: Where all user data, home directories, repos, containers, and tools live (~178 GB).

When running `df -h /`, BSD `df` calculates capacity using **only the mounted volume specified**:

$$\text{Capacity on /} = \frac{\text{Used on /}}{\text{Used on /} + \text{Free Container Space}} = \frac{13\text{ GiB}}{13\text{ GiB} + 19\text{ GiB}} = \frac{13}{32} \approx \mathbf{41\%}$$

It completely excludes the 178 GB on `/System/Volumes/Data`. Comparing `df -h /` with the data volume reveals the true picture:

```sh
df -h / && df -h /System/Volumes/Data
# Filesystem        Size    Used   Avail Capacity  Mounted on
# /dev/disk3s1s1   228Gi    13Gi    19Gi    41%    /
# /dev/disk3s5     228Gi   178Gi    19Gi    91%    /System/Volumes/Data
```

An operator or automated report seeing "Capacity: 37%–41%" on `/` might assume storage utilization was cut in half, when in reality `/System/Volumes/Data` remains at **91% utilization**.

#### Operator Ground Truth Checklist

To avoid false alarms when triaging storage:
1. **Raw Storage Truth:** Always check `df -h /System/Volumes/Data` or `diskutil apfs list` (never rely solely on `df -h /`).
2. **Virtual Machines & Caches:** Use `ls -ls` (allocated blocks $\times$ 512B) or `du -sh` on `~/.colima` to verify physical footprint vs virtual ceiling.
3. **Platform Multi-Bucket View:** Run `zdots-storage` for verified, bucket-level telemetry across models, docker, ingest buffers, tool caches, and logs.

### OpenObserve (logs/metrics/traces)

Observability is native now (the containerized LGTM stack was retired, Z-134).
OpenObserve self-trims via `ZDOTS_O2_RETENTION_DAYS` — **3 days** on home, **2
days** enforced on work (`.zdots.work`, the hotter/PHI-adjacent box). Its data
dir is `${XDG_DATA_HOME:-~/.local/share}/openobserve`. To wipe and start fresh:

```sh
openobserve-ctl reinit   # disposable telemetry; recreates root from Keychain
```

See [openobserve](openobserve.md).

Only do this when historical traces/logs are not needed. OTel spans from
the current session will resume flowing immediately after restart.

**If the store is large, retention is a ceiling, not a brake — suspect ingest
volume.** A derived spanmetrics histogram (`traces_span_metrics_*_bucket`) once
reached 10 GB (~60% of the store) at ~2 GB/day (Z-156); the fix was source-level
connector tuning, not shorter retention. `zdots-doctor` warns when the store
exceeds `ZDOTS_O2_SIZE_WARN_GB` (default 8). Diagnose and tune with the
`/telemetry-volume` runbook.

---

## LLM Models

Models are GGUF files in `$ZDOTS_AI_MODELS_DIR`
(default: `~/.local/share/llama-cpp/models/`).

**Policy:** One active model at a time. Prune aggressively.

```sh
llama-ctl df            # show model directory size and contents
llama-ctl model-list    # list downloaded models; marks active
llama-ctl model-prune   # delete all except active model
```

### External storage

If primary disk is low, point models at an external SSD:

```sh
# In .zdots.env:
export ZDOTS_AI_MODELS_DIR=/Volumes/External/llama-models
```

All `llama-ctl` commands respect this variable.

### Model sizes (active profiles)

| Profile | Model | Disk |
|---|---|---|
| standard | Qwen2.5-Coder-7B Q4_K_M | ~4.7GB |
| llama-3.1 | Meta-Llama-3.1-8B Q4_K_M | ~4.9GB |
| constrained | Qwen2.5-Coder-1.5B Q4_K_M | ~1.0GB |

When disk is critically low: switch to `constrained` profile + prune.

```sh
ZDOTS_AI_PROFILE=constrained llama-ctl model-download
llama-ctl model-prune     # removes standard/llama-3.1 GGUFs
```

---

## Disk Pressure Runbook

When `df -h /` shows less than 20GB free:

```sh
# 1. See what's using space
docker-df
llama-ctl df

# 2. Reclaim Docker (biggest win)
docker-reclaim -f

# 3. Reclaim stale models
llama-ctl model-prune

# 4. If still tight: switch to constrained AI profile
ZDOTS_AI_PROFILE=constrained llama-ctl model-download
llama-ctl model-prune
# Update .zdots.env: export ZDOTS_AI_PROFILE=constrained
# llama-ctl install && llama-ctl restart

# 5. Nuclear Docker option (destroys all containers/volumes):
# docker-reclaim -f  (already done above; step 2 is already aggressive)
```

---

## Agent Notes

- `docker-reclaim` without `-f` is always safe — prints usage only, no writes.
- `fstrim` step requires Colima to be running. Skips if Colima unavailable.
- Volume prune in `docker-reclaim` removes **all** unused volumes including named
  ones. (Observability no longer uses Docker volumes — OpenObserve stores data on
  the host filesystem under `~/.local/share/openobserve`.)
- Model prune uses `ZDOTS_AI_PROFILE` to determine which model to keep.
  Verify the right profile is active before pruning.
- `bin/docker-reclaim` source: inspect for exact prune order if uncertain.
