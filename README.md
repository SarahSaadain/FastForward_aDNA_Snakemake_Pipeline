<p align="center"><img src="docs/img/pastforward_logo_block.svg" width="250"/></p>

# pastForward - An aDNA Pipeline based on snakemake

A pipeline for analyzing raw historical/ancient DNA obtained from a sequencing facility. Using Snakemake, it ensures efficient resource management and automated handling of software dependencies. It processes and generates reports on sequence quality and contamination, with checks specifically suited for aDNA short reads, to assess whether an extraction was successful and the sample is free of major contamination. Additionally, reads are mapped and rescaled according to their damage profiles, ready for downstream analyses. It also optionally enables comparisons of key genomic features across time points, such as transposon insertions, gene copy number changes, or endosymbiont strain replacements.

## Workflow Overview

Below is an overview of the steps of the pipeline:

![Pipeline Overview](docs/img/pf_pipeline_process_withoutLogo.svg)

For detailed information about the processing steps, see the [Process Overview](docs/process_overview.md) page. For common questions and troubleshooting, see the [FAQ](docs/FAQ.md).

## Setup Overview

The pastForward pipeline is implemented using Snakemake. Information about the setup as well as configuration options can be found in the [Setup Instructions](config/README.md).

All pipeline stages are enabled by default, so a minimal `config.yaml` with just the project name and species list is sufficient to get started. If you want to adjust any settings, open [config/config_designer.html](config/config_designer.html) in a browser — the interactive Config Designer lets you configure pipeline stages and species settings through a graphical interface and exports a ready-to-use `config.yaml`.

For more information on Snakemake, see the [Snakemake website](https://snakemake.github.io).

## Running the Pipeline

The pastForward pipeline is implemented using Snakemake, a workflow management system. Snakemake ensures reproducibility and efficient execution of the pipeline.

### Running the Pipeline

Run `snakemake` from the **project root directory** — the folder that directly contains `workflow/`, `config/`, and your `<species>/` folders. This is *not* the `workflow/` folder itself; do not `cd` into `workflow/` before running the commands below. See [Project Structure](config/README.md#project-structure) for how a project is laid out.

```bash
# minimum command to run the pipeline
#snakemake --cores <number_of_threads> --use-conda

# suggested command to run the pipeline
snakemake --cores <number_of_threads> --use-conda --keep-going --rerun-trigger mtime
```

Replace `<number_of_threads>` with the number of CPU threads you want to allocate for the pipeline.

**Note:** 
* The `--use-conda` flag enables the use of conda environments specified in the `Snakefile`.
* The `--keep-going` flag allows the pipeline to continue even if a rule fails. Somtimes the analysis of ECMSD fails due to issues with the input data (e.g. low quality reads or low coverage). In this case, the rest of the pipeline can still be executed.
* The number of threads can be adjusted using the `--cores` option when running Snakemake.
* The `–rerun-trigger mtime` flag ensures that the pipeline only re-runs rules if the input files have been modified since the last run.

Other useful flags:
* `--dryrun` or `-n` to simulate the execution of the pipeline without actually running it
* `--configfile <path_to_config.yaml>` to specify a custom config file
* `--rerun-incomplete` to re-run rules that failed or were cancelled in the previous run
* `--rerun-trigger` to specify which triggers to use for rerunning rules
  * Possible choices: code, input, mtime, params, software-env
  * Define what triggers the rerunning of a job. By default, all triggers are used, which guarantees that results are consistent with the workflow code and configuration. If you rather prefer the traditional way of just considering file modification dates, use `–rerun-trigger mtime`.
* `--touch` to touch output files (mark them up to date without really changing them) instead of running their commands. This is used to pretend that the rules were executed, in order to fool future invocations of snakemake. Note that this will only touch files that would otherwise be recreated by Snakemake (e.g. because their input files are newer). For enforcing a touch, combine this with –force, –forceall, or –forcerun. Note however that you lose the provenance information when the files have been created in reality. Hence, this should be used only as a last resort.

For more information on Snakemake command-line options, see the [Snakemake documentation](https://snakemake.readthedocs.io/en/stable/executing/cli.html).

### Running the Pipeline in the Background

Depending on the size of the data, it may take some time to complete the pipeline. Thus it is recommended to run the pipeline in the background. You can do this by running the following command:

```bash
nohup snakemake --cores 40 --use-conda --keep-going --rerun-trigger mtime > pipeline.log 2>&1 &
```

### Restarting the Pipeline

Snakemake automatically tracks the state of the pipeline and will only re-run steps that are incomplete or outdated. If you want to restart the pipeline from the beginning, you can delete the relevant output files and re-run the pipeline.

If you want to restart the pipeline, because it has crashed or was terminated, you might need to use the `--rerun-incomplete` flag. This will re-run all incomplete steps, even if they have not been modified since the last run.

### Running on an HPC Cluster

pastForward is a plain Snakemake workflow, so it should in principle work with Snakemake's [cluster/HPC execution support](https://snakemake.readthedocs.io/en/stable/executing/cluster.html) (e.g. Slurm, PBS) via the corresponding [executor plugins](https://snakemake.github.io/snakemake-plugin-catalog/), without any changes to the pipeline itself. This has not yet been specifically tested with pastForward — testing on a Slurm-based HPC cluster is planned. If you try it yourself, feedback is very welcome.

## Reports

pastForward generates a MultiQC report for:
- each species (including all samples from this species, to compare the results across all samples)
   - **Location**: `{species}/results/summary/species_level/{species}_multiqc.overall.html`

- each individual sample
   - **Location**: `{species}/results/summary/individual_level/{individual}_multiqc.html`

The reports include a comprehensive summary of reads before and after trimming, contamination analysis, coverage analysis, deduplication and damage rescaling. The reports are essential for assessing the quality of the sequenced reads and for making decisions about the need of additional library preparation.

By leveraging the AI functionality in the MultiQC reports, you can also use AI to interpret the results of the pipeline.
