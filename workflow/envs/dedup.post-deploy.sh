#!/usr/bin/env python3
"""
Side-loads our DeDup fork (https://github.com/SarahSaadain/DeDup) into this
conda environment, since the fork isn't published on bioconda -- only
unmodified upstream DeDup is (as the `dedup` package/command).

Snakemake runs this once, automatically, right after creating the conda
environment from the neighboring dedup.yaml (see "Post-Deployment Scripts
for Conda Environments" in the Snakemake docs) -- no manual setup needed,
and the dedup rule keeps calling the plain `dedup` command.

The installed wrapper is adapted from bioconda's own dedup.py
(recipes/dedup/dedup.py in bioconda-recipes) so the CLI surface matches:
`-Xm*`/`-D*`/`-XX*` args are recognized as JVM options and the rest is
passed through to the jar, with `_JAVA_OPTIONS` honored as a fallback if no
`-Xm*` arg is given. That means if this fork's improvements are ever
released under the upstream `dedup` bioconda package, this env's dependency
can just go back to `- dedup` (bioconda) and this file can be deleted --
no rule changes needed either way.

Fork: https://github.com/SarahSaadain/DeDup
Benchmarks vs. upstream DeDup: https://github.com/SarahSaadain/DeDup_comparison_fork
"""

import hashlib
import json
import os
import urllib.request

DEDUP_VERSION = "0.13.0"
DEDUP_JAR_NAME = f"DeDup-{DEDUP_VERSION}.jar"
DEDUP_JAR_URL = f"https://github.com/SarahSaadain/DeDup/releases/download/{DEDUP_VERSION}/{DEDUP_JAR_NAME}"
DEDUP_RELEASE_API_URL = f"https://api.github.com/repos/SarahSaadain/DeDup/releases/tags/{DEDUP_VERSION}"

conda_prefix = os.environ["CONDA_PREFIX"]
dedup_bin = os.path.join(conda_prefix, "bin", "dedup")

if os.path.isfile(dedup_bin):
    raise SystemExit(0)


def _sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _fetch_expected_sha256():
    """Look up the jar's sha256 from the GitHub release asset metadata.

    GitHub computes and publishes a "sha256:<hex>" digest for each release
    asset, so the pinned checksum can be fetched instead of hardcoded and
    kept in sync automatically as DEDUP_VERSION is bumped.
    """
    request = urllib.request.Request(
        DEDUP_RELEASE_API_URL,
        headers={"Accept": "application/vnd.github+json", "User-Agent": "aDNA-Pipeline"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    for asset in release.get("assets", []):
        if asset.get("name") == DEDUP_JAR_NAME:
            digest = asset.get("digest", "")
            if digest.startswith("sha256:"):
                return digest.removeprefix("sha256:")
    raise RuntimeError(f"no sha256 digest found for {DEDUP_JAR_NAME} in {DEDUP_RELEASE_API_URL}")


print(f"Side-loading DeDup fork {DEDUP_VERSION} into {conda_prefix}")

jar_dir = os.path.join(conda_prefix, "share", f"dedup-{DEDUP_VERSION}")
os.makedirs(jar_dir, exist_ok=True)
jar_path = os.path.join(jar_dir, DEDUP_JAR_NAME)

expected_sha256 = _fetch_expected_sha256()
tmp_path = jar_path + ".tmp"
urllib.request.urlretrieve(DEDUP_JAR_URL, tmp_path)
if _sha256(tmp_path) != expected_sha256:
    os.remove(tmp_path)
    raise RuntimeError(f"downloaded {DEDUP_JAR_URL} does not match expected sha256 {expected_sha256}")
os.rename(tmp_path, jar_path)

# Wrapper adapted from bioconda-recipes' recipes/dedup/dedup.py, pointed at
# our fork's jar.
wrapper = f'''#!/usr/bin/env python3
import os
import sys
import subprocess
from os import access, getenv, X_OK

jar_path = {jar_path!r}
default_jvm_mem_opts = ['-Xms512m', '-Xmx1g']


def java_executable():
    java_home = getenv('JAVA_HOME')
    java_bin = os.path.join('bin', 'java')
    if java_home and access(os.path.join(java_home, java_bin), X_OK):
        return os.path.join(java_home, java_bin)
    return 'java'


def jvm_opts(argv):
    mem_opts = []
    prop_opts = []
    pass_args = []
    for arg in argv:
        if arg.startswith('-D') or arg.startswith('-XX'):
            prop_opts.append(arg)
        elif arg.startswith('-Xm'):
            mem_opts.append(arg)
        else:
            pass_args.append(arg)
    if mem_opts == [] and getenv('_JAVA_OPTIONS') is None:
        mem_opts = default_jvm_mem_opts
    return (mem_opts, prop_opts, pass_args)


def main():
    java = java_executable()
    mem_opts, prop_opts, pass_args = jvm_opts(sys.argv[1:])
    java_args = [java] + mem_opts + prop_opts + ['-jar', jar_path] + pass_args
    if '--jar_dir' in sys.argv[1:]:
        print(os.path.dirname(jar_path))
    else:
        sys.exit(subprocess.call(java_args))


if __name__ == '__main__':
    main()
'''

with open(dedup_bin, "w") as f:
    f.write(wrapper)
os.chmod(dedup_bin, 0o755)

print(f"DeDup fork {DEDUP_VERSION} installed at {dedup_bin}")
