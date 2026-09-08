# transcribe-media

An [Agent Skill](https://github.com/openai/skills) that transcribes local video
and audio with [whisper.cpp](https://github.com/ggml-org/whisper.cpp), in any of
the 100 languages Whisper supports, and then analyzes the transcript.

Audio never leaves the machine. The skill is a `SKILL.md` plus a directory of
bash scripts, which is the portable Agent Skills layout, so it runs under any
agent that reads skills — Claude Code, OpenAI Codex, and others — and under none
of them, if you would rather just run the scripts yourself.

## Requirements

- `ffmpeg` and `ffprobe`
- whisper.cpp's CLI, packaged as `whisper-cli` or `whisper-cpp` depending on the
  distribution; `WHISPER_CLI=/path/to/binary` overrides the search
- `jq`, optional, used to validate the JSON output

```sh
brew install whisper-cpp ffmpeg      # macOS
pacman -S whisper.cpp ffmpeg         # Arch
nix-shell -p whisper-cpp ffmpeg      # Nix
```

Check the machine before doing anything else:

```sh
transcribe-media/scripts/check_environment.sh
```

## Installing the skill

| Runtime | Location |
| --- | --- |
| Claude Code, personal | `~/.claude/skills/transcribe-media/` |
| Claude Code, per project | `<project>/.claude/skills/transcribe-media/` |
| OpenAI Codex, global | `~/.codex/skills/transcribe-media/` |
| Anything else | clone anywhere and run the scripts directly |

Copy or symlink the `transcribe-media/` directory into place:

```sh
ln -s "$PWD/transcribe-media" ~/.claude/skills/transcribe-media
ln -s "$PWD/transcribe-media" ~/.codex/skills/transcribe-media
```

The same directory works in both; `agents/openai.yaml` supplies display metadata
to runtimes that want it and is ignored by the ones that do not.

## Using the scripts directly

```sh
S=transcribe-media/scripts

$S/download_model.sh small                    # ~466 MB, multilingual, cached once
$S/transcribe_media.sh talk.mp4               # auto-detect the language
$S/transcribe_media.sh --language nl talk.mp4 # transcribe Dutch
$S/transcribe_media.sh --detect-language talk.mp4   # 30s probe, then exit
$S/transcribe_media.sh --translate talk.mp4   # non-English speech, English output
$S/transcribe_media.sh --list-languages
$S/transcribe_media.sh --list-models
```

Each run writes `.txt`, `.srt`, `.vtt`, `.json`, and `.log` beside the input and
refuses to overwrite them without `--force`.

### Languages

`--language` takes any Whisper code; `--list-languages` prints all 100. The
default is `auto`, which decides from a single 30 second window — pass the code
explicitly when you know it, and use `--detect-language` when you do not, so a
wrong guess costs seconds rather than the whole recording.

Every language except English needs a multilingual model, meaning any model name
without the `.en` suffix. An `.en` model handed non-English audio does not fail;
it produces confident, fluent, wrong English, so the script rejects that
combination rather than letting it run. Cantonese (`yue`) exists only in
`large-v3` and `large-v3-turbo`.

`--translate` renders non-English speech as English. That is a translation, not
a transcript, so its outputs are named `.translation.*`. To keep both, run twice
and pass `--output-suffix` to distinguish them. `--initial-prompt` seeds the
decoder with terminology, names, or a script preference such as Traditional
versus Simplified Chinese.

### Models

`small` is the default: multilingual, ~466 MB, a reasonable accuracy/speed
balance. Move to `medium` or `large-v3` for difficult audio, specialized
terminology, or a language Whisper saw less of during training. Models are
cached in `$WHISPER_MODEL_CACHE`, defaulting to `${XDG_CACHE_HOME:-~/.cache}/whisper`,
and are downloaded only by `download_model.sh` — never implicitly mid-transcription.

## Environment variables

| Variable | Effect |
| --- | --- |
| `WHISPER_CLI` | Explicit path to the whisper.cpp binary |
| `WHISPER_CPP_HOME` | Root of a whisper.cpp source build |
| `WHISPER_MODEL` | Default model name |
| `WHISPER_MODEL_CACHE` | Model cache directory |
| `WHISPER_LANGUAGE` | Default language code |
