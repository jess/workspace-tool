# workspace

IDEs are for people who like clicking things. The kool kids use vim in tmux with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) running in a split pane — no GUI, no Electron, no waiting for VS Code to "index your project."

This tool manages the boring parts: spin up isolated git worktrees with their own ports, Redis DBs, and overmind processes so you can juggle multiple features without anything stepping on anything else. One command to create a workspace, one to tear it down, and Claude Code sessions get consolidated back to the main project when you're done.

Opinionated? Absolutely. It assumes you're running Rails, tmux, overmind, and vim. If that's not your stack, this isn't your tool.

## Features

- Create isolated workspaces using git worktrees
- Initialize the main checkout as a workspace with port/Redis allocation
- Pull remote branches into workspaces (with PR description fetching)
- Resume existing workspaces with a single command
- Auto-configured tmux sessions with vim + shell + server windows
- Random port assignment to avoid conflicts between workspaces
- Automatic Redis DB allocation (1-15) across all projects
- Per-project Procfile templates
- Automatic `.env` copying with workspace-specific overrides
- Claude Code session consolidation on workspace deletion
- Shell completions for bash and zsh
- PR status display in workspace list (via GitHub CLI)

## Assumptions

This tool is designed for Rails projects with the following setup:

### Environment files

Your project uses a `.env` file for configuration. The tool copies this file to each workspace and adds workspace-specific variables.

### Vite

Your project uses Vite for asset compilation. Each workspace gets a unique `VITE_RUBY_PORT` to avoid conflicts.

### Session store

To allow multiple workspaces to run simultaneously without sharing sessions, your app should read the session cookie name from an environment variable.

In `config/initializers/session_store.rb`:

```ruby
session_key = ENV.fetch("SESSION_COOKIE_NAME", "_myapp_session")
Rails.application.config.session_store :cookie_store, key: session_key
```

Each workspace automatically gets a unique `SESSION_COOKIE_NAME` (e.g., `myapp_cookie_3102`).

### Redis

Each workspace gets its own Redis DB number (1-15) to avoid data conflicts. The tool scans all projects' worktrees to find the next available DB.

## Requirements

- git
- tmux
- overmind
- gum (for styled output)
- gh (optional, for PR status in `list` and PR descriptions in `pull`)

### macOS

```bash
brew install tmux overmind gum gh
```

## Installation

```bash
git clone <this-repo> ~/workspace-tool
cd ~/workspace-tool
./install.sh
```

The installer will:
- Copy the `workspace` script to `~/.local/bin/`
- Install shell completions for your shell (bash or zsh)
- Create an example `~/.workspaces.yml` if it doesn't exist

Make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Configuration

Edit `~/.workspaces.yml` to add your projects:

```yaml
projects:
  myapp:
    path: ~/projects/myapp/main          # Main checkout (source of .env)
    worktree_dir: ~/projects/myapp/workspaces      # Where worktrees are created
```

### Custom Procfile (optional)

By default, each workspace gets a `Procfile.workspace` with:

```
web: RUBY_DEBUG_OPEN=true bin/rails server -p $RAILS_PORT
vite: bin/vite dev
worker: RUBY_DEBUG_OPEN=true bundle exec sidekiq -C config/sidekiq.yml
```

To customize this, create `Procfile.workspace.template` in your project's main path. The template is copied as-is into each workspace, so it should reference environment variables from `.env`:

```
web: RUBY_DEBUG_OPEN=true bin/rails server -p $RAILS_PORT
vite: VITE_RUBY_PORT=$VITE_RUBY_PORT bin/vite dev
worker: bundle exec sidekiq -q default -q mailers
```

Overmind automatically loads `.env` before starting processes, so all workspace-specific variables are available.

## Usage

### Initialize the main checkout

```bash
workspace new myapp main
```

Sets up the main project directory as a workspace with port/Redis allocation, a `Procfile.workspace`, and a tmux session — without creating a worktree. Use `main` or `master` as the feature name.

### Create a feature workspace

```bash
workspace new myapp my-feature
```

This will:
1. Fetch latest from the default branch (`main` or `master`, auto-detected)
2. Create a git worktree at `~/projects/myapp/my-feature` with a new branch
3. Copy `.env` from the main project and add workspace-specific settings (ports, session cookie, Redis DB)
4. Create a tmux session `myapp-my-feature` with:
   - `code` window: vim (with `docs/my-feature.md` open) + shell
   - `server` window: runs nvm use, bundle install, yarn install, then overmind
5. Generate `docs/my-feature.md` with workspace details

### Pull a remote branch

```bash
workspace pull myapp remote-branch
```

Like `new`, but checks out an existing remote branch instead of creating one. If a PR exists for the branch, its title and description are included in the docs file.

### Resume a workspace

```bash
workspace resume myapp my-feature   # Resume one workspace
workspace resume myapp              # Resume all workspaces for project
workspace resume-all                # Resume all workspaces across all projects
```

Re-creates the tmux session and server for an existing worktree (e.g., after a reboot). Reads port configuration from the existing `.env` file.

### Stop a workspace

```bash
workspace stop myapp my-feature     # Stop one workspace
workspace stop myapp                # Stop all workspaces for project
```

Gracefully stops overmind and kills the tmux session.

### Delete a workspace

```bash
workspace delete myapp my-feature
workspace delete myapp my-feature --force  # Skip confirmations
```

This will:
1. Stop overmind
2. Kill the tmux session
3. Confirm, then remove the git worktree
4. Move any Claude Code sessions to the main project (so they appear in `claude resume`)
5. Confirm, then optionally delete the branch

Use `--force` to skip both confirmations (auto-deletes the branch too). The main workspace cannot be deleted.

### Archive and resume a workspace

To free up a workspace without losing your work:

1. `workspace delete myapp my-feature` — answer **yes** to remove the worktree, **no** to keep the branch
2. The worktree is removed but your branch and commits remain in git
3. Later, `workspace resume myapp my-feature` — detects the existing branch, creates a fresh worktree from it, allocates new ports, and starts a new tmux session

This is useful when you want to park a feature and reclaim the disk space / Redis DB / ports, then pick it back up later.

### List workspaces

```bash
workspace list              # All projects
workspace list myapp        # Specific project
```

Shows all active worktrees (including main if initialized) with their tmux status and PR status (open/merged/closed).

### Show port allocations

```bash
workspace ports
```

Shows Rails port, Vite port, and Redis DB for all workspaces.

## Workspace Layout

Each workspace gets:

```
~/projects/myapp/my-feature/
├── .env                      # Copied from main + workspace settings
├── .env.test                 # Forces Vite to compile in test env
├── Procfile.workspace        # Generated from template or default
└── docs/
    └── my-feature.md         # Feature scratchpad
```

### Feature scratchpad (`docs/<feature>.md`)

Each feature workspace gets a notes file that opens in vim when the workspace starts. Use it as a scratchpad for AI-assisted development: add context about what you're building, questions, tasks, reminders, and decisions made along the way. Point Claude at it so it has context for your feature.

When the feature is complete, ask Claude to convert the scratchpad into documentation that can serve as memory/context for future changes or as a reference if you need a reminder of how something works.

## Environment Variables

Each workspace automatically gets:
- `RAILS_PORT` - unique Rails server port
- `VITE_RUBY_PORT` - unique Vite port (RAILS_PORT + 2)
- `SESSION_COOKIE_NAME` - unique cookie name (`<project>_cookie_<port>`)
- `REDIS_URL` - unique Redis DB (`redis://localhost:6379/<N>`)

This allows running multiple workspaces simultaneously without conflicts.
