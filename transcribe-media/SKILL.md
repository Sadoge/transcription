---
name: transcribe-media
description: Transcribe local video or audio files in any of Whisper's 100 languages using ffmpeg and whisper.cpp, produce reusable transcript and subtitle files, optionally translate non-English speech into English, and analyze the content into summaries, chapters, decisions, action items, or claims. Use for recorded media in any language; not for live transcription or media editing.
---

# Transcribe Media

Keep the source media local unless the user explicitly requests an online service. Use the bundled scripts for the repeatable media-processing steps and use model reasoning for the requested analysis.

The scripts are plain POSIX-style bash and make no assumption about which agent is running them, which operating system they are on, or which packages are installed. Do not assume any of that either: check, then report what you found.

## Check the environment

Run `scripts/check_environment.sh` before promising a transcription. It prints the resolved `ffmpeg`, `ffprobe`, and whisper.cpp binaries, the model cache in use, and which models are already cached, then exits nonzero if anything required is missing. It installs and downloads nothing.

The whisper.cpp binary is called `whisper-cli` in some packages and `whisper-cpp` in others, and a source build leaves it under `build/bin/`. The scripts resolve all of these; `WHISPER_CLI` overrides the search with an explicit path. If a dependency is missing, state exactly what is missing and obtain permission before installing anything.

## Choose the language

1. If the user names the language, pass its code with `--language`. `--list-languages` prints all 100 supported codes with their names.
2. If the language is unknown, run `scripts/transcribe_media.sh --detect-language INPUT` first. It extracts a 30 second probe, reports the detected code, and exits without transcribing, so a wrong guess costs seconds instead of an hour. Use `--probe-offset SECONDS` to skip music, silence, or a non-representative introduction.
3. Passing an explicit code is more reliable than leaving the default `auto`, which decides from a single 30 second window. When you do transcribe with `auto`, the script reports the language it detected; repeat that to the user and ask them to confirm it before they rely on the transcript.
4. Multilingual models are required for every language except English. The `.en` models do not error on other languages, they transcribe them into fluent and wrong English, so the script refuses that combination outright.
5. Use `--translate` for an English rendering of non-English speech. This produces a translation, not a verbatim transcript, and outputs are labelled `.translation.*` instead of `.transcript.*`. When the user wants both, run twice and give the second run an `--output-suffix`.
6. For terminology, names, or a specific script such as Traditional versus Simplified Chinese, pass `--initial-prompt` with a few representative words. It steers the decoder and costs nothing.
7. Cantonese (`yue`) exists only in `large-v3` and `large-v3-turbo`. Accuracy on low-resource languages drops sharply on the smaller models; prefer `medium` or larger when the language is not well represented.

## Transcribe

1. Resolve the input file. When several media files are plausible and the choice cannot be inferred safely, list them and ask which one to process.
2. Inspect the selected file with `ffprobe`. Report its duration and whether it has an audio stream before starting a long job.
3. Run `scripts/transcribe_media.sh`. It extracts temporary 16 kHz mono audio and writes `.txt`, `.srt`, `.vtt`, and `.json` outputs beside the source by default.
4. Use multilingual `small` by default. It is a good accuracy/speed balance for clear speech in well-represented languages. Accept another cached model with `--model NAME`, a direct model file with `--model PATH`, or `WHISPER_MODEL`. Run either script with `--list-models` to see supported names.
5. Reuse models from the cache reported by `check_environment.sh` (`WHISPER_MODEL_CACHE`, otherwise `${XDG_CACHE_HOME:-~/.cache}/whisper`). The scripts also check a few other established Whisper cache locations and never download during transcription. On macOS, never use Homebrew's `for-tests-ggml-tiny.bin`; it intentionally contains no model tensors.
6. If the selected model is missing, state its approximate size and obtain any permission required for network access before running `scripts/download_model.sh MODEL`. Downloads are written atomically to the shared cache. If that model already exists, the downloader leaves it untouched and exits successfully.
7. Choose a different model only when the tradeoff matters:
   - `tiny` or `base`: quick drafts and clean audio where speed matters most;
   - `small`: normal default for good local accuracy without a very large model;
   - `medium`: harder audio, specialized terminology, or a less common language;
   - `large-v3-turbo`: stronger accuracy with a better speed tradeoff than full `large-v3`;
   - `large-v3`: maximum local quality, and the only option for Cantonese.
   English-only `.en` variants are appropriate only when the recording is known to be English. When uncertain about a larger model, compare a short representative excerpt before processing the full recording.
8. GPU execution is used automatically when the installed whisper.cpp build supports it, which depends on the build rather than on the operating system. If GPU initialization fails, rerun with `--cpu` and set expectations that processing will take considerably longer.
9. Validate the result: confirm all requested files exist and are nonempty, the JSON parses, and the last subtitle timestamp is close to the media duration. Spot-check the opening and ending text, and confirm it is in the language you expected. State that names and specialized terminology may still need correction.

Do not overwrite existing transcript files unless the user requests it; the script requires `--force` for replacement. It removes extracted audio automatically unless `--keep-audio` is passed.

## Analyze

When the user requests analysis, read the complete transcript rather than only its beginning or selected excerpts. Match the output to the request. Useful modes include:

- concise or detailed summary;
- topic outline or timestamped chapters;
- decisions, commitments, and action items;
- arguments, evidence, assumptions, and counterpoints;
- lessons converted into an implementation or study plan;
- questions left unresolved and claims that would need external verification.

Write the analysis in the language the user is speaking to you in, not necessarily the language of the recording, unless they ask otherwise. When quoting a non-English transcript, keep the original wording and add a translation next to it rather than replacing it. Transcription errors are more frequent in non-English and low-resource languages, so treat unusual phrasing as possible mistranscription rather than as a meaningful choice of words.

Distinguish the speakers' claims from your own inference. Do not present promotional claims, numbers, or predictions in the recording as independently verified facts. Preserve uncertainty around unclear names and technical terms instead of silently inventing corrections.

Return a concise analysis in your reply by default. When the user requests a reusable artifact, or when the analysis is substantial, save `<transcript-base>.analysis.md` beside the transcript and reference it in the response.

## Speaker Labels and Cleanup

Whisper's `--diarize` option only separates stereo channels; it is not general multi-speaker diarization. Do not promise reliable speaker identities without an appropriate diarization workflow or user-provided speaker information.

Never delete the user's source media. Treat downloaded models as reusable cache files; do not replace, redownload, or remove them without an explicit user request. Remove generated intermediate audio only when it is clearly disposable or the user asks for cleanup.
