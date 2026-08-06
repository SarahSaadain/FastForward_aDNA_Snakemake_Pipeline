# =================================================================================================
#     Dependencies and Environment Setup
# =================================================================================================
# Import required Python modules for system, platform, logging, and workflow management
import os
import sys
import pwd
import re
import socket, platform
import subprocess
from datetime import datetime
import logging
from pathlib import Path
import yaml
import json

# import version from workflow/scripts/version.py
from scripts.version import __version__

# Import Snakemake plugin settings for executor modes
from snakemake_interface_executor_plugins.settings import ExecMode

# --- Logging Setup (EARLY) ---
# Configure logging format and output for workflow debugging and status reporting
LOG_FORMAT = '[%(asctime)s] [%(levelname)s] %(message)s'
LOG_DATE_FORMAT = '%Y-%m-%d %H:%M:%S (%Z)'

logging.basicConfig(  # Basic config ASAP (for fallback)
    level=logging.INFO,
    format=LOG_FORMAT,
    datefmt=LOG_DATE_FORMAT,
    handlers=[logging.StreamHandler()]  # Only console for now
)

envvars:
    "CONDA_DEFAULT_ENV",
    "CONDA_PREFIX"

# =================================================================================================
#     Snakemake Version Check
# =================================================================================================
# Ensure the minimum required Snakemake version is available for compatibility
snakemake.utils.min_version("9.9.0")

# =================================================================================================
#     Configuration Files and Reporting
# =================================================================================================
# Specify the main configuration file for the workflow
configfile: "config/config.yaml"

# =================================================================================================
#     Workflow Header Logging
# =================================================================================================
# Skip all info gathering and output when running as a subprocess
# (spawned by a parent Snakemake process — the parent already printed this)
if workflow.exec_mode != ExecMode.SUBPROCESS:

    pastForward_version = __version__

    try:
        process = subprocess.Popen(
            ["git", "rev-parse", "--short", "HEAD"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            cwd=workflow.basedir
        )
        out, err = process.communicate()
        out = out.decode("ascii")
        pastForward_git_hash = out.strip()
        if pastForward_git_hash and pastForward_git_hash not in pastForward_version:
            pastForward_version += " (git: " + pastForward_git_hash + ")"
        del process, out, err, pastForward_git_hash
    except Exception:
        pass

    # --- Platform ---
    pltfrm = f"{platform.platform()}; {platform.version()}"
    try:
        ld = platform.linux_distribution()
        if len(ld):
            pltfrm += "; " + ld
        del ld
    except:
        pass

    try:
        def merge_osx_tuple(x, bases=(tuple, list)):
            for e in x:
                if type(e) in bases:
                    for e in merge_osx_tuple(e, bases):
                        yield e
                else:
                    yield e

        mv = " ".join(merge_osx_tuple(platform.mac_ver()))
        if not mv.isspace():
            pltfrm += "; " + mv
        del mv, merge_osx_tuple
    except:
        pass

    # --- User / host ---
    username = pwd.getpwuid(os.getuid())[0]
    hostname = socket.gethostname()
    hostname = hostname + ("; " + platform.node() if platform.node() != socket.gethostname() else "")

    # --- Conda ---
    try:
        process = subprocess.Popen(["conda", "--version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = process.communicate()
        out = out.decode("ascii")
        conda_ver = out[out.startswith("conda") and len("conda"):].strip()
        del process, out, err
        if not conda_ver:
            conda_ver = "n/a"
    except:
        conda_ver = "n/a"

    conda_env = f"{os.environ['CONDA_DEFAULT_ENV']} ({os.environ['CONDA_PREFIX']})"
    if conda_env == " ()":
        conda_env = "n/a"

    # --- Command line ---
    cmdline = sys.argv[0]
    for i in range(1, len(sys.argv)):
        cmdline += " " + sys.argv[i]

    # --- Config file paths ---
    cfgfiles = []
    for cfg in workflow.configfiles:
        cfgfiles.append(os.path.abspath(cfg))
    cfgfiles = "\n                        ".join(cfgfiles)

    # --- Output ---
    logger.info("pastForward " + pastForward_version + " run:")
    logger.info("\tDate:               " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    logger.info("\tProcess ID:         " + str(os.getpid()))
    logger.info("\tPlatform:           " + pltfrm)
    logger.info("\tHost:               " + hostname)
    logger.info("\tUser:               " + username)
    logger.info("\tConda:              " + str(conda_ver))
    logger.info("\tPython:             " + str(sys.version.split(" ")[0]))
    logger.info("\tSnakemake:          " + str(snakemake.__version__))
    logger.info("\tConda env:          " + str(conda_env))
    logger.info("\tCommand:            " + cmdline)
    logger.info("\tBase directory:     " + workflow.basedir)
    logger.info("\tWorking directory:  " + os.getcwd())
    logger.info("\tConfig file(s):     " + cfgfiles)

    config_str = yaml.dump(config.get("pipeline", {}), sort_keys=False, default_flow_style=False)
    logging.info("Loaded configuration:\n%s", config_str)

# =================================================================================================
# End of initialize.smk
# =================================================================================================
