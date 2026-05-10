# YouTube Transcription Pipeline

A high-performance pipeline for deep context extraction from YouTube videos, leveraging `yt-dlp` and `whisper.cpp`.

## Architecture
The pipeline is designed as an "Opaque Seam" recipe. It orchestrates several specialized tools:
1. **Extraction**: `yt-dlp` captures the highest quality audio stream and full video metadata (`.info.json`).
2. **Normalization**: `ffmpeg` converts the raw audio to 16kHz mono WAV (required for precision transcription).
3. **Inference**: `whisper.cpp` performs absolute-max-accuracy transcription using the `large-v3` model.
4. **Context Capture**: Generates 5 formats (`.txt`, `.json`, `.srt`, `.vtt`, `.csv`) to maximize downstream utility (e.g., RAG, search, subtitling).
5. **Diarization**: Optional `pyannote.audio` integration (via `bin/diarize`) for speaker identification.

## Usage
Invoked via the `ztranscribe` alias:

```bash
ztranscribe <youtube_url> [options]
```

### Options
- `--diarize`: identify speakers. Requires `HUGGINGFACE_TOKEN`.
- `--profile <p>`: choose a Whisper profile (`max-accuracy`, `standard`, `light`).
- `--keep-media`: retain the heavy `.wav` file after processing.

## Locality & Hygiene
- **Outputs**: Stored in `~/Downloads/transcripts/<video_id>/`.
- **Cleanup**: Discards raw media files by default to preserve disk space.
- **Isolation**: Machine Learning dependencies for diarization are isolated via `uv`.

## Hardware Advantage
Fully optimized for **Apple Silicon (M4)**. The pipeline utilizes the GPU via `metal` and features like **Flash Attention** to process audio at ~3x real-time.
