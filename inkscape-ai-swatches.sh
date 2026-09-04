#!/usr/bin/env bash
#
# inkscape-ai-swatches.sh
# -----------------------------------------------------------------------------
# Installs Illustrator-style colour swatch palettes into Inkscape 1.4.x:
#
#   Illustrator-CMYK.ase   true-CMYK swatches (Adobe Swatch Exchange, read
#                          natively by Inkscape 1.4): White, Black,
#                          CMYK Red/Yellow/Green/Cyan/Blue/Magenta,
#                          Registration, Black 10-90%, a few rich mixes,
#                          plus a C/M/Y/K 10-100% process tint chart.
#   Illustrator-RGB.gpl    Basic RGB / sRGB swatches: White, Black,
#                          RGB Red/Yellow/Green/Cyan/Blue/Magenta, grey ramp.
#
# Inkscape already ships sRGB-ish palettes too (WebHex = web-safe, SVG = the
# 147 named CSS colours) - this just adds the AI-flavoured defaults.
#
# Idempotent. Backs up the palettes folder first. Safe on a clean machine.
#
# Usage:
#   inkscape-ai-swatches.sh [--dry-run] [--no-backup] [--profile-dir DIR]
#                           [--color-management]   # also switch on CMYK soft-proof
#   inkscape-ai-swatches.sh --revert
#   inkscape-ai-swatches.sh --help
#
# Notes
#   * Inkscape renders in RGB. A .ase CMYK swatch keeps its CMYK numbers but
#     is shown via an RGB conversion. For an accurate preview use
#     --color-management (needs a CMYK ICC profile) or Preferences > Color
#     management. A real press profile (US Web Coated SWOP, Coated FOGRA39)
#     beats the generic one; get one from  dnf install icc-profiles-openicc .
#   * To use your OWN 20 years of AI swatches: in Illustrator, Swatches panel
#     menu > Save Swatch Library as ASE, then drop the .ase files into
#     ~/.config/inkscape/palettes/ and restart Inkscape.
#   * After restart: Swatches dialog (Shift+Ctrl+W) > palette menu (top-right)
#     > pick "Illustrator CMYK" / "Illustrator RGB". Set the Fill & Stroke
#     colour picker to the CMYK wheel from its own menu button.
# -----------------------------------------------------------------------------
set -euo pipefail

DRY_RUN=0; DO_BACKUP=1; REVERT=0; DO_CMS=0
PROFILE_DIR="${INKSCAPE_PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/inkscape}"
if [ -z "${INKSCAPE_PROFILE_DIR:-}" ] && [ ! -d "$PROFILE_DIR" ] \
   && [ -d "$HOME/.var/app/org.inkscape.Inkscape/config/inkscape" ]; then
  PROFILE_DIR="$HOME/.var/app/org.inkscape.Inkscape/config/inkscape"   # Flatpak
fi

msg()  { printf '  %s\n' "$*"; }
info() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)          DRY_RUN=1 ;;
    --no-backup)        DO_BACKUP=0 ;;
    --revert)           REVERT=1 ;;
    --color-management) DO_CMS=1 ;;
    --profile-dir)      shift; PROFILE_DIR="${1:?--profile-dir needs an argument}" ;;
    -h|--help)          sed -n '3,52p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

command -v inkscape >/dev/null 2>&1 || die "inkscape not found on PATH"
command -v python3  >/dev/null 2>&1 || die "python3 is required"
pgrep -x inkscape >/dev/null 2>&1 && die "Inkscape is running - quit it first."

PAL_DIR="$PROFILE_DIR/palettes"
PREFS="$PROFILE_DIR/preferences.xml"
info "Inkscape $(inkscape --version 2>/dev/null | awk '{print $2; exit}')"
msg  "palettes dir: $PAL_DIR"

# --- revert ---------------------------------------------------------------
if [ "$REVERT" -eq 1 ]; then
  newest="$(find "$PROFILE_DIR" -maxdepth 1 -type d -name 'swatch-backup-*' 2>/dev/null | sort | tail -n1)"
  [ -n "$newest" ] || die "no swatch-backup-* directory in $PROFILE_DIR"
  info "Reverting from $newest"
  [ "$DRY_RUN" -eq 1 ] && { msg "(dry run) would restore palettes/"; exit 0; }
  rm -rf "$PAL_DIR"; mkdir -p "$PAL_DIR"
  [ -d "$newest/palettes" ] && cp -a "$newest/palettes/." "$PAL_DIR/"
  # remove our generated files if the backup didn't contain them
  for f in Illustrator-CMYK.ase Illustrator-RGB.gpl; do
    [ -e "$newest/palettes/$f" ] || rm -f "$PAL_DIR/$f"
  done
  info "Done. Restart Inkscape."
  exit 0
fi

mkdir -p "$PAL_DIR"

# --- backup ------------------------------------------------------------------
if [ "$DO_BACKUP" -eq 1 ]; then
  BDIR="$PROFILE_DIR/swatch-backup-$(date +%Y%m%d-%H%M%S)"
  if [ "$DRY_RUN" -eq 1 ]; then
    msg "(dry run) would back up palettes/ + preferences.xml to $BDIR"
  else
    mkdir -p "$BDIR"
    cp -a "$PAL_DIR" "$BDIR/palettes"
    [ -f "$PREFS" ] && cp -a "$PREFS" "$BDIR/"
    info "Backup: $BDIR"
  fi
fi

# --- generate palettes -----------------------------------------------------
info "Palettes"
if [ "$DRY_RUN" -eq 1 ]; then
  msg "(dry run) would write $PAL_DIR/Illustrator-CMYK.ase and Illustrator-RGB.gpl"
else
  python3 - "$PAL_DIR/Illustrator-CMYK.ase" "$PAL_DIR/Illustrator-RGB.gpl" <<'PY'
import struct, sys

def cblock(name, model, values, ctype=2):
    nb = name.encode("utf-16-be") + b"\x00\x00"
    body = struct.pack(">H", len(nb)//2) + nb + model
    for v in values:
        body += struct.pack(">f", float(v))
    body += struct.pack(">H", ctype)
    return struct.pack(">HI", 0x0001, len(body)) + body

def gstart(name):
    nb = name.encode("utf-16-be") + b"\x00\x00"
    body = struct.pack(">H", len(nb)//2) + nb
    return struct.pack(">HI", 0xC001, len(body)) + body

gend = struct.pack(">HI", 0xC002, 0)

CMYK = [
    ("White",        (0,0,0,0)),      ("Black",        (0,0,0,1)),
    ("CMYK Red",     (0,1,1,0)),      ("CMYK Yellow",  (0,0,1,0)),
    ("CMYK Green",   (1,0,1,0)),      ("CMYK Cyan",    (1,0,0,0)),
    ("CMYK Blue",    (1,1,0,0)),      ("CMYK Magenta", (0,1,0,0)),
    ("Registration", (1,1,1,1)),
]
CMYK += [(f"Black {p}%", (0,0,0,p/100)) for p in range(10,100,10)]
CMYK += [
    ("Rich Black", (0.60,0.40,0.40,1.0)), ("Warm Red", (0,0.85,0.90,0)),
    ("Orange",     (0,0.50,1.00,0)),      ("Violet",   (0.55,0.75,0,0)),
    ("Teal",       (1.00,0,0.30,0.10)),
]

blocks  = [gstart("Illustrator CMYK")]
blocks += [cblock(n, b"CMYK", v) for n, v in CMYK]
blocks += [gend, gstart("CMYK Tints")]
for chan, idx in (("Cyan",0),("Magenta",1),("Yellow",2),("Key",3)):
    for p in range(10,101,10):
        v=[0,0,0,0]; v[idx]=p/100
        blocks.append(cblock(f"{chan} {p}%", b"CMYK", tuple(v)))
blocks.append(gend)

data = b"ASEF" + struct.pack(">HHI", 1, 0, len(blocks)) + b"".join(blocks)
open(sys.argv[1], "wb").write(data)

RGB = [(255,255,255,"White"),(0,0,0,"Black"),
       (255,0,0,"RGB Red"),(255,255,0,"RGB Yellow"),
       (0,255,0,"RGB Green"),(0,255,255,"RGB Cyan"),
       (0,0,255,"RGB Blue"),(255,0,255,"RGB Magenta")]
RGB += [(v,v,v,f"Gray {round(100-v/255*100)}%")
        for v in (230,204,179,153,128,102,77,51,26)]
with open(sys.argv[2], "w") as f:
    f.write("GIMP Palette\nName: Illustrator RGB\nColumns: 8\n"
            "# Illustrator-style RGB / sRGB swatches\n")
    for r,g,b,l in RGB:
        f.write(f"{r:3d} {g:3d} {b:3d}\t{l}\n")
print("  wrote Illustrator-CMYK.ase (%d swatches) and Illustrator-RGB.gpl (%d)"
      % (sum(1 for _ in CMYK)+40, len(RGB)))
PY
fi

# --- optional: CMYK soft-proofing ----------------------------------------
if [ "$DO_CMS" -eq 1 ]; then
  info "Colour management (CMYK soft-proof)"
  ICC=""
  for c in /usr/share/color/icc/*/[Uu]SWebCoatedSWOP.icc \
           /usr/share/color/icc/*/*[Cc]oated*FOGRA39*.icc \
           /usr/share/color/icc/openicc/*[Cc]oated*.icc \
           /usr/share/ghostscript/iccprofiles/default_cmyk.icc; do
    [ -f "$c" ] && { ICC="$c"; break; }
  done
  [ -n "$ICC" ] || die "no CMYK ICC profile found - try: sudo dnf install icc-profiles-openicc"
  msg "profile: $ICC"
  if [ "$DRY_RUN" -eq 1 ]; then
    msg "(dry run) would set /options/softproof enable=1 uri=$ICC and /options/displayprofile enable=1"
  else
    [ -f "$PREFS" ] || die "preferences.xml missing - launch Inkscape once, then re-run"
    ICC="$ICC" python3 - "$PREFS" <<'PY'
import os, sys, xml.etree.ElementTree as ET
path, icc = sys.argv[1], os.environ["ICC"]
tree = ET.parse(path); root = tree.getroot()
def grp(parent, gid):
    for g in parent.findall("group"):
        if g.get("id") == gid: return g
    g = ET.SubElement(parent, "group"); g.set("id", gid); return g
opts = grp(root, "options")
sp = grp(opts, "softproof");     sp.set("enable", "1"); sp.set("uri", icc); sp.set("gamutwarn", "0")
dp = grp(opts, "displayprofile"); dp.set("enable", "1")
try: ET.indent(tree, space="  ")
except Exception: pass
tree.write(path, encoding="UTF-8", xml_declaration=True)
print("  soft-proof enabled (toggle on canvas with View > Color-Managed View)")
PY
  fi
fi

echo
info "Done.  Restart Inkscape."
[ "$DO_BACKUP" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] && msg "Undo:  $0 --revert"
cat <<'NOTE'

  In Inkscape after restart:
    * Swatches dialog: Shift+Ctrl+W  ->  palette menu (small button, top-right
      of the strip)  ->  "Illustrator CMYK", "Illustrator RGB", "CMYK Tints".
    * Fill & Stroke (Shift+Ctrl+F): the color picker has a menu to switch the
      wheel/sliders to CMYK, RGB, HSL, OKLCH, etc.
    * Your real AI swatches: Illustrator > Swatches menu > Save Swatch Library
      as ASE  ->  copy into  ~/.config/inkscape/palettes/
NOTE
