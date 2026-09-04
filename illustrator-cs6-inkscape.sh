#!/usr/bin/env bash
#
# illustrator-cs6-inkscape.sh
# -----------------------------------------------------------------------------
# Nudges Inkscape 1.x toward an Adobe Illustrator (CS6-era) user experience:
#
#   1. Selects the shipped "Adobe Illustrator" base keymap.
#   2. Installs an override keymap (keys/default.xml) with the CS6 shortcuts
#      the base map misses (paste in front/back, Create Outlines, Lock/Hide,
#      Shape Builder = Shift+M, Artboard tool = Shift+O, Fit-all, ...).
#   3. Patches preferences.xml for AI-like behaviour: 1px keyboard nudge,
#      15 deg rotate snap, sqrt(2) zoom step, don't scale stroke/corners on
#      resize, "optimized" transforms, spacebar pan, remember window geometry,
#      dark theme + symbolic icons + narrow spin buttons.
#
# Idempotent. Safe to re-run and to run on a fresh machine. Backs up first.
#
# Usage:
#   illustrator-cs6-inkscape.sh [--dry-run] [--no-backup] [--no-prefs]
#                               [--no-keys] [--profile-dir DIR]
#   illustrator-cs6-inkscape.sh --revert          # restore newest backup
#   illustrator-cs6-inkscape.sh --help
#
# What it deliberately does NOT do:
#   * "Wheel zooms instead of scrolls" - no such preference exists in 1.4.x.
#   * Ctrl+D stays Duplicate (Inkscape) rather than AI's Transform Again -
#     Inkscape has no transform-again command.
#   * Ctrl+F is remapped to Paste-in-Front (AI muscle memory); the Find
#     dialog moves to Ctrl+Alt+F.
# -----------------------------------------------------------------------------
set -euo pipefail

DRY_RUN=0
DO_BACKUP=1
DO_PREFS=1
DO_KEYS=1
REVERT=0
PROFILE_DIR="${INKSCAPE_PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/inkscape}"
# Flatpak keeps its profile elsewhere - fall back to it if the native dir is absent
if [ -z "${INKSCAPE_PROFILE_DIR:-}" ] && [ ! -d "$PROFILE_DIR" ] \
   && [ -d "$HOME/.var/app/org.inkscape.Inkscape/config/inkscape" ]; then
  PROFILE_DIR="$HOME/.var/app/org.inkscape.Inkscape/config/inkscape"
fi

msg()  { printf '  %s\n' "$*"; }
info() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)       DRY_RUN=1 ;;
    --no-backup)     DO_BACKUP=0 ;;
    --no-prefs)      DO_PREFS=0 ;;
    --no-keys)       DO_KEYS=0 ;;
    --revert)        REVERT=1 ;;
    --profile-dir)   shift; PROFILE_DIR="${1:?--profile-dir needs an argument}" ;;
    -h|--help)
      sed -n '3,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

command -v inkscape >/dev/null 2>&1 || die "inkscape not found on PATH"
command -v python3  >/dev/null 2>&1 || die "python3 is required"

INK_VER="$(inkscape --version 2>/dev/null | awk '{print $2; exit}')"
info "Inkscape $INK_VER"
msg  "profile dir: $PROFILE_DIR"

if pgrep -x inkscape >/dev/null 2>&1; then
  die "Inkscape is running. Quit it first (it rewrites preferences.xml on exit)."
fi

KEYS_DIR="$PROFILE_DIR/keys"
PREFS="$PROFILE_DIR/preferences.xml"

# ---------------------------------------------------------------------------
# --revert : restore the most recent backup and exit
# ---------------------------------------------------------------------------
if [ "$REVERT" -eq 1 ]; then
  newest="$(find "$PROFILE_DIR" -maxdepth 1 -type d -name 'cs6-backup-*' 2>/dev/null | sort | tail -n1)"
  [ -n "$newest" ] || die "no cs6-backup-* directory found in $PROFILE_DIR"
  info "Reverting from $newest"
  [ "$DRY_RUN" -eq 1 ] && { msg "(dry run) would restore preferences.xml and keys/"; exit 0; }
  [ -f "$newest/preferences.xml" ] && cp -a "$newest/preferences.xml" "$PREFS" && msg "restored preferences.xml"
  if [ -d "$newest/keys" ]; then
    rm -rf "$KEYS_DIR"; cp -a "$newest/keys" "$KEYS_DIR"; msg "restored keys/"
  fi
  info "Done. Restart Inkscape."
  exit 0
fi

mkdir -p "$PROFILE_DIR" "$KEYS_DIR"

# ---------------------------------------------------------------------------
# Generate a default preferences.xml on a clean machine
# ---------------------------------------------------------------------------
if [ ! -f "$PREFS" ] && [ "$DO_PREFS" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    msg "(dry run) preferences.xml missing - would launch Inkscape once to generate defaults"
  else
    msg "preferences.xml missing - generating defaults..."
    INKSCAPE_PROFILE_DIR="$PROFILE_DIR" inkscape --with-gui --batch-process \
      --actions="quit" >/dev/null 2>&1 || true
  fi
fi

# ---------------------------------------------------------------------------
# Backup
# ---------------------------------------------------------------------------
if [ "$DO_BACKUP" -eq 1 ]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BDIR="$PROFILE_DIR/cs6-backup-$STAMP"
  if [ "$DRY_RUN" -eq 1 ]; then
    msg "(dry run) would back up preferences.xml + keys/ to $BDIR"
  else
    mkdir -p "$BDIR"
    [ -f "$PREFS" ]      && cp -a "$PREFS" "$BDIR/"
    [ -d "$KEYS_DIR" ]   && cp -a "$KEYS_DIR" "$BDIR/keys"
    info "Backup: $BDIR"
  fi
fi

# ---------------------------------------------------------------------------
# 1 + 2.  Override keymap  ->  keys/default.xml
# ---------------------------------------------------------------------------
KEYS_MARKER="illustrator-cs6.sh override block"
read -r -d '' CS6_BLOCK <<'XML' || true
  <!-- === illustrator-cs6.sh override block === -->
  <!-- Loaded last by Inkscape, on top of the "Adobe Illustrator" base map.
       Only the CS6 shortcuts that the base map does not already provide. -->

  <!-- Tools the base AI map leaves unbound in CS6 form -->
  <bind gaction="win.tool-switch('Booleans')" keys="&lt;shift&gt;m, x" />   <!-- Shift+M  Shape Builder -->
  <bind gaction="win.tool-switch('Pages')"    keys="&lt;shift&gt;o" />      <!-- Shift+O  Artboard tool -->
  <bind gaction="win.tool-switch('Measure')"  keys="&lt;shift&gt;i" />      <!-- Shift+I  Measure -->

  <!-- Paste in Front / Back / In Place. Inkscape only has "paste in place";
       all AI variants map to it (position is identical; z-order goes to top). -->
  <bind gaction="win.paste-in-place"
        keys="&lt;primary&gt;f, &lt;primary&gt;b, &lt;primary&gt;&lt;shift&gt;v, &lt;primary&gt;&lt;shift&gt;b, &lt;primary&gt;&lt;alt&gt;v" />
  <bind gaction="win.dialog-open('Find')" keys="&lt;primary&gt;&lt;alt&gt;f" />  <!-- Find off Ctrl+F -->

  <!-- Type > Create Outlines -->
  <bind gaction="app.object-to-path" keys="&lt;primary&gt;&lt;shift&gt;o, &lt;primary&gt;&lt;shift&gt;c" />

  <!-- Object > Lock / Unlock All / Hide / Show All -->
  <bind gaction="app.selection-lock" keys="&lt;primary&gt;2" />
  <bind gaction="app.unlock-all"     keys="&lt;primary&gt;&lt;alt&gt;2" />
  <bind gaction="app.selection-hide" keys="&lt;primary&gt;3" />
  <bind gaction="app.unhide-all"     keys="&lt;primary&gt;&lt;alt&gt;3" />

  <!-- Arrange (explicit, in case a future base map drops them) -->
  <bind gaction="app.selection-top"    keys="&lt;primary&gt;&lt;shift&gt;bracketright" />
  <bind gaction="app.selection-bottom" keys="&lt;primary&gt;&lt;shift&gt;bracketleft" />
  <bind gaction="app.selection-raise"  keys="&lt;primary&gt;bracketright" />
  <bind gaction="app.selection-lower"  keys="&lt;primary&gt;bracketleft" />

  <!-- View: outline toggle on Ctrl+Y, Fit All on Ctrl+Alt+0 -->
  <bind gaction="win.canvas-display-mode-cycle" keys="&lt;primary&gt;y" />
  <bind gaction="win.canvas-zoom-drawing"       keys="&lt;primary&gt;&lt;alt&gt;0, 4" />
  <!-- === end illustrator-cs6.sh override block === -->
XML

DEFAULT_KEYS="$KEYS_DIR/default.xml"
if [ "$DO_KEYS" -eq 1 ]; then
  info "Override keymap  ->  $DEFAULT_KEYS"
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -f "$DEFAULT_KEYS" ] && ! grep -qF "$KEYS_MARKER" "$DEFAULT_KEYS"; then
      msg "(dry run) existing user default.xml found - would inject the block before </keys>"
    else
      msg "(dry run) would write default.xml with the CS6 override block"
    fi
  else
    CS6_BLOCK="$CS6_BLOCK" python3 - "$DEFAULT_KEYS" <<'PY'
import os, re, sys, io
path  = sys.argv[1]
block = os.environ["CS6_BLOCK"].rstrip() + "\n"
begin = "  <!-- === illustrator-cs6.sh override block === -->"
end   = "  <!-- === end illustrator-cs6.sh override block === -->"

if os.path.exists(path) and os.path.getsize(path) > 0:
    src = io.open(path, encoding="utf-8").read()
    if begin in src and end in src:
        src = re.sub(re.escape(begin) + r".*?" + re.escape(end), block.rstrip(),
                     src, count=1, flags=re.S)
        note = "refreshed existing override block"
    elif "</keys>" in src:
        src = src.replace("</keys>", block + "</keys>", 1)
        note = "injected override block into existing user keymap (your own binds kept)"
    else:
        raise SystemExit("existing %s has no </keys> - refusing to touch it" % path)
else:
    src = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<keys name="Illustrator CS6 muscle-memory overrides">\n'
           + block +
           '</keys>\n')
    note = "created"
io.open(path, "w", encoding="utf-8").write(src)
print("  " + note)
PY
  fi
fi

# ---------------------------------------------------------------------------
# 3.  preferences.xml  ->  AI-like base map + behaviour + theme
# ---------------------------------------------------------------------------
if [ "$DO_PREFS" -eq 1 ]; then
  info "Preferences  ->  $PREFS"
  [ -f "$PREFS" ] || die "preferences.xml still missing - launch Inkscape once, then re-run"
  DRY_RUN="$DRY_RUN" python3 - "$PREFS" <<'PY'
import sys, os, xml.etree.ElementTree as ET
path = sys.argv[1]
dry  = os.environ.get("DRY_RUN") == "1"

tree = ET.parse(path)
root = tree.getroot()                       # <inkscape>
changes = []

def child_group(parent, gid, create=True):
    for g in parent.findall("group"):
        if g.get("id") == gid:
            return g
    if not create:
        return None
    g = ET.SubElement(parent, "group"); g.set("id", gid)
    return g

def options():
    return child_group(root, "options")

def setattrs(el, where, **kv):
    for k, v in kv.items():
        v = str(v)
        if el.get(k) != v:
            changes.append("%s @%s: %r -> %r" % (where, k, el.get(k), v))
            el.set(k, v)

opts = options()

# --- 3a. base keymap: the shipped "Adobe Illustrator" map --------------------
kb = None
for g in opts.findall("group"):
    if "shortcutfile" in g.attrib or g.get("id") in ("kbshortcuts", "kbdshortcuts"):
        kb = g; break
if kb is None:
    kb = child_group(opts, "kbshortcuts")
setattrs(kb, "options/%s" % kb.get("id"), shortcutfile="adobe-illustrator-cs2.xml")

# --- 3b. AI-like editing behaviour -----------------------------------------
setattrs(child_group(opts, "nudgedistance"),     "options/nudgedistance",     value="1px")
setattrs(child_group(opts, "rotationsnapsperpi"),"options/rotationsnapsperpi",value="12")     # 15 deg
setattrs(child_group(opts, "zoomincrement"),     "options/zoomincrement",     value="1.414213562")
setattrs(child_group(opts, "spacebarpans"),      "options/spacebarpans",      value="1")
setattrs(child_group(opts, "savewindowgeometry"),"options/savewindowgeometry",value="1")
setattrs(child_group(opts, "preservetransform"), "options/preservetransform", value="0")     # optimized
setattrs(child_group(opts, "transform"),         "options/transform",
         stroke="0", rectcorners="0", pattern="1", gradient="1")

# --- 3c. theme: dark + symbolic icons + narrow spin buttons ---------------
setattrs(child_group(root, "theme"), "theme",
         preferDarkTheme="1", darkTheme="1", symbolicIcons="1", narrowSpinButton="1")

if not changes:
    print("  already up to date")
else:
    for c in changes:
        print("  " + c)
    if dry:
        print("  (dry run) not written")
    else:
        try:
            ET.indent(tree, space="  ")      # py>=3.9; cosmetic only
        except Exception:
            pass
        tree.write(path, encoding="UTF-8", xml_declaration=True)
        print("  written")
PY
fi

echo
info "Done.  Restart Inkscape for changes to take effect."
[ "$DO_BACKUP" -eq 1 ] && [ "$DRY_RUN" -eq 0 ] && msg "Undo:  $0 --revert"
cat <<'NOTE'

  Quick sanity check after restart (Edit > Preferences > Interface > Keyboard):
  the shortcut file should read "Adobe Illustrator", and e.g. Ctrl+Shift+O
  should be listed for "Object to Path".

  Known intentional deviations from CS6:
    * Ctrl+D  = Duplicate (Inkscape has no "Transform Again")
    * Ctrl+F  = Paste in Front  ->  Find dialog moved to Ctrl+Alt+F
    * mouse wheel still scrolls; use Ctrl+wheel to zoom (not configurable in 1.4)
NOTE
