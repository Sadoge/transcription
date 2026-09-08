#!/usr/bin/env bash

# Shared environment resolution for the transcribe-media scripts.
# Sourced by the other scripts; not meant to be run directly.

# Resolve the whisper.cpp command-line binary.
#
# Honours $WHISPER_CLI first, then the names used by the common packages
# (Homebrew ships whisper-cli, Debian and Nixpkgs ship whisper-cpp), then a
# source checkout pointed at by $WHISPER_CPP_HOME. Prints the resolved path.
resolve_whisper_cli() {
  local candidate

  if [[ -n "${WHISPER_CLI:-}" ]]; then
    if [[ -x "$WHISPER_CLI" ]]; then
      printf '%s\n' "$WHISPER_CLI"
      return 0
    fi
    if candidate="$(command -v "$WHISPER_CLI" 2>/dev/null)"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    return 1
  fi

  for candidate in whisper-cli whisper-cpp whisper.cpp; do
    if candidate="$(command -v "$candidate" 2>/dev/null)"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # A source build. "main" is only looked for inside a build tree; it is far
  # too generic a name to trust from $PATH.
  for candidate in \
    "${WHISPER_CPP_HOME:-}/build/bin/whisper-cli" \
    "${WHISPER_CPP_HOME:-}/build/bin/main" \
    "${WHISPER_CPP_HOME:-}/main" \
    "$HOME/whisper.cpp/build/bin/whisper-cli" \
    "$HOME/whisper.cpp/build/bin/main"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

# Default shared model cache, honouring $WHISPER_MODEL_CACHE then XDG.
default_model_cache() {
  printf '%s\n' "${WHISPER_MODEL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/whisper}"
}

# Other cache locations established by whisper tooling, searched read-only.
alternate_model_caches() {
  printf '%s\n' \
    "${XDG_CACHE_HOME:-$HOME/.cache}/whisper.cpp" \
    "$HOME/.cache/whisper" \
    "$HOME/.cache/whisper.cpp" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/whisper" \
    "$HOME/.local/share/whisper"
}

whisper_install_hint() {
  cat <<'HINT'
Install whisper.cpp and ffmpeg with your platform's package manager, e.g.
  macOS:         brew install whisper-cpp ffmpeg
  Debian/Ubuntu: apt install whisper.cpp ffmpeg   (or build whisper.cpp from source)
  Arch:          pacman -S whisper.cpp ffmpeg
  Nix:           nix-shell -p whisper-cpp ffmpeg
If the binary is installed under another name or path, point $WHISPER_CLI at it.
HINT
}
