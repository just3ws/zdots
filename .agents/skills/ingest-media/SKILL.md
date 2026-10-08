---
name: ingest-media
description: Ingest, transcribe, and synthesize YouTube URLs or local audio/video into lessons, vector embeddings, and curated timelines. Use when transcribing video or audio, running zdots-ingest-media, diagnosing ingest_media pipeline jobs, or configuring yt-dlp cookie authentication.
---

# Ingest-Media — Video & Audio Knowledge Pipeline

Orchestrates the acquisition, transcription, synthesis, and knowledge ingestion of remote URLs (YouTube, Vimeo) or local audio/video into the `my` database (`lessons`, `media_sources`, `knowledge_chunks`).

## Quick Start

```bash
# Ingest YouTube URL (default profile: standard; runs full pipeline)
zdots-ingest-media "https://www.youtube.com/watch?v=..."

# Ingest local media (requires non-PHI label for vault reference)
zdots-ingest-media /path/to/recording.mp3 --label "Team Sync 2026-10-08"

# Monitor progress via live bus channel
bus watch "ingest-<source_id>"
```

## Pipeline Stages

Declared in `lib/zdots/jobs/ingest_media.rb` (`PIPELINE`):
1. **primed**: Context primer from title/description via local LLM.
2. **raw**: Whisper transcription (fan-out into windowed chunks for sources > 30m).
3. **cleaned**: Applies confirmed `known_terms` vocabulary corrections.
4. **boundaries**: Audio boundaries (intro/outro jingles, interview span).
5. **distilled**: LLM executive knowledge briefing and structured takeaways.
6. **timeline**: Curated timestamped moments for video navigation.
7. **diarized**: Acoustic speaker turns (`pyannote-3.1`; opt-in `ZDOTS_DIARIZE=1`).
8. **embedded**: Chunks transcript into `knowledge_chunks` with pgvector embeddings.
9. **published**: Export clips / social segments.

## Cookie Strategy & macOS TCC Constraints

YouTube bot-gates some fetches (*"Sign in to confirm you're not a bot"*).

- **Interactive Shells**: `export ZDOTS_YTDLP_COOKIES_FROM_BROWSER=firefox` (or `chrome`/`safari`/`brave`/`edge`).
- **Background Worker (`com.zdots.worker`)**: macOS TCC blocks launchd platform daemons from reading browser application support directories. You **must** use a Netscape-format file for background jobs:
  ```bash
  export ZDOTS_YTDLP_COOKIES_FILE="$HOME/.local/state/zdots/cookies.txt"
  ```
- **Automatic Fallback**: `recipes/yt-transcribe` and `bin/zdots-ingest-media` automatically probe and fall back to anonymous fetching if cookies are unreadable or missing.

## Troubleshooting & Worker Diagnostics

```bash
# Check worker status and logs
zsvc status worker
zsvc logs worker

# Check media_source status in PostgreSQL
psql -U zdots_ro my -c "SELECT id, source_id, title, ingest_status FROM media_sources ORDER BY created_at DESC LIMIT 5;"

# Requeue a failed job
zdots-ctx jobs --failed
zdots-ctx requeue <job_id>
```
