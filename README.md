<p align="center"><img src="docs/img/pastforward_logo_block.svg" width="250"/></p>

# pastForward - A pipeline for ancient and historical DNA based on Snakemake

[![Snakemake](https://img.shields.io/badge/snakemake-≥9.9.0-brightgreen.svg)](https://snakemake.github.io)
[![GitHub release](https://img.shields.io/github/v/release/SarahSaadain/aDNA_Pipeline_Snakemake)](https://github.com/SarahSaadain/aDNA_Pipeline_Snakemake/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

pastForward analyzes raw ancient and historical DNA from a sequencing facility. It checks read quality and screens for contamination, using checks suited to the short, damaged reads typical of ancient and historical DNA, so you can tell whether an extraction worked and the sample is free of major contamination. It then maps reads to a reference genome and corrects them for DNA damage, so they're ready for downstream analysis. Optionally, it can also compare key genomic features across time points, such as transposon insertions, gene copy number changes, or endosymbiont strain replacements.

It's built on [Snakemake](https://snakemake.github.io), a workflow tool that automatically installs the right software versions and only re-runs the steps that actually need it.

> **Note:** pastForward integrates two purpose-built tools for its core analyses: [REVEAL](https://github.com/SarahSaadain/REVEAL) for transposable element and genomic feature dynamics, and [ECMSD](https://github.com/capoony/ECMSD) for contamination screening against a curated mitochondrial database. See their READMEs for details on each tool.

## Workflow Overview

Below is an overview of the steps of the pipeline:

![Pipeline Overview](docs/img/pf_pipeline_process_withoutLogo.svg)

For detailed information about the processing steps, see the [Process Overview](docs/process_overview.md) page. For common questions and troubleshooting, see the [FAQ](docs/FAQ.md).

## Quick Start

New to pastForward? Here's the whole path, start to finish. Each step links to more detail if you need it.

1. **Install Conda and Snakemake, and download pastForward.** The [Setup Guide](config/README.md) walks through this step by step, even if you've never used a terminal before.
2. **Add your species and sequencing data.** Also covered in the [Setup Guide](config/README.md#step-4-add-your-species-and-data), including exactly how your read files need to be named.
3. **Create a `config.yaml` file.** Every pipeline stage is turned on by default, so a minimal config just needs a project name and species list. If you'd rather not edit a text file by hand, open [config/config_designer.html](config/config_designer.html) in your browser and fill in a form instead.
4. **Run the pipeline.** See [Running the Pipeline](#running-the-pipeline) below for the exact command.

For more information on Snakemake itself, see the [Snakemake website](https://snakemake.github.io).

## Running the Pipeline

Run `snakemake` from your **project folder**, the folder that directly contains `workflow/`, `config/`, and your `<species>/` folders. This is *not* the `workflow/` folder itself. See [Project Structure](config/README.md#project-structure) for what that folder should look like.

```bash
# minimum command to run the pipeline
#snakemake --cores <number_of_threads> --use-conda

# suggested command to run the pipeline
snakemake --cores <number_of_threads> --use-conda --keep-going --rerun-trigger mtime
```

Replace `<number_of_threads>` with the number of CPU threads you want to give the pipeline.

**What the suggested flags do:**

* `--use-conda` lets Snakemake install and use the software each step needs automatically.
* `--keep-going` lets the pipeline carry on if one step fails, instead of stopping everything. This matters because the contamination-screening tool ECMSD sometimes fails on individual samples with low-quality or low-coverage data. With this flag, the rest of the pipeline still runs.
* `--rerun-trigger mtime` re-runs a step only when its input files have changed since the last run, instead of pastForward's more thorough (and slower) default checks.

**A few other flags you might want:**

* `--dryrun` (or `-n`): show what the pipeline *would* do, without actually running anything.
* `--configfile <path_to_config.yaml>`: use a config file other than the default.
* `--rerun-incomplete`: pick back up rules that failed or were cancelled in a previous run.
* `--rerun-trigger <code|input|mtime|params|software-env>`: choose what counts as "changed" when deciding whether to re-run a step. By default, all of these are checked, which is the safest option. `mtime` (used above) checks only file modification times, which is faster but less thorough.
* `--touch`: mark output files as up to date without actually running the commands that create them. Use this only as a last resort (for example, to convince pastForward that files created another way don't need to be regenerated), since it throws away the record of how those files were really made. Combine with `--force`, `--forceall`, or `--forcerun` to make it apply.

For the full list of Snakemake's command-line options, see the [Snakemake documentation](https://snakemake.readthedocs.io/en/stable/executing/cli.html).

### Running the Pipeline in the Background

Large datasets can take a while to process, so it's often best to run pastForward in the background. That way it keeps running even if you close your terminal window:

```bash
nohup snakemake --cores 40 --use-conda --keep-going --rerun-trigger mtime > pipeline.log 2>&1 &
```

This starts the pipeline, sends all its output to a file called `pipeline.log`, and immediately gives you your terminal back. Check progress any time with `tail -f pipeline.log`.

### Restarting the Pipeline

Snakemake keeps track of what's already been done and only re-runs steps that are missing or out of date. To start completely over, delete the relevant output files and run the pipeline again.

If the pipeline crashed or was stopped partway through, add `--rerun-incomplete` when you restart it. This re-runs any step that was left unfinished, even if its files look unchanged since the last run.

### Running on an HPC Cluster

pastForward is a standard Snakemake workflow, so it should work with Snakemake's [cluster/HPC execution support](https://snakemake.readthedocs.io/en/stable/executing/cluster.html) (for example, Slurm or PBS) via the matching [executor plugin](https://snakemake.github.io/snakemake-plugin-catalog/), with no changes to the pipeline itself. This hasn't been specifically tested yet on a Slurm-based cluster, though that's planned. If you try it, feedback is very welcome.

## Reports

pastForward generates a MultiQC report for:

* **Each species** (all samples from that species together, so you can compare results across them)
  * Location: `{species}/results/summary/species_level/{species}_multiqc.overall.html`
* **Each individual sample**
  * Location: `{species}/results/summary/individual_level/{individual}_multiqc.html`

These reports summarize reads before and after trimming, contamination analysis, coverage, deduplication, and damage rescaling. Use them to judge the quality of your sequenced reads and decide whether a sample needs additional library preparation.

You can also feed a report into an AI assistant and ask it to help interpret the results, using the AI features built into MultiQC reports.
