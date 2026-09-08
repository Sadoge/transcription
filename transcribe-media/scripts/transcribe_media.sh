#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/model_catalog.sh"

usage() {
  sed -n '/^# Transcribe/,/^$/p' "$0" | sed 's/^# //; s/^#$//'
}

# Transcribe a local video or audio file with whisper.cpp.
#
# Usage:
#   transcribe_media.sh [options] INPUT
#
# Options:
#   --model NAME|PATH    Cached model name or a ggml model file (default: small).
#   --model-cache DIR    Shared model cache (default: ~/.cache/whisper).
#   --list-models        List supported model names and exit.
#   --output-dir DIR     Output directory (default: beside INPUT).
#   --language CODE      Language code or auto (default: en).
#   --threads N          Whisper worker threads (default: 8).
#   --cpu                Disable GPU acceleration.
#   --keep-audio         Keep the extracted 16 kHz mono WAV.
#   --force              Replace existing transcript outputs.
#   -h, --help           Show this help.
#
# Outputs:
#   <input-stem>.transcript.txt
#   <input-stem>.transcript.srt
#   <input-stem>.transcript.vtt
#   <input-stem>.transcript.json
#   <input-stem>.transcript.log

model_spec="${WHISPER_MODEL:-small}"
model_cache="${WHISPER_MODEL_CACHE:-$HOME/.cache/whisper}"
model_path=""
output_dir=""
language="en"
threads="8"
use_cpu="false"
keep_audio="false"
force="false"
input_path=""
show_models="false"

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
    --output-dir)
      output_dir="${2:?--output-dir requires a directory}"
      shift 2
      ;;
    --language)
      language="${2:?--language requires a code}"
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

if [[ -z "$input_path" ]]; then
  usage >&2
  exit 2
fi

for required_command in ffmpeg ffprobe whisper-cli; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Required command not found: $required_command" >&2
    exit 1
  fi
done

if [[ ! -f "$input_path" ]]; then
  echo "Input file not found: $input_path" >&2
  exit 1
fi

if [[ -f "$model_spec" ]]; then
  model_path="$model_spec"
elif is_supported_model "$model_spec"; then
  input_dir="$(cd "$(dirname "$input_path")" && pwd)"
  model_candidates=(
    "$model_cache/ggml-$model_spec.bin"
    "$input_dir/ggml-$model_spec.bin"
    "$PWD/ggml-$model_spec.bin"
    "$HOME/.cache/whisper.cpp/ggml-$model_spec.bin"
    "$HOME/.local/share/whisper/ggml-$model_spec.bin"
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

if [[ -z "$output_dir" ]]; then
  output_dir="$(cd "$(dirname "$input_path")" && pwd)"
else
  mkdir -p "$output_dir"
  output_dir="$(cd "$output_dir" && pwd)"
fi

input_name="$(basename "$input_path")"
input_stem="${input_name%.*}"
output_base="$output_dir/$input_stem.transcript"

for extension in txt srt vtt json log; do
  output_file="$output_base.$extension"
  if [[ -e "$output_file" && "$force" != "true" ]]; then
    echo "Output already exists: $output_file" >&2
    echo "Use --force to replace existing transcript outputs." >&2
    exit 1
  fi
done

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

if [[ "$use_cpu" == "true" ]]; then
  whisper_arguments+=(--no-gpu)
fi

echo "Transcribing with model: $model_path"
set +e
whisper-cli "${whisper_arguments[@]}" 2>&1 \
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

echo "Transcript complete:"
for extension in txt srt vtt json log; do
  echo "  $output_base.$extension"
done
if [[ "$keep_audio" == "true" ]]; then
  echo "  $output_base.audio.wav"
fi
