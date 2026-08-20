#!/usr/bin/env python3
"""
Side-loads REVEAL (https://github.com/SarahSaadain/REVEAL) into this conda environment, since
REVEAL is not yet published on bioconda.

Snakemake runs this once, automatically, right after creating the conda environment from the
neighboring reveal.yaml (see "Post-Deployment Scripts for Conda Environments" in the Snakemake
docs) -- no manual setup needed, and every reveal_module rule keeps calling the plain `REVEAL`
command as if it came from bioconda.

Selected via pipeline.reveal_module.settings.version_source: "conda" (the default; see
initialize.smk, which maps that setting to this env file). "conda" means "whatever the conda
package provides", but no such package exists yet -- so until it does, this script stands in for
it and installs the newest tagged GitHub release. Unpinned by design, since there is nothing to
pin against: recreate the env to pick up a newer release (e.g. `snakemake
--conda-create-envs-only --conda-cleanup-envs`).

Once reveal-tools is published on bioconda: replace reveal.yaml's dependency list with
`- reveal-tools` and delete this file. No rule changes are needed either way.
"""

import hashlib
import json
import os
import shutil
import tarfile
import tempfile
import urllib.request

REVEAL_REPO = "SarahSaadain/REVEAL"

GITHUB_API_HEADERS = {
    "User-Agent": "pastForward-pipeline",
    "Accept": "application/vnd.github+json",
}


def _latest_release_tag():
    req = urllib.request.Request(
        f"https://api.github.com/repos/{REVEAL_REPO}/releases/latest",
        headers=GITHUB_API_HEADERS,
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["tag_name"]


resolved_tag = _latest_release_tag()
tarball_url = f"https://github.com/{REVEAL_REPO}/archive/refs/tags/{resolved_tag}.tar.gz"
description = f"latest release ({resolved_tag})"

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
