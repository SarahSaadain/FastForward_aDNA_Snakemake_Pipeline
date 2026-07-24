# Setup Overview

## Install Snakemake
To install Snakemake, you can use conda, which is a package manager that simplifies the installation of software and its dependencies. You can create a new conda environment for Snakemake and install it using the following commands:

```bash
conda create -c conda-forge -c bioconda -c nodefaults -n snakemake snakemake
conda activate snakemake
snakemake --help
```

Refer to the [Snakemake documentation](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html) for more installation options and details.

## Setup Instructions
- Before running the pipeline, ensure you have an environment with Snakemake and it is activated.
- You need to add species details to the pipeline (config and files).
- Your reads should be renamed according to the naming convention specified below.

## Folder Structure

### Species Folders

The project contains folders for different species, which each contain the raw data, processed data, and results for the particular species.

The species folders should be placed in the root folder of your pipeline.

#### Providing Raw Data
The pipeline supports automatically moving the raw reads to the `<species>/input/reads/` folder as well as the reference to the `<species>/input/reference_module/` folder. Simply provide the files in the `<species>` folder. Alternatively, you can manually move the files to the respective folders.
  - provide the raw reads in `<species>/input/reads/` folder
  - provide the reference in `<species>/input/reference_module/` folder

When adding a new species, make sure to 
- the species folder should be placed in the root folder of your pipeline
- add the folder name should match the species key which is defined in `config.yaml` below `species:` 

#### Folder Structure

All other folders will be created and populated automatically

- Folder `<species>/processed/` contains the intermediary files during processing. Most of these files are marked as temporary and will be deleted at the end of the pipeline. Some files are kept to allow reprocessing the pipeline from different points in case something fails.
- Folder `<species>/results/` contains the final results and reports. 

Everything related to a reference will have a `<reference>` folder under `processed`or `results`. Typically, only the `results` folder will contain information required for further analyis. In case more information is required, the original files can often be found in the `processed` folder. 

Some exemptions include `*.sam` and unsorted `*.bam` files. These are deleted to save storage space. Most other files are kept in order to allow reprocessing the pipeline from different points in case something fails. If a step should be repeated, the relevant files need to be deleted manually. 

#### RAW Reads Filenames

The pipeline expects input read files to follow a standardized naming convention:

```
<Individual>_[<FreeText>_]R<1/2>[_<FreeText>].fastq.gz
```

Following this convention ensures proper organization and automated processing within the pipeline.  

##### Filename Components:
- **`<Individual>`** – A unique identifier for the sample or individual.  
- **`<FreeText>`** – Any additional text or identifier that can be included in the filename. Typically, this is used to differentiate between different samples within the same individual, e.g. the same sample was extracted twice using different protocols.
- **`R<1/2>`** – Indicates the read pair number, typically `R1` for the first read and `R2` for the second read. If the data is single-end, only `R1` should be present.
- **`.fastq.gz`** – The expected file extension, indicating compressed FASTQ format. Only `.fastq.gz` files are supported.

#### Example:
```
Dmel01_DabneyProtocol_R1_001.fastq.gz
```

# Configuration File Structure for aDNA Pipeline (`config.yaml`)

The `config.yaml` file is used to configure the aDNA pipeline. It contains settings such as project name, the species list and the pipeline stages and their process steps.

All pipeline stages are enabled by default, so a minimal config containing only the project name and species list is sufficient to run the pipeline without any further changes:

```yaml
project_name: "pastForward_Project"

species:
  Dmel:
    name: "Drosophila melanogaster"
```

To adjust any pipeline settings, open [config_designer.html](config_designer.html) in a browser. The interactive Config Designer guides you through all available options and exports a ready-to-use `config.yaml`.

## Global Settings

* **project\_name**: Name of the project.

## Pipeline Settings

Defines the overall pipeline behavior, including execution controls and process details.

### Pipeline Stages and Process Steps

* The pipeline is broken into **stages** (e.g., `read_module`, `reference_module`).
* Each stage contains multiple **process steps** (e.g., `adapter_removal`, `deduplication`, ...).
* Both stages and process steps can be controlled with `execute: true/false` flags to enable or disable them.
* Some process steps include additional configurable settings (e.g., adapter sequences, database paths, ...).
* If an enabled process step requires data from a previous stage which is disabled in the config, the pipeline will execute the disabled process step anyway.

### Important Defaults

* You **do not need to specify all stages or process steps** explicitly.
* Any **stage or process step not provided in the config defaults to `execute: true`** and will be executed.

### Global Pipeline Settings

| Setting | Default | Description |
|---|---|---|
| `pipeline.global.skip_existing_files` | `true` | When true, existing output files are skipped to avoid re-computation. |

### Stage: `read_module`

Quality checking, adapter removal, quality filtering, merging, contamination analysis, and read count statistics of raw reads.

> **Read count statistics always run** — per-stage counts (raw → trimmed → quality-filtered) are written unconditionally as `{species}/results/reads/statistics/{species}_reads_counts.csv`.

#### `analysis`

Controls FastQC + MultiQC quality reports at each processing stage and read count visualisation. Individual stages are toggled via `settings`.

| Setting | Default | Description |
|---|---|---|
| `settings.multiqc_raw_reads` | on | FastQC/MultiQC on raw reads. |
| `settings.multiqc_trimmed_reads` | on | FastQC/MultiQC on adapter-trimmed reads. |
| `settings.multiqc_quality_filtered_reads` | on | FastQC/MultiQC on quality-filtered reads. |
| `settings.multiqc_merged_reads` | on | FastQC/MultiQC on merged per-individual reads. |
| `settings.create_plots` | on | Generate read count bar plots per species. |

#### `adapter_removal`

| Setting | Default | Description |
|---|---|---|
| `settings.min_quality` | `0` | Minimum base quality score for adapter trimming. |
| `settings.min_length` | `0` | Minimum read length after adapter removal. |
| `settings.adapters_sequences.r1` | auto-detect | Adapter sequence for read 1. If omitted, fastp detects adapters automatically. |
| `settings.adapters_sequences.r2` | auto-detect | Adapter sequence for read 2. If omitted, fastp detects adapters automatically. |
| `settings.extra_params` | — | Optional extra parameters passed directly to fastp. |

#### `quality_filtering`

| Setting | Default | Description |
|---|---|---|
| `settings.min_quality` | `15` | Minimum base quality score for quality filtering. |
| `settings.min_length` | `30` | Minimum read length after quality filtering. |

#### `contamination_analysis`

Both tools operate on quality-filtered reads and can be toggled independently.

**ECMSD** — maps reads against a curated mitochondrial reference database.

| Setting | Default | Description |
|---|---|---|
| `tools.ecmsd.settings.database` | — | Path to the ECMSD database folder. If omitted, the pipeline auto-creates a database at `resources/ecmsd_database` via `ECMSD --create-db`. |
| `tools.ecmsd.settings.cov_threshold` | `50` | Minimum % of reference covered by reads to retain it. |
| `tools.ecmsd.settings.top_n` | `25` | Number of top references to generate alignment plots for. |
| `tools.ecmsd.settings.mapping_quality` | `20` | Minimum mapping quality score to include a read. |
| `tools.ecmsd.settings.taxonomic_hierarchy` | `species` | Taxonomic level at which to aggregate and report results. Options: `species`, `genus`, `family`, `order`. |

**Centrifuge** — k-mer-based taxonomic classification against a user-provided database.

| Setting | Default | Description |
|---|---|---|
| `tools.centrifuge.settings.include_human_taxid` | `false` | When true, the human taxid is included in the Centrifuge analysis. |
| `tools.centrifuge.settings.index` | — | Optional path to the Centrifuge index prefix. If omitted, the default index will be downloaded automatically. |
| `tools.centrifuge.settings.conda_env` | — | Optional path to a custom conda environment for Centrifuge. |

### Stage: `reference_module`

Mapping, deduplication, damage analysis, coverage — runs per individual per reference.

#### `mapping`

Merged per-individual reads are mapped to the reference genome. Mapping always runs when Reference Processing is enabled.

| Setting | Default | Description |
|---|---|---|
| `settings.mapper` | `bwa-mem2` | Mapper to use. Options: `bwa-aln` (classic seed-and-extend, recommended for short aDNA reads <70 bp), `bwa-mem2` (faster, for longer reads), `minimap2` (versatile, uses `-ax sr` preset for short reads). |
| `settings.mapper_extra_params` | — | Optional extra parameters passed directly to the mapper. For `bwa-aln`, defaults to `-n 0.01 -k 2 -l 1024 -o 2` (Oliva et al. 2021). |

#### `deduplication`

Removes PCR and sequencing duplicates using DeDup. Default: **off**.

Uses a [modified DeDup fork](https://github.com/SarahSaadain/DeDup) for performance improvements over upstream DeDup ([benchmark comparison repo](https://github.com/SarahSaadain/DeDup_comparison_fork)).

| Setting | Default | Description |
|---|---|---|
| `settings.min_contigs_per_cluster` | `1` | Minimum number of contigs grouped into a cluster. Small contigs below this count are merged together before deduplication. |
| `settings.max_contigs_per_cluster` | `500` | Maximum number of contigs grouped per deduplication cluster. Lower values use less memory but increase runtime. Reduce (e.g. to 100) only for large, highly fragmented reference genomes. |

#### `filter_unmapped_reads`

Optionally removes or extracts reads that did not map to the reference. Default: **off**.

| Setting | Default | Description |
|---|---|---|
| `settings.action` | `keep` | What to do with unmapped reads: `keep` — retain in final BAM (default, must be changed explicitly); `remove` — write a mapped-reads-only BAM; `extract_fastq` — write unmapped reads to a compressed FASTQ; `extract_fasta` — write unmapped reads to a compressed FASTA. |

#### Other `reference_module` steps

| Step | Default | Description |
|---|---|---|
| `damage_rescaling` | on | Profiles cytosine deamination and rescales base quality scores using mapDamage2. |
| `analysis` | on | Computes coverage breadth and mean depth; runs Qualimap and Preseq. Endogenous content data always generated. |
| `analysis.settings.damage_analysis` | on | Visualises damage patterns (mapDamage2) and includes them in the MultiQC report. |
| `analysis.settings.create_plots` | on | Generate coverage breadth/depth and endogenous reads plots per reference. |
| `analysis.settings.individual_multiqc` | on | Generate a per-individual BAM MultiQC report. |
| `analysis.settings.species_multiqc` | on | Generate a per-reference MultiQC report aggregating all individuals. |
| `analysis.settings.c_curve` | on | Include Preseq c_curve complexity data in MultiQC reports. |
| `analysis.settings.qualimap` | on | Include Qualimap BAM QC data in MultiQC reports. |
| `analysis.settings.samtools_stats` | on | Include samtools stats data in MultiQC reports. |

### Stage: `reveal_module`

TE and genomic feature abundance analysis — maps to a combined SCG + feature library for depth-normalised comparisons.

Place feature libraries in `{species}/input/reveal_module/feature_library/` and, optionally, a pre-built SCG FASTA in `{species}/input/reveal_module/scg/`. If no SCG FASTA is provided and `scg_selector.execute` is `true`, SCGs are determined automatically via BUSCO (requires a lineage configured per species). To use competitive mapping, place a single competition FASTA in `{species}/input/reveal_module/competition/`.

#### `scg_selector`

Automatically identifies single-copy genes (SCGs) from the reference genome using BUSCO. SCGs serve as coverage normalisers for the REVEAL pipeline. Skipped automatically when a user-provided SCG FASTA is already present in `{species}/input/reveal_module/scg/` or when no BUSCO lineage is configured for the species.

Can also be used standalone (without feature libraries) to produce an SCG ranking table as the sole output.

| Setting | Default | Description |
|---|---|---|
| `execute` | `true` | Enable SCG auto-determination when no user-provided FASTA is present. |
| `settings.mapper` | *(inherits from `reveal_module.mapping.settings.mapper`)* | Mapper for reads-to-SCG-library mapping. Uncomment to override. Options: `bwa-mem2`, `bwa-aln`, `minimap2`. |
| `settings.mapper_extra_params` | *(inherits from `reveal_module.mapping.settings.mapper_extra_params`)* | Optional extra parameters for the mapper. Falls back to mapper-specific defaults if not set. |
| `settings.num_top_scgs` | `20` | Number of top-ranked SCGs to retain as normalisers. |
| `settings.min_length_scg` | `4000` | Minimum SCG sequence length in bp to include from BUSCO results. |
| `settings.max_length_scg` | `8000` | Maximum SCG sequence length in bp to include from BUSCO results. |
| `settings.min_mapq` | `15` | Minimum mapping quality for reads in the SCG library BAM. Reads with MAPQ below this value are removed after unmapped-read removal. The same threshold is applied when computing per-contig coverage stats for ranking. Set to `0` to disable MAPQ filtering. |
| `settings.keep_mapped_bam` | `false` | When `true`, the filtered sorted SCG BAM and its index (`{species}/processed/reveal_module/scg/reads_mapped/{individual}_scg_library.sorted.bam[.bai]`) are kept as permanent outputs. When `false` (default), they are marked as temporary and deleted after SCG ranking consumes them. |

**Per-species SCG settings** (directly under `species.<key>`):

| Setting | Default | Description |
|---|---|---|
| `lineage` | — | **Required** for SCG auto-determination. BUSCO lineage database name (e.g. `drosophilidae_odb12`). Browse available lineages at [busco.ezlab.org](https://busco.ezlab.org/). |
| `scg_reference` | auto-detect | Path to the reference genome to use for BUSCO. Required when multiple FASTA files exist in `{species}/input/reference_module/`; if only one is present it is auto-detected and logged. |

#### `mapping`

| Setting | Default | Description |
|---|---|---|
| `settings.mapper` | `bwa-mem2` | Mapper for feature-library mapping. Same options as `reference_module.mapping`. |
| `settings.mapper_extra_params` | — | Optional extra parameters passed directly to the mapper. |
| `settings.keep_mapped_bam` | `false` | When `true`, the filtered sorted BAM and its index (`{species}/processed/reveal_module/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam[.bai]`) are kept as permanent outputs and explicitly requested by the pipeline. When `false` (default), they are marked as temporary and deleted after REVEAL consumes them. Set to `true` to inspect the mapped BAM or to run the mapping step independently of REVEAL. |
| `settings.min_mapq_scg` | `0` | Minimum mapping quality applied selectively to SCG sequences (`_scg` suffix) in the combined library BAM. Reads mapping to SCG references with MAPQ below this value are removed after mapping. Feature library reads are not affected. Set to `0` (default) to disable. |
| `settings.min_mapq_fle` | `0` | Minimum mapping quality applied selectively to feature library sequences (`_fle` suffix) in the combined library BAM. Reads mapping to feature references with MAPQ below this value are removed after mapping. SCG reads are not affected. Set to `0` (default) to disable. |

#### `competitive_mapping`

Competitive mapping adds a competition FASTA to the combined reference (alongside SCG and feature library sequences) before mapping. Reads mapping to competition sequences are removed after mapping, so only SCG and feature library reads reach downstream analysis. This is useful for reducing false-positive mappings when reads originate from competing sources (e.g. a host genome fragment).

To use competitive mapping, place exactly one FASTA file in `{species}/input/reveal_module/competition/`. The pipeline auto-discovers it — no path needs to be specified in the config.

Competition sequences are internally suffixed with `_comp` to distinguish them from SCG (`_scg`) and feature library (`_fle`) sequences.

| Setting | Default | Description |
|---|---|---|
| `settings.competitive_mapping` | `false` | When `true`, the FASTA in `{species}/input/reveal_module/competition/` is included in the combined reference. Reads mapping to `_comp` sequences are filtered out after mapping. |

#### Other `reveal_module` steps

| Step / Setting | Default | Description |
|---|---|---|
| `visualization` | on | Generates SO profiles — per-position coverage, SNP, and indel information — normalised into a REVEAL directory structure for per-individual TE occupancy plots and a faceted species-level comparison plot. |
| `analysis` | on | Produces coverage/SNP/indel stats and comparisons per `analysis.settings.*` below. |
| `analysis.settings.coverage_analysis` | `true` | When `true`, produce per-individual and species-level coverage stats, comparisons, and plots. |
| `analysis.settings.snp_analysis` | `false` | When `true`, produce per-individual and species-level SNP stats and comparisons. |
| `analysis.settings.indel_analysis` | `false` | When `true`, produce per-individual and species-level indel stats and comparisons. |
| `visualization.settings.individual_plots` | `plot` | `plot` — generate plotables and render per-individual plots; `plotable_only` — generate plotables only, skip rendering; `skip` — skip both. |
| `visualization.settings.comparison_plots` | `plot` | `plot` — generate plotables and render the faceted species comparison plot; `plotable_only` — generate plotables only, skip rendering; `skip` — skip both. |
| `visualization.settings.y_axis_log_scale_threshold_individual` | `25` | Y-axis value above which per-individual plots switch to a log scale. |
| `visualization.settings.y_axis_log_scale_threshold_species` | `25` | Y-axis value above which the species comparison plot switches to a log scale. |
| `sequence_overview.settings.mapping_quality_threshold` | `5` | Mapping quality threshold for bam2so; reads below this value are treated as ambiguously mapped and excluded. |
| `sequence_overview.settings.minimum_count_snp` | `5` | Minimum number of reads supporting a variant for it to be called as a SNP. |
| `sequence_overview.settings.minimum_frequency_snp` | `0.1` | Minimum allele frequency (0–1) for a SNP call. |
| `sequence_overview.settings.minimum_count_indel` | `3` | Minimum number of reads supporting an indel for it to be reported. |
| `sequence_overview.settings.minimum_frequency_indel` | `0.01` | Minimum allele frequency (0–1) for an indel call. |
| `normalization.settings.end_distance` | `100` | Number of positions from each end of a sequence excluded when computing the normalisation factor, to avoid edge-coverage artefacts. |
| `normalization.settings.exclude_quantile` | `25` | Percentile used to exclude the most extreme coverage values from normalisation (excludes both the top and bottom tail). |

### Stage: `summary_module`

Consolidates all QC outputs into MultiQC HTML reports.

| Setting | Default | Description |
|---|---|---|
| `settings.individual_multiqc` | on | Generate a per-individual MultiQC summary report (all references, one individual). |
| `settings.species_multiqc` | on | Generate a per-species MultiQC summary report (all individuals, all references). |

## Species settings

Each entry under `species:` in the config corresponds to a species folder in the pipeline root. The key must match the folder name exactly.

| Setting | Default | Description |
|---|---|---|
| `execute` | `true` | Whether to process this species. Set to `false` to skip all pipeline stages for this species without removing it from the config. Skipped species are listed in the startup preview log. |
| `name` | — | Human-readable species name used in reports. |
| `individuals` | *(all discovered)* | Optional list of individual IDs to process. Each ID must match the part of a read filename before the first `_` (e.g. `IND001` from `IND001_L001_R1.fastq.gz`). If omitted, all individuals discovered in `{species}/input/reads/` are used. An error is raised if any listed ID is not found on disk. |
| `references` | *(all discovered)* | Optional list of reference IDs to process. IDs are derived from filenames: basename without extension, dots replaced by underscores (e.g. `EquCab3.0.fna` → `EquCab3_0`). If omitted, all references in `{species}/input/reference_module/` are used. An error is raised if any listed ID is not found on disk. |
| `feature_libraries` | *(all discovered)* | Optional list of feature library IDs to use for the REVEAL stage. Same ID format as `references`. If omitted, all libraries in `{species}/input/reveal_module/feature_library/` are used. An error is raised if any listed ID is not found on disk. |
| `lineage` | — | Required for SCG auto-determination. BUSCO lineage name (e.g. `drosophilidae_odb12`). Browse available lineages at [busco.ezlab.org](https://busco.ezlab.org/). |
| `scg_reference` | auto-detect | Explicit path to the reference FASTA used by BUSCO. Required when multiple FASTAs exist in `{species}/input/reference_module/`; auto-detected and logged when exactly one is present. |

When `individuals`, `references`, or `feature_libraries` are specified, the startup preview logs which items were found but not selected under **"ignored"** entries. This makes it easy to verify your selection before a full run.

### Minimum Config

Only `project_name` and at least one entry under `species` are required. All pipeline stages run with their defaults.

```yaml
project_name: "pastForward_Project"

species:
  Dmel:
    name: "Drosophila melanogaster"
```

### Example `config.yaml`

```yaml
# config.yaml - Configuration file for pastForward
# This file contains settings for various stages of the pipeline

project_name: "pastForward_Project"

# Pipeline stages and their configurations
pipeline:

  # Global settings
  global:
    # When true, existing output files will be skipped to avoid re-computation (Default: true)
    skip_existing_files: true

  # Raw reads processing
  read_module:
    execute: true

    analysis:
      execute: true
      settings:
        multiqc_raw_reads: true
        multiqc_trimmed_reads: true
        multiqc_quality_filtered_reads: true
        multiqc_merged_reads: true
        create_plots: true

    adapter_removal:
      execute: true
      settings:
        min_quality: 0
        min_length: 0
        # Optional: custom adapter sequences (auto-detected by fastp if not provided)
        #adapters_sequences:
        #  r1: "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
        #  r2: "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"
        # Optional: extra parameters for fastp
        #extra_params: ""

    quality_filtering:
      execute: true
      settings:
        min_quality: 15
        min_length: 30

    contamination_analysis:
      execute: true
      tools:
        ecmsd:
          execute: true
          settings:
            # Optional: path to ECMSD database folder (auto-created if not set)
            #database: "resources/ecmsd_database"
            # Minimum % of reference covered by reads to retain it (Default: 50)
            cov_threshold: 50
            # Number of top references to generate alignment plots for (Default: 25)
            top_n: 25
            # Minimum mapping quality to include a read (Default: 20)
            mapping_quality: 20
            # Taxonomic level for results: "species" (default), "genus", "family", "order"
            taxonomic_hierarchy: "species"
        centrifuge:
          execute: true
          settings:
            # When true, human will be included in the Centrifuge analysis (Default: false)
            include_human_taxid: false
            # Optional: path to the Centrifuge index (downloaded automatically if not provided)
            #index: "/path/to/centrifuge_index"
            # Optional: custom conda environment for Centrifuge
            #conda_env: "../../../../envs/centrifuge.yaml"

  # Reference processing
  reference_module:
    execute: true

    mapping:
      settings:
        # Options: "bwa-mem2" (default), "bwa-aln", "minimap2"
        mapper: "bwa-mem2"
        # Optional: extra parameters passed directly to the mapper
        #mapper_extra_params: ""

    deduplication:
      # Default: true — set to false only if library complexity is very low
      execute: true
      settings:
        # Minimum contigs per deduplication cluster (Default: 1)
        min_contigs_per_cluster: 1
        # Maximum contigs per deduplication cluster (Default: 500)
        max_contigs_per_cluster: 500

    damage_rescaling:
      execute: true

    filter_unmapped_reads:
      # Default: false — enable to remove or extract unmapped reads
      execute: false
      settings:
        # Options: "remove", "extract_fastq", "extract_fasta"
        action: "keep"

    analysis:
      execute: true
      settings:
        damage_analysis: true
        create_plots: true
        individual_multiqc: true
        species_multiqc: true
        c_curve: true
        qualimap: true
        samtools_stats: true

  reveal_module:
    execute: true

    scg_selector:
      execute: true
      settings:
        # mapper and mapper_extra_params default to reveal_module.mapping.settings values if not set
        num_top_scgs: 20
        min_length_scg: 4000
        max_length_scg: 8000

    mapping:
      settings:
        # Options: "bwa-mem2" (default), "bwa-aln", "minimap2"
        mapper: "bwa-mem2"
        # Optional: extra parameters passed directly to the mapper
        #mapper_extra_params: ""

    analysis:
      execute: true
      settings:
        coverage_analysis: true
        snp_analysis: false
        indel_analysis: false

    sequence_overview:
      settings:
        mapping_quality_threshold: 5
        minimum_count_snp: 5
        minimum_frequency_snp: 0.1
        minimum_count_indel: 3
        minimum_frequency_indel: 0.01

    normalization:
      settings:
        end_distance: 100
        exclude_quantile: 25

    visualization:
      execute: true
      settings:
        individual_plots: "plot"
        comparison_plots: "plot"
        y_axis_log_scale_threshold_individual: 25
        y_axis_log_scale_threshold_species: 25

  summary_module:
    execute: true
    settings:
      individual_multiqc: true
      species_multiqc: true

# Species details
species:
  Dmel:
    name: "Drosophila melanogaster"
    # Required for SCG auto-determination. Find lineages at https://busco.ezlab.org/
    lineage: "drosophilidae_odb12"
    # Optional: explicit reference path (required only if multiple refs exist in input/reference_module/)
    #scg_reference: "/path/to/reference.fasta"
    # Optional: process only these individuals (all discovered if omitted)
    #individuals:
    #  - IND001
    #  - IND002
    # Optional: process only these references (all discovered if omitted)
    # IDs are filename stems with dots replaced by underscores (e.g. genome.fna → genome)
    #references:
    #  - genome
    # Optional: use only these feature libraries (all discovered if omitted)
    #feature_libraries:
    #  - my_lib
```
