#!/usr/bin/env python3
"""Post-release verification for moonrockz/gherkin.

Verifies that a release completed successfully:
- Git tag exists
- GitHub Release exists
- Expected artifacts present
- Mooncakes.io package accessible
- moon.mod.json version matches
- CHANGELOG.md includes version header
"""

import argparse
import json
import subprocess
import sys
import urllib.request
import urllib.error


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=30)


EXPECTED_ARTIFACTS = [
    "gherkin-linux-amd64",
    "gherkin-macos-arm64",
    "gherkin-windows-amd64.exe",
    "gherkin-core.wasm",
    "gherkin.component.wasm",
]


def check_tag_exists(version: str) -> tuple[bool, str]:
    tag = f"v{version}"
    result = run(["git", "tag", "-l", tag])
    if result.stdout.strip():
        return True, f"Tag '{tag}' exists"
    return False, f"Tag '{tag}' not found"


def check_github_release(version: str) -> tuple[bool, str]:
    tag = f"v{version}"
    result = run(["gh", "release", "view", tag, "--json", "tagName,name"])
    if result.returncode != 0:
        return False, f"GitHub Release '{tag}' not found"
    data = json.loads(result.stdout)
    return True, f"GitHub Release '{data.get('name', tag)}' exists"


def check_release_artifacts(version: str) -> tuple[bool, str]:
    tag = f"v{version}"
    result = run(["gh", "release", "view", tag, "--json", "assets"])
    if result.returncode != 0:
        return False, "Could not fetch release assets"

    data = json.loads(result.stdout)
    asset_names = [a["name"] for a in data.get("assets", [])]

    missing = [name for name in EXPECTED_ARTIFACTS if name not in asset_names]
    if missing:
        return False, f"Missing artifacts: {', '.join(missing)}"
    return True, f"All {len(EXPECTED_ARTIFACTS)} expected artifacts present"


def check_mooncakes_published() -> tuple[bool, str]:
    try:
        url = "https://mooncakes.io/docs/moonrockz/gherkin"
        req = urllib.request.Request(url, method="HEAD")
        req.add_header("User-Agent", "gherkin-release-verifier/1.0")
        resp = urllib.request.urlopen(req, timeout=10)
        if resp.status == 200:
            return True, "Package accessible on mooncakes.io"
        return False, f"Mooncakes.io returned status {resp.status}"
    except urllib.error.HTTPError as e:
        return False, f"Mooncakes.io HTTP error: {e.code}"
    except Exception as e:
        return False, f"Could not reach mooncakes.io: {e}"


def check_version_matches(version: str) -> tuple[bool, str]:
    try:
        with open("moon.mod.json") as f:
            data = json.load(f)
        mod_version = data.get("version", "")
        if mod_version == version:
            return True, f"moon.mod.json version matches ({version})"
        return False, f"moon.mod.json version is '{mod_version}', expected '{version}'"
    except Exception as e:
        return False, f"Could not read moon.mod.json: {e}"


def check_changelog_includes_version(version: str) -> tuple[bool, str]:
    try:
        with open("CHANGELOG.md") as f:
            content = f.read()
        if f"[{version}]" in content or f"## [{version}]" in content:
            return True, f"CHANGELOG.md includes version {version}"
        return False, f"CHANGELOG.md does not mention version {version}"
    except Exception as e:
        return False, f"Could not read CHANGELOG.md: {e}"


def main():
    parser = argparse.ArgumentParser(description="Post-release verification")
    parser.add_argument(
        "--version", required=True,
        help="Version to verify (e.g., 0.2.0)"
    )
    args = parser.parse_args()

    checks = [
        ("Git tag exists", lambda: check_tag_exists(args.version)),
        ("GitHub Release exists", lambda: check_github_release(args.version)),
        ("Release artifacts present", lambda: check_release_artifacts(args.version)),
        ("Mooncakes.io published", check_mooncakes_published),
        ("Version in moon.mod.json", lambda: check_version_matches(args.version)),
        ("Version in CHANGELOG.md", lambda: check_changelog_includes_version(args.version)),
    ]

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
        print("Release verification: ISSUES FOUND")
        sys.exit(1)
    else:
        print("Release verification: ALL GOOD")
        sys.exit(0)


if __name__ == "__main__":
    main()
