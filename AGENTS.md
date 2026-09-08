# Repository guide for coding agents

This repository contains one Agent Skill, `transcribe-media/`, which transcribes
local video and audio with ffmpeg and whisper.cpp and then analyzes the result.

## Layout

```
transcribe-media/
├── SKILL.md                    entry point: name + description frontmatter, then instructions
├── agents/openai.yaml          UI-facing metadata read by OpenAI runtimes, ignored elsewhere
└── scripts/
    ├── check_environment.sh    preflight: report binaries, cache, and cached models
    ├── transcribe_media.sh     extract audio and run whisper.cpp
    ├── download_model.sh       fetch a model into the shared cache
    ├── whisper_env.sh          shared: locate the whisper binary and model caches
    ├── model_catalog.sh        shared: supported models and their sizes
    └── language_catalog.sh     shared: the 100 languages Whisper supports
```

## Working on the skill

- `SKILL.md` frontmatter carries exactly `name` and `description`. Adding other
  keys narrows the set of runtimes that accept the skill; put runtime-specific
  metadata in `agents/` instead.
- Keep `SKILL.md` free of assumptions about the host agent, the operating
  system, the package manager, and which models happen to be cached. Anything
  environment-specific belongs in `check_environment.sh`, which reports it at
  runtime.
- The scripts are the contract. They must run under bash with no interpreter
  beyond ffmpeg, whisper.cpp, and optionally jq, so that a runtime with nothing
  but shell access can use the skill.
- `bash -n` every script after editing. `scripts/language_catalog.sh` mirrors the
  language table in `openai/whisper`'s `tokenizer.py`; verify against upstream
  rather than editing it from memory.
