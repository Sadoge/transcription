#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/model_catalog.sh"

usage() {
  sed -n '/^# Download/,/^$/p' "$0" | sed 's/^# //; s/^#$//'
}

# Download a whisper.cpp model into a shared cache.
#
# Usage:
#   download_model.sh [options] [MODEL]
#
# Options:
#   --model-cache DIR  Shared model cache (default: ~/.cache/whisper).
#   --list-models      List supported model names and exit.
#   -h, --help         Show this help.
#
# Existing cached models are never overwritten or downloaded again.

model_name="small"
model_cache="${WHISPER_MODEL_CACHE:-$HOME/.cache/whisper}"

while (($#)); do
  case "$1" in
    --model-cache)
      model_cache="${2:?--model-cache requires a directory}"
      shift 2
      ;;
    --list-models)
      list_models
      exit 0
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
      model_name="$1"
      shift
      if (($#)); then
        echo "Only one model name is supported per run." >&2
        exit 2
      fi
      ;;
  esac
done

if ! is_supported_model "$model_name"; then
  echo "Unsupported model: $model_name" >&2
  echo "Use --list-models to see supported names." >&2
  exit 2
fi

destination="$model_cache/ggml-$model_name.bin"
model_url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$model_name.bin"

if ! command -v curl >/dev/null 2>&1; then
  echo "Required command not found: curl" >&2
  exit 1
fi

if [[ -s "$destination" ]]; then
  echo "Model already cached; leaving it unchanged: $destination"
  exit 0
elif [[ -e "$destination" ]]; then
  echo "A zero-length or incomplete-looking destination already exists." >&2
  echo "It was left unchanged: $destination" >&2
  exit 1
fi

mkdir -p "$model_cache"
temporary_model="$(mktemp "$model_cache/.ggml-$model_name.partial.XXXXXX")"
download_complete="false"
cleanup() {
  if [[ "$download_complete" != "true" ]]; then
    rm -f "$temporary_model"
  fi
}
trap cleanup EXIT

echo "Downloading Whisper model '$model_name' ($(model_size "$model_name"))."
curl -fL --retry 3 -o "$temporary_model" "$model_url"

if [[ ! -s "$temporary_model" ]]; then
  echo "Downloaded model is empty; cache was not changed." >&2
  exit 1
fi

if [[ -e "$destination" ]]; then
  echo "The model appeared in the cache during download; leaving it unchanged."
  echo "Cached model: $destination"
  exit 0
fi

mv "$temporary_model" "$destination"
download_complete="true"
echo "Model saved to: $destination"
