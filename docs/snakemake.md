# Running with Snakemake

pastForward is a [Snakemake](https://snakemake.github.io) workflow. The [`pastForward` CLI](../README.md#running-the-pipeline) is a thin wrapper around `snakemake` that covers day-to-day use (backgrounding, progress checks, a clean stop) and is the recommended way to run the pipeline. This page is for calling `snakemake` directly instead: tuning its flags, running on an HPC cluster, and how it decides what to (re-)run.

Run these commands from your **project folder**, the folder that directly contains `workflow/`, `config/`, and your `<species>/` folders. See [Project Structure](../config/README.md#project-structure) for what that folder should look like.

## Calling `snakemake` Directly

```bash
# minimum command to run the pipeline
snakemake --cores <number_of_threads> --use-conda

# suggested command to run the pipeline
snakemake --cores <number_of_threads> --use-conda --keep-going --rerun-trigger mtime
```

Replace `<number_of_threads>` with the number of CPU threads you want to give the pipeline.

**What the suggested flags do:**

* `--use-conda` lets Snakemake install and use the software each step needs automatically.
* `--keep-going` lets the pipeline carry on if one step fails, instead of stopping everything. This matters because the taxonomic screening tool ECMSD sometimes fails on individual samples with low-quality or low-coverage data. With this flag, the rest of the pipeline still runs.
* `--rerun-trigger mtime` re-runs a step only when its input files have changed since the last run, instead of Snakemake's more thorough (and slower) default checks.

**A few other flags you might want:**

* `--dryrun` (or `-n`): show what the pipeline *would* do, without actually running anything. Use it to check if pastForward picks up all your data correctly (this is what `./pastForward dryrun` runs for you).
* `--configfile <path_to_config.yaml>`: use a config file other than the default.
* `--rerun-incomplete`: pick back up rules that failed or were cancelled in a previous run (this is what `./pastForward resume` runs for you).
* `--rerun-trigger <code|input|mtime|params|software-env>`: choose what counts as "changed" when deciding whether to re-run a step. By default, all of these are checked, which is the safest option. `mtime` (used above) checks only file modification times, which is faster but less thorough.
* `--unlock`: clear a stale Snakemake lock left by a crashed run (this is what `./pastForward unlock` runs for you).

For the full list of Snakemake's command-line options, see the [Snakemake documentation](https://snakemake.readthedocs.io/en/stable/executing/cli.html).

## Running in the Background

Large datasets can take a while to process, so it's often best to run pastForward in the background. That way it keeps running even if you close your terminal window. `./pastForward run` does this by default; the equivalent with plain `snakemake` is:

```bash
nohup snakemake --cores 40 --use-conda --keep-going --rerun-trigger mtime > pipeline.log 2>&1 &
```

This starts the pipeline and sends all its output to a file called `pipeline.log`. Check progress any time with `tail -f pipeline.log`.

## Restarting the Pipeline

Snakemake keeps track of what's already been done and only re-runs steps that are missing or out of date. To start completely over, delete the relevant `results` and `processed` folders and run the pipeline again.

If the pipeline crashed or was stopped partway through, add `--rerun-incomplete` when you restart it (or use `./pastForward resume`). This re-runs any step that was left unfinished, even if its files look unchanged since the last run.

If a stale Snakemake lock is left behind by a hard crash, clear it with `--unlock` (or `./pastForward unlock`) before re-running.

## Forcing a Re-run

To redo a specific step, delete its output file and re-run, or use `--forcerun <rule_name>` to force a specific rule. Use `--touch` with `--forceall` to mark all outputs as up to date without re-running (use as a last resort). Check the Snakemake documentation for more options on controlling rule execution.

## Running on an HPC Cluster

pastForward is a standard Snakemake workflow, so it should work with Snakemake's [cluster/HPC execution support](https://snakemake.readthedocs.io/en/stable/executing/cluster.html) (for example, Slurm or PBS) via the matching [executor plugin](https://snakemake.github.io/snakemake-plugin-catalog/), with no changes to the pipeline itself. This hasn't been specifically tested yet on a Slurm-based cluster, though that's planned. If you try it, feedback is very welcome.
