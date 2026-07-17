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
import json
import os
import urllib.request

from snakemake_interface_executor_plugins.settings import ExecMode

DEDUP_VERSION = "0.13.0"
DEDUP_JAR_NAME = f"DeDup-{DEDUP_VERSION}.jar"
DEDUP_JAR_URL = f"https://github.com/SarahSaadain/DeDup/releases/download/{DEDUP_VERSION}/{DEDUP_JAR_NAME}"
DEDUP_RELEASE_API_URL = f"https://api.github.com/repos/SarahSaadain/DeDup/releases/tags/{DEDUP_VERSION}"


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


def dedup_jar_path(repo_root):
    return os.path.join(repo_root, "resources", "dedup", DEDUP_JAR_NAME)


def ensure_dedup_jar(jar_path):
    if os.path.isfile(jar_path):
        return

    logger.info(f"DeDup fork jar {DEDUP_VERSION} not found — downloading from {DEDUP_JAR_URL}")
    os.makedirs(os.path.dirname(jar_path), exist_ok=True)

    try:
        expected_sha256 = _fetch_expected_sha256()
    except Exception as e:
        raise RuntimeError(
            f"could not fetch expected sha256 for {DEDUP_JAR_NAME} from {DEDUP_RELEASE_API_URL}: {e}"
        ) from e

    tmp_path = jar_path + ".tmp"
    urllib.request.urlretrieve(DEDUP_JAR_URL, tmp_path)
    if _sha256(tmp_path) != expected_sha256:
        os.remove(tmp_path)
        raise RuntimeError(f"downloaded {DEDUP_JAR_URL} does not match expected sha256 {expected_sha256}")
    os.rename(tmp_path, jar_path)


DEDUP_JAR_PATH = dedup_jar_path(os.path.dirname(workflow.basedir))

if workflow.exec_mode != ExecMode.SUBPROCESS:
    ensure_dedup_jar(DEDUP_JAR_PATH)
