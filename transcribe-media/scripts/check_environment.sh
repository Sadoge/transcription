#!/usr/bin/env bash

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/whisper_env.sh"
source "$script_dir/model_catalog.sh"

usage() {
  sed -n '/^# Report/,/^$/p' "$0" | sed 's/^# //; s/^#$//'
}

# Report whether this machine can run the transcribe-media scripts.
#
# Usage:
#   check_environment.sh
#
# Exits 0 when transcription can proceed, 1 when a dependency is missing.
# Nothing is downloaded, installed, or modified.

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ready="true"

printf 'platform          %s %s\n' "$(uname -s)" "$(uname -m)"

for required_command in ffmpeg ffprobe; do
  if path="$(command -v "$required_command" 2>/dev/null)"; then
    printf '%-17s %s\n' "$required_command" "$path"
  else
    printf '%-17s MISSING\n' "$required_command"
    ready="false"
  fi
done

if whisper_cli="$(resolve_whisper_cli)"; then
  printf '%-17s %s\n' "whisper.cpp" "$whisper_cli"
else
  printf '%-17s MISSING\n' "whisper.cpp"
  ready="false"
fi

if path="$(command -v jq 2>/dev/null)"; then
  printf '%-17s %s\n' "jq" "$path (optional, used to validate JSON output)"
else
  printf '%-17s absent (optional)\n' "jq"
fi

model_cache="$(default_model_cache)"
printf '%-17s %s\n' "model cache" "$model_cache"

echo
echo "Cached models:"
found_model="false"
seen_caches=""
while IFS= read -r cache_dir; do
  case " $seen_caches " in
    *" $cache_dir "*) continue ;;
  esac
  seen_caches="$seen_caches $cache_dir"
  [[ -d "$cache_dir" ]] || continue
  for model_file in "$cache_dir"/ggml-*.bin; do
    [[ -f "$model_file" ]] || continue
    case "$model_file" in
      *for-tests*) continue ;;
    esac
    model_name="$(basename "$model_file")"
    model_name="${model_name#ggml-}"
    model_name="${model_name%.bin}"
    if is_english_only_model "$model_name"; then
      languages="English only"
    else
      languages="multilingual"
    fi
    printf '  %-17s %-14s %s\n' "$model_name" "$languages" "$model_file"
    found_model="true"
  done
done < <(printf '%s\n' "$model_cache"; alternate_model_caches)

if [[ "$found_model" != "true" ]]; then
  echo "  none"
  echo
  echo "Download one before transcribing, for example:"
  echo "  $script_dir/download_model.sh small"
  echo "Transcription in a language other than English needs a multilingual model"
  echo "(any name without the .en suffix)."
fi

echo
if [[ "$ready" == "true" ]]; then
  echo "Ready to transcribe."
  exit 0
fi

echo "Missing dependencies; transcription cannot run yet." >&2
whisper_install_hint >&2
exit 1
