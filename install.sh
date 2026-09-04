#!/usr/bin/env bash
# Symlink the aInkscape scripts into a bin directory on your PATH.
# Usage:  ./install.sh [TARGET_DIR]      (default: ~/.local/bin)
#         ./install.sh --uninstall [TARGET_DIR]
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS=(illustrator-cs6-inkscape.sh inkscape-ai-swatches.sh inkscape-print-libraries.sh)

UNINSTALL=0
[ "${1:-}" = "--uninstall" ] && { UNINSTALL=1; shift; }
DEST="${1:-$HOME/.local/bin}"
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

case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo; echo "note: $DEST is not on your PATH. Add to your shell rc:"
     echo "      export PATH=\"$DEST:\$PATH\"" ;;
esac
