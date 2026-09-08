#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/whisper_env.sh"
source "$script_dir/model_catalog.sh"
source "$script_dir/language_catalog.sh"

usage() {
  sed -n '/^# Transcribe/,/^$/p' "$0" | sed 's/^# //; s/^#$//'
}

# Transcribe a local video or audio file with whisper.cpp, in any language
# Whisper supports.
#
# Usage:
#   transcribe_media.sh [options] INPUT
#
# Options:
#   --model NAME|PATH     Cached model name or a ggml model file (default: small).
#   --model-cache DIR     Shared model cache (default: ~/.cache/whisper).
#   --list-models         List supported model names and exit.
#   --language CODE       Whisper language code, or auto (default: auto).
#   --list-languages      List supported language codes and exit.
#   --detect-language     Detect the spoken language and exit without transcribing.
#   --probe-offset SECS   Where the detection probe starts (default: 0).
#   --translate           Translate speech into English instead of transcribing it.
#   --initial-prompt TEXT Seed terminology, spelling, or script for the decoder.
#   --output-dir DIR      Output directory (default: beside INPUT).
#   --output-suffix LABEL Label in the output filenames (default: transcript).
#   --threads N           Whisper worker threads (default: 8).
#   --cpu                 Disable GPU acceleration.
#   --keep-audio          Keep the extracted 16 kHz mono WAV.
#   --force               Replace existing transcript outputs.
#   -h, --help            Show this help.
#
# Outputs:
#   <input-stem>.<label>.txt
#   <input-stem>.<label>.srt
#   <input-stem>.<label>.vtt
#   <input-stem>.<label>.json
#   <input-stem>.<label>.log

model_spec="${WHISPER_MODEL:-small}"
model_cache="$(default_model_cache)"
model_path=""
output_dir=""
output_suffix=""
language="${WHISPER_LANGUAGE:-auto}"
initial_prompt=""
probe_offset="0"
threads="8"
use_cpu="false"
keep_audio="false"
force="false"
translate="false"
detect_only="false"
input_path=""
show_models="false"
show_languages="false"

while (($#)); do
  case "$1" in
    --model)
      model_spec="${2:?--model requires a name or path}"
      shift 2
      ;;
    --model-cache)
      model_cache="${2:?--model-cache requires a directory}"
      shift 2
      ;;
    --list-models)
      show_models="true"
      shift
      ;;
    --language)
      language="${2:?--language requires a code}"
      shift 2
      ;;
    --list-languages)
      show_languages="true"
      shift
      ;;
    --detect-language)
      detect_only="true"
      shift
      ;;
    --probe-offset)
      probe_offset="${2:?--probe-offset requires a number of seconds}"
      shift 2
      ;;
    --translate)
      translate="true"
      shift
      ;;
    --initial-prompt)
      initial_prompt="${2:?--initial-prompt requires text}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:?--output-dir requires a directory}"
      shift 2
      ;;
    --output-suffix)
      output_suffix="${2:?--output-suffix requires a label}"
      shift 2
      ;;
    --threads)
      threads="${2:?--threads requires a number}"
      shift 2
      ;;
    --cpu)
      use_cpu="true"
      shift
      ;;
    --keep-audio)
      keep_audio="true"
      shift
      ;;
    --force)
      force="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$input_path" ]]; then
        echo "Only one input file is supported per run." >&2
        exit 2
      fi
      input_path="$1"
      shift
      ;;
  esac
done

if [[ "$show_models" == "true" ]]; then
  list_models
  exit 0
fi

if [[ "$show_languages" == "true" ]]; then
  list_languages
  exit 0
fi

if [[ -z "$input_path" ]]; then
  usage >&2
  exit 2
fi

if ! whisper_cli="$(resolve_whisper_cli)"; then
  echo "Could not find the whisper.cpp command-line binary." >&2
  whisper_install_hint >&2
  exit 1
fi

for required_command in ffmpeg ffprobe; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Required command not found: $required_command" >&2
    whisper_install_hint >&2
    exit 1
  fi
done

if [[ ! -f "$input_path" ]]; then
  echo "Input file not found: $input_path" >&2
  exit 1
fi

if ! is_supported_language "$language"; then
  echo "Unknown language code: $language" >&2
  echo "Use --list-languages to see supported codes, or 'auto' to detect." >&2
  exit 2
fi

if [[ -f "$model_spec" ]]; then
  model_path="$model_spec"
  model_name="$(basename "$model_spec")"
else
  model_name="$model_spec"
  if is_supported_model "$model_spec"; then
    input_dir="$(cd "$(dirname "$input_path")" && pwd)"
    model_candidates=("$model_cache/ggml-$model_spec.bin")
    while IFS= read -r alternate_cache; do
      model_candidates+=("$alternate_cache/ggml-$model_spec.bin")
    done < <(alternate_model_caches)
    model_candidates+=(
      "$input_dir/ggml-$model_spec.bin"
      "$PWD/ggml-$model_spec.bin"
    )
    for candidate in "${model_candidates[@]}"; do
      if [[ -f "$candidate" ]]; then
        model_path="$candidate"
        break
      fi
    done
  else
    echo "Unknown model name or missing model path: $model_spec" >&2
    echo "Use --list-models to see supported names." >&2
    exit 1
  fi
fi

if [[ -z "$model_path" || ! -f "$model_path" ]]; then
  echo "Whisper model '$model_spec' is not cached ($(model_size "$model_spec"))." >&2
  echo "Run: $script_dir/download_model.sh $model_spec" >&2
  echo "No download was started." >&2
  exit 1
fi

if [[ "$model_path" == *for-tests* ]]; then
  echo "Refusing the empty Homebrew test model: $model_path" >&2
  exit 1
fi

# An English-only model does not error on other languages; it transcribes them
# into fluent, wrong English. Refuse the combination instead.
if is_english_only_model "$model_name"; then
  if [[ "$translate" == "true" ]]; then
    echo "Model '$model_name' is English-only and cannot translate." >&2
    echo "Use a multilingual model, for example --model ${model_name%.en}." >&2
    exit 2
  fi
  if [[ "$language" != "en" ]]; then
    echo "Model '$model_name' is English-only but --language is '$language'." >&2
    echo "Use a multilingual model (--model ${model_name%.en}) or --language en." >&2
    exit 2
  fi
elif [[ "$detect_only" != "true" && "$language" == "yue" && "$model_name" != large-v3* ]]; then
  echo "Cantonese (yue) was added in large-v3; model '$model_name' does not know it." >&2
  echo "Use --model large-v3 or --model large-v3-turbo." >&2
  exit 2
fi

if [[ "$translate" == "true" && "$language" == "en" ]]; then
  echo "Note: --translate with --language en has no effect; the output is English either way." >&2
fi

if [[ -z "$output_dir" ]]; then
  output_dir="$(cd "$(dirname "$input_path")" && pwd)"
else
  mkdir -p "$output_dir"
  output_dir="$(cd "$output_dir" && pwd)"
fi

if [[ -z "$output_suffix" ]]; then
  if [[ "$translate" == "true" ]]; then
    output_suffix="translation"
  else
    output_suffix="transcript"
  fi
fi

input_name="$(basename "$input_path")"
input_stem="${input_name%.*}"
output_base="$output_dir/$input_stem.$output_suffix"

if ! ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
  -of default=noprint_wrappers=1:nokey=1 "$input_path" | grep -q .; then
  echo "The input does not contain a readable audio stream: $input_path" >&2
  exit 1
fi

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/transcribe-media.XXXXXX")"
temporary_audio="$temporary_dir/audio.wav"
cleanup() {
  if [[ "$keep_audio" == "true" && -f "$temporary_audio" ]]; then
    cp "$temporary_audio" "$output_base.audio.wav"
  fi
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

# Whisper detects language from a single 30-second window, so the probe only
# needs that much audio. --probe-offset skips music or silence at the start.
if [[ "$detect_only" == "true" ]]; then
  echo "Extracting a 30 second probe from: $input_path (offset ${probe_offset}s)"
  ffmpeg -hide_banner -loglevel error -ss "$probe_offset" -t 30 -i "$input_path" \
    -map 0:a:0 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$temporary_audio" -y

  detect_output="$("$whisper_cli" -m "$model_path" -f "$temporary_audio" \
    -t "$threads" --detect-language 2>&1)" || {
    echo "$detect_output" >&2
    echo "Language detection failed." >&2
    exit 1
  }
  detected="$(printf '%s\n' "$detect_output" \
    | sed -n 's/.*auto-detected language: \([a-z][a-z]*\).*/\1/p' | tail -n 1)"
  if [[ -z "$detected" ]]; then
    echo "$detect_output" >&2
    echo "Could not parse a detected language from the model output." >&2
    exit 1
  fi
  echo "Detected language: $detected ($(language_name "$detected"))"
  echo "Rerun with --language $detected to transcribe."
  exit 0
fi

for extension in txt srt vtt json log; do
  output_file="$output_base.$extension"
  if [[ -e "$output_file" && "$force" != "true" ]]; then
    echo "Output already exists: $output_file" >&2
    echo "Use --force to replace them, or --output-suffix to write alongside them." >&2
    exit 1
  fi
done

echo "Extracting audio from: $input_path"
ffmpeg -hide_banner -loglevel error -i "$input_path" -map 0:a:0 -vn \
  -ac 1 -ar 16000 -c:a pcm_s16le "$temporary_audio" -y

whisper_arguments=(
  -m "$model_path"
  -f "$temporary_audio"
  -l "$language"
  -t "$threads"
  -ml 80
  -sow
  -of "$output_base"
  -otxt
  -osrt
  -ovtt
  -oj
  --print-progress
)

if [[ "$translate" == "true" ]]; then
  whisper_arguments+=(--translate)
fi

if [[ -n "$initial_prompt" ]]; then
  whisper_arguments+=(--prompt "$initial_prompt")
fi

if [[ "$use_cpu" == "true" ]]; then
  whisper_arguments+=(--no-gpu)
fi

if [[ "$language" == "auto" ]]; then
  echo "Transcribing with model: $model_path (language: auto-detect)"
else
  echo "Transcribing with model: $model_path (language: $language, $(language_name "$language"))"
fi
set +e
"$whisper_cli" "${whisper_arguments[@]}" 2>&1 \
  | tee "$output_base.log" \
  | sed -n '/progress =/p; /saving output/p; /error:/p'
whisper_status="${PIPESTATUS[0]}"
set -e

if [[ "$whisper_status" -ne 0 ]]; then
  echo "Transcription failed. See: $output_base.log" >&2
  exit "$whisper_status"
fi

for extension in txt srt vtt json; do
  output_file="$output_base.$extension"
  if [[ ! -s "$output_file" ]]; then
    echo "Expected output is missing or empty: $output_file" >&2
    exit 1
  fi
done

if command -v jq >/dev/null 2>&1; then
  jq -e '.transcription | length > 0' "$output_base.json" >/dev/null
fi

if [[ "$language" == "auto" ]]; then
  detected="$(sed -n 's/.*auto-detected language: \([a-z][a-z]*\).*/\1/p' \
    "$output_base.log" | tail -n 1)"
  if [[ -n "$detected" ]]; then
    echo "Auto-detected language: $detected ($(language_name "$detected"))"
    echo "Confirm this matches the recording before trusting the transcript."
  fi
fi

if [[ "$translate" == "true" ]]; then
  echo "Output is an English translation, not a verbatim transcript."
fi

echo "Transcript complete:"
for extension in txt srt vtt json log; do
  echo "  $output_base.$extension"
done
if [[ "$keep_audio" == "true" ]]; then
  echo "  $output_base.audio.wav"
fi
