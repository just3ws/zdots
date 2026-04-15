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
5. `colima prune` — unused Colima instances/snapshots
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

### LGTM stack (Grafana/Loki/Tempo/Mimir)

The LGTM stack runs in Colima. Config: `etc/docker-compose.lgtm.yaml`.

Loki and Tempo accumulate trace/log data over time. To prune stale data:

```sh
# Stop and remove LGTM stack (data volumes included):
cd ~/.config/zsh && docker compose -f etc/docker-compose.lgtm.yaml down -v

# Restart fresh:
docker compose -f etc/docker-compose.lgtm.yaml up -d
```

Only do this when historical traces/logs are not needed. OTel spans from
the current session will resume flowing immediately after restart.

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
| reasoning | Qwen2.5-7B Q4_K_M | ~4.7GB |
| constrained | Qwen2.5-Coder-1.5B Q4_K_M | ~1.0GB |

When disk is critically low: switch to `constrained` profile + prune.

```sh
ZDOTS_AI_PROFILE=constrained llama-ctl model-download
llama-ctl model-prune     # removes standard/reasoning GGUFs
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

# 5. Nuclear Docker option (destroys all containers/volumes including LGTM):
# docker-reclaim -f  (already done above; step 2 is already aggressive)
```

---

## Agent Notes

- `docker-reclaim` without `-f` is always safe — prints usage only, no writes.
- `fstrim` step requires Colima to be running. Skips if Colima unavailable.
- Volume prune in `docker-reclaim` removes **all** unused volumes including named
  ones. If LGTM data must be preserved, stop the stack first so its volumes
  stay attached (attached volumes are not pruned).
- Model prune uses `ZDOTS_AI_PROFILE` to determine which model to keep.
  Verify the right profile is active before pruning.
- `bin/docker-reclaim` source: inspect for exact prune order if uncertain.
