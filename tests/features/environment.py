"""Behave environment hooks for the Gherkin parser BDD tests."""

import os
import subprocess
import logging

logger = logging.getLogger("behave.environment")

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "..", "fixtures")


def before_all(context):
    """Build the MoonBit parser once before any tests run."""
    context.project_root = PROJECT_ROOT
    context.fixtures_dir = FIXTURES_DIR

    logger.info("Building MoonBit Gherkin parser...")
    result = subprocess.run(
        ["moon", "build"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        logger.error("Parser build failed:\n%s", result.stderr)
        raise RuntimeError(f"moon build failed: {result.stderr}")

    logger.info("Parser built successfully.")


def before_scenario(context, scenario):
    """Reset per-scenario state."""
    context.parser_output = None
    context.parser_returncode = None
    context.parser_stderr = None
    context.input_file = None


def after_scenario(context, scenario):
    """Clean up any temporary files created during the scenario."""
    for path in getattr(context, "_temp_files", []):
        try:
            os.unlink(path)
        except OSError:
            pass
    context._temp_files = []


def run_parser(context, input_path, *extra_args):
    """Invoke the MoonBit parser against an input file.

    Stores stdout, stderr, and return code on the context object.
    """
    cmd = [
        "moon", "run", "src/cmd/main", "--",
        input_path,
        *extra_args,
    ]
    result = subprocess.run(
        cmd,
        cwd=context.project_root,
        capture_output=True,
        text=True,
        timeout=30,
    )
    context.parser_output = result.stdout
    context.parser_stderr = result.stderr
    context.parser_returncode = result.returncode
    return result
