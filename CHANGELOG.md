# Changelog

All notable changes to this project will be documented in this file.


## [Unreleased]

> ⚠️ NOTE: This release renames the `dynamics` pipeline stage to `reveal_module` and replaces the vendored SeqVista scripts with the standalone [REVEAL](https://github.com/SarahSaadain/REVEAL) toolkit. It also renames the other three pipeline stages for naming consistency. Existing configs and output directories must be updated to match.

### Breaking Changes

- **Module rename**: The `dynamics` pipeline stage is now `reveal_module` (`pipeline.dynamics` → `pipeline.reveal_module`; `{species}/raw|processed/results/dynamics/` → `{species}/raw|processed/results/reveal_module/`)
- **Config structure**: The former `seqvista` sub-section is now `visualization` (`pipeline.reveal_module.seqvista` → `pipeline.reveal_module.visualization`); output subfolder renamed to match (`.../reveal_module/<feature_library>/seqvista/` → `.../reveal_module/<feature_library>/visualization/`)
- **Config structure**: `coverage_analysis`, `snp_analysis`, and `indel_analysis` moved out of `visualization.settings` into their own sibling section, `pipeline.reveal_module.analysis.settings`
- **Config structure**: bam2so thresholds (`mapping_quality_threshold`, `minimum_count_snp`, `minimum_frequency_snp`, `minimum_count_indel`, `minimum_frequency_indel`) moved into a new `pipeline.reveal_module.sequence_overview.settings` section; normalize-so thresholds (`end_distance`, `exclude_quantile`) moved into a new `pipeline.reveal_module.normalization.settings` section — `visualization.settings` now holds only plot-rendering options
- **REVEAL as external dependency**: The vendored SeqVista scripts under `workflow/scripts/dynamics/seqvista/` have been removed. Rules now call the `REVEAL` CLI from the `reveal-tools` bioconda package (new `workflow/envs/reveal_module.yaml` conda environment) instead of invoking local copies of `bam2so.py`, `normalize-so.py`, `estimate-so.py`, `so2plotable.py`, `plot.py`, and the stats/compare scripts
- **Module rename (naming consistency)**: The remaining three pipeline stages are renamed to match the `_module` convention: `raw_reads_processing` → `read_module`, `reference_processing` → `reference_module`, `summary_processing` → `summary_module`. Rule/script directories under `workflow/rules/` and `workflow/scripts/` are renamed accordingly (e.g. `raw_read/` → `read_module/`, `reads_to_reference/` → `reference_module/`, `processing_summary/` → `summary_module/`); existing configs must update the corresponding `pipeline.*` keys.
- **Folder structure**: The species input root is now `{species}/input/` (previously `{species}/raw/`); read files now live under `{species}/input/reads_module/` (previously `input/reads/`) and reference genomes under `{species}/input/reference_module/` (previously `input/ref/`)
- **Folder structure**: `reference_module` results are now namespaced under `{species}/results/reference_module/{reference}/...` (previously `{species}/results/{reference}/...`); the final per-individual BAM (`_final.bam`) is now written to `results/reference_module/{reference}/mapped/` instead of `processed/reference_module/{reference}/mapped/`
- **Folder structure**: Contamination analysis outputs moved to `{species}/results/reads_module/contamination/` (previously `{species}/results/contamination_analysis/`)
- **Config structure**: `pipeline.read_module.contamination_analysis` renamed to `pipeline.read_module.contamination`

### Other Changes

- Config designer updated to match the `reveal_module`/`visualization` naming and the `read_module`/`reference_module`/`summary_module` renames

## [2.0.0] - 2026-06-02

> ⚠️ NOTE: This release includes significant changes to the pipeline's configuration structure and output organization. Users will need to update their existing configurations and reorganize outputs to align with the new structure.

### Breaking Changes

- **Config structure**: Quality checking settings consolidated under a single `analysis` key — existing configs using the old structure must be updated
- **Config structure**: PF normalization section removed from config
- **Config structure**: MultiQC output paths now require species and individual level directory structure
- **Default mapper changed**: Default aligner switched from `bwa-mem` to `bwa-mem2`
- **New config sections**: `SeqVista`, `ECMSD`, and updated `MultiQC` sections
- **Folder structure**: Output directory structure updated to include species and individual level subdirectories for all outputs -> existing outputs will need to be reorganized or regenerated to match the new structure

### New Features

- **SCG & feature library dynamics processing**: New analysis mapping reads to a combined single-copy-gene (SCG) and feature library reference (via `minimap2`/`bwa-aln`/`bwa-mem2`) for TE and genomic feature abundance comparisons; SCGs can be auto-determined with BUSCO or supplied as a pre-built FASTA; adds per-individual depth normalization and scoring for SCG ranking, minimum mapping quality and contig-count filtering for SCG/feature library reads, and an option to keep the mapped BAM as a permanent output
- **Competitive mapping**: Optional competition FASTA can be combined with the SCG/feature library reference before mapping; reads mapping to competition sequences are filtered out afterwards to reduce false-positive mappings from competing sources (e.g. host genome fragments)
- **Species configuration**: New `execute` option to conditionally include/exclude a species from processing; new species-level settings for individuals, references, and feature libraries; preview logging now reports counts of references, individuals, samples, feature libraries, and SCG libraries; config designer updated to match
- **DeDup**: Deduplication now uses a modified DeDup fork for improved performance over upstream DeDup, with the jar pinned and downloaded automatically; minimum contigs-per-cluster is now configurable (default `1`)
- **SeqVista**: Replaced `teplotter` with SeqVista for dynamics normalization; updated to latest SeqVista version with compressed output; added cross-library stats combination; added plotting options for individual and comparison outputs; added flag files for quick sequence checks; added SNP/indel statistics calculation and comparison, mean coverage calculation and additional output columns; output files now gzip-compressed
- **SeqVista**: Added independent `seqvista.settings.coverage_analysis` (default: on), `snp_analysis` (default: off), and `indel_analysis` (default: off) settings to control which per-individual and species-level outputs are generated; config designer updated to match
- **Config Designer**: New interactive configuration designer to guide pipeline setup
- **Configurable mapper selection**: Pipeline now supports `bwa-aln`, `bwa-mem2`, and `minimap2` for dynamics and reference processing via config
- **MultiQC refactor**: Restructured data preparation and analytics rules; output paths now include species and individual level directories; added optional `c_curve`, `qualimap`, and `samtools stats` analysis stages; streamlined contamination analysis execution logic for species and individual reports
- **Raw reads analysis settings**: Per-stage quality checking options (raw, trimmed, quality-filtered, merged reads); read count statistics now mandatory output
- **ECMSD settings**: Pinned to ECMSD `1.2.*`; `binsize`/`RMUS_threshold` settings replaced with `cov_threshold` (minimum % of reference covered) and `top_n` (number of top references to plot), alongside mapping quality and taxonomic hierarchy; contamination analysis rule now produces a ranked summary output
- **Unmapped reads handling**: Enhanced post-mapping processing; BAM files now optionally extract or remove unmapped reads; extraction now uses the pre-filter BAM together with `samtools`/`fastx`
- **Centrifuge**: Output compressed with `pigz` and marked as temporary to reduce disk usage
- **Automated version sync**: CI workflow now manages version synchronization automatically
- **README**: Added minimum configuration requirements section
- **Initialize**: Now shows identified files on startup
- **Dynamics processing**: Dynamics processing now supports different file extensions
- **FAQ**: Expanded with adapter removal, pre-processed reads, and DeDup fork guidance

### Bug Fixes

- `file_manager`: Improved error messages for read file retrieval
- Symlink paths now use absolute paths
- Expected raw read outputs now always created even when other pipeline stages are disabled
- `move_rescaled_bam`: output paths for rescaled BAM and index now use temp files to avoid leftover files
- SeqVista plots: added `limitsize` option to `ggsave` to allow larger plots


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