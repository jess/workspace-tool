# workspace

A tool for managing multiple git worktree-based development workspaces across Rails projects.

## Features

- Create isolated workspaces using git worktrees
- Auto-configured tmux sessions with vim + shell + server windows
- Random port assignment to avoid conflicts between workspaces
- Per-project Procfile templates
- Automatic `.env` copying with workspace-specific overrides

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

## Requirements

- git
- tmux
- overmind

### macOS

```bash
brew install tmux overmind
```

## Installation

```bash
git clone <this-repo> ~/workspace-tool
cd ~/workspace-tool
./install.sh
```

Or manually:

```bash
cp workspace ~/.local/bin/workspace
chmod +x ~/.local/bin/workspace
cp workspaces.yml.example ~/.workspaces.yml
```

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
1. Create a git worktree at `~/projects/myapp/my-feature`
2. Create a new branch `my-feature`
3. Copy `.env` from the main project and add workspace-specific settings
4. Create a tmux session `myapp-my-feature` with:
   - `code` window: vim (with `docs/my-feature.md` open) + shell
   - `server` window: runs bundle install, yarn install, then overmind
5. Generate `docs/my-feature.md` with workspace details

### Delete a workspace

```bash
workspace delete myapp my-feature
workspace delete myapp my-feature --force  # Skip confirmations
```

This will:
1. Kill the tmux session
2. Stop overmind
3. Remove the git worktree
4. Optionally delete the branch

### List workspaces

```bash
workspace list              # All projects
workspace list myapp        # Specific project
```

## Workspace Layout

Each workspace gets:

```
~/projects/myapp/my-feature/
├── .env                      # Copied from main + workspace settings
├── .banner                   # Displayed in shell pane
├── Procfile.workspace        # Generated from template
└── docs/
    └── my-feature.md         # Feature notes template
```

## Environment Variables

Each workspace automatically gets:
- `SESSION_COOKIE_NAME` - unique cookie name (`<project>_cookie_<port>`)
- `VITE_RUBY_PORT` - unique Vite port

This allows running multiple workspaces simultaneously without session conflicts.
