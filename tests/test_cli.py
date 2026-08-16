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
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from datetime import datetime

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

    def test_configfile_from_cmd(self):
        self.assertEqual(
            cli._configfile_from_cmd(["snakemake", "--configfile", "other.yaml"]), "other.yaml"
        )
        self.assertEqual(cli._configfile_from_cmd(["snakemake", "--cores", "4"]), cli.DEFAULT_CONFIGFILE)

    def test_read_project_name(self):
        with tempfile.TemporaryDirectory() as d:
            cfg = os.path.join(d, "config.yaml")
            with open(cfg, "w") as f:
                f.write('project_name: "Demo Project"\n')
            self.assertEqual(cli._read_project_name(cfg), "Demo Project")
            self.assertIsNone(cli._read_project_name(os.path.join(d, "missing.yaml")))

    def test_progress_bar(self):
        bar = cli._progress_bar(50.0, width=10)
        self.assertIn("50.0%", bar)
        self.assertIn("#####", bar)
        full = cli._progress_bar(100.0, width=10)
        self.assertIn("100.0%", full)


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

    def test_resume_without_cores_exits_before_spawning_anything(self):
        with self.assertRaises(SystemExit):
            cli.cmd_resume(["--forceall"])
        self.assertFalse(cli.STATE_FILE.exists())

    def test_resume_adds_rerun_incomplete(self):
        # cmd_resume only differs from cmd_run by this flag - confirm it lands in the built
        # command rather than actually spawning snakemake.
        captured = {}
        orig = cli._run_background
        cli._run_background = lambda cmd, log_path: captured.setdefault("cmd", cmd)
        try:
            cli.cmd_resume(["--cores", "4"])
        finally:
            cli._run_background = orig
        self.assertIn("--rerun-incomplete", captured["cmd"])

    def test_run_refuses_when_a_tracked_run_is_still_alive(self):
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        cli.STATE_FILE.write_text(json.dumps({"pid": os.getpid()}))
        with self.assertRaises(SystemExit):
            cli.cmd_run(["--cores", "4"])

    def test_unlock_rejects_arguments(self):
        with self.assertRaises(SystemExit):
            cli.cmd_unlock(["--foo"])

    def test_unlock_passes_cores_one(self):
        # snakemake >= 9.9 requires --cores even for --unlock.
        captured = {}
        orig = cli.subprocess.call
        cli.subprocess.call = lambda cmd: captured.setdefault("cmd", cmd) or 0
        try:
            with self.assertRaises(SystemExit):
                cli.cmd_unlock([])
        finally:
            cli.subprocess.call = orig
        self.assertEqual(captured["cmd"], ["snakemake", "--unlock", "--cores", "1"])

    def test_check_rejects_arguments(self):
        # check/preview always run a plain `snakemake --dryrun` - passing a target/rule name
        # through would build a different DAG and silently drop the output they parse for.
        with self.assertRaises(SystemExit):
            cli.cmd_check(["--configfile", "other.yaml"])

    def test_preview_rejects_arguments(self):
        with self.assertRaises(SystemExit):
            cli.cmd_preview(["some_target"])

    def test_status_rejects_unknown_arguments(self):
        # --live/--tail moved to `print-log` - status must reject them, not silently ignore.
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        cli.STATE_FILE.write_text(
            json.dumps(
                {
                    "pid": os.getpid(),
                    "cmd": ["snakemake", "--cores", "4"],
                    "log_file": str(cli.LOG_DIR / "run_missing.log"),
                    "started_at": datetime.now().isoformat(timespec="seconds"),
                }
            )
        )
        with self.assertRaises(SystemExit):
            cli.cmd_status(["--live"])

    def test_status_headline_shows_project_and_config(self):
        with open(os.path.join("config", "config.yaml"), "w") as f:
            f.write('project_name: "Demo Project"\n')
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        cli.STATE_FILE.write_text(
            json.dumps(
                {
                    "pid": os.getpid(),
                    "cmd": ["snakemake", "--cores", "4"],
                    "log_file": str(cli.LOG_DIR / "run_missing.log"),
                    "started_at": datetime.now().isoformat(timespec="seconds"),
                }
            )
        )
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_status([])
        output = out.getvalue()
        self.assertIn("Demo Project", output)
        self.assertIn("config/config.yaml", output)

    def test_status_shows_progress_bar(self):
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        os.makedirs(cli.LOG_DIR)
        log_path = cli.LOG_DIR / "run_progress.log"
        log_path.write_text("5 of 10 steps (50.0%) done\n")
        cli.STATE_FILE.write_text(
            json.dumps(
                {
                    "pid": os.getpid(),
                    "cmd": ["snakemake", "--cores", "4"],
                    "log_file": str(log_path),
                    "started_at": datetime.now().isoformat(timespec="seconds"),
                }
            )
        )
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_status([])
        output = out.getvalue()
        self.assertIn("50.0%", output)
        self.assertIn("[", output)

    def test_status_last_finished_and_running_labels_say_jobs(self):
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        os.makedirs(cli.LOG_DIR)
        log_path = cli.LOG_DIR / "run_jobs.log"
        log_path.write_text("")
        cli.STATE_FILE.write_text(
            json.dumps(
                {
                    "pid": os.getpid(),
                    "cmd": ["snakemake", "--cores", "4"],
                    "log_file": str(log_path),
                    "started_at": datetime.now().isoformat(timespec="seconds"),
                }
            )
        )
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_status([])
        output = out.getvalue()
        self.assertIn("Last finished jobs", output)
        self.assertIn("Currently running jobs", output)

    def test_watch_passes_tail_lines_to_print_status(self):
        # Stub both the terminal clear and _print_status: exercise cmd_status's watch wiring
        # without actually clearing the real terminal or looping forever.
        calls = []

        def fake_print_status(tail=None):
            calls.append(tail)
            return False  # not alive -> loop exits after one iteration

        orig_print_status = cli._print_status
        orig_system = cli.os.system
        cli._print_status = fake_print_status
        cli.os.system = lambda *_: None
        try:
            cli.cmd_status(["--watch"])
        finally:
            cli._print_status = orig_print_status
            cli.os.system = orig_system
        self.assertEqual(calls, [cli.WATCH_TAIL_LINES])

    def test_print_log_tail_shows_only_last_n_lines(self):
        os.makedirs(cli.LOG_DIR)
        log = cli.LOG_DIR / "run_tail.log"
        log.write_text("\n".join(f"line{i}" for i in range(30)) + "\n")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_print_log(["--tail", "3"])
        output = out.getvalue()
        self.assertIn("line29", output)
        self.assertNotIn("line26", output)

    def test_print_log_tail_without_number_defaults(self):
        os.makedirs(cli.LOG_DIR)
        log = cli.LOG_DIR / "run_tail_default.log"
        log.write_text("\n".join(f"l{i}" for i in range(30)) + "\n")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_print_log(["--tail"])
        output = out.getvalue()
        self.assertIn("l29", output)
        self.assertNotIn("l9\n", output)

    def test_print_log_live_uses_tail_dash_f(self):
        os.makedirs(cli.LOG_DIR)
        log = cli.LOG_DIR / "run_live.log"
        log.write_text("hello\n")
        captured = {}
        orig = cli.subprocess.run
        cli.subprocess.run = lambda cmd, **kw: captured.setdefault("cmd", cmd)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                cli.cmd_print_log(["--live"])
        finally:
            cli.subprocess.run = orig
        self.assertIn("-f", captured["cmd"])
        self.assertIn(str(log), captured["cmd"])

    def test_status_flags_force_kill_when_dead_without_failure_or_completion(self):
        # Process not running, log has partial progress and no "did not complete successfully"
        # marker (Snakemake never got to log a reason) - most likely a force-kill.
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        log_path = cli.LOG_DIR / "run_forcekilled.log"
        os.makedirs(cli.LOG_DIR)
        log_path.write_text("31 of 210 steps (15%) done\n")
        cli.STATE_FILE.write_text(
            json.dumps(
                {
                    "pid": 999999,
                    "cmd": ["snakemake", "--cores", "4"],
                    "log_file": str(log_path),
                    "started_at": datetime.now().isoformat(timespec="seconds"),
                }
            )
        )
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_status([])
        self.assertIn("Interrupted", out.getvalue())

    def test_status_flags_lock_exception(self):
        # Process not running, log has a LockException (stale lock from a killed run or
        # power loss) - must be reported as "Locked", not misread as a force-kill.
        cli.STATE_DIR.mkdir(parents=True, exist_ok=True)
        log_path = cli.LOG_DIR / "run_locked.log"
        os.makedirs(cli.LOG_DIR)
        log_path.write_text(
            "[2026-08-16 12:49:14 (CEST)] [ERROR] LockException:\n"
            "Error: Directory cannot be locked. Please make sure that no other Snakemake "
            "process is trying to create the same files in the following directory:\n"
            "/mnt/data5/sarah/snakemake_demo_pipelines/demo_adna_pipeline\n"
        )
        cli.STATE_FILE.write_text(
            json.dumps(
                {
                    "pid": 999999,
                    "cmd": ["snakemake", "--cores", "4"],
                    "log_file": str(log_path),
                    "started_at": datetime.now().isoformat(timespec="seconds"),
                }
            )
        )
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_status([])
        output = out.getvalue()
        self.assertIn("Locked", output)
        self.assertIn("pastForward unlock", output)
        self.assertNotIn("Interrupted", output)

    def test_print_log_rejects_arguments(self):
        with self.assertRaises(SystemExit):
            cli.cmd_print_log(["--foo"])

    def test_print_log_dies_without_logs_dir(self):
        with self.assertRaises(SystemExit):
            cli.cmd_print_log([])

    def test_print_log_prints_most_recently_modified_file(self):
        os.makedirs(cli.LOG_DIR)
        old = cli.LOG_DIR / "dryrun_20260101_000000.log"
        new = cli.LOG_DIR / "run_20260101_000001.log"
        old.write_text("old log\n")
        new.write_text("new log\n")
        os.utime(old, (1, 1))
        os.utime(new, (2, 2))
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.cmd_print_log([])
        self.assertIn("new log", out.getvalue())
        self.assertNotIn("old log", out.getvalue())


class ParseLastStepsTestCase(unittest.TestCase):
    # One finished job (id 3, a plain rule with no `message:`) and one still-running job
    # (id 7, a wrapper rule with a `message:` directive - so it has no "rule X:"/"jobid:"
    # block at all, only the "Rule: X, Jobid: N" line that initialize.smk's root
    # logging.basicConfig duplicates for every job regardless of `message:`).
    LOG = """\
[2026-08-16 10:00:00 (CEST)] [INFO] Building DAG of jobs...
[2026-08-16 10:00:00 (CEST)] [INFO]  Rule: fastqc, Jobid: 3
rule fastqc:
    input: reads.fastq.gz
    output: reads_fastqc.html
    jobid: 3
    reason: Missing output files

[2026-08-16 10:00:05 (CEST)] [INFO] Finished jobid: 3 (Rule: fastqc)
[2026-08-16 10:00:05 (CEST)]
Finished jobid: 3 (Rule: fastqc)
3 of 10 steps (30%) done
[2026-08-16 10:00:06 (CEST)] [INFO]  Rule: map_reads_to_reference_bwa_mem2, Jobid: 7
[2026-08-16 10:00:06 (CEST)]
Job 7: Mapping reads.fastq.gz to ref.fasta with BWA-MEM2
Reason: Missing output files
"""

    def test_progress_takes_last_match(self):
        m = None
        for m in cli.PROGRESS_RE.finditer(self.LOG):
            pass
        self.assertEqual(m.groups(), ("3", "10", "30"))

    def test_last_steps_status(self):
        finished, running = cli._parse_last_steps(self.LOG)
        self.assertEqual(finished, [("fastqc", "3")])
        self.assertEqual(running, [("map_reads_to_reference_bwa_mem2", "7")])

    def test_last_steps_caps_at_n(self):
        many = "\n".join(
            f"[2026-08-16 10:00:00 (CEST)] [INFO]  Rule: r{i}, Jobid: {i}\n"
            f"[2026-08-16 10:00:01 (CEST)] [INFO] Finished jobid: {i} (Rule: r{i})"
            for i in range(8)
        )
        finished, running = cli._parse_last_steps(many, n=5)
        self.assertEqual(len(finished), 5)
        self.assertEqual(running, [])


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
