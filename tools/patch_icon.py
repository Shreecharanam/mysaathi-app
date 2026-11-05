"""Copy the MySaathi launcher icons into the generated Android project.

The icons live in assets/launcher/ as ic_launcher_<size>.png and replace the
default Flutter launcher icon in every mipmap density folder.
"""

import os
import shutil

DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

RES = os.path.join("android", "app", "src", "main", "res")
SRC = os.path.join("assets", "launcher")

copied = 0
for folder, size in DENSITIES.items():
    src = os.path.join(SRC, "ic_launcher_%d.png" % size)
    if not os.path.exists(src):
        print("missing icon:", src)
        continue
    dest_dir = os.path.join(RES, folder)
    os.makedirs(dest_dir, exist_ok=True)
    for name in ("ic_launcher.png", "ic_launcher_round.png"):
        shutil.copyfile(src, os.path.join(dest_dir, name))
    copied += 1
    print("icon ->", folder)

if copied == 0:
    print("ERROR: no icons copied")
    raise SystemExit(1)

print("icon patch done (%d densities)" % copied)
