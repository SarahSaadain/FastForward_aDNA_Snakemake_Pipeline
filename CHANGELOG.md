# Changelog

All notable changes to this project will be documented in this file.


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