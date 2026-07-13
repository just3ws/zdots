# YouTube Transcription Pipeline

A high-performance pipeline for deep context extraction from YouTube videos, leveraging `yt-dlp` and `whisper.cpp`.

## Architecture
The pipeline is designed as an "Opaque Seam" recipe. It orchestrates several specialized tools:
1. **Extraction**: `yt-dlp` captures the highest quality audio stream and full video metadata (`.info.json`).
2. **Normalization**: `ffmpeg` converts the raw audio to 16kHz mono WAV (required for precision transcription).
3. **Inference**: `whisper.cpp` performs absolute-max-accuracy transcription using the `large-v3` model.
4. **Context Capture**: Generates 5 formats (`.txt`, `.json`, `.srt`, `.vtt`, `.csv`) to maximize downstream utility (e.g., RAG, search, subtitling).
5. **Diarization**: Optional `pyannote.audio` integration (via `bin/diarize`) for speaker identification.

### `ingest_media` pipeline stages (the queue path)
The durable queue path (`ingest_media`, `lib/zdots/jobs/ingest_media.rb`) walks a
declared `PIPELINE` — add a stage there and both the executor and the Mermaid
diagram (`docs/generated/ingest-pipeline.mmd`, drift-tested) follow. Stages:
`raw → cleaned → boundaries → distilled → timeline → diarized → embedded → published`.

- **boundaries**: marks theme-song intro/outro + the real interview span from the
  timestamped whisper JSON (writes `<id>.boundaries.json`). Non-destructive —
  annotates; never edits the transcript. Jingle registry: `etc/theme-songs.yml`
  (detect phrases + canonical lyrics). Detector: `lib/zdots/transcript_boundaries.rb`
  (shared by the stage and `bin/zdots-backfill-boundaries`, a re-transcription-free
  backfill over existing JSONs).
- **diarized** (opt-in `ZDOTS_DIARIZE=1`): the speaker-count hint comes from the
  caller as `payload["num_speakers"]` (site passes `interviewees + 1`), applied as
  a ±1 bracket, not an exact count. **Env gotcha:** the launchd worker only sees
  `HUGGINGFACE_TOKEN` because `bin/zdots-worker`'s `cmd_run` loads it from Keychain
  — `env.sh` only covers interactive shells. A stale `HF_TOKEN=mock` triggers
  `bin/diarize`'s mock mode (degenerate 1-speaker sidecar), so `cmd_run` forces
  both names to the real Keychain value.

**Sanity gate (the virtuous loop):** the site's `bin/lib/transcript_sanity.rb` is
one shared definition of "is this output sane" — loop scoring + diarization sanity
(rejects `engine=*mock*`, empty segments, a lone segment spanning the whole file).
Both `report_transcript_loops.rb` (detect) and `stage_completed_transcripts.rb`
(promote) call it, so "flagged as looping" and "refused promotion" can't drift.

## Usage
Invoked via the `ztranscribe` alias:

```bash
ztranscribe <youtube_url> [options]
```

### Options
- `--diarize`: identify speakers. Requires `HUGGINGFACE_TOKEN` + accepted model licenses — see [Diarization setup](#diarization-setup-token--licenses).
- `--profile <p>`: choose a Whisper profile (`max-accuracy`, `standard`, `light`).
- `--keep-media`: retain the heavy `.wav` file after processing.

## Locality & Hygiene
- **Outputs**: Stored in `~/Downloads/transcripts/<video_id>/`.
- **Cleanup**: Discards raw media files by default to preserve disk space.
- **Isolation**: Machine Learning dependencies for diarization are isolated via `uv`.

## Hardware Advantage
Fully optimized for **Apple Silicon (M4)**. The pipeline utilizes the GPU via `metal` and features like **Flash Attention** to process audio at ~3x real-time.

## Diarization setup (token & licenses)

Diarization (`--diarize`, and the `ingest_media` `diarized` stage) runs
`pyannote/speaker-diarization-3.1` via `bin/diarize`. It needs a Hugging Face
token **and** three accepted model licenses. Accepting only the top-level
`speaker-diarization-3.1` license is **not** enough — the pipeline loads two more
gated repos.

### Token — ✅ verified working
- **Env var:** `HUGGINGFACE_TOKEN` (or `HF_TOKEN`); read directly by `bin/diarize`.
- **Scope:** **Read** is sufficient — a classic read token, or a fine-grained
  token with *"Read access to contents of all public gated repos you can access."*
- **Location:** `~/.config/zsh/.env`. The zdots transcription service is the only
  thing that calls `bin/diarize`; the site repo is a thin consumer of the
  resulting sidecar and never needs the token.

### Licenses — ✅ verified accessible with the current token
Accept each once at hf.co while logged in as the token's owner. Each is an
instant click-through form (name/website → immediate access):

| Gated repo | Role | Accept at |
|---|---|---|
| `pyannote/speaker-diarization-3.1` | the pipeline | https://hf.co/pyannote/speaker-diarization-3.1 |
| `pyannote/segmentation-3.0` | voice-activity / segmentation | https://hf.co/pyannote/segmentation-3.0 |
| `pyannote/wespeaker-voxceleb-resnet34-LM` | speaker embeddings | https://hf.co/pyannote/wespeaker-voxceleb-resnet34-LM |

Verified by loading the full pipeline end-to-end (`Pipeline.from_pretrained`
downloaded every component with no 403).

### Do NOT use `community-1` — and keep the version pins
`bin/diarize` pins `pyannote.audio>=3.1,<4` deliberately. With **unpinned** deps,
`uv` resolves pyannote.audio **4.x**, whose 3.1 loader instead fetches
`pyannote/speaker-diarization-community-1` — a *separate* gated repo that
accepting `speaker-diarization-3.1` does **not** unblock. The pins keep the tool
on the 3.x stack, which uses only the three licenses above. The full pinned set
(in the script's PEP-723 header — don't loosen):

- **Python 3.10–3.12** — torch 2.x has no macOS-arm64 wheel for 3.13+, and 3.14
  forces pyannote 4.x (→ community-1).
- **torch / torchaudio `>=2.2,<2.5`**, **huggingface_hub `>=0.19,<0.26`** — the
  latter keeps the `use_auth_token=` API that pyannote 3.x calls.

`uv run` reads these from the header and fetches a matching Python automatically,
so the tool stays reproducible even though the machine's ambient Python is 3.14.
