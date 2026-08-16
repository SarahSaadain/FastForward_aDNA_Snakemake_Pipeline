#!/usr/bin/env python3
"""
Unit tests for workflow/scripts/cli.py (the `pastForward` CLI's command building and log
parsing). Pure Python, no Snakemake/conda required. Run with either:
    python3 tests/test_cli.py
    python3 -m unittest tests.test_cli -v          (from the repo root)

Regex fixtures below mirror the real formats confirmed against snakemake 9.25.1's
snakemake/logging.py (_format_job_info, format_job_finished) and
snakemake/scheduling/job_scheduler.py ("Finished jobid: ..."), plus a real --dryrun run of
this repo's own initialize.smk/check.py/expected_output_manager.py.
"""
import os
import shutil
import sys
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "workflow"))

import scripts.cli as cli  # noqa: E402


class BuildCmdTestCase(unittest.TestCase):
    def test_run_cmd_adds_defaults(self):
        cmd = cli._build_run_cmd(["--cores", "8"])
        self.assertEqual(
            cmd,
            ["snakemake", "--use-conda", "--keep-going", "--rerun-trigger", "mtime", "--cores", "8"],
        )

    def test_run_cmd_does_not_duplicate_user_supplied_flags(self):
        cmd = cli._build_run_cmd(["--use-conda", "--cores", "4", "--forceall", "count_reads_raw"])
        self.assertEqual(cmd.count("--use-conda"), 1)
        self.assertEqual(cmd.count("--cores"), 1)
        self.assertIn("--forceall", cmd)
        self.assertIn("count_reads_raw", cmd)

    def test_dryrun_cmd_defaults_cores(self):
        cmd = cli._build_dryrun_cmd([])
        self.assertEqual(cmd, ["snakemake", "--dryrun", "--cores", "1"])

    def test_dryrun_cmd_respects_user_cores(self):
        cmd = cli._build_dryrun_cmd(["-j", "8"])
        self.assertEqual(cmd, ["snakemake", "--dryrun", "-j", "8"])


class StatusHelpersTestCase(unittest.TestCase):
    def test_format_duration(self):
        self.assertEqual(cli._format_duration(5), "5s")
        self.assertEqual(cli._format_duration(65), "1m 5s")
        self.assertEqual(cli._format_duration(3661), "1h 1m 1s")
        self.assertEqual(cli._format_duration(90000), "1d 1h 0m 0s")

    def test_cores_from_cmd(self):
        self.assertEqual(cli._cores_from_cmd(["snakemake", "--use-conda", "--cores", "8", "--forceall"]), "8")
        self.assertEqual(cli._cores_from_cmd(["snakemake", "-j", "all"]), "all")
        self.assertIsNone(cli._cores_from_cmd(["snakemake"]))


class ArgvValidationTestCase(unittest.TestCase):
    """Argument checks that must fail fast, before any subprocess is spawned: `run` (unlike
    `dryrun`) never guesses a thread count, and `check`/`preview` never take snakemake
    arguments at all - see README's "Using the pastForward CLI" section."""

    def setUp(self):
        self._orig_cwd = os.getcwd()
        self.project_dir = tempfile.mkdtemp(prefix="pf_test_cli_project_")
        os.makedirs(os.path.join(self.project_dir, "workflow"))
        os.makedirs(os.path.join(self.project_dir, "config"))
        os.chdir(self.project_dir)

    def tearDown(self):
        os.chdir(self._orig_cwd)
        shutil.rmtree(self.project_dir, ignore_errors=True)

    def test_run_without_cores_exits_before_spawning_anything(self):
        with self.assertRaises(SystemExit):
            cli.cmd_run(["--forceall"])
        self.assertFalse(cli.STATE_FILE.exists())

    def test_check_rejects_arguments(self):
        # check/preview always run a plain `snakemake --dryrun` - passing a target/rule name
        # through would build a different DAG and silently drop the output they parse for.
        with self.assertRaises(SystemExit):
            cli.cmd_check(["--configfile", "other.yaml"])

    def test_preview_rejects_arguments(self):
        with self.assertRaises(SystemExit):
            cli.cmd_preview(["some_target"])


class ParseLastStepsTestCase(unittest.TestCase):
    # One finished job (id 3) and one still-running job (id 7), in start order.
    LOG = """\
[2026-08-16 10:00:00 (CEST)] [INFO] Building DAG of jobs...
rule fastqc:
    input: reads.fastq.gz
    output: reads_fastqc.html
    jobid: 3
    reason: Missing output files

[2026-08-16 10:00:05 (CEST)]
Finished jobid: 3 (Rule: fastqc)
3 of 10 steps (30%) done
localrule map_reads_to_reference_bwa_mem2:
    input: reads.fastq.gz, ref.fasta
    output: mapped.bam
    jobid: 7
    reason: Missing output files
"""

    def test_progress_takes_last_match(self):
        m = None
        for m in cli.PROGRESS_RE.finditer(self.LOG):
            pass
        self.assertEqual(m.groups(), ("3", "10", "30"))

    def test_last_steps_status(self):
        steps = cli._parse_last_steps(self.LOG)
        self.assertEqual(steps, [("fastqc", "done"), ("map_reads_to_reference_bwa_mem2", "running")])

    def test_last_steps_caps_at_n(self):
        many = "\n".join(f"rule r{i}:\n    jobid: {i}\n" for i in range(8))
        self.assertEqual(len(cli._parse_last_steps(many, n=5)), 5)


class CheckPreviewParsingTestCase(unittest.TestCase):
    # Trimmed real output from `snakemake --dryrun` against a throwaway fixture project.
    LOG = """\
[2026-08-16 09:53:15 (CEST)] [INFO] Loaded configuration:
{}

[2026-08-16 09:53:15 (CEST)] [INFO] Detected species (1):
- TestSpecies [TestSpecies]
    References (1):
      - genome: TestSpecies/input/reference_module/genome.fasta
    SCG Libraries: (none provided; skipping auto-determination)
Workflow defines that rule index_reference_for_mapping_bwa_mem2 is eligible for caching.
[2026-08-16 09:53:17 (CEST)] [WARNING] Workflow defines that rule index_reference_for_mapping_bwa_mem2 is eligible for caching.
[2026-08-16 09:53:17 (CEST)] [INFO] Skipping species 'OtherSpecies' (execute: false)
[2026-08-16 09:53:17 (CEST)] [INFO] The following files already exist and will be skipped:
[2026-08-16 09:53:17 (CEST)] [INFO] \t- Skipping: TestSpecies/results/read_module/reads_merged/IND001.fastq.gz
[2026-08-16 09:53:17 (CEST)] [INFO] Determined input for the 'all' rule:
[2026-08-16 09:53:17 (CEST)] [INFO] \t- Requesting: TestSpecies/results/summary/species_level/TestSpecies_multiqc.overall.html
[2026-08-16 09:53:17 (CEST)] [INFO] \t- Requesting: TestSpecies/results/summary/individual_level/IND001_multiqc.html
"""

    def test_check_block_stops_before_unrelated_warning(self):
        m = cli.DETECTED_SPECIES_RE.search(self.LOG)
        lines = self.LOG[m.start() :].splitlines()
        block = [lines[0]]
        for line in lines[1:]:
            if line == "" or line.startswith("-") or line[:1].isspace():
                block.append(line)
            else:
                break
        block_text = "\n".join(block)
        self.assertIn("SCG Libraries", block_text)
        self.assertNotIn("Workflow defines", block_text)

    def test_preview_extracts_requested_skipped_and_disabled_species(self):
        import re

        skipped_species = re.findall(r"Skipping species '(.+?)' \(execute: false\)", self.LOG)
        existing = re.findall(r"- Skipping: (.+)", self.LOG)
        requested = re.findall(r"- Requesting: (.+)", self.LOG)
        self.assertEqual(skipped_species, ["OtherSpecies"])
        self.assertEqual(existing, ["TestSpecies/results/read_module/reads_merged/IND001.fastq.gz"])
        self.assertEqual(len(requested), 2)


if __name__ == "__main__":
    unittest.main()
