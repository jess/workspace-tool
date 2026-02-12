# workspace

A tool for managing multiple git worktree-based development workspaces across Rails projects.

## Features

- Create isolated workspaces using git worktrees
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
- gh (optional, for PR status in `list` and PR descriptions in `pull`)

### macOS

```bash
brew install tmux overmind gh
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
    path: ~/projects/myapp/web          # Main checkout (source of .env)
    worktree_dir: ~/projects/myapp      # Where worktrees are created
```

### Custom Procfile

Create `Procfile.workspace.template` in your project's main path to customize the Procfile:

```
web: RUBY_DEBUG_OPEN=true bin/rails server -p $RAILS_PORT
vite: VITE_RUBY_PORT=$VITE_PORT bin/vite dev
worker: bundle exec sidekiq -q default -q mailers
```

Available variables:
- `$RAILS_PORT` - generated Rails server port
- `$VITE_PORT` - generated Vite port

If no template exists, a default Rails/Sidekiq Procfile is used.

## Usage

### Create a workspace

```bash
workspace new myapp my-feature
```

This will:
1. Fetch latest from `origin/master`
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
workspace resume myapp my-feature
```

Re-creates the tmux session and server for an existing worktree (e.g., after a reboot). Reads port configuration from the existing `.env` file.

### Delete a workspace

```bash
workspace delete myapp my-feature
workspace delete myapp my-feature --force  # Skip confirmations
```

This will:
1. Kill the tmux session
2. Stop overmind
3. Remove the git worktree
4. Move any Claude Code sessions to the main project (so they appear in `claude resume`)
5. Optionally delete the branch

### List workspaces

```bash
workspace list              # All projects
workspace list myapp        # Specific project
```

Shows all active worktrees with their tmux status and PR status (open/merged/closed).

## Workspace Layout

Each workspace gets:

```
~/projects/myapp/my-feature/
├── .env                      # Copied from main + workspace settings
├── .env.test                 # Forces Vite to compile in test env
├── .banner                   # Displayed in shell pane
├── Procfile.workspace        # Generated from template
└── docs/
    └── my-feature.md         # Feature notes template
```

## Environment Variables

Each workspace automatically gets:
- `SESSION_COOKIE_NAME` - unique cookie name (`<project>_cookie_<port>`)
- `VITE_RUBY_PORT` - unique Vite port
- `REDIS_URL` - unique Redis DB (`redis://localhost:6379/<N>`)

This allows running multiple workspaces simultaneously without conflicts.
