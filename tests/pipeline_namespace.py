#!/usr/bin/env python3
"""
Loads workflow/scripts/file_manager.py and the expected_output_manager_*.py files into a
single shared namespace, mimicking how Snakemake's `include:` directive runs them (see the
include order in workflow/Snakefile): all in the same globals dict, seeing a shared
`config` and each other's top-level functions with no imports between them. That shared-
namespace trick is also why expected_output_manager_summary_module_processing.py can call
`logging.info(...)` without importing `logging` itself - it relies on an earlier included
file having already done so (reproduced here by loading the files in the same order).

This lets test_expected_output_manager.py unit test the real DAG-target-computation logic
without needing Snakemake or conda. check.py is intentionally skipped - it imports
snakemake_interface_executor_plugins and isn't needed by expected_output_manager.py.

Not a test module itself - has no tests of its own.
"""
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_SCRIPTS_DIR = os.path.join(REPO_ROOT, "workflow", "scripts")

# Mirrors the include: order in workflow/Snakefile.
_SOURCE_FILES = [
    "file_manager.py",
    os.path.join("expected_output", "expected_output_manager_reveal_module_processing.py"),
    os.path.join("expected_output", "expected_output_manager_read_module_processing.py"),
    os.path.join("expected_output", "expected_output_manager_reference_module_processing.py"),
    os.path.join("expected_output", "expected_output_manager_summary_module_processing.py"),
    "expected_output_manager.py",
]


def load_pipeline_namespace(config):
    """Returns a namespace dict with `config` bound and every manager function loaded,
    exactly as they'd see each other and `config` when run for real under Snakemake."""
    namespace = {"config": config}
    for relpath in _SOURCE_FILES:
        path = os.path.join(_SCRIPTS_DIR, relpath)
        with open(path) as f:
            source = f.read()
        exec(compile(source, path, "exec"), namespace)
    return namespace
