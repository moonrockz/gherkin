---
name: release-manager
description: Manages the release lifecycle for moonrockz/gherkin MoonBit parser. Use when performing releases, publishing to mooncakes.io, creating tags, validating release readiness, running post-release verification, or conducting release retrospectives. Covers version bumping, changelog generation, mooncakes publishing, GitHub release creation, and release troubleshooting.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Task
---

# Release Manager

Manage the full release lifecycle for the moonrockz/gherkin MoonBit Gherkin parser. Releases publish to mooncakes.io first (hard gate), then build artifacts and create GitHub Releases. Tags and releases are immutable.

## Release Pipeline (5 Phases)

1. **Validate** - Pre-checks, version computation, release notes generation
2. **Tag** - Create immutable git tag `v{version}` (workflow_dispatch only)
3. **Publish to Mooncakes** - `moon publish` to mooncakes.io (MUST succeed before artifacts)
4. **Build Artifacts** - Native binaries (Linux, macOS, Windows) + WASM components (parallel)
5. **Create GitHub Release** - Upload artifacts with release notes

The pipeline runs via `.github/workflows/release.yml`. Triggers:
- **Tag push** (`v*`): Starts from Phase 3 (tag already exists)
- **workflow_dispatch**: Runs all 5 phases from main branch

## Mise Tasks

| Task | Purpose |
|------|---------|
| `release:pre-check` | Validate release readiness (tests, version, changelog) |
| `release:version` | Compute next version from conventional commits |
| `release:bump` | Update moon.mod.json version to match |
| `release:changelog` | Generate CHANGELOG.md from git history |
| `release:notes` | Generate release notes for latest version |
| `release:credentials` | Set up mooncakes credentials from MOONCAKES_USER_TOKEN |
| `release:publish` | Publish to mooncakes.io (runs pre-publish checks) |
| `release:prepare-assets` | Prepare release assets from build artifacts |

## Immutability Rules

- Tags are **immutable**: never `git tag --force`, never `git push --force` tags
- GitHub Releases are **immutable**: never delete and recreate
- If a release has problems, create a new **patch release** (e.g., 0.2.1 to fix 0.2.0)

## Manual Release Procedure

```bash
# 1. Ensure on main, working tree clean
git checkout main && git pull

# 2. Validate readiness
mise run release:pre-check

# 3. Bump version and regenerate changelog
mise run release:bump
mise run release:changelog

# 4. Commit version bump
VERSION=$(mise run release:version)
git add moon.mod.json CHANGELOG.md
git commit -m "chore(release): v${VERSION}"

# 5. Tag and push (triggers release workflow from Phase 3)
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin main --tags
```

Alternatively, trigger `workflow_dispatch` from GitHub Actions (runs all 5 phases automatically).

## Pre-Release Checks

Run `mise run release:pre-check` or directly:
```bash
python3 .claude/skills/release-manager/scripts/pre_release_check.py [--branch main] [--skip-tests]
```

Validates: clean working tree, correct branch, moon check, moon fmt, tests, no duplicate tag, changelog up to date.

## Post-Release Verification

After a release completes:
```bash
python3 .claude/skills/release-manager/scripts/post_release_verify.py --version 0.2.0
```

Checks: tag exists, GitHub Release exists, artifacts present, mooncakes.io published, version matches.

## Release Retrospective

Generate a retrospective report:
```bash
python3 .claude/skills/release-manager/scripts/release_retrospective.py --version 0.2.0
```

Produces: timeline, commit summary by type, contributors, artifact inventory, changelog excerpt.

## Troubleshooting

**Mooncakes publish fails**: Check `MOONCAKES_USER_TOKEN` secret is set. Use `workflow_dispatch` with `skip_publish=true` to bypass temporarily.

**Tag already exists**: The workflow skips tag creation. If the version needs to change, create a new patch release.

**Build fails after publish**: Mooncakes.io already has the version published. Fix the build issue and re-run the workflow (publish step will need to be skipped or the version incremented).

See `references/release-workflow.md` for detailed workflow documentation.
