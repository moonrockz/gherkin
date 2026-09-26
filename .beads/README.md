# Beads issue tracker

This project uses Beads for local issue tracking. The database uses embedded
Dolt and syncs through the Git `origin` remote. The tracked `issues.jsonl` is
the snapshot imported from the earlier Beads setup; the Dolt history is the
current source of truth.

## Set up a fresh clone

Install `bd`, then run from the repository root:

```bash
bd bootstrap --yes
bd status
bd sync
```

`bd bootstrap` clones the Dolt history from `origin` without deleting existing
issues. The tracked JSONL snapshot is available for recovery if needed.
Do not use `bd init --reinit-local` to set up a clone: that replaces local data.

## Work with issues

```bash
bd ready             # open issues without blockers
bd list              # list issues
bd show <issue-id>   # inspect an issue
bd create "Title"    # create an issue
bd close <issue-id>  # close completed work
bd sync              # pull and push Dolt changes
```

`bd sync` handles Beads data. Commit and push changes to tracked repository
files with Git as usual. The local database, backup files, and lock files stay
out of Git.
