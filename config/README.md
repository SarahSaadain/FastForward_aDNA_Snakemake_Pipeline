# Setup Overview

## Requirements

* [Snakemake](https://snakemake.readthedocs.io) **>= 9.9.0** — pastForward checks this at startup and refuses to run on older versions.
* [Conda](https://docs.conda.io) **>= 24.7.1** (or a compatible drop-in such as Mamba/Miniforge) — used by `--use-conda` to manage all tool dependencies automatically.

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

### Project Structure

A pastForward **project** is a directory that contains the `workflow/` and `config/` folders (i.e. a copy/clone of this repository) plus one `<species>/` folder for each species you want to process:

```
my_project/                  <- project root — run `snakemake` from here
├── workflow/                <- pastForward pipeline code (Snakefile, rules, scripts)
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

There is currently no separation between the pipeline code and your input/output data — a project is a self-contained directory. To start a new project, copy (or `git clone`) pastForward into a new folder and add your species folders there.

One project can process 1–n species. Which layout to use depends on how you want to run them:

* **Combined** — several species in one project folder, sharing one `snakemake` invocation and one config. Convenient when you just want a quick look across many species at once, e.g. checking data quality for a low-depth trial-sequencing batch covering several species with a single command.
* **Separate** — one project folder per species. Each species can then be started, re-run, and configured independently without affecting the others. This is the better choice for deep-sequencing / production runs.

### Species Folders

The project contains folders for different species, which each contain the raw data, processed data, and results for the particular species.

The species folders should be placed in the project root, alongside `workflow/` and `config/` (see [Project Structure](#project-structure) above).

#### Providing Raw Data
The pipeline supports automatically moving the raw reads to the `<species>/input/read_module/` folder as well as the reference to the `<species>/input/reference_module/` folder. Simply provide the files in the `<species>` folder. Alternatively, you can manually move the files to the respective folders.
  - provide the raw reads in `<species>/input/read_module/` folder
  - provide the reference in `<species>/input/reference_module/` folder

If you don't want to move or copy the original files (e.g. they are large, shared with other tools, or live on a different volume), place a **symlink** in the expected location instead — pastForward detects symlinks and uses them directly without copying. The symlink itself must follow pastForward's naming convention, but the file it points to can keep its own name and live anywhere on disk.

When adding a new species, make sure to 
- the species folder should be placed in the project root, alongside `workflow/` and `config/`
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
<Individual>_[<FreeText>_]<ReadNumber>[_<FreeText>].fastq.gz
<Individual>_[<FreeText>_]<ReadNumber>[_<FreeText>].fq.gz
```

Following this convention ensures proper organization and automated processing within the pipeline.  

##### Filename Components:
- **`<Individual>`** – A unique identifier for the sample or individual.  
- **`<FreeText>`** – Any additional text or identifier that can be included in the filename. Typically, this is used to differentiate between different samples within the same individual, e.g. the same sample was extracted twice using different protocols.
- **`<ReadNumber>`** – Indicates the read pair number: either `R1`/`R2`, or a bare `1`/`2`. Typically read 1 for the first read and read 2 for the second read. If the data is single-end, only read 1 should be present. A bare `1`/`2` must stand alone as its own segment, either immediately before the extension (`..._1.fastq.gz`) or between underscores (`..._1_<FreeText>.fastq.gz`) — it will not match inside a longer number such as `_10_` or `_21`.
- **`.fastq.gz` / `.fq.gz`** – The expected file extensions, indicating compressed FASTQ format. Only these two compressed extensions are supported; uncompressed `.fastq`/`.fq` files are ignored.

#### Examples:
```
Dmel01_DabneyProtocol_R1_001.fastq.gz
Dmel01_DabneyProtocol_1_001.fastq.gz
Dmel01_DabneyProtocol_R1_001.fq.gz
```

# Configuration (`config.yaml`)

The `config.yaml` file is used to configure the aDNA pipeline. It contains settings such as project name, the species list and the pipeline stages and their process steps.

All pipeline stages are enabled by default, so a minimal config containing only the project name and species list is sufficient to run the pipeline without any further changes:

```yaml
project_name: "pastForward_Project"

species:
  Dmel:
    name: "Drosophila melanogaster"
```

* To adjust any pipeline settings, open [config_designer.html](config_designer.html) in a browser. The interactive Config Designer guides you through all available options and exports a ready-to-use `config.yaml`.
* For the full list of settings, their defaults, and descriptions, see [parameters.md](parameters.md).
* For a fully-commented example config using every available setting, see [max_config_sample.yaml](max_config_sample.yaml).
