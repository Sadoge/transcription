#!/usr/bin/env bash

# The whisper.cpp models this skill knows how to fetch and run.
# Sourced by the other scripts; not meant to be run directly.

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

# The .en models were trained on English only. Pairing one with any other
# language produces confident nonsense rather than an error, so callers check.
is_english_only_model() {
  case "$1" in
    *.en) return 0 ;;
    *) return 1 ;;
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
  printf '%-17s %-10s %-14s %s\n' "MODEL" "DOWNLOAD" "LANGUAGES" "BEST FOR"
  printf '%-17s %-10s %-14s %s\n' "tiny" "~75 MB" "multilingual" "Fast drafts"
  printf '%-17s %-10s %-14s %s\n' "tiny.en" "~75 MB" "English only" "Fast English drafts"
  printf '%-17s %-10s %-14s %s\n' "base" "~142 MB" "multilingual" "Faster transcription"
  printf '%-17s %-10s %-14s %s\n' "base.en" "~142 MB" "English only" "Faster English transcription"
  printf '%-17s %-10s %-14s %s\n' "small" "~466 MB" "multilingual" "Default accuracy/speed balance"
  printf '%-17s %-10s %-14s %s\n' "small.en" "~466 MB" "English only" "Default quality, English only"
  printf '%-17s %-10s %-14s %s\n' "medium" "~1.5 GB" "multilingual" "Harder audio, better non-English"
  printf '%-17s %-10s %-14s %s\n' "medium.en" "~1.5 GB" "English only" "Harder English audio"
  printf '%-17s %-10s %-14s %s\n' "large-v3-turbo" "~1.6 GB" "multilingual" "Strong quality with better speed"
  printf '%-17s %-10s %-14s %s\n' "large-v3" "~3.1 GB" "multilingual" "Maximum local quality; only model for yue"
}
