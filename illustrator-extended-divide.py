#!/usr/bin/env python3
"""Extended Divide -- Illustrator-style Pathfinder > Divide for Inkscape, plus
two opt-in cleanup toggles Illustrator doesn't have.

Given N selected, overlapping shapes (any z-order, groups are flattened),
slice the whole stack into every distinct face: for each shape, the region of
it not covered by anything stacked above it. Each face keeps its source
shape's fill/stroke. Disjoint regions of the same source become separate
objects; holes stay as sub-paths of their object unless another shape sits
inside the hole, in which case that inner shape becomes its own object again.
Results are grouped into one new <g>, matching Illustrator's Divide.

Two extra toggles (both off by default, matching plain Illustrator behaviour):

  --remove-uncolored  drop resulting faces whose source object had neither a
                      fill nor a stroke (the "invisible object" leftovers a
                      real Illustrator Divide also produces and most people
                      throw away by hand afterwards).
  --merge-by-color    after dividing, Union together every resulting face
                      that shares the same fill colour (Illustrator's
                      "Select Same Fill Colour, then Unite", automated).

Selected groups are expanded to their leaf shapes (recursively) in true
document paint order, then removed; groups left empty by that are deleted
too, everything else keeps its place.

Geometry is done with pyclipper (Clipper polygon-boolean library) because
inkex exposes no path-boolean operations of its own. Bezier curves in the
selection are flattened to straight segments first (--flatness); this is a
permanent trade-off, not a bug: see the aInkscape README for details.
"""

import copy

import inkex
from inkex import bezier

try:
    import pyclipper
except ImportError as exc:  # pragma: no cover - reported to the user, not testable headlessly
    raise inkex.AbortExtension(
        "The 'pyclipper' Python package is required but not installed.\n"
        "Install it with:  pip install --user --break-system-packages pyclipper\n"
        "(see the aInkscape README for details, including the Fedora caveat)"
    ) from exc

SCALE_EXPONENT = 4          # 10**4 - see README "How it works" for the safe-range rationale
SCALE = 10 ** SCALE_EXPONENT
MIN_CONTOUR_POINTS = 3
D_DECIMALS = 4

# Presentation properties to preserve even when the source expresses them as a
# bare XML attribute (fill="#f00") rather than in the style="" attribute --
# element.style only reflects the latter, so a plain deepcopy of it silently
# drops styling on SVGs authored that way (common for imported/hand-written SVG).
PRESENTATION_PROPS = [
    "fill", "stroke", "stroke-width", "stroke-opacity", "fill-opacity",
    "opacity", "stroke-linecap", "stroke-linejoin", "stroke-dasharray",
]


def _effective_style(element):
    style = copy.deepcopy(element.style)
    for prop in PRESENTATION_PROPS:
        if prop not in style:
            value = element.get_computed_style(prop)
            if value is not None:
                style[prop] = str(value)
    return style


def _is_uncolored(style):
    fill = str(style.get("fill", "")).strip().lower()
    stroke = str(style.get("stroke", "")).strip().lower()
    return fill in ("none", "") and stroke in ("none", "")


def _fill_key(style):
    return str(style.get("fill", "none")).strip().lower()


def _expand_to_leaves(elements):
    """Recursively flatten any container (group) elements in `elements` into
    their leaf descendants, returning (leaves, containers_to_clean_up) --
    containers is every original element that had children (so it can be
    deleted afterwards if left empty)."""
    leaves = []
    containers = []

    def walk(el):
        children = list(el.iterchildren())
        if children:
            containers.append(el)
            for child in children:
                walk(child)
        else:
            leaves.append(el)

    for el in elements:
        walk(el)
    return leaves, containers


def _document_order(svg, elements):
    """Return `elements` sorted into true document paint order (bottom -> top),
    regardless of what order they were originally collected in."""
    wanted = set(elements)
    return [el for el in svg.iter() if el in wanted]


def _polygons_from_element(element, flatness):
    """Return (polygons, fill_rule) for one element, in document user-unit
    space (ancestor transforms baked in), as plain (x, y) float tuples."""
    composed = element.composed_transform()
    path = element.path.transform(composed).to_superpath()
    bezier.cspsubdiv(path, flatness)

    polygons = []
    for subpath in path:
        pts = [(float(node[1][0]), float(node[1][1])) for node in subpath]
        if len(pts) >= MIN_CONTOUR_POINTS:
            polygons.append(pts)

    fill_rule = str(element.get_computed_style("fill-rule") or "nonzero").strip().lower()
    return polygons, fill_rule


def _pyclipper_fill(fill_rule):
    return pyclipper.PFT_EVENODD if fill_rule == "evenodd" else pyclipper.PFT_NONZERO


def _polytree_to_objects(root):
    """Walk a pyclipper PyPolyNode tree (as returned by Execute2) into a list
    of objects, each a list of int-space contours: [outer, hole, hole, ...].
    A non-hole child of a hole starts a brand new object (recursion) --
    that's a shape sitting inside another object's hole."""
    objects = []

    def start_object(node):
        contours = [node.Contour]
        for child in node.Childs:
            if child.IsHole:
                contours.append(child.Contour)
                for grandchild in child.Childs:
                    if not grandchild.IsHole:
                        start_object(grandchild)
            else:
                # Not expected from a well-formed Execute2() result (a non-hole
                # directly under a non-hole), but handled for robustness.
                start_object(child)
        objects.append(contours)

    for child in root.Childs:
        if not child.IsHole:
            start_object(child)
        else:
            # A hole directly under the dummy root is degenerate; its contour
            # itself is dropped but islands nested inside it still count.
            for grandchild in child.Childs:
                if not grandchild.IsHole:
                    start_object(grandchild)

    return objects


def _contours_to_path_d(int_contours):
    parts = []
    for contour in int_contours:
        if len(contour) < MIN_CONTOUR_POINTS:
            continue
        pts = pyclipper.scale_from_clipper(contour, SCALE)
        seg = " L ".join(f"{x:.{D_DECIMALS}f},{y:.{D_DECIMALS}f}" for x, y in pts)
        parts.append(f"M {seg} Z")
    return " ".join(parts)


class ExtendedDivide(inkex.EffectExtension):
    def add_arguments(self, pars):
        pars.add_argument(
            "--flatness", type=float, default=0.2,
            help="Curve-flattening tolerance in document user units (lower = more accurate, slower).",
        )
        pars.add_argument(
            "--remove-uncolored", type=inkex.Boolean, default=False, dest="remove_uncolored",
            help="Drop resulting faces whose source object had no fill and no stroke.",
        )
        pars.add_argument(
            "--merge-by-color", type=inkex.Boolean, default=False, dest="merge_by_color",
            help="Union together resulting faces that share the same fill colour.",
        )

    def effect(self):
        selected = list(self.svg.selection.values())
        leaves, containers = _expand_to_leaves(selected)
        elements = _document_order(self.svg, leaves)  # bottom -> top
        elements.reverse()                              # now top -> bottom

        pieces = []
        skipped = 0
        for element in elements:
            if isinstance(element, (inkex.TextElement, inkex.Image)):
                skipped += 1
                continue
            path_attr = getattr(element, "path", None)
            if not path_attr or len(path_attr) == 0:
                skipped += 1
                continue

            style = _effective_style(element)
            if self.options.remove_uncolored and _is_uncolored(style):
                skipped += 1
                continue

            polygons, fill_rule = _polygons_from_element(element, self.options.flatness)
            if not polygons:
                skipped += 1
                continue

            pieces.append(dict(
                element=element,
                style=style,
                fill_rule=fill_rule,
                polygons=pyclipper.scale_to_clipper(polygons, SCALE),
            ))

        if skipped:
            self.msg(
                f"Extended Divide: skipped {skipped} selected object(s) - "
                f"text/images/empty paths, or filtered by 'remove uncolored'."
            )
        if len(pieces) < 2:
            raise inkex.AbortExtension(
                "Select at least 2 overlapping shapes to Divide."
            )

        # faces: list of (style, [int_contours, int_contours, ...]) - one
        # entry per reconstructed object, built up across every source piece.
        faces = []
        cutter_union = None  # running union of everything processed so far, int space

        for piece in pieces:
            own_fill = _pyclipper_fill(piece["fill_rule"])

            # 1. Resolve this object's OWN true solid shape first (respecting its
            #    own fill-rule). This - not its raw, possibly self-overlapping
            #    polygons - is what actually occludes objects below it, so it is
            #    what gets folded into cutter_union in step 3. A flat (Execute)
            #    form is needed for that; a tree (Execute2) form is needed below
            #    when this happens to also BE the face (topmost object).
            self_clip = pyclipper.Pyclipper()
            self_clip.AddPaths(piece["polygons"], pyclipper.PT_SUBJECT, True)
            own_flat = self_clip.Execute(pyclipper.CT_UNION, own_fill, pyclipper.PFT_NONZERO)

            # 2. Face(Oi) = own shape minus everything stacked above it.
            face_clip = pyclipper.Pyclipper()
            face_clip.AddPaths(piece["polygons"], pyclipper.PT_SUBJECT, True)
            if cutter_union is not None:
                face_clip.AddPaths(cutter_union, pyclipper.PT_CLIP, True)
                tree = face_clip.Execute2(pyclipper.CT_DIFFERENCE, own_fill, pyclipper.PFT_NONZERO)
            else:
                # Topmost object: nothing above it, face == its own resolved shape.
                tree = face_clip.Execute2(pyclipper.CT_UNION, own_fill, pyclipper.PFT_NONZERO)

            for int_contours in _polytree_to_objects(tree):
                if any(len(c) >= MIN_CONTOUR_POINTS for c in int_contours):
                    faces.append((piece["style"], int_contours))

            # 3. Fold this object's OWN resolved shape (own_flat, not its raw
            #    polygons and not Face(Oi)) into the running occluder. Clipper's
            #    own output contours are always simple/consistently wound, so a
            #    plain nonzero union here is always safe regardless of the
            #    object's original fill-rule.
            union = pyclipper.Pyclipper()
            if cutter_union is not None:
                union.AddPaths(cutter_union, pyclipper.PT_SUBJECT, True)
            union.AddPaths(own_flat, pyclipper.PT_SUBJECT, True)
            cutter_union = union.Execute(pyclipper.CT_UNION, pyclipper.PFT_NONZERO, pyclipper.PFT_NONZERO)

        if self.options.merge_by_color:
            faces = _merge_faces_by_color(faces)

        group = self.svg.get_current_layer().add(inkex.Group())
        total_objects = 0
        for style, int_contours in faces:
            d = _contours_to_path_d(int_contours)
            if not d:
                continue
            new = group.add(inkex.PathElement())
            new.path = d
            new.style = copy.deepcopy(style)
            new.style["fill-rule"] = "evenodd"
            total_objects += 1

        if total_objects == 0:
            group.delete()
            raise inkex.AbortExtension("Divide produced no faces (empty result).")

        for piece in pieces:
            piece["element"].delete()
        # Groups (recursively) left with nothing in them are removed too, per
        # "flatten groups, keep layer order" - containers that still hold
        # un-processed content (e.g. skipped text/images) are left alone.
        for container in reversed(containers):
            if len(container) == 0:
                container.delete()


def _merge_faces_by_color(faces):
    """Union together every face that shares the same resolved fill colour,
    into ONE compound-path object per colour (Illustrator's own Pathfinder
    Unite always yields a single object, even for disjoint/holed geometry --
    unlike Divide's one-object-per-disjoint-region rule, which is deliberately
    NOT reused here). Representative style per group = its first face's style."""
    groups = {}
    order = []
    for style, int_contours in faces:
        key = _fill_key(style)
        if key not in groups:
            groups[key] = dict(style=style, contours=[])
            order.append(key)
        groups[key]["contours"].extend(int_contours)

    merged = []
    for key in order:
        entry = groups[key]
        contours = [c for c in entry["contours"] if len(c) >= MIN_CONTOUR_POINTS]
        if not contours:
            continue
        if len(contours) == 1:
            merged.append((entry["style"], contours))
            continue
        pc = pyclipper.Pyclipper()
        pc.AddPaths(contours, pyclipper.PT_SUBJECT, True)
        # Flat union (not Execute2/polytree): every resulting contour -- solid
        # islands AND holes alike -- becomes one subpath of a single evenodd
        # path, which alone is enough to render correctly (see README).
        flat = pc.Execute(pyclipper.CT_UNION, pyclipper.PFT_NONZERO, pyclipper.PFT_NONZERO)
        merged.append((entry["style"], flat))
    return merged


if __name__ == "__main__":
    ExtendedDivide().run()
