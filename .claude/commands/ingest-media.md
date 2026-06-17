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

Full actor/dataflow map + per-stage verification table:
[docs/ingest-media-pipeline.md](../../docs/ingest-media-pipeline.md).

## Step 0 — Preconditions
- `curl -sf http://127.0.0.1:11500/v1/models` — local LLM up (synthesis needs it).
- `zsvc list | grep zdots-worker` — the embed worker must be **running**, or
  semantic recall (Step 5) silently returns nothing. Start with `zsvc start worker`.
- Deps: `whisper-ctl`, `ai-query`, `zdots-ctx`. URL sources also need `yt-dlp` + `ffmpeg`.
- HOME context for URL fetch (egress). Treat the *content's* sensitivity as the
  data class: a patient-recorded MP4 is PHI — it stays on-box, never goes to a
  cloud subagent prompt; the local chain is the only path.
- **Set identity once** — every later step reuses these, so don't re-type paths:
  ```bash
  ID=<video-id-or-filename>; SLUG=<kebab-slug>
  DIR="$HOME/.local/state/zdots/ingest-sources/${SLUG}-${ID}"; mkdir -p "$DIR"
  ```

## Step 1 — Get audio
- **Local MP4/audio:** use the file directly (extract audio with `ffmpeg -i in.mp4 -ac 1 -ar 16000 out.wav` if whisper wants WAV).
- **URL:** grab metadata first — `yt-dlp --print "%(title)s|%(channel)s|%(duration_string)s|%(upload_date)s"` (duration sets transcription cost), then fetch **directly to whisper-ready 16k mono**:
  ```bash
  yt-dlp -f bestaudio --extract-audio --audio-format wav \
    --postprocessor-args "-ac 1 -ar 16000" -o "$DIR/source.%(ext)s" "$URL"
  ```
  Verify: `file "$DIR/source.wav"` → `WAVE … mono 16000 Hz`.

## Step 2 — Transcribe (the faithful path = whisper)
`whisper-ctl transcribe "$DIR/source.wav"` → `source.wav.txt` (clean prose, no
inline timestamps). large-v3-turbo does ~31 min of audio in ~5 min on Apple
Silicon (~16 min ran in ~108s in the validation run). **Run long transcriptions
in the background** so you're not blocked — redirect to `"$DIR/whisper.log"`.

**Progress signal** (whisper is otherwise blind): `tail -f "$DIR/whisper.log"` —
each line is stamped `[HH:MM:SS.mmm --> …]`; compare the last timestamp to the
video duration to gauge how far along it is. Done when `source.wav.txt` exists
and `grep -cE '\[[0-9]{2}:' source.wav.txt` is **0** (timestamps stripped).

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
1. **Map** — chunk with **portable** `split` (the GNU `split -n l/3` is rejected
   by macOS BSD `split` and silently yields zero chunks), then summarize each:
   ```bash
   cd "$DIR"; lines=$(wc -l < source.wav.txt); split -l $(((lines+2)/3)) source.wav.txt chunk_
   for c in chunk_??; do
     [[ -s "$c" ]] || { echo "SKIP empty $c"; continue; }   # ai-query HALLUCINATES on empty stdin (exit 0)
     ai-query --timeout 240 --temperature 0.3 'Extract key points/claims/named entities. Bullet list. No invention, transcript only.' < "$c" > "$c.sum"
     echo "$c: in=$(wc -w <$c)w out=$(wc -w <$c.sum)w"   # sanity: out must be << in and non-zero
   done
   ```
2. **Reduce:** feed the chunk-summaries to one `ai-query --timeout 300` call asking for a structured markdown report with EXACTLY these sections: `## Core Thesis` / `## Key Concepts & Claims` / `## Synthesized Lessons` / `## What To Investigate Next`.
Keep the model faithful — "no invention, transcript only." **Caveat:** whisper
mis-hears proper nouns and the LLM propagates them (e.g. Jan→"Gen", Ollama→"Olama");
note this in the MANIFEST and treat names as approximate.

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
   `type`/`slug`/`title`/`tags[]` are validated; `slug` must be non-empty and
   `type` must be `lesson`. **Lead the body with a one-line summary**, then the
   provenance line pointing at the Step-4 retention path — `zdots-ctx query`
   shows the first body line as the preview, so don't bury the thesis under
   boilerplate.
2. `zdots-ctx ingest --dry-run <file>` → expect `1 ingested, 0 skipped, 0 errors`.
   Fix frontmatter if it says `[skip] no frontmatter` / `[skip] missing slug`.
3. `zdots-ctx ingest <file>` (real) → `[ok] lesson '<slug>'`.
4. **Verify it landed — three signals, no ambiguity:**
   - `zdots-ctx status` — lessons count rose by exactly 1.
   - **Embed drained** — ingest only *queues* the embed job; `zdots-worker`
     drains it async (seconds on a healthy queue). The authoritative signal is
     that **semantic recall returns the lesson** — poll it rather than hunting
     the job row:
     ```bash
     for i in $(seq 1 18); do
       zdots-ctx query --semantic "<topic>" 2>/dev/null | sed -n '/SEMANTIC MATCHES: LESSONS/,$p' | grep -qi "<distinctive-phrase>" && { echo "embedded ✓"; break; }
       sleep 5   # ~90s ceiling; if it never lands the queue is stuck (see below)
     done
     ```
     If it never lands, the queue is stuck — a prior non-recoverable job
     (e.g. `[:phi_suppressed, …]`) can loop and starve yours; check
     `zdots-ctx jobs` and file a `zdots-issue`, don't hand-fix the worker.
   - **Keyword recall** — `zdots-ctx query "<term>"`. Mind the output format:
     keyword results sit under a lowercase `searching lessons (text)...` header
     (NOT `LESSONS` — that's the *semantic* header `### SEMANTIC MATCHES: LESSONS`).
     Grepping for `LESSONS` silently misses keyword hits.

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
