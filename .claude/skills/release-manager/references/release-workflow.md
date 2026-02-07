# Release Workflow Reference

## Pipeline Diagram

```
                    ┌──────────┐
                    │ Trigger  │
                    └────┬─────┘
                         │
              ┌──────────┴──────────┐
              │                     │
        workflow_dispatch      tag push (v*)
              │                     │
              v                     │
        ┌───────────┐              │
        │  validate  │              │
        └─────┬─────┘              │
              │                     │
              v                     │
        ┌───────────┐              │
        │    tag     │              │
        │ (if new)   │              │
        └─────┬─────┘              │
              │                     │
              ├─────────────────────┘
              v
        ┌───────────┐
        │  publish   │  <- HARD GATE
        │ mooncakes  │
        └─────┬─────┘
              │
       ┌──────┴──────┐
       v              v
  ┌──────────┐  ┌──────────┐
  │  build   │  │  build   │
  │  native  │  │  wasm    │
  └────┬─────┘  └────┬─────┘
       │              │
       └──────┬───────┘
              v
        ┌───────────┐
        │  release   │
        │  GitHub    │
        └───────────┘
```

## Triggers

### Tag Push (`v*`)
When a tag matching `v*` is pushed to the repository:
- Skips validate and tag phases (tag already exists)
- Starts directly at the publish phase
- Used for: manual CLI-driven releases

### Workflow Dispatch
Manual trigger from GitHub Actions UI:
- Runs all 5 phases
- **Must be triggered from `main` branch** (enforced in validate job)
- Optional `skip_publish` input for troubleshooting
- Used for: standard releases, testing the pipeline

## Mooncakes.io Credentials

### Format
Mooncakes.io uses a simple JSON credential file:

```json
{"token": "your-mooncakes-token-here"}
```

**Location:** `~/.moon/credentials.json`

### GitHub Actions Setup
Required secrets and variables in the GitHub repository:

| Type | Name | Purpose |
|------|------|---------|
| Secret | `MOONCAKES_USER_TOKEN` | Authentication token for mooncakes.io |
| Variable | `MOONCAKES_USERNAME` | Username on mooncakes.io (e.g., `moonrockz`) |

The `release:credentials` mise task reads `MOONCAKES_USER_TOKEN` from the environment and writes the credentials file.

### Getting a Token
1. Visit [mooncakes.io](https://mooncakes.io)
2. Log in with your account
3. Run `moon login` locally to authenticate via OAuth
4. The token is stored at `~/.moon/credentials.json`
5. Copy the token value to the GitHub repository secret

## Manual Release Procedure

For cases where the GitHub Actions workflow cannot be used:

```bash
# 1. Ensure you're on main with a clean tree
git checkout main
git pull origin main
git status  # must be clean

# 2. Run pre-release checks
mise run release:pre-check

# 3. Compute and bump version
mise run release:bump
mise run release:changelog

# 4. Commit the version bump
VERSION=$(mise run release:version)
git add moon.mod.json CHANGELOG.md
git commit -m "chore(release): v${VERSION}"

# 5. Create tag
git tag -a "v${VERSION}" -m "Release v${VERSION}"

# 6. Publish to mooncakes.io
export MOONCAKES_USER_TOKEN="your-token"
mise run release:credentials
mise run release:publish

# 7. Push (triggers GitHub Actions for build + release)
git push origin main --tags

# 8. Verify
python3 .claude/skills/release-manager/scripts/post_release_verify.py --version "${VERSION}"
```

## Rollback Procedures

**Tags and releases are immutable.** Never:
- `git tag --force`
- `git push --force` tags
- Delete GitHub Releases

### Bad Release Recovery

If a release has problems:

1. **Code bug**: Fix the bug, create a new patch release (e.g., 0.2.0 -> 0.2.1)
2. **Wrong version**: The next release will naturally increment correctly
3. **Missing artifacts**: Re-run the release workflow (publish will be skipped if mooncakes already has the version)
4. **Mooncakes publish failed**: Use `workflow_dispatch` to re-trigger; the tag phase will be skipped (tag exists)

### Never Do

- Delete a git tag from the remote
- Delete a GitHub Release
- Force-push over a tag
- Re-use a version number

## Pre-Publish Checks

The `release:publish` mise task runs these checks before `moon publish`:

1. `moon check` - Type checking and compilation
2. `moon test` - Full test suite
3. `moon fmt` + `git diff --exit-code` - No formatting changes

## Build Artifacts

Each release produces 5 artifacts:

| Artifact | Platform | Source |
|----------|----------|--------|
| `gherkin-linux-amd64` | Linux x86_64 | Native build |
| `gherkin-macos-arm64` | macOS ARM64 | Native build |
| `gherkin-windows-amd64.exe` | Windows x86_64 | Native build |
| `gherkin-core.wasm` | WASM | Core module |
| `gherkin.component.wasm` | WASM Component | Component model |
