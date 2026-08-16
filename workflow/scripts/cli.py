#!/usr/bin/env python3
"""
pastForward CLI — thin wrapper around the `snakemake` command.

Standalone: no Snakemake/conda import needed, just stdlib. Shells out to `snakemake`
and, for `check`/`preview`, parses the provenance logging that initialize.smk,
check.py and expected_output_manager.py already emit on every invocation (including
--dryrun) — see workflow/rules/initialize.smk, workflow/scripts/check.py and
workflow/scripts/expected_output_manager.py.

Entry point: bin/pastForward (repo root) — a tiny shim that imports main() from here.

Dispatch below is a hand-rolled `sys.argv` split rather than argparse subparsers: argparse's
REMAINDER positional (needed to pass arbitrary snakemake flags through untouched) errors out
on any "-"-looking token - like a genuine snakemake flag, e.g. --forceall - that appears
before the parser has committed to consuming positionals. Splitting on the command name
ourselves sidesteps that entirely.
"""
import json
import os
import re
import signal
import subprocess
import sys
from datetime import datetime
from pathlib import Path

STATE_DIR = Path(".pastforward")
LOG_DIR = Path("logs")
STATE_FILE = STATE_DIR / "run_state.json"

CORES_FLAGS = ("--cores", "-c", "-j", "--jobs")

# Matches CLAUDE.md's documented "real run" command.
DEFAULT_RUN_FLAGS = [("--use-conda", None), ("--keep-going", None), ("--rerun-trigger", "mtime")]

PROGRESS_RE = re.compile(r"(\d+) of (\d+) steps \(([\d.]+)%\) done")
JOB_START_RE = re.compile(r"^(?:local)?(?:rule|checkpoint) (\S+):$", re.MULTILINE)
JOBID_RE = re.compile(r"^\s*jobid:\s*(\d+)", re.MULTILINE)
JOB_FINISHED_RE = re.compile(r"Finished jobid:\s*(\d+)")
DETECTED_SPECIES_RE = re.compile(r"^\[.*?Detected species", re.MULTILINE)


RED, GREEN, YELLOW, CYAN, DIM = 31, 32, 33, 36, 90


def _color(code, text):
    if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
        return text
    return f"\033[{code}m{text}\033[0m"


def _die(msg):
    sys.exit(_color(RED, msg))


def _ensure_project_root():
    if not Path("workflow").is_dir() or not Path("config").is_dir():
        _die(
            "pastForward: this isn't a project root (needs workflow/ and config/ in the "
            "current directory). cd into your project folder first."
        )


def _timestamp():
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _build_run_cmd(extra_args):
    cmd = ["snakemake"]
    for flag, value in DEFAULT_RUN_FLAGS:
        if flag not in extra_args:
            cmd.append(flag)
            if value is not None:
                cmd.append(value)
    cmd += extra_args
    return cmd


def _build_dryrun_cmd(extra_args):
    cmd = ["snakemake", "--dryrun"]
    if not any(a in CORES_FLAGS for a in extra_args):
        cmd += ["--cores", "1"]
    cmd += extra_args
    return cmd


def _run_foreground(cmd, log_path):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print(_color(DIM, f"$ {' '.join(cmd)}"))
    print(_color(DIM, f"Logging to {log_path}"))
    with open(log_path, "w") as logf:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in proc.stdout:
            sys.stdout.write(line)
            logf.write(line)
        return proc.wait()


def _run_background(cmd, log_path):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    logf = open(log_path, "w")
    proc = subprocess.Popen(
        cmd, stdout=logf, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True
    )
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(
        json.dumps(
            {
                "pid": proc.pid,
                "cmd": cmd,
                "log_file": str(log_path.resolve()),
                "started_at": datetime.now().isoformat(timespec="seconds"),
            },
            indent=2,
        )
    )
    print(_color(GREEN, f"Started pastForward run (PID {proc.pid})"))
    print(_color(DIM, f"Log: {log_path}"))
    print(_color(DIM, "Check progress with: pastForward status"))


def cmd_run(argv):
    _ensure_project_root()
    # --fg/--foreground is pastForward's own flag, not snakemake's - pulled out here rather
    # than by argparse so it can sit anywhere among the passed-through snakemake args.
    extra = [a for a in argv if a not in ("--fg", "--foreground")]
    foreground = len(extra) != len(argv)
    if not any(a in CORES_FLAGS for a in extra):
        _die("pastForward run: pass --cores <N> (e.g. --cores 8, or --cores all).")
    cmd = _build_run_cmd(extra)
    log_path = LOG_DIR / f"run_{_timestamp()}.log"
    if foreground:
        sys.exit(_run_foreground(cmd, log_path))
    _run_background(cmd, log_path)


def cmd_dryrun(argv):
    _ensure_project_root()
    cmd = _build_dryrun_cmd(argv)
    log_path = LOG_DIR / f"dryrun_{_timestamp()}.log"
    sys.exit(_run_foreground(cmd, log_path))


def _read_state():
    if not STATE_FILE.exists():
        _die("pastForward: no tracked run in this directory (start one with `pastForward run`).")
    return json.loads(STATE_FILE.read_text())


def _is_alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _parse_last_steps(text, n=5):
    finished_ids = set(JOB_FINISHED_RE.findall(text))
    steps = []
    for m in JOB_START_RE.finditer(text):
        block = text[m.end() : m.end() + 400]
        jm = JOBID_RE.search(block)
        jobid = jm.group(1) if jm else None
        status = "done" if jobid in finished_ids else "running"
        steps.append((m.group(1), status))
    return steps[-n:]


def _format_duration(seconds):
    minutes, seconds = divmod(int(seconds), 60)
    hours, minutes = divmod(minutes, 60)
    days, hours = divmod(hours, 24)
    parts = [f"{days}d"] if days else []
    if days or hours:
        parts.append(f"{hours}h")
    if days or hours or minutes:
        parts.append(f"{minutes}m")
    parts.append(f"{seconds}s")
    return " ".join(parts)


def _cores_from_cmd(cmd):
    for i, a in enumerate(cmd):
        if a in CORES_FLAGS and i + 1 < len(cmd):
            return cmd[i + 1]
    return None


def cmd_status(argv):
    state = _read_state()
    pid = state["pid"]
    alive = _is_alive(pid)
    started = datetime.fromisoformat(state["started_at"])
    runtime = _format_duration((datetime.now() - started).total_seconds())
    cores = _cores_from_cmd(state["cmd"]) or "?"
    print(f"{_color(CYAN, 'PID:')}       {pid} ({_color(GREEN, 'running') if alive else _color(RED, 'not running')})")
    print(f"{_color(CYAN, 'Started:')}   {state['started_at']}")
    print(f"{_color(CYAN, 'Runtime:')}   {runtime}")
    print(f"{_color(CYAN, 'Cores:')}     {cores}")
    print(f"{_color(CYAN, 'Log:')}       {state['log_file']}")

    log_path = Path(state["log_file"])
    if not log_path.exists():
        print(_color(DIM, "(log file not found yet)"))
        return
    text = log_path.read_text(errors="replace")

    progress = None
    for progress in PROGRESS_RE.finditer(text):
        pass
    progress_str = f"{progress.group(1)}/{progress.group(2)} steps ({progress.group(3)}%)" if progress else _color(DIM, "(not available yet)")
    print(f"{_color(CYAN, 'Progress:')}  {progress_str}")

    steps = _parse_last_steps(text)
    print(_color(CYAN, "Last steps:") if steps else _color(DIM, "Last steps: (none yet)"))
    for rule_name, status in steps:
        marker = _color(GREEN, "done") if status == "done" else _color(YELLOW, "running")
        print(f"  - {rule_name} [{marker}]")


def cmd_abort(argv):
    state = _read_state()
    pid = state["pid"]
    if not _is_alive(pid):
        _die("pastForward: tracked process is not running.")
    if "--force" in argv:
        os.killpg(pid, signal.SIGKILL)
        print(_color(RED, f"Force-killed process group {pid} (main process + subprocesses)."))
    else:
        os.kill(pid, signal.SIGTERM)
        print(_color(YELLOW, f"Sent SIGTERM to PID {pid}. Snakemake will shut its subprocesses down itself."))
        print(_color(DIM, "Use --force to kill the whole process group immediately instead."))


def _dryrun_capture():
    # No passthrough args: check/preview parse the "Detected species"/"Requesting:" log lines
    # that only get emitted while Snakemake builds rule all's DAG - passing a target/rule name
    # through here would build a different DAG and silently drop that output instead.
    _ensure_project_root()
    proc = subprocess.run(_build_dryrun_cmd([]), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if proc.returncode != 0:
        print(_color(RED, "snakemake --dryrun failed:"), file=sys.stderr)
        print("\n".join(proc.stdout.splitlines()[-20:]), file=sys.stderr)
        sys.exit(proc.returncode)
    return proc.stdout


def cmd_check(argv):
    if argv:
        _die("pastForward check: takes no arguments (it always runs a plain `snakemake --dryrun`).")
    text = _dryrun_capture()
    m = DETECTED_SPECIES_RE.search(text)
    if not m:
        _die("pastForward: no species tree found in dryrun output — check config.yaml.")
    # check.py's tree lines all start with "-" or indentation (or are blank, between species) -
    # the first line that starts with anything else is the next, unrelated log message.
    lines = text[m.start() :].splitlines()
    block = [lines[0]]
    for line in lines[1:]:
        if line == "" or line.startswith("-") or line[:1].isspace():
            block.append(line)
        else:
            break
    print("\n".join(block).strip())


def cmd_preview(argv):
    if argv:
        _die("pastForward preview: takes no arguments (it always runs a plain `snakemake --dryrun`).")
    text = _dryrun_capture()
    skipped_species = re.findall(r"Skipping species '(.+?)' \(execute: false\)", text)
    existing = re.findall(r"- Skipping: (.+)", text)
    requested = re.findall(r"- Requesting: (.+)", text)

    if skipped_species:
        print(_color(YELLOW, f"Skipped species ({len(skipped_species)}, execute: false):"))
        for s in skipped_species:
            print(_color(DIM, f"  - {s}"))
        print()
    if existing:
        print(_color(YELLOW, f"Already produced ({len(existing)}, will be skipped):"))
        for f in existing:
            print(_color(DIM, f"  - {f}"))
        print()
    print(_color(GREEN, f"Expected output ({len(requested)}):"))
    for f in requested:
        print(f"  - {f}")
    if not requested:
        print(_color(DIM, "  (none — check config.yaml, or run `pastForward check` to see what was discovered)"))


def cmd_version(argv):
    _ensure_project_root()
    sys.path.insert(0, str(Path("workflow")))
    from scripts.version import __version__

    print(__version__)


COMMANDS = {
    "run": cmd_run,
    "dryrun": cmd_dryrun,
    "status": cmd_status,
    "abort": cmd_abort,
    "check": cmd_check,
    "preview": cmd_preview,
    "version": cmd_version,
}

HELP = """pastForward — CLI wrapper around the pastForward Snakemake pipeline.

Usage: pastForward <command> [args...]

Commands:
  run --cores <N> [snakemake-args...]
                                Run the pipeline. --cores (or -j/--jobs) is required. Backgrounded
                                by default; add --fg/--foreground anywhere to run in the
                                foreground instead.
  dryrun [snakemake-args...]   Run `snakemake --dryrun` in the foreground.
  status                       Show progress of the tracked background run.
  abort [--force]              Stop the tracked background run: SIGTERM by default (Snakemake
                                shuts its own subprocesses down); --force kills the whole
                                process group immediately.
  check                         Show what pastForward discovers on disk for the current config
                                 (species/individuals/references/...).
  preview                       Show expected output files for the current config, including
                                 skipped ones.
  version                      Print the pastForward pipeline version.

Run from a project root: the folder containing workflow/ and config/.
Logs for `run`/`dryrun` are written to logs/<command>_<timestamp>.log.
"""


def _print_help():
    for line in HELP.splitlines():
        if line.startswith("pastForward") or line in ("Usage: pastForward <command> [args...]", "Commands:"):
            print(_color(CYAN, line))
        else:
            print(line)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("-h", "--help"):
        _print_help()
        return
    command, rest = argv[0], argv[1:]
    func = COMMANDS.get(command)
    if func is None:
        print(_color(RED, f"pastForward: unknown command '{command}'"))
        print()
        _print_help()
        sys.exit(1)
    func(rest)


if __name__ == "__main__":
    main()
