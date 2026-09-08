#!/usr/bin/env bash

is_supported_model() {
  case "$1" in
    tiny|tiny.en|base|base.en|small|small.en|medium|medium.en|large-v3-turbo|large-v3)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

model_size() {
  case "$1" in
    tiny|tiny.en) echo "approximately 75 MB" ;;
    base|base.en) echo "approximately 142 MB" ;;
    small|small.en) echo "approximately 466 MB" ;;
    medium|medium.en) echo "approximately 1.5 GB" ;;
    large-v3-turbo) echo "approximately 1.6 GB" ;;
    large-v3) echo "approximately 3.1 GB" ;;
    *) echo "unknown size" ;;
  esac
}

list_models() {
  printf '%-17s %-18s %s\n' "MODEL" "DOWNLOAD" "BEST FOR"
  printf '%-17s %-18s %s\n' "tiny" "~75 MB" "Fast drafts, multilingual"
  printf '%-17s %-18s %s\n' "tiny.en" "~75 MB" "Fast drafts, English only"
  printf '%-17s %-18s %s\n' "base" "~142 MB" "Faster multilingual transcription"
  printf '%-17s %-18s %s\n' "base.en" "~142 MB" "Faster English transcription"
  printf '%-17s %-18s %s\n' "small" "~466 MB" "Default accuracy/speed balance"
  printf '%-17s %-18s %s\n' "small.en" "~466 MB" "Default-quality English only"
  printf '%-17s %-18s %s\n' "medium" "~1.5 GB" "Harder multilingual audio"
  printf '%-17s %-18s %s\n' "medium.en" "~1.5 GB" "Harder English audio"
  printf '%-17s %-18s %s\n' "large-v3-turbo" "~1.6 GB" "Strong quality with better speed"
  printf '%-17s %-18s %s\n' "large-v3" "~3.1 GB" "Maximum local quality"
}
