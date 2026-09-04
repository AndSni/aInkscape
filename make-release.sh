#!/usr/bin/env bash
# Build the aInkscape release archives (tar.gz + zip + SHA256SUMS) into ./dist/.
#
#   ./make-release.sh [VERSION]
#
# VERSION defaults to the contents of ./VERSION. The archives contain only the
# runnable scripts and docs, laid out flat under a versioned top directory, with
# .sh files mode 0755 so they run straight after extraction from any location.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-$(cat VERSION)}"
NAME="aInkscape-$VERSION"
OUT="dist"
FILES=(
  illustrator-cs6-inkscape.sh
  inkscape-ai-swatches.sh
  inkscape-print-libraries.sh
  install.sh
  README.md
  LICENSE
  NOTICE
)

command -v zip >/dev/null 2>&1 || { echo "error: zip not found" >&2; exit 1; }

rm -rf "${OUT:?}/$NAME"
mkdir -p "$OUT/$NAME"
cp -p "${FILES[@]}" "$OUT/$NAME/"
chmod 0755 "$OUT/$NAME"/*.sh
chmod 0644 "$OUT/$NAME"/README.md "$OUT/$NAME"/LICENSE "$OUT/$NAME"/NOTICE

# Reproducible-ish: sorted entries, no owner names, timestamp pinned to last commit.
MTIME="@$(git log -1 --format=%ct 2>/dev/null || echo 946684800)"
tar --sort=name --numeric-owner --owner=0 --group=0 --mtime="$MTIME" \
    -C "$OUT" -czf "$OUT/$NAME.tar.gz" "$NAME"

( cd "$OUT" && rm -f "$NAME.zip" && zip -q -X -r "$NAME.zip" "$NAME" )

( cd "$OUT" && sha256sum "$NAME.tar.gz" "$NAME.zip" | tee SHA256SUMS )

echo
echo "built in $OUT/:"
ls -l "$OUT/$NAME.tar.gz" "$OUT/$NAME.zip" "$OUT/SHA256SUMS"
