# Changelog

All notable changes to this project will be documented in this file.

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