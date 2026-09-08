#!/usr/bin/env bash

# The languages Whisper was trained on, as accepted by whisper.cpp's -l flag.
# Sourced by the other scripts; not meant to be run directly.

language_name() {
  case "$1" in
    af) echo "Afrikaans" ;;
    am) echo "Amharic" ;;
    ar) echo "Arabic" ;;
    as) echo "Assamese" ;;
    az) echo "Azerbaijani" ;;
    ba) echo "Bashkir" ;;
    be) echo "Belarusian" ;;
    bg) echo "Bulgarian" ;;
    bn) echo "Bengali" ;;
    bo) echo "Tibetan" ;;
    br) echo "Breton" ;;
    bs) echo "Bosnian" ;;
    ca) echo "Catalan" ;;
    cs) echo "Czech" ;;
    cy) echo "Welsh" ;;
    da) echo "Danish" ;;
    de) echo "German" ;;
    el) echo "Greek" ;;
    en) echo "English" ;;
    es) echo "Spanish" ;;
    et) echo "Estonian" ;;
    eu) echo "Basque" ;;
    fa) echo "Persian" ;;
    fi) echo "Finnish" ;;
    fo) echo "Faroese" ;;
    fr) echo "French" ;;
    gl) echo "Galician" ;;
    gu) echo "Gujarati" ;;
    ha) echo "Hausa" ;;
    haw) echo "Hawaiian" ;;
    he) echo "Hebrew" ;;
    hi) echo "Hindi" ;;
    hr) echo "Croatian" ;;
    ht) echo "Haitian Creole" ;;
    hu) echo "Hungarian" ;;
    hy) echo "Armenian" ;;
    id) echo "Indonesian" ;;
    is) echo "Icelandic" ;;
    it) echo "Italian" ;;
    ja) echo "Japanese" ;;
    jw) echo "Javanese" ;;
    ka) echo "Georgian" ;;
    kk) echo "Kazakh" ;;
    km) echo "Khmer" ;;
    kn) echo "Kannada" ;;
    ko) echo "Korean" ;;
    la) echo "Latin" ;;
    lb) echo "Luxembourgish" ;;
    ln) echo "Lingala" ;;
    lo) echo "Lao" ;;
    lt) echo "Lithuanian" ;;
    lv) echo "Latvian" ;;
    mg) echo "Malagasy" ;;
    mi) echo "Maori" ;;
    mk) echo "Macedonian" ;;
    ml) echo "Malayalam" ;;
    mn) echo "Mongolian" ;;
    mr) echo "Marathi" ;;
    ms) echo "Malay" ;;
    mt) echo "Maltese" ;;
    my) echo "Burmese" ;;
    ne) echo "Nepali" ;;
    nl) echo "Dutch" ;;
    nn) echo "Norwegian Nynorsk" ;;
    no) echo "Norwegian" ;;
    oc) echo "Occitan" ;;
    pa) echo "Punjabi" ;;
    pl) echo "Polish" ;;
    ps) echo "Pashto" ;;
    pt) echo "Portuguese" ;;
    ro) echo "Romanian" ;;
    ru) echo "Russian" ;;
    sa) echo "Sanskrit" ;;
    sd) echo "Sindhi" ;;
    si) echo "Sinhala" ;;
    sk) echo "Slovak" ;;
    sl) echo "Slovenian" ;;
    sn) echo "Shona" ;;
    so) echo "Somali" ;;
    sq) echo "Albanian" ;;
    sr) echo "Serbian" ;;
    su) echo "Sundanese" ;;
    sv) echo "Swedish" ;;
    sw) echo "Swahili" ;;
    ta) echo "Tamil" ;;
    te) echo "Telugu" ;;
    tg) echo "Tajik" ;;
    th) echo "Thai" ;;
    tk) echo "Turkmen" ;;
    tl) echo "Tagalog" ;;
    tr) echo "Turkish" ;;
    tt) echo "Tatar" ;;
    uk) echo "Ukrainian" ;;
    ur) echo "Urdu" ;;
    uz) echo "Uzbek" ;;
    vi) echo "Vietnamese" ;;
    yi) echo "Yiddish" ;;
    yo) echo "Yoruba" ;;
    yue) echo "Cantonese" ;;
    zh) echo "Chinese" ;;
    *) echo "" ;;
  esac
}

# "auto" is accepted here because whisper.cpp accepts it as a language value.
is_supported_language() {
  if [[ "$1" == "auto" ]]; then
    return 0
  fi
  [[ -n "$(language_name "$1")" ]]
}

# Language codes that carry a dedicated English-only Whisper model.
is_english_only_language() {
  [[ "$1" == "en" ]]
}

list_languages() {
  local code
  echo "auto  (detect from the audio)"
  echo
  for code in af am ar as az ba be bg bn bo br bs ca cs cy da de el en es et eu \
    fa fi fo fr gl gu ha haw he hi hr ht hu hy id is it ja jw ka kk km kn ko la \
    lb ln lo lt lv mg mi mk ml mn mr ms mt my ne nl nn no oc pa pl ps pt ro ru \
    sa sd si sk sl sn so sq sr su sv sw ta te tg th tk tl tr tt uk ur uz vi yi \
    yo yue zh; do
    printf '%-5s %s\n' "$code" "$(language_name "$code")"
  done
  echo
  echo "Cantonese (yue) needs large-v3 or large-v3-turbo; earlier models do not know it."
}
