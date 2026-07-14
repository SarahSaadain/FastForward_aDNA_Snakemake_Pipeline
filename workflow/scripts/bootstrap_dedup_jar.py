"""
Ensures the pinned DeDup fork jar (see DEDUP_VERSION/DEDUP_JAR_URL below) is
present at DEDUP_JAR_PATH, downloading it from the fork's GitHub release if
missing. Runs automatically when the Snakefile is parsed (see the `include:`
in workflow/Snakefile) so a fresh clone works with zero manual setup: the
first `snakemake` invocation downloads the jar once, and every invocation
after that is a fast no-op check.

Replaces the previous approach of building the fork from source via
conda-build/gradle on every fresh clone.

Fork: https://github.com/SarahSaadain/DeDup
Benchmarks vs. upstream DeDup: https://github.com/SarahSaadain/DeDup_comparison_fork
"""

import hashlib
import os
import urllib.request

from snakemake_interface_executor_plugins.settings import ExecMode

DEDUP_VERSION = "0.13.0"
DEDUP_JAR_URL = f"https://github.com/SarahSaadain/DeDup/releases/download/{DEDUP_VERSION}/DeDup-{DEDUP_VERSION}.jar"
# Pin the expected sha256 of the downloaded jar. Leave empty to skip
# verification (e.g. before the release has been published).
DEDUP_JAR_SHA256 = ""


def _sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def dedup_jar_path(repo_root):
    return os.path.join(repo_root, "resources", "dedup", f"DeDup-{DEDUP_VERSION}.jar")


def ensure_dedup_jar(jar_path):
    if os.path.isfile(jar_path):
        return

    logger.info(f"DeDup fork jar {DEDUP_VERSION} not found — downloading from {DEDUP_JAR_URL}")
    os.makedirs(os.path.dirname(jar_path), exist_ok=True)
    tmp_path = jar_path + ".tmp"
    urllib.request.urlretrieve(DEDUP_JAR_URL, tmp_path)
    if DEDUP_JAR_SHA256 and _sha256(tmp_path) != DEDUP_JAR_SHA256:
        os.remove(tmp_path)
        raise RuntimeError(f"downloaded {DEDUP_JAR_URL} does not match pinned sha256")
    os.rename(tmp_path, jar_path)


DEDUP_JAR_PATH = dedup_jar_path(os.path.dirname(workflow.basedir))

if workflow.exec_mode != ExecMode.SUBPROCESS:
    ensure_dedup_jar(DEDUP_JAR_PATH)
