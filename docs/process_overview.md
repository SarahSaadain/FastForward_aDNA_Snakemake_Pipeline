# Past Forward aDNA Pipeline — Process Overview
This document describes the processing logic of the Past Forward aDNA Pipeline across its three main modules: raw read processing, reference processing, and REVEAL processing. A fourth module handles summary reporting across all results. All pipeline behaviour is controlled through `config/config.yaml`.

![Pipeline Overview](img/pf_pipeline_process.svg)

## Module 1 — Raw Read Processing

This module takes raw sequencing data and prepares it for all downstream analyses. It runs on a per-sample basis and produces clean, merged reads ready for mapping.

### Prepare Raw Reads

Before any processing begins, raw FASTQ files are moved into a standardised directory structure. This staging step ensures that all subsequent rules consistently locate their input data regardless of where files were originally placed on disk.

### Adapter Removal

Adapter sequences are removed from raw reads using **fastp**. This step can be turned on or off with **`pipeline.read_module.adapter_removal.execute`**. The pipeline automatically detects whether a sample is single-end or paired-end by checking for the presence of an R2 file, and each mode is handled by a dedicated rule.

For single-end data, an adapter sequence can optionally be provided via **`pipeline.read_module.adapter_removal.settings.adapters_sequences.r1`**. If left empty, fastp performs automatic adapter detection. For paired-end data, separate sequences can be set for R1 and R2 via **`adapters_sequences.r1`** and **`adapters_sequences.r2`**; if neither is provided, fastp's built-in paired-end detection is used instead. Beyond adapters, the step enforces a minimum read length (**`settings.min_length`**, default 0) and a minimum per-base quality score (**`settings.min_quality`**, default 0). Poly-X tail trimming is always active. Additional fastp parameters can be passed directly via **`settings.extra_params`**.

Paired-end reads receive additional treatment: overlapping read pairs are merged into single reads, which is particularly important for ancient DNA where fragment lengths are often shorter than the combined read length. The final output for PE samples concatenates the merged reads, the unmerged trimmed R1 and R2, and any unpaired reads into a single FASTQ file — ensuring no data is discarded. Fastp generates an HTML and JSON report for every sample, which feed into later QC aggregation.

### Quality Filtering

After adapter removal, reads go through a second dedicated quality filtering step, again using **fastp**, controlled by **`pipeline.read_module.quality_filtering.execute`**. Adapter trimming is explicitly disabled here so the step acts purely as a quality gate. The minimum quality score (**`pipeline.read_module.quality_filtering.settings.min_quality`**, default 15) and minimum read length (**`settings.min_length`**, default 15) are configured independently from the adapter removal thresholds, allowing for separate tuning of each stage. The step produces its own HTML and JSON reports per sample.

### Merge by Individual

Many sequencing projects split a single individual across multiple sequencing runs or lanes, each producing a separate FASTQ file. This step concatenates all quality-filtered samples belonging to the same individual into a single merged FASTQ. Individual identity is derived from the sample filename — everything before the first underscore is treated as the individual identifier. The merged file serves as the single input to all downstream reference mapping and REVEAL analyses.

### Read Count Statistics

Read counts are tracked at each processing stage — raw, after adapter removal, and after quality filtering — for every sample. These per-sample counts are collected into a species-level summary CSV. The counts are later used for QC plotting and are incorporated into the MultiQC summary reports.

### Quality Checks with FastQC and MultiQC

**FastQC** is run at four points in the workflow to track how read quality evolves through processing: on the raw reads, on the adapter-trimmed reads, on the quality-filtered reads, and on the final merged per-individual reads.

After FastQC, **MultiQC** aggregates the results from each stage into a single HTML report per stage per species, giving a consolidated quality overview for all samples at a glance.

### Read Count Plots

Two R-based plots are generated from the read count statistics: one showing total read counts per sample across all processing stages, and one comparing read counts grouped by individual. These plots provide a quick visual check of how much data was retained through the processing steps.

### Contamination Analysis

The Past Forward aDNA Pipeline supports two contamination detection tools, both operating on the quality-filtered reads. The entire contamination analysis block is controlled by **`pipeline.read_module.contamination.execute`**, and each tool can additionally be toggled individually.

Both tools are, mechanically, taxonomic read classifiers — they assign reads to reference taxa and report abundance/proportions, the same kind of output a general metagenomic profiling pipeline would produce. There is no dedicated contamination statistic (e.g. mismatch-to-consensus or heterozygosity-based estimates) computed here. The "contamination" framing comes from how the results are interpreted: since each sample is expected to derive from one known target organism, any substantial proportion of reads assigned to other taxa is treated as evidence of exogenous/contaminating DNA rather than as a community worth profiling for its own sake.

**ECMSD** assesses contamination by mapping reads against a curated mitochondrial reference database and reporting the proportional contribution of different taxa. It is enabled via **`tools.ecmsd.execute`**. The conda environment can be customised via **`settings.conda_env`**. Several analysis parameters are configurable: **`settings.cov_threshold`** (default 25) sets the minimum % of reference covered by reads to retain it, **`settings.top_n`** (default 25) controls how many top references get alignment plots, **`settings.mapping_quality`** (default 20) sets the minimum mapping quality for a read to be considered, and **`settings.taxonomic_hierarchy`** (default `species`) determines at which taxonomic level results are reported. Results from all samples belonging to the same individual are merged into a combined summary file.

**Centrifuge** performs k-mer-based taxonomic classification against a user-provided database and is enabled via **`tools.centrifuge.execute`**. The **`settings.index`** parameter optionally points to the Centrifuge database index prefix; if omitted, the default index is downloaded automatically. The conda environment can be overridden with **`settings.conda_env`**. The **`settings.include_human_taxid`** flag (default `false`) controls whether the human taxid is included in the analysis. Beyond raw classification, the pipeline derives proportional taxon abundance and extracts the top 10 taxa ranked by both total and unique read assignments.

## Module 2 — Reference Processing

This module maps reads to one or more reference genomes and produces a final analysis-ready BAM for each individual, along with a comprehensive suite of mapping statistics and coverage metrics. All steps run per individual per reference. The entire module is gated by **`pipeline.reference_module.execute`** (default `true`).

### Reference Preparation

Before mapping can begin, the reference genome is standardised to a `.fa` extension (regardless of whether the input is `.fna`, `.fasta`, or `.fa`) and two index files are created: a BWA index for read mapping and a samtools FAI index used by deduplication and damage analysis. Multiple reference genomes per species are supported — each is given a unique identifier derived from its filename and processed entirely independently. BWA indexing results are cached so the index is only rebuilt if the reference changes.

### Read Mapping

The merged per-individual reads are mapped to the reference using a configurable mapper, set via **`pipeline.reference_module.mapping.settings.mapper`** (default `bwa-mem2`). Three mappers are supported: **bwa-aln** (classic seed-and-extend, recommended for short aDNA reads <70 bp), **bwa-mem2** (faster modern aligner, suited for longer reads), and **minimap2** (versatile aligner, uses the `-ax sr` preset for short reads). Additional mapper flags can be supplied via **`settings.mapper_extra_params`**; for `bwa-aln`, the pipeline defaults to `-n 0.01 -k 2 -l 1024 -o 2` (Oliva et al. 2021) if no custom parameters are provided.

The resulting alignments are immediately sorted by coordinate and indexed. The unsorted BAM is discarded to save disk space. At this point the sorted BAM represents all mapped reads including duplicates, and is used as-is for library complexity estimation before any duplicate removal or damage rescaling.

### Deduplication

PCR and sequencing duplicates are removed using **DeDup**, a tool specifically designed for ancient DNA that correctly handles merged single-stranded reads. Deduplication is controlled by **`pipeline.reference_module.deduplication.execute`** (default `true`). If disabled, the sorted BAM from mapping is passed directly to subsequent steps.

The pipeline uses a [modified DeDup fork](https://github.com/SarahSaadain/DeDup) for performance improvements over upstream DeDup; the jar is downloaded automatically (see `workflow/scripts/bootstrap_dedup_jar.py`). Benchmarks against upstream DeDup are tracked in a [separate comparison repo](https://github.com/SarahSaadain/DeDup_comparison_fork).

Because DeDup can be memory-intensive on reference genomes with many contigs, the pipeline uses a divide-and-conquer approach: contigs are grouped into clusters, the sorted BAM is split by cluster, each cluster is deduplicated independently, and the results are merged back together. The maximum cluster size is configurable via **`deduplication.settings.max_contigs_per_cluster`** (default 500). Lowering this value reduces peak memory use at the cost of more merge operations; reducing it is only necessary for large, highly fragmented reference genomes. Each deduplication run produces a histogram and a JSON statistics file; the per-cluster JSON files are merged into a single summary that feeds into downstream QC reporting.

### DNA Damage Analysis and BAM Rescaling

Ancient DNA is characterised by cytosine deamination, appearing as C→T substitutions at the 5' end and G→A substitutions at the 3' end of reads. This step profiles those damage patterns and optionally corrects for them. It is controlled by **`pipeline.reference_module.damage_rescaling.execute`** (default `true`).

The input BAM for this step is selected dynamically: if deduplication was enabled the deduplicated BAM is used, otherwise the sorted BAM from mapping. The tool **mapDamage2** is run on the selected BAM to estimate damage patterns and rescale base quality scores accordingly. The rescaled BAM is then sorted and indexed, and the unsorted rescaled BAM is discarded. The mapDamage2 output directory, including the rescaled BAM and all statistics files, is copied into the summary folder structure to be included in the MultiQC report.

The input BAM for this step is selected dynamically: if deduplication was enabled the deduplicated BAM is used, otherwise the sorted BAM from mapping.

### Final BAM

After all optional processing steps, a single canonical `_final.bam` is produced by selecting the most-processed available BAM following a priority chain: rescaled BAM (if **`damage_rescaling.execute`** is true) → deduplicated BAM (if **`deduplication.execute`** is true) → sorted BAM. This ensures all downstream analytics always work from a consistently named file regardless of which steps were enabled.

### Filter Unmapped Reads

This optional step is controlled by **`pipeline.reference_module.filter_unmapped_reads.execute`** (default `false`) and is not needed for standard aDNA workflows. When enabled, it processes the final BAM to handle reads that did not map to the reference. The **`settings.action`** parameter determines the behaviour:

- **`remove`** — writes a mapped-reads-only BAM (`{individual}_{reference}_mapped_only.bam`), reducing file size by stripping unmapped reads.
- **`extract_fastq`** — writes unmapped reads to a compressed FASTQ (`{individual}_{reference}_unmapped.fastq.gz`), useful for downstream metagenomic screening of non-endogenous content.
- **`extract_fasta`** — writes unmapped reads to a compressed FASTA (`{individual}_{reference}_unmapped.fasta.gz`).

### Coverage Analysis

Coverage analysis runs whenever **`pipeline.reference_module.analysis.execute`** is enabled (default `true`). The final BAM is interrogated using **samtools depth**, which reports per-position depth across the entire reference including zero-coverage sites. A custom Python script then analyses the depth output to compute coverage breadth at multiple depth thresholds and mean depth statistics per individual. All individual results are combined into species-level summary tables, and the data is reformatted into MultiQC-compatible custom content files.

### Mapping Statistics

Four additional tools are run to produce complementary QC metrics:

**samtools stats** generates a comprehensive statistics file from the final BAM, used among other things to extract the fraction of reads that successfully mapped to the reference (the endogenous content).

**Qualimap bamqc** produces an HTML quality report covering mapping rates, coverage uniformity, GC content, and insert size distributions.

**Picard MarkDuplicates** is run on the sorted (pre-dedup) BAM to provide duplicate metrics for QC comparison purposes.

**Preseq** estimates library complexity and extrapolates sequencing yield. Critically, preseq must be run on the sorted BAM *before* deduplication and damage rescaling — running it afterwards removes the duplication information that preseq requires, leading to invalid estimates. Both a complexity curve and an lc_extrap extrapolation are generated.

### Endogenous Read Fraction

The samtools stats output is parsed to determine how many reads mapped to the reference genome. This endogenous content is reported per individual and combined across all individuals into a species-level file. Together with the raw read counts from Module 1, this provides a full picture of how much of the sequenced data is target-derived.

### Plots

A set of R-based plots summarise the mapping results visually. Coverage breadth and depth are each shown as both a violin plot and a bar chart, comparing all individuals for a given species and reference. Endogenous read fractions are shown as a bar chart per individual, and a combined plot shows raw read counts alongside endogenous fractions to provide full context from raw sequencing through to usable data.

### MultiQC BAM Report

All QC outputs for a given individual and reference are aggregated into a single **MultiQC** HTML report. This includes the fastp reports from adapter removal and quality filtering, FastQC of merged reads, contamination analysis outputs, Preseq curves, the Qualimap directory, samtools stats, the custom coverage and reads processing summary tables, the mapDamage2 output directory, and the DeDup JSON summary. Each input type is only requested if its corresponding config toggle is enabled — disabled steps are silently omitted, keeping the report self-consistent.

## Module 3 — REVEAL Processing

This module quantifies the relative abundance and activity of transposable elements (TEs) and other genomic features across individuals. It works by mapping reads to a purpose-built reference consisting of TE sequences combined with single-copy genes (SCGs). The SCGs serve as a stable normalisation reference, making TE abundance estimates comparable across individuals regardless of differences in sequencing depth.

### SCG Determination

Single-copy genes can either be provided directly or determined automatically from the reference genome. If a FASTA file is placed under `{species}/input/reveal_module/scg/`, it is used as-is. If no file is present and **`pipeline.reveal_module.scg_selector.execute`** is `true` (the default), the pipeline runs an automatic SCG determination step — provided a BUSCO lineage is configured for the species under **`species.<key>.lineage`**.

Automatic SCG determination runs in three steps. First, **BUSCO** is run against the reference genome in genome mode to identify Complete single-copy genes within the configured lineage database. BUSCO's coordinates are used to extract each gene's nucleotide sequence from the reference, applying minimum (**`settings.min_length_scg`**, default 4,000 bp) and maximum (**`settings.max_length_scg`**, default 8,000 bp) length filters. Second, the merged per-individual reads are mapped to this candidate SCG library and per-position coverage statistics are computed for every SCG in every individual. Third, SCGs are scored on three criteria — breadth of coverage, evenness of depth, and consistency of depth relative to the global SCG population — and the top-ranked sequences (**`settings.num_top_scgs`**, default 20) are selected. The ranking table is written to `{species}/results/reveal_module/scg/` as a permanent result; the filtered FASTA is passed to the Library Preparation step.

The mapper used for SCG read mapping is configured via **`pipeline.reveal_module.scg_selector.settings.mapper`** and defaults to the same mapper set for the main REVEAL mapping step. The mapping BAMs produced during SCG determination are temporary and deleted once coverage statistics have been computed. For a detailed description of the scoring methodology see [docs/scg_determination.md](scg_determination.md).

### Library Preparation

The REVEAL pipeline requires a **feature library** containing the TE or other feature sequences of interest, placed under `{species}/input/reveal_module/feature_library/`. Both `.fna`, `.fasta`, and `.fa` formats are supported. The SCG library is either user-provided (placed under `{species}/input/reveal_module/scg/`) or produced by the SCG Determination step described above.

Before mapping, sequence headers in both libraries are standardised and suffixed to make TE and SCG sequences distinguishable in the alignments — `_fle` is appended to every feature library header, and `_scg` to every SCG header. The two processed libraries are then concatenated into a single combined FASTA, which is indexed in preparation for mapping using the indexer that matches the configured mapper. Multiple feature libraries per species are supported; each produces an entirely independent set of downstream results.

### Mapping to the Combined Library

Merged per-individual reads (from Module 1) are mapped to the combined SCG + TE library using a configurable mapper, set via **`pipeline.reveal_module.mapping.settings.mapper`** (default `bwa-mem2`). The same three options are available as in reference processing: **bwa-aln**, **bwa-mem2**, and **minimap2**. Additional flags can be supplied via **`settings.mapper_extra_params`**. After conversion from SAM to BAM, unmapped reads are immediately discarded to reduce file sizes. The filtered BAM is then sorted and indexed. Intermediate files are cleaned up automatically.

### Normalisation

For each individual, the pipeline calculates read coverage across both the SCG and TE sequences in the combined library. The SCG coverage serves as the normalisation factor, accounting for differences in sequencing depth and mapping efficiency between individuals. This normalisation is critical for making meaningful comparisons of TE abundance across a population. Per-individual coverage files are combined into a species-level table, and an R-based plot is generated showing normalised TE abundance across all individuals. The order and labels of individuals in the plot are derived from the individual list for the species.

### REVEAL Visualization

**REVEAL** (formerly TEplotter) provides a complementary view focusing on a sequence overview (SO) — a tab-delimited file containing coverage, SNP, and indel information for each reference sequence. The analysis runs through a multi-step pipeline:

First, the sorted BAM is converted into a sequence overview (`.so`) profile using `REVEAL bam2so`, with sequence lengths derived from the combined library FASTA. The raw SO values are then normalised against SCG coverage using `REVEAL normalize`, and per-sequence statistics are estimated using `REVEAL estimate`. The normalised profiles are converted into a plotable directory structure using `REVEAL so2plotable`, processing all sequences and labelling outputs with the individual's identifier.

From the plotable directories, per-individual TE occupancy plots are generated using `REVEAL plot`. A second pass combines all individual plotable directories to produce a faceted species-level comparison plot, allowing side-by-side visual comparison of TE dynamics across all individuals simultaneously.

#### Per-Individual Stats Files

For each individual, **`so2stats`** computes per-sequence coverage and SNP statistics from the normalised SO file and writes a `{individual}_coverage.normalized.stats.tsv`. Each row represents one sequence in the combined library and contains:

- **Coverage metrics** — `median_cov` (copy number proxy when SCG-normalised), `mad_cov` (robust spread), `cv_cov` (scale-independent variation), `max_cov` (peak coverage), `frac_low` (fraction of positions with near-zero coverage, proxy for absence or deletion)
- **SNP metrics** — `n_snps` (total alt allele observations), `snp_density` (SNPs per 100 bp), `median_alt` (median alt allele count across SNP sites)

#### Species-Level Comparison and Flagging

After all individual stats files are produced, **`compare_stats`** pivots the per-individual long-format tables into a single wide-format species-level summary (`{species}_{feature_library}_coverage_comparison.tsv`), with one row per sequence and per-sample metric columns named `{metric}__{sampleid}`. Cross-sample copy number metrics are added:

- `cn_min` / `cn_max` — lowest and highest `median_cov` across all individuals
- `cn_abs` — absolute range (`cn_max − cn_min`)
- `cn_log2fc` — log₂ fold-change (`log2(cn_max / cn_min)`)

Sequences are flagged if they show a relative copy number shift exceeding the **`CN_FC`** threshold (default log₂FC ≥ 2) or an absolute shift exceeding the **`CN_ABS`** threshold (default Δ ≥ 10). Flagged sequences are written to a companion file `{species}_{feature_library}_flagged_seqids.tsv` and sorted to the top of the comparison table.

A top-level cross-library summary (`{species}_reveal_coverage_comparison.tsv`) aggregates the flagged sequence lists across all feature libraries into a single file for rapid inspection.

## Module 4 — Processing Summary

The summary module consolidates outputs from all three processing modules into cohesive **MultiQC** HTML reports at two levels: a per-individual report covering all QC and analytics for a single individual across all references, and a per-species overall report aggregating all individuals.

Custom data preparation scripts transform pipeline outputs — coverage breadth, coverage depth, and reads processing statistics — into TSV files formatted for MultiQC's custom content sections. Reads processing summaries are produced both as absolute values (raw, trimmed, quality-filtered, endogenous, deduplicated counts) and as a stacked representation (non-endogenous, duplicates, retained endogenous reads) suited to stacked bar chart visualisation in MultiQC. Both formats are additionally combined into species-level files for the overall report.

Because Qualimap and mapDamage2 output directories need to be co-located with other MultiQC inputs, they are copied into the summary folder structure before report generation. All inputs to MultiQC are conditionally requested based on which pipeline steps were enabled, so the reports always accurately reflect the steps that were actually run.

## Global Configuration and Pipeline Behaviour

The entire Past Forward aDNA Pipeline is controlled through a single `config/config.yaml` file. Species to be processed are defined as a top-level mapping under `species:`, each with an optional display name, and all modules run for every species listed. Every major processing step can be independently enabled or disabled.

For a full description of all configuration options, defaults, and an annotated example config, see [config/README.md](../config/README.md).

On every execution the pipeline logs extensive provenance information: timestamp, platform and OS details, Python and Snakemake versions, the active conda environment, the git commit hash of the pipeline code, the full command line used, all config file paths, and the complete loaded configuration. A minimum Snakemake version of 9.9.0 is enforced at startup.