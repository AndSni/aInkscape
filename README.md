# aInkscape — make Inkscape feel like Adobe Illustrator

**aInkscape** is a small set of shell scripts that reconfigure **Inkscape 1.4.x** for
designers moving over from **Adobe Illustrator** (CS6 and later) who have years of
keyboard **muscle memory** and expect real **CMYK colour swatches** and
**print-industry colour libraries**.

It does three things:

1. **Illustrator keyboard shortcuts** — switches Inkscape to the shipped *Adobe
   Illustrator* keymap and adds the CS6 shortcuts that map is missing
   (Paste in Front/Back, Create Outlines, Lock/Hide, Shape Builder, Artboard tool…),
   plus a batch of Illustrator-like behaviour tweaks.
2. **Illustrator-style swatches** — installs *Basic CMYK* and *Basic RGB / sRGB*
   swatch palettes like the ones Illustrator gives a new document, as real
   Adobe Swatch Exchange (`.ase`) and GIMP (`.gpl`) files.
3. **Open print colour libraries** — downloads and installs the **HLC Colour Atlas**
   and the **Open Colour Systems Collection** (HKS, offset & screen printing inks,
   paper whites, DIN 6164, British/Australian Standard…): a free, redistributable
   **Pantone / RAL alternative** built on CIELAB.

Every script is **idempotent**, **backs up** what it changes, and has a **`--revert`**.
Nothing is sent anywhere; the only network access is script 3 downloading the
Creative-Commons colour archives from freiefarbe.de.

- Developed on **Fedora Linux** with **Inkscape 1.4.4**. Should work on any Linux
  distro; see [Compatibility](#compatibility).
- Scripts: **MIT licensed**. Downloaded colour data: **CC BY-ND 4.0** (installed
  unmodified, not redistributed in this repo).

---

## Table of contents

- [Why this exists](#why-this-exists)
- [What's in the box](#whats-in-the-box)
- [Requirements](#requirements)
- [Install](#install)
- [1. `illustrator-cs6-inkscape.sh` — Illustrator keymap & behaviour](#1-illustrator-cs6-inkscapesh--illustrator-keymap--behaviour)
- [2. `inkscape-ai-swatches.sh` — Illustrator-style CMYK / RGB swatches](#2-inkscape-ai-swatchessh--illustrator-style-cmyk--rgb-swatches)
- [3. `inkscape-print-libraries.sh` — open print colour libraries](#3-inkscape-print-librariessh--open-print-colour-libraries)
- [What gets changed on disk](#what-gets-changed-on-disk)
- [Reverting / uninstalling](#reverting--uninstalling)
- [Known limitations](#known-limitations)
- [Compatibility](#compatibility)
- [How it works](#how-it-works)
- [Licensing](#licensing)
- [Credits](#credits)
- [Contributing](#contributing)

---

## Why this exists

If you have spent a decade or two in Adobe Illustrator and then switch to Inkscape,
three things break your flow immediately:

- **The keyboard is wrong.** `V`/`A` selection, `Ctrl+F`/`Ctrl+B` paste, Create
  Outlines, Lock, Hide, Shape Builder, the Artboard tool — the keys are different
  or unbound. Inkscape ships an "Adobe Illustrator" keymap, but it only covers the
  basics and it is not enabled by default.
- **There are no CMYK swatches.** A new Illustrator document comes with *Basic CMYK*
  or *Basic RGB* swatches; Inkscape starts empty and RGB-only.
- **Pantone is gone.** Adobe removed Pantone books from Illustrator in 2022 for
  licensing reasons; Inkscape never had them. Pantone, RAL, TOYO, DIC, Focoltone
  and Trumatch are all trademarked and cannot legally be bundled by anyone.

aInkscape fixes the first two directly and answers the third with the genuinely
open, CIELAB-based colour systems that the print industry publishes for free.

## What's in the box

| Script | What it does | What it touches | Reversible |
|---|---|---|---|
| `illustrator-cs6-inkscape.sh` | Selects the Adobe Illustrator keymap, installs a `keys/default.xml` override with the missing CS6 shortcuts, patches Illustrator-like behaviour (nudge, rotate snap, zoom step, no stroke scaling, dark UI…) | `preferences.xml`, `keys/default.xml` | `--revert` (timestamped backup) |
| `inkscape-ai-swatches.sh` | Installs *Illustrator CMYK* + *CMYK Tints* (true `.ase` CMYK) and *Illustrator RGB* (`.gpl`) palettes; optional CMYK soft-proof setup | `palettes/`, optionally `preferences.xml` | `--revert` (timestamped backup) |
| `inkscape-print-libraries.sh` | Downloads & installs HLC Colour Atlas + Open Colour Systems Collection print palettes | `palettes/` only | `--revert` (manifest-tracked) |
| `install.sh` | Symlinks the three scripts into a `bin` dir on your `PATH` | `~/.local/bin` | `./install.sh --uninstall` |

## Requirements

- **Inkscape 1.4.x** (tested on 1.4.4). The native distro package is recommended.
- **bash**, **python3** (standard library only — no pip packages), **coreutils**.
- **curl** and **unzip** — only for `inkscape-print-libraries.sh`.
- **Quit Inkscape before running any script.** Inkscape rewrites `preferences.xml`
  on exit and would overwrite the changes.

## Install

```sh
git clone https://github.com/AndSni/aInkscape.git
cd aInkscape
./install.sh                 # symlinks the 3 scripts into ~/.local/bin
```

Or don't install anything and just run them from the clone:

```sh
./illustrator-cs6-inkscape.sh --dry-run
```

Every script supports `--help`, `--dry-run`, `--revert` and `--profile-dir DIR`
(or the `INKSCAPE_PROFILE_DIR` environment variable) for a non-standard Inkscape
profile location. Flatpak profiles are auto-detected.

**Recommended first run:**

```sh
./illustrator-cs6-inkscape.sh
./inkscape-ai-swatches.sh
./inkscape-print-libraries.sh        # needs curl + unzip, ~9 MB download
# then restart Inkscape
```

---

## 1. `illustrator-cs6-inkscape.sh` — Illustrator keymap & behaviour

### What it changes

**Base keymap** — sets `preferences.xml` → *Adobe Illustrator*
(`adobe-illustrator-cs2.xml`, shipped with Inkscape). That alone gives you
`V`/`E` select, `A` direct-select, `P` pen, `T` type, `M` rectangle, `L` ellipse,
`N` pencil, `I` eyedropper, `K` paint bucket, `Ctrl+Y` outline view, `Ctrl+5`
guides, `Ctrl+7` clip, the panel F-keys, and Illustrator zoom keys.

**Override keymap** — writes `~/.config/inkscape/keys/default.xml`, which Inkscape
always loads last, with the CS6 shortcuts the base map does not provide:

| Illustrator CS6 | Bound to |
|---|---|
| `Ctrl+F` / `Ctrl+B` / `Ctrl+Shift+V` — Paste in Front / Back / in Place | Inkscape *Paste in Place* (position identical; z-order goes to top) |
| `Ctrl+Shift+O` — Create Outlines | Object → Object to Path |
| `Ctrl+2` / `Ctrl+Alt+2` — Lock / Unlock All | ✓ |
| `Ctrl+3` / `Ctrl+Alt+3` — Hide / Show All | ✓ |
| `Shift+M` — Shape Builder | Booleans tool |
| `Shift+O` — Artboard tool | Page tool |
| `Shift+I` — Measure | ✓ |
| `Ctrl+Alt+0` — Fit All in Window | ✓ |
| `Ctrl+Shift+[` `]` / `Ctrl+[` `]` — arrange | ✓ |

The Find dialog moves off `Ctrl+F` to `Ctrl+Alt+F`.

**Behaviour** (`preferences.xml`):

- keyboard nudge `1px` (was `2px`)
- rotate snap `15°`
- zoom step `√2`
- **don't scale stroke width or rounded corners when resizing** (Illustrator default)
- store transforms "optimized"
- spacebar-pan on, remember window geometry
- dark theme + symbolic icons + narrow spin buttons (enforced for clean installs)

### Usage

```sh
illustrator-cs6-inkscape.sh [--dry-run] [--no-backup] [--no-prefs] [--no-keys]
                            [--profile-dir DIR]
illustrator-cs6-inkscape.sh --revert          # restore newest backup
illustrator-cs6-inkscape.sh --help
```

| Flag | Effect |
|---|---|
| `--dry-run` | print what would change, write nothing |
| `--no-keys` | skip the `keys/default.xml` override, only touch prefs |
| `--no-prefs` | skip `preferences.xml`, only install the keymap file |
| `--no-backup` | don't create the `cs6-backup-*` snapshot |
| `--revert` | restore `preferences.xml` and `keys/` from the newest backup |

If `preferences.xml` doesn't exist yet (fresh machine) the script launches Inkscape
once, headless, to generate defaults, then patches them.

---

## 2. `inkscape-ai-swatches.sh` — Illustrator-style CMYK / RGB swatches

Installs into `~/.config/inkscape/palettes/`:

| File | Contents |
|---|---|
| `Illustrator-CMYK.ase` | True-CMYK Adobe Swatch Exchange: White, Black, CMYK Red/Yellow/Green/Cyan/Blue/Magenta, Registration, Black 10–90 %, a few rich mixes, **plus a C/M/Y/K 10–100 % process tint chart** (~63 swatches) |
| `Illustrator-RGB.gpl` | Basic RGB / sRGB: White, Black, RGB Red/Yellow/Green/Cyan/Blue/Magenta, grey ramp |

Inkscape already ships some sRGB-ish palettes too — **WebHex** (web-safe) and
**SVG** (the 147 named CSS colours).

### Usage

```sh
inkscape-ai-swatches.sh [--dry-run] [--no-backup] [--color-management]
                        [--profile-dir DIR]
inkscape-ai-swatches.sh --revert
inkscape-ai-swatches.sh --help
```

`--color-management` also turns on **CMYK soft-proofing**: it finds a CMYK ICC
profile (US Web Coated SWOP / Coated FOGRA39 if present, otherwise the generic
Ghostscript `default_cmyk.icc`) and sets `preferences.xml` to proof against it.
Get real press profiles for free from ECI (see below) and re-run.

### Using your own Illustrator swatches

In Illustrator: **Swatches panel menu → Save Swatch Library as ASE**, then copy
the `.ase` files into `~/.config/inkscape/palettes/` and restart Inkscape.
Inkscape 1.4 reads Adobe Swatch Exchange (`.ase`) and Adobe Color Book (`.acb`),
including CMYK- and LAB-defined swatches.

---

## 3. `inkscape-print-libraries.sh` — open print colour libraries

Downloads (cached in `~/.cache/inkscape-print-libraries/`) and installs, verbatim,
two Creative-Commons colour collections:

**HLC Colour Atlas** — freieFarbe e.V. — **2040 colours defined in CIELAB**.
A systematic Hue / Lightness / Chroma atlas, device-independent, designed as an
open alternative to Pantone and RAL, with no licence fees. `--xl` installs the
**13 283-colour** version instead.

**Open Colour Systems Collection (OCSC) 2.0** — dtp studio oldenburg — **376
spectrally-measured colour systems**, all CIELAB. The default `--print` subset
installs the graphic-arts ones:

| Category | Libraries |
|---|---|
| Spot colour (Europe) | HKS N, HKS K, HKS E, HKS Z, HKS N/K 3000plus, HKS Rasterfächer |
| Offset inks | K+E Novavit Serie 250, Siegwerk Druckfarben, MAN print & sign |
| Screen-printing inks | Sericol Std / Tx / UCG, Marabu Siebdruck, Marabu TX |
| Tint / raster fans | J+S Rasterfächer, J+S K / N, J+S K mit Raster |
| Paper white | GS Palette 141 Naturpapier / Kunstdruck, DeutschePapier |
| Standards | DIN 6164, British Standard, Australian Standard |

### Usage

```sh
inkscape-print-libraries.sh [--print | --all] [--format ase|gpl|both]
                            [--xl] [--no-download] [--dry-run] [--profile-dir DIR]
inkscape-print-libraries.sh --list        # names of all 376 OCSC collections
inkscape-print-libraries.sh --revert      # remove everything this installed
inkscape-print-libraries.sh --help
```

| Flag | Effect |
|---|---|
| `--print` | *(default)* curated graphic-arts subset (~26 libraries) |
| `--all` | every OCSC collection — paints, vinyl films, artist oils, architectural standards (~376 palettes in the menu) |
| `--format ase` | *(default)* CIELAB `.ase` — best fidelity |
| `--format gpl` | RGB-preconverted GIMP palettes |
| `--format both` | install both |
| `--xl` | HLC Colour Atlas 13 283-colour edition |
| `--no-download` | use only what's already in the cache |
| `--list` | print all OCSC collection names and exit |
| `--revert` | delete every file listed in `palettes/.print-libraries-manifest` |

Installed files are prefixed `OCSC - …` so they group together in Inkscape's
palette menu. Attribution and the CC licence text are written next to them
(`PRINT-LIBRARIES-ATTRIBUTION.txt`, `OCSC-Licence.txt`, `OCSC-Readme.txt`).

### Accurate CMYK preview

These libraries are CIELAB values; Inkscape shows them through an RGB conversion.
For a true press preview, install a real CMYK ICC profile — the free ones are
**ECI's** ISO Coated v2 / PSO Uncoated v3 from <https://www.eci.org/en/downloads> —
then run `inkscape-ai-swatches.sh --color-management`.

---

## In Inkscape after installing

- **Keyboard:** *Edit → Preferences → Interface → Keyboard* — the shortcut file
  should read *Adobe Illustrator*.
- **Swatches:** *Object → Swatches* (`Shift+Ctrl+W`) → the small palette menu at
  the top-right of the swatch strip → pick *Illustrator CMYK*, *HLC Colour Atlas*,
  *OCSC - HKS N 3000plus*, …
- **Colour picker mode:** *Fill & Stroke* (`Shift+Ctrl+F`) — the colour picker has
  a menu to switch the wheel/sliders to **CMYK**, RGB, HSL, OKLCH, …

## What gets changed on disk

Everything lives under your Inkscape profile, normally `~/.config/inkscape/`
(Flatpak: `~/.var/app/org.inkscape.Inkscape/config/inkscape/`):

```
preferences.xml                         # scripts 1 and 2 (--color-management)
keys/default.xml                        # script 1  (override shortcuts)
palettes/Illustrator-CMYK.ase           # script 2
palettes/Illustrator-RGB.gpl            # script 2
palettes/HLC Colour Atlas.ase           # script 3
palettes/OCSC - *.ase                   # script 3
palettes/.print-libraries-manifest      # script 3  (revert list)
cs6-backup-<timestamp>/                 # script 1  (preferences.xml + keys/)
swatch-backup-<timestamp>/              # script 2  (palettes/ + preferences.xml)
```

## Reverting / uninstalling

```sh
illustrator-cs6-inkscape.sh --revert     # restore prefs + keymap from newest backup
inkscape-ai-swatches.sh --revert         # restore palettes + prefs from newest backup
inkscape-print-libraries.sh --revert     # delete the downloaded palettes
./install.sh --uninstall                 # remove the ~/.local/bin symlinks
```

The backup folders (`cs6-backup-*`, `swatch-backup-*`) are left in place — delete
them by hand when you're happy.

## Known limitations

- **Mouse wheel still scrolls.** Inkscape 1.4 has no "wheel zooms instead of
  scrolls" preference. Use `Ctrl`+wheel to zoom, `Shift`+wheel for horizontal.
- **`Ctrl+D` stays Duplicate.** Inkscape has no "Transform Again" command, so
  Illustrator's `Ctrl+D` can't be reproduced.
- **`Ctrl+F` is remapped to Paste in Front.** Inkscape's Find dialog moves to
  `Ctrl+Alt+F`. Skip script 1's keymap part with `--no-keys` if you'd rather keep
  Inkscape's Find binding.
- **CMYK is display-converted.** Inkscape renders in RGB; CMYK/LAB swatches keep
  their numbers but are shown via conversion. Link a CMYK ICC profile for accuracy.
- **No Pantone / RAL / TOYO / DIC / Focoltone / Trumatch.** They are trademarked
  and cannot be redistributed. Use the vendor's own plug-in or files.
- **Flatpak:** the profile is auto-detected, but script 1's clean-install path
  needs `inkscape` on your `PATH` to generate a default `preferences.xml`.

## Compatibility

- **Inkscape 1.4.x** — developed and tested against 1.4.4 on Fedora 44.
- **Inkscape 1.1–1.3** — the keymap override and most preference keys should work;
  ASE import needs ≥ 1.1; LAB ASE needs a recent 1.x. Untested.
- **Inkscape 0.92 and earlier** — not supported (different action names, no ASE).
- **Linux** — any distro. `curl`, `unzip`, `python3`, `bash` are the only
  non-Inkscape dependencies.
- **macOS** — untested; try
  `--profile-dir "$HOME/Library/Application Support/org.inkscape.Inkscape"`.

## How it works

- **`keys/default.xml`** is a special file Inkscape always loads *after* the
  selected shortcut file, so it's the safe place for user overrides. A
  custom-named keymap in the user `keys/` folder is *not* picked up — Inkscape
  resolves the `shortcutfile` preference only against its system keys directory.
- **`preferences.xml`** is patched with Python's standard-library `xml.etree`:
  find the `<group id="…">`, set attributes, write back. Inkscape normalises the
  file again on its next exit.
- **`.ase` (Adobe Swatch Exchange)** is a documented binary format: `ASEF`
  signature, big-endian block list, colour blocks carrying a `RGB `, `CMYK`,
  `LAB ` or `Gray` model tag and IEEE-754 floats. `inkscape-ai-swatches.sh`
  generates one directly; Inkscape 1.4 reads all four models.

## Licensing

- **Scripts** (`*.sh`): MIT — see [`LICENSE`](LICENSE).
- **Colour data**: not included in this repository. `inkscape-print-libraries.sh`
  downloads it on request and installs it **unmodified**:
  - *HLC Colour Atlas* — © freieFarbe e.V. — **CC BY-ND 4.0**
  - *Open Colour Systems Collection 2.0* — © dtp studio oldenburg — **CC BY-ND 4.0**

  CC BY-ND 4.0 permits verbatim redistribution, including commercially, with
  attribution; it does **not** permit distributing modified colour data.

## Credits

- [Inkscape](https://inkscape.org/) — the application this configures.
- [freieFarbe e.V.](https://freiefarbe.de/) — HLC Colour Atlas and the Open
  Colour Systems Collection release.
- [dtp studio oldenburg](https://www.dtpstudio.de/) — the OCSC measurements.
- [ECI](https://www.eci.org/) — free offset-printing ICC profiles.

## Contributing

Issues and pull requests welcome. Please keep the scripts:

- **bash + POSIX tools + standard-library python3** only — no runtime dependencies;
- **idempotent** — safe to run twice;
- **reversible** — back up before writing, provide a `--revert`;
- **non-destructive by default** — support `--dry-run`.

---

<sub>Keywords: Inkscape Adobe Illustrator keyboard shortcuts keymap CS6 muscle memory,
Inkscape CMYK swatches, Inkscape Pantone alternative, open source print colour
library, HLC Colour Atlas, Open Colour Systems Collection, CIELAB palette, ASE
Adobe Swatch Exchange, switch from Illustrator to Inkscape, Linux Fedora graphic
design.</sub>
