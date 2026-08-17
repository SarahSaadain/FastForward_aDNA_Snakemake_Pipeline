#!/usr/bin/env python3
"""
Side-loads the pinned release of REVEAL (https://github.com/SarahSaadain/REVEAL) into this conda
environment, since REVEAL is not yet published on bioconda.

Snakemake runs this once, automatically, right after creating the conda environment from the
neighboring reveal.yaml (see "Post-Deployment Scripts for Conda Environments" in the Snakemake
docs) -- no manual setup needed, and every reveal_module rule keeps calling the plain `REVEAL`
command as if it came from bioconda.

Mirrors REVEAL's own shell/install.sh (which installs into $CONDA_PREFIX of the currently active
conda env) and conda/build.sh (what the eventual bioconda recipe will do) -- just triggered by
Snakemake instead of by hand.

Selected via pipeline.reveal_module.settings.version_source: "pinned" (the default; see
initialize.smk, which maps that setting to this env file). Since conda only re-runs this script
when the environment is (re)created, bumping REVEAL_PINNED_TAG below requires recreating the env
to take effect (e.g. `snakemake --conda-create-envs-only --conda-cleanup-envs`).

Once reveal-tools is published on bioconda: replace reveal.yaml's dependency list with
`- reveal-tools` and delete this file. No rule changes are needed either way.
"""

import hashlib
import os
import shutil
import tarfile
import tempfile
import urllib.request

REVEAL_REPO = "SarahSaadain/REVEAL"

# Pinned default: exact tag + sha256 of its source tarball (matches REVEAL's own
# conda/meta.yaml). GitHub does not expose a digest API for auto-generated source archives
# (unlike uploaded release assets), so this must be updated by hand -- e.g. via
# `curl -sL <url> | shasum -a 256` -- whenever the pinned tag is bumped.
REVEAL_PINNED_TAG = "v1.0.0"
REVEAL_PINNED_SHA256 = "93c65603a2db0bc5ee2dd551468f385fb7fdcf44cc33534d3b37ff68d0338843"

tarball_url = f"https://github.com/{REVEAL_REPO}/archive/refs/tags/{REVEAL_PINNED_TAG}.tar.gz"
description = f"pinned release {REVEAL_PINNED_TAG}"

conda_prefix = os.environ["CONDA_PREFIX"]
reveal_bin = os.path.join(conda_prefix, "bin", "REVEAL")

if os.path.isfile(reveal_bin):
    raise SystemExit(0)

print(f"Side-loading REVEAL ({description}) into {conda_prefix}")

with tempfile.TemporaryDirectory() as tmp_dir:
    tarball_path = os.path.join(tmp_dir, "reveal.tar.gz")
    urllib.request.urlretrieve(tarball_url, tarball_path)

    digest = hashlib.sha256()
    with open(tarball_path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    print(f"Downloaded {tarball_url} (sha256: {digest.hexdigest()})")
    if digest.hexdigest() != REVEAL_PINNED_SHA256:
        raise RuntimeError(
            f"downloaded {tarball_url} does not match expected sha256 {REVEAL_PINNED_SHA256}"
        )

    with tarfile.open(tarball_path) as tar:
        tar.extractall(tmp_dir)

    extracted_dirs = [
        name for name in os.listdir(tmp_dir) if os.path.isdir(os.path.join(tmp_dir, name))
    ]
    if len(extracted_dirs) != 1:
        raise RuntimeError(
            f"expected exactly one top-level directory in {tarball_url}, found {extracted_dirs}"
        )
    src_dir = os.path.join(tmp_dir, extracted_dirs[0], "src")

    lib_dir = os.path.join(conda_prefix, "lib", "reveal")
    os.makedirs(lib_dir, exist_ok=True)
    for name in os.listdir(src_dir):
        if name.endswith(".py") or name.endswith(".R"):
            shutil.copy2(os.path.join(src_dir, name), os.path.join(lib_dir, name))

with open(reveal_bin, "w") as f:
    f.write('#!/bin/bash\nexec python "$CONDA_PREFIX/lib/reveal/reveal.py" "$@"\n')
os.chmod(reveal_bin, 0o755)

print(f"REVEAL ({description}) installed at {reveal_bin}")
