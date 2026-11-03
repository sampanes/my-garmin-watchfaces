"""Bake the watch's cutout planes from the generator's PNGs.

The opinion-round mock (compose_preview.py) turns every mass and near hill
into a paper cutout at compose time (paper_backed: its ink over its own
paper, so the horizon and farther masses behind it are hidden) and mirrors
the wide mountain when its summit belongs at the right end. The watch has
no per-pixel step for that, so this script bakes exactly the mock's images
(compose_preview.mass_image) into resources/drawables as *_cut[_night].png,
plus the mirrored twins of the wide planes:

    spire, spire_pale, broad, broad_pale, wide_mountain, wide_mountain_pale,
    near_hill, near_hill2                -> <name>_cut.png, <name>_cut_night.png
    wide_mountain, wide_mountain_pale    -> <name>_flip_cut.png, ..._flip_cut_night.png

Run it after gen_ink_layers.py --only extras. --check exits 1 when a baked
file no longer matches what the mock would paint (a plane was regenerated
and not re-baked)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose_preview as cp  # noqa: E402
from PIL import Image, ImageChops  # noqa: E402

PLANES = ["spire", "spire_pale", "broad", "broad_pale", "wide_mountain",
          "wide_mountain_pale", "near_hill", "near_hill2"]
FLIPPED = ["wide_mountain", "wide_mountain_pale"]


def targets():
    for name in PLANES:
        for night in (False, True):
            yield name, night, False, name + "_cut" + ("_night" if night else "") + ".png"
    for name in FLIPPED:
        for night in (False, True):
            yield name, night, True, name + "_flip_cut" + ("_night" if night else "") + ".png"


def main(argv):
    check = "--check" in argv
    stale = 0
    for name, night, flip, out in targets():
        img = cp.mass_image(name, night, flip)
        path = os.path.join(cp.DRAW, out)
        if check:
            same = os.path.exists(path) and ImageChops.difference(
                Image.open(path).convert("RGBA"), img).getbbox() is None
            if not same:
                print("stale:", out)
                stale += 1
        else:
            img.save(path, optimize=True)
            print("wrote", out, os.path.getsize(path), "bytes")
    if check:
        print("cutouts:", "all current" if not stale else "%d stale" % stale)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
