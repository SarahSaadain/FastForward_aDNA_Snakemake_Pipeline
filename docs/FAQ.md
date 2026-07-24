# pastForward FAQ

## Setup & Installation

**Q: What is the minimum Snakemake version required?**
Snakemake 9.9.0 or higher is required. pastForward enforces this at startup and will refuse to run on older versions.

**Q: Do I need to pre-install all the bioinformatics tools?**
No. pastForward manages all tool dependencies through conda environments automatically when you pass `--use-conda`. Snakemake creates the environments on the first run.

**Q: Can I run pastForward without conda?**
Not reliably. Each pastForward rule is tied to a specific conda environment that ensures reproducible software versions. Running without `--use-conda` will fail unless you have all required tools installed and on your PATH with compatible versions.

**Q: How does the pastForward know which files to create?**
pastForward defines a set of expected output files based on the configuration and the input data. At the start of each run, it performs an input validation step that checks for the presence of available input files and prints a summary of the detected files.

Based on your configuration and the detected input files, pastForward determines which output files will be generated in a particular run. It prints a list of all the files that will be requested by pastForward based on the current config. You can review this list in a dry run to ensure that all your input files are correctly detected and will be processed as expected.

---

## Input Data

**Q: Where do I put my raw sequencing reads?**
Place them in `<species>/input/reads_module/`. pastForward expects compressed FASTQ files following a specific naming convention (see below) to group samples by individual for merging.

**Q: What read file format does pastForward expect?**
Reads must be compressed FASTQ (`.fastq.gz`). The filename must follow the convention:

```
<Individual>_[<FreeText>_]R<1/2>[_<FreeText>].fastq.gz
```

Everything before the first underscore is treated as the individual identifier and is used to group samples for merging.

**Q: My data is single-end. Does pastForward support that?**
Yes. pastForward auto-detects single-end vs. paired-end by checking whether an R2 file exists for each R1 file. Both modes are handled automatically.

**Q: Can I have multiple sequencing runs for the same individual?**
Yes. All samples belonging to the same individual (same prefix before the first underscore) are merged into a single FASTQ during the "Merge by Individual" step. You can place all run files in `<species>/input/reads_module/` and they will be processed and concatenated automatically.

**Q: Where do I put the reference genome?**
Place it in `<species>/input/reference_module/`. pastForward accepts `.fa`, `.fasta`, and `.fna` extensions and normalises them internally. Multiple reference genomes per species are supported — each is processed independently.

**Q: Can I point to files outside the species folder without moving them?**
The recommended approach is to place files directly in the species folder. pastForward will detect and move them to the correct subfolders automatically on the first run.

**Q: I have a lot of data. Can I symlink to it instead of copying?**
Yes. pastForward will detect if files are symlinks and will use them directly without copying. Just place the symlinks in the expected locations under `<species>/input/` and pastForward will handle them seamlessly.

**Q: Can I have multiple species in the same project?**
Yes. Each species is processed independently, so you can have as many species as needed within the same project. Just add additional entries under the `species` section in the config.yaml and place their respective data in separate subfolders under `<species>/input/`.

**Q: Do I need to provide a separate reference genome for each species?**
Yes. Each species entry in the config must have its own reference genome placed in `<species>/input/reference_module/`. pastForward processes each species independently, so it requires a reference genome for each one to perform mapping and downstream analyses.

**Q: Can I use multiple references for the same species?**
Yes. pastForward supports multiple references per species. Just place each reference file in `<species>/input/reference_module/` and pastForward will process them independently, generating separate outputs for each reference.

**Q: Does the reference need to be a reference genome?**
No. The reference can be any FASTA file of sequences you want to map to and analyse. While a reference genome is typical, you could also use a transcriptome assembly, a custom set of contigs, or even a single sequence if that suits your research question.

**Q: Which format does the reference need to be in?**
The reference must be in FASTA format with a `.fa`, `.fasta`, or `.fna` extension. pastForward normalises the reference internally, so you can use any of these extensions without issue.

**Q: Can I process only a subset of individuals for a species?**
Yes. Add an `individuals` list under the species entry in `config.yaml`:

```yaml
species:
  Dmel:
    name: "Drosophila melanogaster"
    individuals:
      - IND001
      - IND002
```

Each entry must match the individual identifier extracted from read filenames — the part before the first `_` (e.g. `IND001` from `IND001_L001_R1.fastq.gz`). If the list is omitted, all individuals discovered on disk are processed. The startup preview will report which individuals were found but not selected under a "ignored" section.

**Q: Can I use only specific reference genomes for a species?**
Yes. Add a `references` list under the species entry:

```yaml
species:
  Dmel:
    name: "Drosophila melanogaster"
    references:
      - genome
```

Each entry must match the reference ID derived from the filename: basename without extension, with dots replaced by underscores (e.g. `EquCab3.0.fna` → `EquCab3_0`). If omitted, all references in `{species}/input/reference_module/` are used.

**Q: Can I use only specific feature libraries for the REVEAL stage?**
Yes. Add a `feature_libraries` list under the species entry:

```yaml
species:
  Dmel:
    name: "Drosophila melanogaster"
    feature_libraries:
      - my_lib
```

Same ID format as references (filename stem, dots → underscores). If omitted, all libraries in `{species}/input/reveal_module/feature_library/` are used.

**Q: What happens if I list an individual, reference, or feature library that does not exist on disk?**
pastForward raises an error at startup and aborts before any processing starts. The error message lists which IDs were not found and shows all available IDs, so you can correct the config. This prevents silent misconfiguration where a typo would cause a run to silently skip data.

**Q: Can I add new samples after the first run?**
Yes. pastForward is designed to be flexible and can accommodate new samples at any time. Just add the new FASTQ files to the appropriate `<species>/input/reads_module/` folder. pastForward will detect and process them automatically.

In case you use `skip_existing_files: true`, pastForward will not re-process existing files, so only the new samples will be processed without affecting previous results. This might be an issue if summary reports need to be updated to include the new samples, as they may rely on outputs from all samples. Either you can re-run pastForward without `skip_existing_files` to regenerate all outputs including the new samples, or you can remove the summary reports, so they will be regenerated with the new samples included.

**Q: I added new samples but they are not showing up in the reports. What do I do?**
If you added new samples after the first run and your summary reports are not updating, it may be because pastForward is skipping existing files. 

To fix this, you can either:
1. Re-run pastForward without `skip_existing_files: true` to regenerate all outputs and include the new samples in the reports.
2. Manually delete the existing summary report files so that pastForward regenerates them with the new samples included

You can see the skipped files in pastForward log (use a dry run to check). 

**Q: How can I validate that my input files are correctly formatted and will be processed by pastForward?**
You can perform a dry run of pastForward using the command:
```bash
snakemake --cores <N> --use-conda --dryrun
```

At the beginning of each run, pastForward performs an input validation step that checks for the presence and correct formatting of all required input files. It will print a summary of the detected files and any issues found. 

Additionally, it will print all the files that will be requested by pastForward based on the current config. You can review this list to ensure that all your input files are correctly detected and will be processed as expected.

Lastly, you can also see the rules that will be executed and their inputs/outputs. This allows you to verify that pastForward is correctly set up to process your data before actually running it.

**Q: Can I provide the adapter sequences for adapter removal?**
Yes. If you want to provide custom adapter sequences for adapter removal, you can provide a FASTA file containing the adapter sequences and specify its path in the config under `pipeline.read_module.adapter_removal.settings.adapters_sequences.[r1|r2]`. 

In case they are not provided, fastp will try to auto-detect adapters based on the read data.

**Q: Can I provide already pre-processed reads?**
Yes. If you have already pre-processed reads (e.g., adapter-trimmed and quality-filtered) and want to skip the raw reads processing step, you can place your pre-processed FASTQ files in the expected location under `<species>/input/reads_module/` with the correct naming convention. 

To skip the adapter removal and quality filtering steps, set the `execute` flag to `false` for those steps in the config:

```yaml
pipeline:
  read_module:
    adapter_removal:
      execute: false
    quality_filtering:
      execute: false
``` 

This way, pastForward will use your pre-processed reads directly for downstream steps without attempting to re-process them. 

---

## Configuration

**Q: What is the minimum config I need to run pastForward?**
A project name and at least one species entry:

```yaml
project_name: "my_project"

species:
  Dmel:
    name: "Drosophila melanogaster"
```

All pastForward stages are enabled by default, so this minimal config is sufficient to run the full pipeline.

**Q: How do I configure pastForward without editing YAML by hand?**
Open `config/config_designer.html` in a browser. The interactive Config Designer lets you toggle pastForward stages and species settings and exports a ready-to-use `config.yaml`.

**Q: How do I disable a pastForward stage I don't need?**
Set its `execute` flag to `false` in `config/config.yaml`. For example, to skip contamination analysis:

```yaml
pipeline:
  read_module:
    contamination:
      execute: false
```

**Q: Can I enable or disable specific steps after a completed run?**
Yes. You can modify the config to enable or disable specific steps and then re-run pastForward. pastForward will detect which outputs are missing or outdated based on the new configuration and will only execute the necessary rules to generate the required outputs.

For example, if you initially ran pastForward with contamination analysis disabled and later want to enable it, simply set `execute: true` for the contamination analysis step in the config and re-run pastForward. It will then execute only the rules related to contamination analysis without re-running the entire pipeline.

> ⚠️ Warning: In some cases, enabling certain steps may affect downstream outputs (e.g., summary reports). In such cases, pastForward will automatically re-run the affected downstream rules to ensure that all outputs are consistent with the new configuration (Snakemake default behavior). Using `skip_existing_files: true` can help avoid unnecessary re-processing of unchanged files, but be cautious as it may still lead to re-processing of some steps. In such cases, you can also disable the affected downstream steps temporarily, run pastForward to generate the new outputs for the enabled step, and then re-enable the downstream steps in a subsequent run to update the reports or other affected outputs. Check using a dry run to see which steps will be re-run and adjust the config accordingly to minimise unnecessary processing.
>
> Example: If you enable contamination analysis after the first run (e.g. reads + ref + summary), pastForward will need to re-run adapter removal and quality filtering for all samples to generate the necessary inputs for contamination analysis. Since these outputs are temporary, they are not stored between runs. To allow contamination analysis, pastForward must re-generate these outputs. In this case Snakemake will determine that there has been a change and conclude that all downstream steps that depend on these outputs need to be re-run to ensure consistency. Using `skip_existing_files: true` can help avoid unnecessary re-processing, but it is better to check the pastForward log to ensure that the re-processing is indeed suppressed. If Snakemake still triggers a re-run (e.g. reference processing, mapping, ...), the downstream steps can be temporarily disabled in the config.

---

## Running pastForward

**Q: What is the recommended command to run pastForward?**
```bash
snakemake --cores <N> --use-conda --keep-going --rerun-trigger mtime
```

`--keep-going` lets pastForward continue past individual rule failures (e.g., ECMSD failing on low-coverage samples). `--rerun-trigger mtime` re-runs only rules whose inputs have changed since the last run.

**Q: How do I run pastForward in the background so I can close my terminal?**
```bash
nohup snakemake --cores 40 --use-conda --keep-going --rerun-trigger mtime > pipeline.log 2>&1 &
```

Monitor progress with `tail -f pipeline.log`.

**Q: How do I do a dry run to see what would be executed without actually running anything?**
```bash
snakemake --cores <N> --use-conda --dryrun
```

**Q: pastForward crashed midway. How do I resume?**
Re-run with `--rerun-incomplete` to pick up where it left off:

```bash
snakemake --cores <N> --use-conda --keep-going --rerun-trigger mtime --rerun-incomplete
```

**Q: How do I force a specific rule or file to be regenerated?**
Delete the output file and re-run, or use `--forcerun <rule_name>` to force a specific rule. Use `--touch` with `--forceall` to mark all outputs as up to date without re-running (use as a last resort). Check the Snakemake documentation for more options on controlling rule execution.

**Q: I have lots of data. How does pastForward manage disk space?**
pastForward automatically deletes intermediate files that are no longer needed after each step to save disk space. The final outputs (e.g., `_final.bam`, summary reports) are retained, while temporary files (e.g., raw mappings, rescaled BAMs) are removed once they have been processed. This allows you to run pastForward on large datasets without worrying about running out of disk space.

Additionally, if possible, certain ouputs are compressed to save space.

Non theless, it is recommended to monitor disk usage during the first run to ensure that you have sufficient space for the intermediate files, especially if you are working with large datasets.

**Q: Can I run multiple instances of pastForward simultaneously?**
Yes, you can run multiple instances of pastForward simultaneously, provided that each instance has its own independent working directory and configuration. This allows you to process different datasets or run the same dataset with different parameters in parallel.

**Q: Can I stop a running pastForward instance without corrupting the results?**
Yes. pastForward is designed to handle interruptions gracefully. If you need to stop a running instance, you can safely terminate the process (e.g., using `Ctrl+C` or `kill`). pastForward will leave behind a lock file to prevent concurrent runs from interfering with each other.

In case you run pastForward in the background, you can stop it using `kill -SIGINT <PID>` where `<PID>` is the process ID of the running instance (you can get it with `head <pipeline.log>`).

When you are ready to resume, simply run pastForward again with the same command. It will detect the existing lock file and prompt you to unlock it using `snakemake --unlock`. After unlocking, you can re-run pastForward, and it will pick up where it left off without corrupting any results.

---

## Read Mapping

**Q: Which mapper should I use for my data?**
- **bwa-aln** — recommended for short aDNA reads (<70 bp). Uses aDNA-optimised defaults from Oliva et al. 2021 if no custom params are provided. While this one is recommended for short reads, it is very slow in some cases. Thats why bwa-mem2 is the default mapper, as it is much faster and still performs well on short reads.
- **bwa-mem2** — default; faster and suitable for longer reads.
- **minimap2** — versatile; uses the `-ax sr` preset for short reads. If you want to get a "quick and dirty" mapping to check your aDNA data, minimap2 is a good choice. However, it is not optimised for the specific challenges of aDNA and may produce lower-quality alignments compared to bwa-aln or bwa-mem2.

Set the mapper via `pipeline.reference_module.mapping.settings.mapper`.

**Q: Can I use different mappers for reference processing and REVEAL processing?**
Yes. The mapper is configured independently under `pipeline.reference_module.mapping.settings.mapper` and `pipeline.reveal_module.mapping.settings.mapper`.

---

## Deduplication & Damage

**Q: Which DeDup build does pastForward use?**
A [modified DeDup fork](https://github.com/SarahSaadain/DeDup), not upstream DeDup — the fork includes performance improvements. The jar is pinned and downloaded automatically by `workflow/scripts/bootstrap_dedup_jar.py`, so no manual build step is required. Benchmarks against upstream DeDup are tracked in a [separate comparison repo](https://github.com/SarahSaadain/DeDup_comparison_fork).

**Q: Why does deduplication split the BAM into clusters?**
DeDup can use large amounts of memory on reference genomes with many contigs. Splitting by contig cluster caps peak memory use. Adjust `deduplication.settings.max_contigs_per_cluster` (default 500) — lower values reduce memory at the cost of more merge operations.

Also, splitting by cluster allows for more efficient parallel processing. Each cluster is processed independently, so multiple clusters can be deduplicated simultaneously across available CPU cores.

**Q: What determines which BAM becomes the `_final.bam`?**
pastForward follows a priority chain: rescaled BAM → deduplicated BAM → sorted BAM, using the most-processed available result based on which steps are enabled.

---

## Contamination Analysis

**Q: ECMSD keeps failing on some samples. Do I have to fix this before pastForward continues?**
No. Run with `--keep-going` and pastForward will skip the failed samples and continue processing everything else. ECMSD failures are common on low-coverage or low-quality samples.

**Q: Why does ECMSD fail on some samples?**
ECMSD is sensitive to low-coverage samples and may fail to detect contamination in some cases. It is recommended to run pastForward with `--keep-going` and ignore ECMSD failures.

**Q: Can I reuse the same ECMSD database for multiple runs?**
Yes. The ECMSD database is downloaded and stored in the pipelines resource directory. If it already exists, pastForward will reuse it without re-downloading. You can safely run multiple instances of pastForward without worrying about redundant ECMSD database downloads.

**Q: Can I reuse the same ECMSD database for multiple pastForward instances?**
Yes. As long as the ECMSD database is accessible at the expected path in the pipelines resource directory, multiple pastForward instances can use the same database for contamination analysis without conflict.

Use `tools.ecmsd.settings.database` to specify a custom path to the ECMSD database if needed. Otherwise, pastForward will manage it automatically.

**Q: The Centrifuge database isn't specified. What happens?**
If `tools.centrifuge.settings.index` is not set, pastForward will attempt to download a default index automatically. For reproducible runs, specify your own index path.

**Q: Can I use a custom Centrifuge database?**
Yes. Set `tools.centrifuge.settings.index` to the path of your custom index. pastForward will use it for contamination analysis instead of downloading the default.

**Q: Can I reuse the same index for multiple runs?**
Yes. pastForward checks if the specified Centrifuge index already exists and will reuse it if found. You can safely point to the same index across multiple runs without worrying about redundant downloads.

**Q: Can I reuse the same Centrifuge database for multiple pastForward instances?**
Yes. As long as the Centrifuge index is accessible at the specified path, multiple pastForward instances can use the same database for contamination analysis without conflict.

You can even share the same Centrifuge index across different projects or species, as long as the path is correctly specified in each config. This allows for efficient use of resources and consistent contamination analysis across multiple datasets.

---

## REVEAL Module

**Q: What goes in the feature library?**
A FASTA file of genomic features sequences (e.g. transposable element, genes, ...) you want to quantify. Place it under `<species>/input/reveal_module/feature_library/`. Multiple feature libraries per species are supported and each is processed independently.

**Q: Do I need to provide SCG sequences?**
Not necessarily. If a FASTA file is placed under `<species>/input/reveal_module/scg/` it is used directly. Otherwise, if `pipeline.reveal_module.scg_selector.execute: true` (the default) and a BUSCO lineage is configured under `species.<key>.scg_selector.settings.lineage`, pastForward determines SCGs automatically from the reference genome.

**Q: How are SCGs selected automatically?**
BUSCO identifies complete single-copy genes in the reference genome. Candidate sequences are filtered by length (`min_length_scg` / `max_length_scg`, defaults 4,000–8,000 bp), then scored on coverage breadth, depth evenness, and cross-individual consistency. The top-ranked sequences (`num_top_scgs`, default 20) are selected. See [scg_determination.md](scg_determination.md) for the full scoring methodology.

**Q: How does pastForward determine the reference genome for determining SCGs?**
pastForward will try to use the reference from the folder `<species>/input/reference_module/`. If it doesn't exist, it will fall back to using the reference specified in `species.<key>.reference`. If neither is available, pastForward will raise an error since a reference genome is required for SCG selection.

In case multiple references are available in `<species>/input/reference_module/`, pastForward will raise an error asking you to specify which one to use for SCG selection by setting `species.<key>.reference` to the filename of the desired reference.

**Q: What does the copy number fold-change flag mean in the REVEAL output?**
Sequences are flagged if the log₂ fold-change in median coverage across individuals exceeds `CN_FC` (default ≥ 2) or the absolute difference exceeds `CN_ABS` (default Δ ≥ 10). Flagged sequences are sorted to the top of the comparison table and written to a companion `_flagged_seqids.tsv` file.

---

## Reports

**Q: Where are the MultiQC reports?**
- Per-individual: `{species}/results/summary/individual_level/{individual}_multiqc.html`
- Per-species: `{species}/results/summary/species_level/{species}_multiqc.overall.html`

**Q: A step was disabled. Will the report still work?**
Yes. Each report only requests inputs from enabled steps. Disabled steps are silently omitted — the report accurately reflects what was actually run.

---

## Troubleshooting

**Q: pastForward says it is locked. What do I do?**
A lock file is left behind when a previous run was forcefully terminated. Run `snakemake --unlock` to remove it, then re-run normally. Do not delete the lock file manually.

**Q: I accidentally deleted some intermediate files. Can I regenerate them?**
Yes. Delete the corresponding output files (or use `--forcerun`) and re-run pastForward. Snakemake will re-execute only the rules needed to regenerate the missing files.

**Q: How do I know what version of pastForward code was used for a run?**
Each run logs a full provenance record to pastForward log, including the git commit hash, Snakemake and Python versions, platform details, and the full configuration that was loaded.
