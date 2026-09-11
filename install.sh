#!/usr/bin/env bash
# Symlink the aInkscape CLI scripts onto your PATH, and the Divide extension
# into Inkscape's user extensions folder.
# Usage:  ./install.sh [TARGET_DIR]      (default: ~/.local/bin)
#         ./install.sh --uninstall [TARGET_DIR]
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS=(illustrator-cs6-inkscape.sh inkscape-ai-swatches.sh inkscape-print-libraries.sh)
EXT_FILES=(illustrator-extended-divide.py illustrator-extended-divide.inx)

UNINSTALL=0
[ "${1:-}" = "--uninstall" ] && { UNINSTALL=1; shift; }
DEST="${1:-$HOME/.local/bin}"

PROFILE_DIR="${INKSCAPE_PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/inkscape}"
if [ -z "${INKSCAPE_PROFILE_DIR:-}" ] && [ ! -d "$PROFILE_DIR" ] \
   && [ -d "$HOME/.var/app/org.inkscape.Inkscape/config/inkscape" ]; then
  PROFILE_DIR="$HOME/.var/app/org.inkscape.Inkscape/config/inkscape"   # Flatpak
fi
EXT_DEST="$PROFILE_DIR/extensions"

mkdir -p "$DEST"

for s in "${SCRIPTS[@]}"; do
  if [ "$UNINSTALL" -eq 1 ]; then
    [ -L "$DEST/$s" ] && { rm -f "$DEST/$s"; echo "removed  $DEST/$s"; }
  else
    chmod +x "$SRC/$s"
    ln -sf "$SRC/$s" "$DEST/$s"
    echo "linked   $DEST/$s -> $SRC/$s"
  fi
done

# The Divide extension is a different kind of thing (an Inkscape plugin, not a
# standalone CLI tool) and goes to a different, Inkscape-specific directory.
if [ "$UNINSTALL" -eq 1 ]; then
  for f in "${EXT_FILES[@]}"; do
    [ -L "$EXT_DEST/$f" ] && { rm -f "$EXT_DEST/$f"; echo "removed  $EXT_DEST/$f"; }
  done
else
  mkdir -p "$EXT_DEST"
  for f in "${EXT_FILES[@]}"; do
    chmod +x "$SRC/$f" 2>/dev/null || true
    ln -sf "$SRC/$f" "$EXT_DEST/$f"
    echo "linked   $EXT_DEST/$f -> $SRC/$f"
  done
  echo "note: illustrator-extended-divide.py needs pyclipper -- see the README --"
  echo "      and Inkscape only scans extensions/ at startup, so restart Inkscape."
fi

case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo; echo "note: $DEST is not on your PATH. Add to your shell rc:"
     echo "      export PATH=\"$DEST:\$PATH\"" ;;
esac
