---
name: ingest-media
description: Transcribe an audio/video source (local MP4/audio, or a URL) and turn it into a synthesized, remembered Lesson in the Knowledge Layer — LOCAL-FIRST. Pipeline: fetch → whisper transcribe → local-LLM map-reduce synthesis → vault + DB ingest, with originals retained durably. Use for "ingest this video/talk", "transcribe and remember this", or testing the work-machine MP4 ingestion flow.
---

# /ingest-media — transcribe → synthesize → remember, on-box

The work-machine flow is **MP4 → transcript → lesson**, all local (PHI-safe, no
cloud tokens). This skill is that pipeline. A URL source (YouTube etc.) is the
home dry-run of the same chain. Inference stays on-box throughout — whisper for
transcription, the local LLM for synthesis.

Usage: `/ingest-media <path-to-mp4|audio>` · `/ingest-media <url>`

## Step 0 — Preconditions
- `curl -sf http://127.0.0.1:11500/v1/models` — local LLM up (synthesis needs it).
- Deps: `whisper-ctl`, `ai-query`, `zdots-ctx`. URL sources also need `yt-dlp` + `ffmpeg`.
- HOME context for URL fetch (egress). Treat the *content's* sensitivity as the
  data class: a patient-recorded MP4 is PHI — it stays on-box, never goes to a
  cloud subagent prompt; the local chain is the only path.

## Step 1 — Get audio
- **Local MP4/audio:** use the file directly (extract audio with `ffmpeg -i in.mp4 -ac 1 -ar 16000 out.wav` if whisper wants WAV).
- **URL:** `yt-dlp -f bestaudio --extract-audio --audio-format wav -o "src.%(ext)s" <url>`.
  Grab metadata first (`yt-dlp --print "%(title)s … %(duration_string)s"`) — duration sets transcription cost.

## Step 2 — Transcribe (the faithful path = whisper)
`whisper-ctl transcribe <audio.wav>` → `<audio>.wav.txt`. large-v3-turbo does
~31 min of audio in ~5 min on Apple Silicon. **Run long transcriptions in the
background** so you're not blocked.

**Do NOT rely on YouTube auto-captions as the transcript.** They are
rolling-window VTT with word-level timing and ~3.7× scroll-duplication;
`zdots-ingest-prepare` does not clean them (Z-154 / Z-150 — the YouTube adapter
needs a de-roll step). MP4 has no captions anyway — whisper is the real path.
If you *do* pull captions, use them only as a **two-signal cross-check** (de-roll
via overlap-reconstruction first; whisper-vs-caption word counts should agree
within ~1%).

## Step 3 — Synthesize with the LOCAL LLM (map-reduce)
A full transcript (~5k words ≈ 29KB) is near `ai-query`'s 32KB ceiling AND
`ai-query`'s default `--timeout` is **30s** — a single big synthesis call times
out (exit 5 = AIQ_TRANSPORT). So **map-reduce**:
1. **Map:** `split -n l/3 transcript chunk_` → `cat chunk | ai-query --timeout 240 --temperature 0.3 'extract key points…'` per chunk.
2. **Reduce:** feed the chunk-summaries to one `ai-query --timeout 300` call asking for a structured markdown report: `## Core Thesis` / `## Key Concepts & Claims` / `## Synthesized Lessons` / `## What To Investigate Next`.
Keep the model faithful — "no invention, transcript only."

## Step 4 — Retain originals (durable, NON-git)
Audio is large (a 31-min WAV is ~360MB) — it must NOT go in a git vault. Retain
under `~/.local/state/zdots/ingest-sources/<slug>-<id>/`:
source audio · whisper transcript · any captions · the synthesis · a
`MANIFEST.md` with full provenance (URL/title/channel/date, file roles, the
two-signal word counts). This is the retranscription/clarification source.

## Step 5 — Remember it (vault + DB)
The Knowledge Vault (`~/my/knowledge/`) is the source of truth; the DB mirrors it.
1. Write the lesson to `~/my/knowledge/lessons/<slug>.md` with the **required
   ingest frontmatter** (exact schema — generic YAML is rejected):
   ```yaml
   ---
   type: lesson
   slug: <kebab-slug>
   title: "<title>"
   tags: [ai, …, video-ingest]
   source: youtube:<id>   # or mp4:<filename>
   ---
   ```
   Point the body's provenance line at the Step-4 retention path.
2. `zdots-ctx ingest --dry-run <file>` → expect `1 ingested, 0 skipped`. Fix
   frontmatter if it says `[skip] no frontmatter`.
3. `zdots-ctx ingest <file>` (real). Verify: `zdots-ctx status` (lessons count
   rose) and `zdots-ctx query --semantic "<topic>"` returns it (embedding ran).

## Closing report
Give the user: the synthesis (the four sections), the retention path, the vault
+ DB confirmation, and any pipeline finding worth a `zdots-issue`.

## Rules
- Local-first, always. Whisper + `ai-query` keep audio and text on-box — never
  paste transcript chunks into a cloud subagent; that defeats the PHI boundary.
- `~/my` is a separate repo with 100s of unrelated changes possible — when
  committing the lesson, `git add` the **one** lesson path only. Never sweep.
- Don't hand-fix `zdots-ingest-prepare` for caption quirks — file it (Z-154/Z-150)
  and work around at the task level (AGENTS.md §5).
- Few word do trick.
