# Changelog

All notable changes to this project will be documented in this file.


## [Unreleased]

### New Features

- **Configurable ECMSD/REVEAL version source**: New `tools.ecmsd.settings.version_source` (default `conda`) and `pipeline.reveal_module.settings.version_source` (default `pinned`) config settings let either tool be side-loaded straight from GitHub instead of its conda-pinned build — `latest_release` always takes the newest tagged release, and an experimental `dev` tracks the tip of the tool's development branch. Each option has its own dedicated conda env file (`workflow/envs/ecmsd*.yaml` / `reveal*.yaml`) with a matching single-step `*.post-deploy.sh`, resolved by `workflow/scripts/config_validation.py`; switching `version_source` therefore builds/reuses the right env automatically, though picking up a newer release/commit on an already-built unpinned env still needs a manual rebuild — see [docs/FAQ.md](docs/FAQ.md)
- **`pastForward` CLI** (`pastForward` at the project root, logic in `workflow/scripts/cli.py`): a thin wrapper around `snakemake` with `run` (backgrounded by default, `--fg` for foreground; requires `--cores`/`-j`, same as plain `snakemake`; refuses to start if a tracked run in the same project folder is still alive), `resume` (same as `run`, plus `--rerun-incomplete`, for continuing after a crash/kill), `dryrun`, `status`/`status --live`/`status --watch` (PID, progress %, last few steps; `--live` tails the log afterward, `--watch` reprints the formatted status every 5s until the run ends; both a failed and a likely force-killed run now print a `pastForward resume` hint), `abort`/`abort --force` (graceful SIGTERM vs. killing the whole process group), `unlock` (`snakemake --unlock`, to clear a stale lock left by a crashed run), `doctor` (lists the pipeline's conda environments and whether each is built; `--rebuild-envs [name ...]` force-removes and recreates one, several, or — with no names — all of them, e.g. after changing an ECMSD/REVEAL `version_source` setting), `check` (discovered species/individuals/references for the current config), `preview` (expected output files, including skipped ones), `print-log` (prints the most recently written log from `logs/`), and `version`. `run`/`dryrun` write timestamped logs to `logs/` in the project folder

### Changed

- **`contamination` renamed to `taxonomic_screening`**: the read-module step, its config key, its workflow folders, and its output folder are now named after what the step measures (taxonomic classification of reads) rather than after how the result is interpreted. Concretely:
  - Config: `pipeline.read_module.contamination` -> `pipeline.read_module.taxonomic_screening`. **The old key still works** - it is rewritten onto the new name at startup (`workflow/scripts/config_compat.py`, called from `initialize.smk`) and logs a deprecation warning, so existing `config.yaml` files keep running unchanged
  - Outputs: `{species}/results/read_module/contamination/` -> `{species}/results/read_module/taxonomic_screening/`. This has **no** fallback - rename the folder in existing projects to reuse previous results, or let pastForward regenerate them
  - Workflow layout: `workflow/{rules,scripts}/read_module/contamination/` -> `.../taxonomic_screening/`, with `check_contamination_*` files renamed to `check_taxonomic_screening_*`; the two Centrifuge helper scripts also lost their incorrect `_ecmsd_` infix. Rules `ecmsd_analyze_contamination` and `analyze_contamination_with_centrifuge` are now `ecmsd_taxonomic_screening` and `centrifuge_taxonomic_screening`

- **`pastForward check`/`preview` no longer need Snakemake installed at all**: `workflow/scripts/check.py` imported `snakemake_interface_executor_plugins` at module level purely to compare `workflow.exec_mode` against `ExecMode.SUBPROCESS`, so running either command outside the pipeline's conda env died with `ModuleNotFoundError: No module named 'snakemake_interface_executor_plugins'`. That import is now optional and falls back to "not a subprocess" when it fails, which is always correct for the in-process path - PyYAML is the only third-party package the two commands still need

- **`pastForward version` no longer requires `snakemake` on `PATH`**: it only reads `workflow/scripts/version.py`, so it now skips the startup check the snakemake-spawning commands share - matching `check`/`preview`, which stopped needing it when they moved in-process. The remaining `check`/`preview` import error also no longer names snakemake specifically (what it actually needs is the pipeline's conda env, for `yaml` and friends)

- **CLI hints now use `./pastForward`**: every command suggestion the CLI prints (help usage line, `status`/`abort` hints, resume/unlock hints, `check`/`run` hints) is written as `./pastForward <command>` instead of a bare `pastForward`, matching how it is actually invoked from a project root — it is a script in the project folder, not something on `PATH`. `docs/FAQ.md` and `tests/README.md` updated to match. Message text only, no behavior change

- **`pastForward check`/`preview` no longer start Snakemake**: both commands now load `check.py` and `expected_output_manager.py` in-process (`workflow/scripts/pipeline_namespace.py`, the same shared-namespace loader the unit tests use) instead of shelling out to `snakemake --dryrun` and parsing its log. Same output, but they return in well under a second instead of waiting for a full DAG build, and a rule-level dry-run error (e.g. an ambiguous SCG reference) no longer hides the discovery/expected-output listing they exist to show

- **`pastForward status`**: now flags a likely force-kill (SIGKILL, `abort --force`, OOM-killer) when the tracked process is not running and the log shows neither completion nor a recorded failure - previously that case printed no explanation at all
- **`preview.py` renamed to `check.py`**: matches the new `pastForward check` command it backs; no behavior change (still the per-species discovery tree logged at startup)

- **Auto-determined SCG library output path**: `{species}_relevant_scg.fasta` (the filtered FASTA used by the REVEAL mapping step) now lands in `{species}/results/reveal_module/scg/` instead of `processed/` — it's a primary output, not an intermediate. `{species}_relevant_scg.txt`/`.bed` stay in `processed/`. Existing SCG-selector logging also now states whether a previously-generated SCG library was found and reused, versus one being freshly auto-determined
- **`visualization.settings.individual_plots` default**: Now defaults to `skip` (was `plot`) — per-individual REVEAL plot rendering is off by default; set explicitly in `config.yaml` to re-enable

### Docs

- **README overhaul**: `README.md`'s "Running the Pipeline" section now leads with the `pastForward` CLI (suggested order: `check` -> `preview` -> optional `dryrun` -> `run`); direct-`snakemake` usage, flags, backgrounding, restarting, and HPC/cluster notes moved to new [docs/snakemake.md](docs/snakemake.md)

### CI / Maintenance

- **`tests/dryrun_scenarios.sh` on macOS**: Was hard-coded to GNU `timeout`, which macOS doesn't ship, so every scenario failed with exit 127 there; now falls back to `gtimeout` (`brew install coreutils`) when plain `timeout` isn't on PATH
- **`file_manager.py` logger**: Was importing `logger` from the stdlib `venv` module (an internal implementation detail, not a public API) instead of creating its own; now uses `logging.getLogger(__name__)`. No behavior change today, but the old import was one Python version away from breaking
- Removed dead commented-out code (copy-pasted across `common.smk` and one `expected_output` script) and unused imports
- Consolidated duplicated FASTA-glob discovery logic in `file_manager.py` (reference/feature-library/SCG/competition lookups) into a shared helper
- De-duplicated repeated nested config lookups in `get_expected_output_reference_module` and `get_expected_output_multiqc`

## [2.0.1] - 2026-08-10

### New Features

- **Configurable species data locations**: New optional per-species `config.yaml` settings (`species_dir`, `reads_dir`, `reference_dir`, `scg_dir`, `feature_library_dir`, `competition_dir`, `processed_dir`, `results_dir`) let a species' data live outside the project directory instead of the fixed `<species>/{input,processed,results}` layout. pastForward resolves these into symlinks at the conventional locations at startup, so all existing rules/scripts keep working unchanged; when none are set, behavior is identical to before. `processed_dir`/`results_dir` overrides are additionally protected by a new cross-project lock (`.pastforward.lock`, written inside the resolved target) that detects two independent projects resolving to the same output location — separate from, and not cleared by, Snakemake's own `--unlock`. See [config/README.md](config/README.md#storing-species-data-elsewhere) and [docs/FAQ.md](docs/FAQ.md).

### Bug Fixes

- **SCG/feature-library rule collision**: An SCG FASTA legitimately named `scg.fasta` produced the same processed-output path as the generic feature-library rules, raising `AmbiguousRuleException` while building the DAG; the SCG rules' processed path now has one fewer directory segment so the two patterns can never collide, regardless of what a library file is named
- **`scg_selector.execute` default**: Expected-output calculation defaulted this setting to `False`, out of sync with discovery, preview logging, and the docs (all default `True`) — a config that correctly omitted the key would silently skip SCG auto-determination and all of `reveal_module`. Now defaults to `True` as documented
- **DeDup logging**: `dedup_deduplicate_bam_cluster` declared a `log:` file but the shell command never wrote to it; dedup's output is now redirected there

### CI / Maintenance

- `snakemake --lint` backlog fully resolved (zero findings): added missing `log:` directives to 79 rules, missing `conda:` environments to 25 rules, migrated 9 long `run:` blocks into `script:` files, fixed absolute-path false positives, and split mixed rules/functions across 21 files into a new `workflow/rules/common.smk`; a (currently disabled, pending re-enable) `lint.yml` CI workflow was added to keep this clean going forward
- Applied `snakefmt` formatting across all `.smk` files
- Added a fast pure-Python regression test suite (`tests/test_file_manager.py`, `tests/test_expected_output_manager.py`, `tests/test_endogenous_reads_stats.py`) covering discovery and DAG-target logic without needing Snakemake or conda
- New CI workflow stamps a `<base-version>-dev.<timestamp>+<sha>` version on every push to `develop`, so unreleased test runs can be traced to a commit
- Setup docs (`README.md`, `config/README.md`, `docs/FAQ.md`) rewritten as a step-by-step guide for non-technical users, with REVEAL and ECMSD linked as the tools behind core analyses and REVEAL input file placement (feature library, SCG) documented

## [2.0.0]

> ⚠️ NOTE: This release restructures the pipeline's configuration and output layout, renames all four pipeline stages for naming consistency, and replaces the vendored `teplotter` scripts with the standalone [REVEAL](https://github.com/SarahSaadain/REVEAL) toolkit. Existing configs and output directories will need to be updated/reorganized to match.

### Breaking Changes

- **Module renames**: All four pipeline stages are renamed to a consistent `_module` convention: `dynamics` → `reveal_module`, `raw_reads_processing` → `read_module`, `reference_processing` → `reference_module`, `summary_processing` → `summary_module`. Rule/script directories under `workflow/rules/` and `workflow/scripts/` are renamed accordingly (e.g. `dynamics/` → `reveal_module/`, `raw_read/` → `read_module/`, `reads_to_reference/` → `reference_module/`, `processing_summary/` → `summary_module/`); existing configs must update the corresponding `pipeline.*` keys
- **REVEAL as external dependency**: The vendored `teplotter` scripts under `workflow/scripts/dynamics/teplotter/` have been removed. Rules now call the `REVEAL` CLI (new `workflow/envs/reveal_module.yaml` conda environment) instead of invoking local copies of `bam2so.py`, `normalize-so.py`, `estimate-so.py`, `so2plotable.py`, and the plotting/stats/compare scripts. REVEAL isn't published on bioconda yet, so `reveal_module.yaml` currently pins REVEAL's own runtime deps and a post-deploy script (`workflow/envs/reveal_module.post-deploy.sh`) side-loads the pinned REVEAL release into that conda environment automatically; once the `reveal-tools` bioconda package exists, that yaml can go back to a plain `reveal-tools` dependency and the post-deploy script can be deleted, with no rule changes required
- **Config structure**: The former `dynamics.pf_normalization` sub-stage is removed; `reveal_module` settings are now split into `pipeline.reveal_module.visualization.settings` (plot-rendering options), `pipeline.reveal_module.analysis.settings` (`coverage_analysis`, `snp_analysis`, `indel_analysis` toggles), `pipeline.reveal_module.sequence_overview.settings` (bam2so thresholds: `mapping_quality_threshold`, `minimum_count_snp`, `minimum_frequency_snp`, `minimum_count_indel`, `minimum_frequency_indel`), and `pipeline.reveal_module.normalization.settings` (normalize-so thresholds: `end_distance`, `exclude_quantile`)
- **Config structure**: Quality checking settings (`quality_checking_raw`/`trimmed`/`quality_filtered`/`merged`) consolidated under a single `analysis` key — existing configs using the old flat structure must be updated
- **Config structure**: MultiQC output paths now require species and individual level directory structure
- **Config structure**: New `ECMSD` config section, and an updated `MultiQC` section
- **Config structure**: `pipeline.read_module.contamination_analysis` renamed to `pipeline.read_module.contamination`
- **Default mapper changed**: Default aligner switched from `bwa-mem` to `bwa-mem2`
- **Folder structure**: The species input root is now `{species}/input/` (previously `{species}/raw/`); read files now live under `{species}/input/read_module/` (previously `input/reads/`) and reference genomes under `{species}/input/reference_module/` (previously `input/ref/`)
- **Folder structure**: Output directories now include species and individual level subdirectories throughout; `reference_module` results are namespaced under `{species}/results/reference_module/{reference}/...` (previously `{species}/results/{reference}/...` and `{species}/processed/{reference}/...`), with the final per-individual BAM (`_final.bam`) now written to `{species}/results/reference_module/{reference}/mapped/` (previously `{species}/processed/{reference}/mapped/`)
- **Folder structure**: Contamination analysis outputs moved to `{species}/results/read_module/contamination/` (previously `{species}/results/contamination_analysis/`)
- **Config structure**: The Snakemake rule `preseq_c_curve` is now `preseq_complexitiy_curve`, matching the new `pipeline.reference_module.analysis.settings.preseq_complexitiy_curve` toggle (output file names and the underlying `preseq c_curve` command are unchanged)

### New Features

- **`reveal_module`**: The vendored `teplotter` scripts are replaced by the standalone REVEAL toolkit for TE/genomic-feature dynamics normalization, adding cross-library stats combination, plotting options for individual and comparison outputs, flag files for quick sequence checks, SNP/indel statistics calculation and comparison, mean coverage calculation, additional output columns, and gzip-compressed output. Independent `coverage_analysis` (default: on), `snp_analysis` (default: off), and `indel_analysis` (default: off) settings control which per-individual and species-level outputs are generated
- **SCG & feature library mapping**: New analysis mapping reads to a combined single-copy-gene (SCG) and feature library reference (via `minimap2`/`bwa-aln`/`bwa-mem2`) for TE and genomic feature abundance comparisons; SCGs can be auto-determined with BUSCO or supplied as a pre-built FASTA; adds per-individual depth normalization and scoring for SCG ranking, minimum mapping quality and contig-count filtering for SCG/feature library reads, and an option to keep the mapped BAM as a permanent output; inputs now support different file extensions
- **Competitive mapping**: Optional competition FASTA can be combined with the SCG/feature library reference before mapping; reads mapping to competition sequences are filtered out afterwards to reduce false-positive mappings from competing sources (e.g. host genome fragments)
- **Species configuration**: New `execute` option to conditionally include/exclude a species from processing; new species-level settings for individuals, references, and feature libraries (correctly applied across the read, reference, and reveal modules); preview logging now reports counts of references, individuals, samples, feature libraries, and SCG libraries
- **DeDup**: Deduplication now uses a modified DeDup fork for improved performance over upstream DeDup; the fork's jar is pinned and side-loaded automatically into the `dedup` conda environment via a post-deploy script the first time that environment is created (behind a `dedup` command matching upstream bioconda's own wrapper convention); minimum contigs-per-cluster is now configurable (default `1`). If this fork's improvements are ever released under the upstream `dedup` bioconda package, the env's dependency can revert to plain `dedup` with no rule changes needed
- **Config Designer**: New interactive configuration designer to guide pipeline setup, kept in sync with the current module/config structure
- **Configurable mapper selection**: Pipeline now supports `bwa-aln`, `bwa-mem2`, and `minimap2` for reveal and reference processing via config
- **MultiQC refactor**: Restructured data preparation and analytics rules; output paths now include species and individual level directories; added optional `c_curve`, `qualimap`, and `samtools stats` analysis stages; streamlined contamination analysis execution logic for species and individual reports
- **Raw reads analysis settings**: Per-stage quality checking options (raw, trimmed, quality-filtered, merged reads); read count statistics now mandatory output
- **Raw read naming convention**: read files may now use a bare `1`/`2` instead of `R1`/`R2` as the read-number marker (e.g. `Sample_1.fastq.gz` or `Sample_1_001.fastq.gz`), as long as the digit stands alone as its own underscore-delimited segment
- **ECMSD settings**: Pinned to ECMSD `1.2.*`; new `cov_threshold` (minimum % of reference covered) and `top_n` (number of top references to plot) settings, alongside mapping quality and taxonomic hierarchy settings; contamination analysis rule now produces a ranked summary output
- **Unmapped reads handling**: Enhanced post-mapping processing; BAM files now optionally extract or remove unmapped reads; extraction now uses the pre-filter BAM together with `samtools`/`fastx`
- **Centrifuge**: Output compressed with `pigz` and marked as temporary to reduce disk usage
- **Preview logging**: now also reports raw read files found in `input/read_module/` that don't match the R1/R2 naming convention, and uncompressed `.fastq` files (the pipeline only processes `.fastq.gz`), both of which were previously silently ignored
- **Automated version sync**: CI workflow now manages version synchronization automatically
- **README**: Added minimum configuration requirements section
- **Initialize**: Now shows identified files on startup
- **FAQ**: Expanded with adapter removal, pre-processed reads, and DeDup fork guidance

### Bug Fixes

- `file_manager`: Improved error messages for read file retrieval
- Expected raw read outputs now always created even when other pipeline stages are disabled
- `move_rescaled_bam`: output paths for rescaled BAM and index now use temp files to avoid leftover files

---

## [1.0.1] - 2026-04-26

### New Features

- Updated config with dynamics and summary settings

### Bug Fixes

- BAM rules: replaced `mv` with `cp` to prevent data loss; guarded header logging in subprocess mode
- Log paths consolidated to `processed/`; cleaned up f-strings; fixed R scripts
- Git version retrieval now includes error handling and logs process ID

### CI / Maintenance

- Added GitHub Actions workflow for automatic version tagging on main branch
- Added automated release creation
- Version now dynamically set from git tag instead of hardcoded string
