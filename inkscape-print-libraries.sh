#!/usr/bin/env bash
#
# inkscape-print-libraries.sh
# -----------------------------------------------------------------------------
# Installs open, redistributable print-industry colour libraries into Inkscape.
#
# Sources (both CC BY-ND 4.0 - free to redistribute verbatim, incl. commercial,
# with attribution; the files are installed unmodified):
#
#   * HLC Colour Atlas  - freieFarbe e.V.  -  2040 colours defined in CIELAB,
#     a systematic, licence-free alternative to Pantone/RAL built for print.
#     (--xl swaps in the 13283-colour version.)
#
#   * Open Colour Systems Collection (OCSC) 2.0 - dtp studio oldenburg -
#     376 measured colour systems, all CIELAB. The --print subset (default)
#     installs the graphic-arts ones: HKS N/K/E/Z + screen fans, K+E / Siegwerk
#     offset inks, Sericol / Marabu screen inks, J+S raster fans, paper-white
#     systems (GS Palette 141, DeutschePapier), DIN 6164, British / Australian
#     Standard. --all installs every collection (paints, vinyl films, artist
#     oils, architectural standards - ~376 palettes in the menu).
#
# NOT included, because they are trademarked and cannot be redistributed:
# Pantone, RAL, HKS-the-brand-books beyond measured Lab values, TOYO, DIC,
# Focoltone, Trumatch. Adobe removed Pantone from Illustrator for the same
# reason. For those you must use the vendor's own plug-in / files.
#
# Idempotent. Downloads are cached in ~/.cache/inkscape-print-libraries/.
# Tracks what it installed in a manifest for a clean --revert.
#
# Usage:
#   inkscape-print-libraries.sh [--print | --all] [--format ase|gpl|both]
#                               [--xl] [--no-download] [--dry-run]
#                               [--profile-dir DIR]
#   inkscape-print-libraries.sh --list        # names of all OCSC collections
#   inkscape-print-libraries.sh --revert      # remove everything this installed
#   inkscape-print-libraries.sh --help
#
# After install: restart Inkscape, open Swatches (Shift+Ctrl+W), use the
# palette menu (top-right of the strip) to pick a library.
#
# Accurate CMYK preview needs a real press ICC profile. Free ones:
#   ECI  -> https://www.eci.org/en/downloads  (ISO Coated v2, PSO Uncoated v3)
#   then run:  inkscape-ai-swatches.sh --color-management
# -----------------------------------------------------------------------------
set -euo pipefail

MODE=print          # print | all
FORMAT=ase          # ase | gpl | both
USE_XL=0
DOWNLOAD=1
DRY_RUN=0
DO_LIST=0
REVERT=0
PROFILE_DIR="${INKSCAPE_PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/inkscape}"
if [ -z "${INKSCAPE_PROFILE_DIR:-}" ] && [ ! -d "$PROFILE_DIR" ] \
   && [ -d "$HOME/.var/app/org.inkscape.Inkscape/config/inkscape" ]; then
  PROFILE_DIR="$HOME/.var/app/org.inkscape.Inkscape/config/inkscape"   # Flatpak
fi
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/inkscape-print-libraries"

BASE="https://freiefarbe.de/wp-content/uploads/2022/12"
Z_OCSC_ASE="OCSC_20_ASE.zip"
Z_OCSC_GPL="OCSC_20_GPL.zip"
Z_HLC="HLC-Colour-Atlas_EPV_A10_v2.03.zip"
Z_HLC_XL="HLC-Colour-Atlas-XL_Set_DE_v1-2.zip"

msg()  { printf '  %s\n' "$*"; }
info() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --print)        MODE=print ;;
    --all)          MODE=all ;;
    --format)       shift; FORMAT="${1:?}" ;;
    --xl)           USE_XL=1 ;;
    --no-download)  DOWNLOAD=0 ;;
    --dry-run)      DRY_RUN=1 ;;
    --list)         DO_LIST=1 ;;
    --revert)       REVERT=1 ;;
    --profile-dir)  shift; PROFILE_DIR="${1:?}" ;;
    -h|--help)      sed -n '3,53p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done
case "$FORMAT" in ase|gpl|both) ;; *) die "--format must be ase, gpl or both" ;; esac

command -v curl  >/dev/null 2>&1 || die "curl is required"
command -v unzip >/dev/null 2>&1 || die "unzip is required"

PAL_DIR="$PROFILE_DIR/palettes"
MANIFEST="$PAL_DIR/.print-libraries-manifest"

# --- revert -------------------------------------------------------------------
if [ "$REVERT" -eq 1 ]; then
  [ -f "$MANIFEST" ] || die "no manifest at $MANIFEST - nothing to revert"
  info "Removing files listed in $MANIFEST"
  n=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    f="$PAL_DIR/$rel"
    if [ -e "$f" ]; then
      [ "$DRY_RUN" -eq 1 ] && msg "(dry run) rm $rel" || { rm -f "$f"; n=$((n+1)); }
    fi
  done < "$MANIFEST"
  [ "$DRY_RUN" -eq 1 ] || { rm -f "$MANIFEST"; msg "removed $n files + manifest"; }
  info "Done. Restart Inkscape."
  exit 0
fi

mkdir -p "$CACHE"

fetch() {  # fetch <zipname>
  local z="$1" dest="$CACHE/$1"
  if [ -s "$dest" ]; then msg "cached: $z"; return; fi
  [ "$DOWNLOAD" -eq 1 ] || die "missing $dest and --no-download given"
  [ "$DRY_RUN" -eq 1 ] && { msg "(dry run) would download $BASE/$z"; return; }
  msg "downloading $z ..."
  curl -fSL --retry 3 -o "$dest.part" "$BASE/$z"
  mv "$dest.part" "$dest"
}

extract() {  # extract <zipname> <subdir-in-cache>; unpacking into the cache is
             # harmless, so it runs even under --dry-run (only profile writes are gated)
  local z="$1" out="$CACHE/$2"
  [ -d "$out" ] && { echo "$out"; return; }
  [ -s "$CACHE/$z" ] || { echo "$out"; return; }
  mkdir -p "$out"; unzip -o -q "$CACHE/$z" -d "$out"
  echo "$out"
}

# --- --list ----------------------------------------------------------------
if [ "$DO_LIST" -eq 1 ]; then
  fetch "$Z_OCSC_ASE"
  d="$(extract "$Z_OCSC_ASE" ocsc_ase)"
  info "OCSC 2.0 colour systems ($(find "$d" -name '*.ase' | wc -l)):"
  find "$d" -name '*.ase' -printf '  %f\n' | sed 's/\.ase$//' | sort
  exit 0
fi

# --- curated print subset (exact OCSC basenames, no extension) ------------
PRINT_SET=(
  "HKS N 3000plus" "HKS N" "HKS K 3000plus" "HKS K" "HKS E" "HKS Z"
  "HKS Rasterfaecher"
  "K+E Novavit Serie 250" "Siegwerk Druckfarben" "MAN print and sign"
  "Sericol StdColourSelector" "Sericol Tx MatchingSystem"
  "Sericol UCG MatchingSystem" "Marabu Siebdruckfarben" "Marabu_TX"
  "J+S Rasterfaecher" "J+S K mit Raster" "J+S N" "J+S K"
  "GS Palette 141 Naturpapier" "GS Palette 141 Kunstdruck" "DeutschePapier"
  "DIN 6164" "British Standard Colours" "Australian Standard"
)

info "Inkscape print libraries  ->  $PAL_DIR"
msg "mode: $MODE   format: $FORMAT   HLC: $([ $USE_XL -eq 1 ] && echo XL || echo standard)"
mkdir -p "$PAL_DIR"
: > "${MANIFEST}.tmp"

record() {  # record <relpath>
  echo "$1" >> "${MANIFEST}.tmp"
}
install_file() {  # install_file <src> <destname>
  local src="$1" dst="$PAL_DIR/$2"
  if [ "$DRY_RUN" -eq 1 ]; then msg "(dry run) + $2"; record "$2"; return; fi
  cp -f "$src" "$dst"; chmod 0644 "$dst"; record "$2"
}

# --- HLC Colour Atlas ----------------------------------------------------
if [ "$USE_XL" -eq 1 ]; then
  fetch "$Z_HLC_XL"; HLC_DIR="$(extract "$Z_HLC_XL" hlc_xl)"
else
  fetch "$Z_HLC";    HLC_DIR="$(extract "$Z_HLC" hlc)"
fi
if [ "$DRY_RUN" -eq 1 ]; then
  msg "(dry run) + HLC Colour Atlas.ase"; record "HLC Colour Atlas.ase"
else
  hlc_ase="$(find "$HLC_DIR" -iname '*Swatches*.ase' -o -iname '*HLC*.ase' | head -n1)"
  [ -n "$hlc_ase" ] || die "no HLC .ase found in archive"
  install_file "$hlc_ase" "HLC Colour Atlas.ase"
fi

# --- OCSC --------------------------------------------------------------------
want_ase=0; want_gpl=0
case "$FORMAT" in ase) want_ase=1 ;; gpl) want_gpl=1 ;; both) want_ase=1; want_gpl=1 ;; esac

copy_ocsc() {  # copy_ocsc <srcdir> <ext>
  local dir="$1" ext="$2" f name
  if [ "$MODE" = all ]; then
    for f in "$dir"/*."$ext"; do
      [ -e "$f" ] || continue
      name="$(basename "$f")"
      case "$name" in Licence.txt|Readme.txt) continue ;; esac
      install_file "$f" "OCSC - $name"
    done
  else
    for name in "${PRINT_SET[@]}"; do
      f="$dir/$name.$ext"
      if [ -e "$f" ]; then install_file "$f" "OCSC - $name.$ext"
      elif [ "$DRY_RUN" -eq 0 ]; then msg "note: '$name.$ext' not in archive, skipped"
      fi
    done
  fi
}

if [ "$want_ase" -eq 1 ]; then
  fetch "$Z_OCSC_ASE"; d="$(extract "$Z_OCSC_ASE" ocsc_ase)"
  sub="$(find "$d" -maxdepth 1 -type d -name 'OCSC_20_ASE' | head -n1)"; sub="${sub:-$d}"
  copy_ocsc "$sub" ase
  [ "$DRY_RUN" -eq 1 ] || { cp -f "$sub/Licence.txt" "$PAL_DIR/OCSC-Licence.txt" 2>/dev/null || true
                            cp -f "$sub/Readme.txt"  "$PAL_DIR/OCSC-Readme.txt"  2>/dev/null || true; }
fi
if [ "$want_gpl" -eq 1 ]; then
  fetch "$Z_OCSC_GPL"; d="$(extract "$Z_OCSC_GPL" ocsc_gpl)"
  sub="$(find "$d" -maxdepth 1 -type d -name 'OCSC_20_GPL' | head -n1)"; sub="${sub:-$d}"
  copy_ocsc "$sub" gpl
fi

# --- attribution + manifest -----------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  cat > "$PAL_DIR/PRINT-LIBRARIES-ATTRIBUTION.txt" <<'TXT'
Colour libraries in this folder were installed by inkscape-print-libraries.sh.

HLC Colour Atlas
  (c) freieFarbe e.V. - https://freiefarbe.de - CC BY-ND 4.0
  https://www.freiefarbe.de/en/thema-farbe/hlc-colour-atlas/

Open Colour Systems Collection (OCSC) 2.0
  (c) dtp studio oldenburg - https://www.dtpstudio.de - CC BY-ND 4.0
  See OCSC-Licence.txt and OCSC-Readme.txt in this folder.

Files are distributed unmodified. CC BY-ND allows verbatim redistribution
(including commercial) with attribution; it does NOT allow distributing
modified versions of the colour data.
TXT
  record "PRINT-LIBRARIES-ATTRIBUTION.txt"
  [ -f "$PAL_DIR/OCSC-Licence.txt" ] && record "OCSC-Licence.txt"
  [ -f "$PAL_DIR/OCSC-Readme.txt" ]  && record "OCSC-Readme.txt"
  sort -u "${MANIFEST}.tmp" > "$MANIFEST"; rm -f "${MANIFEST}.tmp"
  n="$(grep -c . "$MANIFEST" || true)"
  info "Installed $n files."
else
  rm -f "${MANIFEST}.tmp"
  info "(dry run) nothing written."
fi

echo
info "Restart Inkscape, then Swatches (Shift+Ctrl+W) -> palette menu."
msg "Undo:  $0 --revert"
[ "$MODE" = print ] && msg "More systems:  $0 --list   /   install everything:  $0 --all"
