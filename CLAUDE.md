# Agentic Instructions

Common agentic instructions are in AGENTS.md, imported here:

@AGENTS.md

Only place claude specific agentic instructions in this file.

## Claude Code

- Track work in bd only (see AGENTS.md > Work Tracking). Do not use the
  TodoWrite or TaskCreate tools.
- Store persistent knowledge with `bd remember`, not in Claude Code auto
  memory (`MEMORY.md`). See AGENTS.md > Persistent Memory.
- Use `mise run <task>` for builds and tests, not ad hoc command chains.

## Release Management

- Use `/release-manager` skill for release tasks
- Releases publish to **mooncakes.io first**, then GitHub Releases
- Tags and releases are **immutable** -- never force-push tags or delete releases
- `mise run release:pre-check` validates readiness before release
- `mise run release:publish` publishes to mooncakes.io
- Release workflow: validate -> tag -> publish -> build -> release
- Mooncakes credentials: `MOONCAKES_USER_TOKEN` secret in GitHub Actions
