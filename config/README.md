# Setup Guide

This guide walks through everything you need to set up and configure pastForward. It assumes no prior experience with the command line or bioinformatics tools.

## What You'll Need

pastForward runs on two free tools:

* **Conda** installs and manages all the other software the pipeline needs. You don't install anything else by hand.
* **Snakemake** runs the pipeline itself. Version **9.9.0** or newer is required. pastForward checks this automatically at startup and stops with a clear message if your version is too old.

You'll also need a **terminal** (also called a "command line" or "shell"). This is a text window where you type commands instead of clicking buttons. Every computer has one:

* **macOS**: open the "Terminal" app. You can find it by pressing Cmd+Space and typing "Terminal".
* **Windows**: after installing conda (Step 1 below), use the "Anaconda Prompt" that comes with it.
* **Linux**: open your distribution's terminal app.

## Step 1: Install Conda

If you don't already have conda, download and install [Miniforge](https://github.com/conda-forge/miniforge). It's a small, free installer for conda. Follow the instructions on that page for your operating system.

## Step 2: Install Snakemake

Open a terminal and type each of these lines, pressing Enter after each one:

```bash
conda create -c conda-forge -c bioconda -c nodefaults -n snakemake snakemake
conda activate snakemake
snakemake --help
```

What each line does:

1. Creates a separate, self-contained space called `snakemake` and installs Snakemake into it. You only need to do this once.
2. Switches your terminal into that space. Run this line every time you open a new terminal window, before using pastForward.
3. Checks that the install worked. You should see a page of help text print out.

For more installation options, see the [Snakemake documentation](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html).

## Step 3: Get pastForward

Download or `git clone` this repository into a folder on your computer. That folder becomes your **project folder**. Your pipeline code, your data, and your results will all live inside it. See [Project Structure](#project-structure) below for what this folder should contain.

## Step 4: Add Your Species and Data

### Project Structure

A pastForward **project** is a single folder containing the `workflow/` and `config/` folders (the pipeline code you just downloaded) plus one folder per species you want to process:

```text
my_project/                  <- project folder — run `snakemake` from here
├── workflow/                <- pastForward pipeline code (do not edit)
├── config/                  <- config.yaml, config_designer.html
├── Dmel/                    <- one folder per species; name must match the `species:` key in config.yaml
│   ├── input/
│   ├── processed/
│   └── results/
└── Dsim/
    ├── input/
    ├── processed/
    └── results/
```

The pipeline code and your data live side by side in this one folder. There's no separate install location. To start a new project, copy (or `git clone`) pastForward into a new folder and add your species folders next to `workflow/` and `config/`.

One project can handle one species or many. Which you choose depends on how you want to work:

* **Combine several species in one project folder** if you just want a quick look across many species at once, sharing a single command and config. For example, checking data quality across a batch from a low-depth trial run.
* **Give each species its own project folder** if you want to start, re-run, and configure each one independently without affecting the others. This is the better choice for a full production run.

### Add a Species

To add a new species:

1. Create a folder for it in the project root (next to `workflow/` and `config/`). The folder name must exactly match the species key you'll use under `species:` in `config.yaml` (see [Configuration](#configuration-configyaml) below).
2. Put your raw read files and reference genome inside that folder (see below).

#### Providing Your Data

The simplest option: drop your raw read files and reference genome anywhere inside the `<species>` folder. The first time you run pastForward, it automatically finds them there. This shortcut only works for reads and the reference genome — REVEAL input files (feature library, and optionally SCG) must go in their specific folders below, not just anywhere in `<species>`.

Put your files here:

* raw reads in `<species>/input/read_module/`
* the reference genome in `<species>/input/reference_module/`
* (optional) a feature library — a FASTA of TE or other genomic feature sequences to compare across samples — in `<species>/input/reveal_module/feature_library/`, needed only if you're using the REVEAL comparison stage
* (optional) a pre-built SCG (single-copy gene) FASTA in `<species>/input/reveal_module/scg/`. If you skip this, pastForward determines SCGs automatically via BUSCO, as long as `pipeline.reveal_module.scg_selector.execute` is `true` (the default) and `species.<key>.lineage` is set to a BUSCO lineage name (e.g. `drosophilidae_odb12`, see [busco.ezlab.org](https://busco.ezlab.org/)). No lineage configured and no FASTA provided means SCG determination is skipped.

If your files are large, shared with other tools, or already live somewhere else on disk, you don't need to copy them. Place a **symlink** (a shortcut/pointer file) in the expected location instead, and pastForward will use it directly. The symlink's name must follow pastForward's naming convention (below), but the real file it points to can keep its own name and live anywhere.

#### Storing Species Data Elsewhere

> This is an optional, advanced feature. Skip this section if your data lives inside the project folder as shown above. That's the default, and most people don't need to change it.

If you'd rather keep some or all of a species' data elsewhere (a different disk, a shared network drive, or a folder outside the project entirely), set one or more of the following optional settings under `species.<key>` in `config.yaml`. If you don't set any of these, nothing changes from the default behavior described above.

| Setting | Overrides |
|---|---|
| `species_dir` | The whole species root. Must contain the same `input/{read_module,reference_module,reveal_module/{scg,feature_library,competition}}`, `processed/`, `results/` layout as a normal species folder. Used as the default target for every setting below. |
| `reads_dir` | `<species>/input/read_module/` |
| `reference_dir` | `<species>/input/reference_module/` |
| `scg_dir` | `<species>/input/reveal_module/scg/` |
| `feature_library_dir` | `<species>/input/reveal_module/feature_library/` |
| `competition_dir` | `<species>/input/reveal_module/competition/` |
| `processed_dir` | `<species>/processed/` |
| `results_dir` | `<species>/results/` |

If you set both `species_dir` and one of the more specific settings, the specific setting wins.

```yaml
species:
  Dmel:
    name: "Drosophila melanogaster"
    # Everything for Dmel lives on a different disk...
    species_dir: "/mnt/big_disk/pastforward_data/Dmel"
    # ...except processed/, which should go to fast local scratch instead.
    processed_dir: "/scratch/pastforward_processed/Dmel"
```

At startup, pastForward creates a shortcut (symlink) at the usual in-project location (e.g. `Dmel/input/read_module`) pointing at your configured target, so every part of the pipeline keeps working normally. A few things to know:

* This happens automatically, once per run, before pastForward looks for any input files.
* It's safe to run more than once. Nothing bad happens if you run pastForward again with the same config.
* If something already exists at the usual location (a real folder, or a shortcut to somewhere else), pastForward will stop and show an error instead of overwriting it. Fix the config, or move/remove the conflicting folder, then try again.
* `processed_dir` and `results_dir` are additionally protected against two different projects accidentally writing to the same place at the same time. See [FAQ.md](../docs/FAQ.md) if you run into a lock error.

#### What Gets Created Automatically

You don't need to create any folders beyond your species folder. Everything else is created for you as the pipeline runs:

* `<species>/processed/` holds files created while the pipeline is working. Most are deleted automatically once they're no longer needed. Some are kept so the pipeline can pick up from a failed step without starting over.
* `<species>/results/` holds your final results and reports. This is what you'll actually look at.

Everything related to one reference genome is grouped under a `<reference>` folder inside `processed/` or `results/`. For most purposes, only `results/` matters. If you need more detail, the `processed/` folder usually has it. A couple of large intermediate file types (`.sam` and unsorted `.bam` files) are always deleted to save disk space. If you ever need to redo a step, just delete its output files and re-run pastForward.

#### Naming Your Read Files

pastForward needs your raw read filenames to follow one consistent pattern, so it can tell which files belong to which sample and which read pair they are. A few correct examples:

```text
Dmel01_DabneyProtocol_R1_001.fastq.gz
Dmel01_DabneyProtocol_1_001.fastq.gz
Dmel01_DabneyProtocol_R1_001.fq.gz
```

The pattern, piece by piece:

```text
<Individual>_[<FreeText>_]<ReadNumber>[_<FreeText>].fastq.gz
```

* **`<Individual>`** is a unique ID for the sample, e.g. `Dmel01`. It's everything before the first underscore, and pastForward uses it to group files that belong together.
* **`<FreeText>`** (optional, can appear before or after the read number) is any extra label you want, e.g. a protocol name. Useful when the same individual was extracted twice with different methods.
* **`<ReadNumber>`** marks which read of the pair this file is: `R1`/`R2`, or a plain `1`/`2`. Use read 1 only for single-end data. A plain `1` or `2` must stand on its own between underscores or right before the file extension. It won't be picked up inside a longer number like `_10_` or `_21`.
* The file must end in **`.fastq.gz`** or **`.fq.gz`** (compressed FASTQ). Uncompressed `.fastq`/`.fq` files are not supported.

## Configuration (`config.yaml`)

`config.yaml` tells pastForward which species to process and which pipeline options to use.

**If you're not comfortable editing text files by hand**, open [config_designer.html](config_designer.html) in your web browser. This interactive tool walks you through every option with a graphical interface and generates a ready-to-use `config.yaml` for you. No code required.

If you'd rather write it yourself, every pipeline stage is turned on by default, so a minimal config only needs a project name and species list:

```yaml
project_name: "pastForward_Project"

species:
  Dmel:
    name: "Drosophila melanogaster"
```

* For the full list of settings, their defaults, and what they do, see [parameters.md](parameters.md).
* For a fully-commented example using every available setting, see [max_config_sample.yaml](max_config_sample.yaml).

Once your data is in place and your config is ready, head back to the main [README](../README.md#running-the-pipeline) to start the pipeline.
