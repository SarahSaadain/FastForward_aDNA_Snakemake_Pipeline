# Tests

Covers the configurable species data locations feature (`species_dir`, `reads_dir`,
`reference_dir`, `scg_dir`, `feature_library_dir`, `competition_dir`, `processed_dir`,
`results_dir` — see [config/README.md](../config/README.md#storing-species-data-elsewhere)) and
its cross-project lock.

## `test_species_paths.py` — unit tests

Pure Python, no Snakemake or conda required. Exercises
`workflow/scripts/species_paths.py` directly against throwaway directories: symlink creation,
idempotency, both conflict cases, `execute: false` skipping, the cross-project lock (fresh
acquire, stale takeover, foreign-host refusal, scoped release), and the dry-run lock skip.

```bash
python3 tests/test_species_paths.py            # or: python3 -m unittest discover tests -v
```

## `dryrun_scenarios.sh` — Snakemake integration checks

Drives the real `snakemake` CLI against throwaway project directories (each just symlinks this
repo's `workflow/`) to catch anything only visible once Snakemake itself parses `initialize.smk`
and builds the DAG — rule/wildcard resolution through the symlinks, and Snakemake's own
dry-run/`onsuccess:` hook timing (dry runs never fire `onsuccess:`/`onerror:`, so the
cross-project lock must not be acquired during a dry run — see the comment in
`setup_species_data_locations`).

Requires a conda environment named `snakemake` (Snakemake >= 9.9.0; see
[config/README.md](../config/README.md)). The first run may be slow while Snakemake clones
`snakemake-wrappers` into `~/.cache/snakemake` for a wrapper-based rule; that cache is reused on
later runs.

```bash
tests/dryrun_scenarios.sh            # runs all scenarios, cleans up its temp workspace
tests/dryrun_scenarios.sh --keep     # keeps the workspace and prints its path, for inspection
```

Scenarios: default/fallback (zero symlinks, zero behavior change), fresh `species_dir` (symlinks
created, DAG job count identical to the default-layout run), idempotent re-run, both conflict
cases (pre-existing real directory / pre-existing symlink elsewhere — must error and leave the
conflicting path untouched), dry-runs never leaking `.pastforward.lock`, and a real run acquiring
then releasing the lock via `onsuccess:`.
