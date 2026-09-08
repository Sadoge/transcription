---
name: transcribe-media
description: Transcribe English-language local video or audio files with ffmpeg and whisper.cpp, produce reusable transcript and subtitle files, and optionally analyze the content into summaries, chapters, decisions, action items, or claims. Use for recorded media; not for live transcription or media editing.
---

# Transcribe Media

Keep the source media local unless the user explicitly requests an online service. Use the bundled scripts for the repeatable media-processing steps and use model reasoning for the requested analysis.

## Transcribe

1. Resolve the input file. When several media files are plausible and the choice cannot be inferred safely, list them and ask which one to process.
2. Inspect the selected file with `ffprobe`. Report its duration and whether it has an audio stream before starting a long job.
3. Run `scripts/transcribe_media.sh`. It extracts temporary 16 kHz mono audio and writes `.txt`, `.srt`, `.vtt`, and `.json` outputs beside the source by default. English (`en`) is the tested and configured default. Use another language code or `auto` only when the user requests best-effort non-English transcription.
4. Use multilingual `small` by default. It gave a good accuracy/speed balance on an hour-long English technical recording and is already cached on the user's device. Do not download the separate `small.en` model without a demonstrated reason. Accept another cached model with `--model NAME`, a direct model file with `--model PATH`, or `WHISPER_MODEL`. Run either script with `--list-models` to see supported names.
5. Reuse models from `${WHISPER_MODEL_CACHE:-$HOME/.cache/whisper}`. The scripts also check a few established Whisper cache locations and never download during transcription. Never use Homebrew's `for-tests-ggml-tiny.bin`; it intentionally contains no model tensors.
6. If the selected model is missing, state its approximate size and obtain any permission required for network access before running `scripts/download_model.sh MODEL`. Downloads are written atomically to the shared cache. If that model already exists, the downloader leaves it untouched and exits successfully.
7. Choose a different model only when the tradeoff matters:
   - `tiny` or `base`: quick drafts and clean audio where speed matters most;
   - `small`: normal default for good local accuracy without a very large model;
   - `medium`: harder audio or terminology when extra time and memory are acceptable;
   - `large-v3-turbo`: stronger accuracy with a better speed tradeoff than full `large-v3`;
   - `large-v3`: maximum local quality when storage, memory, and processing time are secondary.
   English-only `.en` variants are appropriate only when the recording is known to be English. When uncertain about a larger model, compare a short representative excerpt before processing the full recording.
8. Use GPU execution by default. If Metal or GPU initialization fails, rerun with `--cpu` and set expectations that processing will take longer.
9. Validate the result: confirm all requested files exist and are nonempty, the JSON parses, and the last subtitle timestamp is close to the media duration. Spot-check the opening and ending text. State that names and specialized terminology may still need correction.

Do not overwrite existing transcript files unless the user requests it; the script requires `--force` for replacement. It removes extracted audio automatically unless `--keep-audio` is passed.

## Analyze

When the user requests analysis, read the complete transcript rather than only its beginning or selected excerpts. Match the output to the request. Useful modes include:

- concise or detailed summary;
- topic outline or timestamped chapters;
- decisions, commitments, and action items;
- arguments, evidence, assumptions, and counterpoints;
- lessons converted into an implementation or study plan;
- questions left unresolved and claims that would need external verification.

Distinguish the speakers' claims from your own inference. Do not present promotional claims, numbers, or predictions in the recording as independently verified facts. Preserve uncertainty around unclear names and technical terms instead of silently inventing corrections.

Return a concise analysis in chat by default. When the user requests a reusable artifact, or when the analysis is substantial, save `<transcript-base>.analysis.md` beside the transcript and link it in the response.

## Speaker Labels and Cleanup

Whisper's `--diarize` option only separates stereo channels; it is not general multi-speaker diarization. Do not promise reliable speaker identities without an appropriate diarization workflow or user-provided speaker information.

Never delete the user's source media. Treat downloaded models as reusable cache files; do not replace, redownload, or remove them without an explicit user request. Remove generated intermediate audio only when it is clearly disposable or the user asks for cleanup.
