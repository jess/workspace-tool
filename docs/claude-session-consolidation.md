# Plan: Consolidate Claude Code Sessions After Worktree Deletion

## Problem

Claude Code stores conversation history in `~/.claude/projects/` keyed by the **absolute directory path** (with `/` replaced by `-`). When a git worktree is deleted, those conversations become orphaned — they don't show up in `claude resume` from any existing directory.

## How Claude Code stores sessions

```
~/.claude/projects/-Users-jess-projects-tract-workspaces-web-comms-permissions/
├── caf25c53-2f3d-4a0d-ae4a-39126e5e6533.jsonl   # conversation transcript
├── caf25c53-2f3d-4a0d-ae4a-39126e5e6533/         # conversation artifacts
├── decbe560-f772-44b1-a167-8ed52d1f7eab.jsonl
├── decbe560-f772-44b1-a167-8ed52d1f7eab/
└── memory/                                         # project-scoped memory
```

- Each conversation is a UUID `.jsonl` file + optional UUID directory (for artifacts/task data)
- The `memory/` subdirectory contains project-scoped memory files (like `MEMORY.md`)
- The parent directory name is the absolute path with `/` replaced by `-`

## What to do when a worktree is deleted

After the worktree directory is removed, move its Claude session files into the **main repo's** Claude project directory so they appear in `claude resume` from the main repo.

### Steps

1. Derive the Claude project dir name from the worktree's absolute path:
   - Take the worktree path (e.g., `/Users/jess/projects/tract/workspaces/web-comms-permissions`)
   - Replace all `/` with `-` and prepend `-` → `-Users-jess-projects-tract-workspaces-web-comms-permissions`
   - Full path: `~/.claude/projects/-Users-jess-projects-tract-workspaces-web-comms-permissions/`

2. Derive the Claude project dir for the **main repo** (the bare/main checkout the worktree belongs to):
   - Use `git -C <worktree-path> worktree list` (before deletion) or `git worktree list` from the main repo to find the main working tree path
   - Encode it the same way

3. Move all `.jsonl` files and their matching UUID directories from the worktree's project dir into the main repo's project dir:
   ```bash
   src="$HOME/.claude/projects/$worktree_encoded"
   dst="$HOME/.claude/projects/$main_repo_encoded"

   if [ -d "$src" ]; then
     mkdir -p "$dst"
     for jsonl in "$src"/*.jsonl; do
       [ -f "$jsonl" ] || continue
       uuid=$(basename "$jsonl" .jsonl)
       mv "$jsonl" "$dst/"
       [ -d "$src/$uuid" ] && mv "$src/$uuid" "$dst/"
     done
     # Optionally merge memory/ or just leave it
     # Clean up the now-empty directory
     rm -rf "$src"
   fi
   ```

4. Do **not** move the `memory/` directory — it's project-path-specific and may conflict. It can be deleted with the rest of the empty dir.

## Integration point

This logic should run as part of the **worktree delete** workflow, after `git worktree remove` but while you still know the worktree's absolute path. The key inputs are:

- `worktree_path`: the absolute path of the worktree being deleted
- `main_repo_path`: the absolute path of the main repo (from `git worktree list`, first entry)

## Edge cases

- If no Claude project dir exists for the worktree (no conversations happened), skip silently
- UUID collisions between worktree and main repo are astronomically unlikely — no dedup needed
- If the main repo project dir doesn't exist yet, create it
