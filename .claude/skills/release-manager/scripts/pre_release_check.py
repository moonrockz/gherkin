#!/usr/bin/env python3
"""Pre-release readiness validator for moonrockz/gherkin.

Checks that the project is ready for release:
- Working tree clean
- On correct branch
- moon check passes
- moon fmt produces no changes
- Tests pass (unless --skip-tests)
- No existing tag for computed version
- Changelog up to date
"""

import argparse
import subprocess
import sys


def run(cmd: list[str], capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, capture_output=capture, text=True, timeout=600
    )


def check_clean_tree() -> tuple[bool, str]:
    result = run(["git", "status", "--porcelain"])
    if result.stdout.strip():
        return False, f"Working tree has uncommitted changes:\n{result.stdout.strip()}"
    return True, "Working tree is clean"


def check_branch(expected: str) -> tuple[bool, str]:
    result = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    branch = result.stdout.strip()
    if branch != expected:
        return False, f"On branch '{branch}', expected '{expected}'"
    return True, f"On branch '{branch}'"


def check_moon_check() -> tuple[bool, str]:
    result = run(["moon", "check"])
    if result.returncode != 0:
        return False, f"moon check failed:\n{result.stderr.strip()}"
    return True, "moon check passed"


def check_moon_fmt() -> tuple[bool, str]:
    run(["moon", "fmt"])
    result = run(["git", "diff", "--exit-code", "--quiet"])
    if result.returncode != 0:
        diff = run(["git", "diff", "--stat"])
        run(["git", "checkout", "--", "."])  # restore
        return False, f"moon fmt produced changes:\n{diff.stdout.strip()}"
    return True, "moon fmt produces no changes"


def check_tests() -> tuple[bool, str]:
    result = run(["mise", "run", "test:all"])
    if result.returncode != 0:
        stderr = result.stderr.strip() if result.stderr else ""
        stdout = result.stdout.strip() if result.stdout else ""
        output = stderr or stdout
        return False, f"Tests failed:\n{output[:500]}"
    return True, "All tests pass"


def check_no_existing_tag() -> tuple[bool, str]:
    version_result = run(["mise", "run", "release:version"])
    if version_result.returncode != 0:
        return False, "Could not compute version"
    version = version_result.stdout.strip().splitlines()[-1]
    tag = f"v{version}"

    result = run(["git", "tag", "-l", tag])
    if result.stdout.strip():
        return False, f"Tag '{tag}' already exists (tags are immutable)"
    return True, f"Tag '{tag}' does not exist yet"


def check_changelog_up_to_date() -> tuple[bool, str]:
    run(["mise", "run", "release:changelog"])
    result = run(["git", "diff", "--exit-code", "--quiet", "CHANGELOG.md"])
    if result.returncode != 0:
        run(["git", "checkout", "--", "CHANGELOG.md"])  # restore
        return False, "CHANGELOG.md is out of date (run mise run release:changelog)"
    return True, "CHANGELOG.md is up to date"


def main():
    parser = argparse.ArgumentParser(description="Pre-release readiness check")
    parser.add_argument(
        "--branch", default="main",
        help="Expected branch name (default: main)"
    )
    parser.add_argument(
        "--skip-tests", action="store_true",
        help="Skip running the test suite"
    )
    args = parser.parse_args()

    checks = [
        ("Clean working tree", check_clean_tree),
        ("Correct branch", lambda: check_branch(args.branch)),
        ("moon check", check_moon_check),
        ("moon fmt", check_moon_fmt),
    ]

    if not args.skip_tests:
        checks.append(("Tests pass", check_tests))

    checks.extend([
        ("No existing tag", check_no_existing_tag),
        ("Changelog up to date", check_changelog_up_to_date),
    ])

    passed = 0
    failed = 0

    for name, check_fn in checks:
        try:
            ok, message = check_fn()
        except Exception as e:
            ok, message = False, str(e)

        status = "[PASS]" if ok else "[FAIL]"
        print(f"{status} {name}: {message}")

        if ok:
            passed += 1
        else:
            failed += 1

    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed")

    if failed > 0:
        print("Release readiness: NOT READY")
        sys.exit(1)
    else:
        print("Release readiness: READY")
        sys.exit(0)


if __name__ == "__main__":
    main()
