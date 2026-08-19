#!/usr/bin/env python3
"""
Side-loads the latest tagged GitHub release of ECMSD (https://github.com/capoony/ECMSD) into this
conda environment, overriding the bioconda-installed copy created from the neighboring
ecmsd_git_release.yaml (see "Post-Deployment Scripts for Conda Environments" in the Snakemake
docs). Matches bioconda's own recipe layout (bioconda-recipes/recipes/ecmsd/build.sh) exactly so
every ecmsd rule keeps calling the plain `ECMSD` command unchanged.

Selected via pipeline.read_module.taxonomic_screening.tools.ecmsd.settings.version_source: "latest_release"
(see initialize.smk, which maps that setting to this env file). Unpinned by design -- recreate the
env to pick up a newer release (e.g. `snakemake --conda-create-envs-only --conda-cleanup-envs`).
"""

import hashlib
import json
import os
import shutil
import tarfile
import tempfile
import urllib.request

ECMSD_REPO = "capoony/ECMSD"

GITHUB_API_HEADERS = {
    "User-Agent": "pastForward-pipeline",
    "Accept": "application/vnd.github+json",
}


def _latest_release_tag():
    req = urllib.request.Request(
        f"https://api.github.com/repos/{ECMSD_REPO}/releases/latest",
        headers=GITHUB_API_HEADERS,
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["tag_name"]


resolved_tag = _latest_release_tag()
tarball_url = f"https://github.com/{ECMSD_REPO}/archive/refs/tags/{resolved_tag}.tar.gz"
description = f"latest release ({resolved_tag})"

conda_prefix = os.environ["CONDA_PREFIX"]

print(f"Side-loading ECMSD ({description}) into {conda_prefix}, overriding the bioconda-installed copy")

with tempfile.TemporaryDirectory() as tmp_dir:
    tarball_path = os.path.join(tmp_dir, "ecmsd.tar.gz")
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
    src_dir = os.path.join(tmp_dir, extracted_dirs[0])

    shell_dir = os.path.join(conda_prefix, "lib", "ecmsd", "shell")
    scripts_dir = os.path.join(conda_prefix, "lib", "ecmsd", "scripts")
    os.makedirs(shell_dir, exist_ok=True)
    os.makedirs(scripts_dir, exist_ok=True)

    shutil.copy2(os.path.join(src_dir, "shell", "ECMSD.sh"), os.path.join(shell_dir, "ECMSD.sh"))
    shutil.copy2(os.path.join(src_dir, "shell", "MakeRef.sh"), os.path.join(shell_dir, "MakeRef.sh"))
    for name in os.listdir(os.path.join(src_dir, "scripts")):
        if name.endswith(".py") or name.endswith(".R"):
            shutil.copy2(os.path.join(src_dir, "scripts", name), os.path.join(scripts_dir, name))

    ecmsd_bin = os.path.join(conda_prefix, "bin", "ECMSD")
    shutil.copy2(os.path.join(src_dir, "shell", "ECMSD.sh"), ecmsd_bin)
    os.chmod(ecmsd_bin, 0o755)

print(f"ECMSD ({description}) installed at {ecmsd_bin}")
