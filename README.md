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
- A readable hostname per workspace (`my-feature.myapp.test`) routed by Caddy, on top of the port
- Automatic Redis DB allocation (1-15) across all projects
- Per-project Procfile customization (direct or via templates)
- Automatic `.env` copying with workspace-specific overrides
- Claude Code session consolidation on workspace deletion
- Shell completions for bash and zsh
- PR status display in workspace list (via GitHub CLI)
- Agent status column in `list` — see at a glance which workspace's Claude session needs you

## Assumptions

This tool is designed for Rails projects with the following setup:

### Environment files

Your project uses a `.env` file for configuration. The tool copies this file to each workspace and adds workspace-specific variables.

If the main checkout has a gitignored `config/master.key`, it's copied into the new worktree too (only when the worktree doesn't already have one), so apps that keep secrets in `credentials.yml.enc` — Active Record encryption keys, for example — boot and pass tests without any manual copying. Projects without a `master.key` are unaffected.

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
- jq (optional, for `install-hooks` — the agent status column)
- caddy + dnsmasq (optional, for `<feature>.<project>.test` hostnames — see [Hostnames](#hostnames))

### macOS

```bash
brew install tmux overmind gum gh jq
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

### Hostname routing (optional)

Two top-level keys control where the Caddy snippets live and which Caddyfile imports them. The defaults match a Homebrew install:

```yaml
caddy_dir: ~/.workspaces/caddy           # one snippet per workspace
caddyfile: /opt/homebrew/etc/Caddyfile   # must `import <caddy_dir>/*.caddy`
```

### Custom Procfile (optional)

By default, each workspace gets a `Procfile.workspace` with:

```
web: RUBY_DEBUG_OPEN=true bin/rails server -p $RAILS_PORT
vite: bin/vite dev
worker: RUBY_DEBUG_OPEN=true bundle exec sidekiq -C config/sidekiq.yml
```

To customize this, create a `Procfile.workspace` in your project's main path and it will be copied directly into each new workspace. Alternatively, create a `Procfile.workspace.template` which works the same way but signals that the file is a template. If both exist, `Procfile.workspace` takes precedence.

Since Overmind automatically loads `.env` before starting processes, your Procfile can reference environment variables:

```
web: RUBY_DEBUG_OPEN=true bin/rails server -p $RAILS_PORT
vite: VITE_RUBY_PORT=$VITE_RUBY_PORT bin/vite dev
worker: bundle exec sidekiq -q default -q mailers
```


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
3. Copy `.env` (and `config/master.key`, if present) from the main project and add workspace-specific settings (ports, session cookie, Redis DB)
4. Register `http://my-feature.myapp.test` with Caddy (see [Hostnames](#hostnames))
5. Create a tmux session `myapp-my-feature` with:
   - `code` window: vim (with `tmp/my-feature.md` open) + shell
   - `server` window: runs nvm use, bundle install, yarn install, then overmind
6. Generate `tmp/my-feature.md` with workspace details

### Create a workspace from an existing branch

```bash
workspace new myapp my-feature --existing
```

Like `new`, but instead of creating a new branch from the default branch, it creates the worktree from an existing local branch. Useful when you started work directly on a branch in the main checkout and want to move it into its own workspace.

### Pull a remote branch

```bash
workspace pull myapp remote-branch
```

Like `new`, but checks out an existing remote branch instead of creating one. If a PR exists for the branch, its title and description are included in the scratchpad.

### Resume a workspace

```bash
workspace resume myapp my-feature   # Resume one workspace
workspace resume myapp              # Resume all workspaces for project
workspace resume --all              # Resume all workspaces across all projects
```

Re-creates the tmux session and server for an existing worktree (e.g., after a reboot). Reads port configuration from the existing `.env` file and makes sure the workspace's hostname is registered with Caddy.

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
1. If `docs/local` holds untracked files, offer to copy them to `docs/local/rescued-<feature>/` in the main worktree, skip, or abort before anything is torn down
2. Stop overmind
3. Kill the tmux session
4. Confirm, then remove the git worktree
5. Move any Claude Code sessions to the main project (so they appear in `claude resume`)
6. Remove the workspace's hostname from Caddy
7. Confirm, then optionally delete the branch

Because `docs/local` is gitignored, real files there would be lost with the worktree. The rescue prompt copies only real files (symlinks inside `docs/local` point to shared locations that survive deletion, so they're left alone) and defaults to **abort**, so a stray keypress never deletes anything. The feature scratchpad is excluded — it's throwaway by design and deleted with the worktree without prompting (this also covers older workspaces that kept it in `docs/local`).

Use `--force` to skip the confirmations (auto-deletes the branch too, and auto-rescues any `docs/local` files since copying is non-destructive). The main workspace cannot be deleted.

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
workspace list --pr         # Include PR status (slower, queries GitHub)
workspace list myapp --pr   # Specific project with PR status
workspace list --recent     # Sort by last active across projects
```

Shows all active worktrees (including main if initialized) with their hostname and tmux status. Use `--pr` to include PR status (open/merged/closed) via GitHub CLI. The **Status** column reports the state of each workspace's Claude Code session (see below).

The **Last active** column shows when each workspace was last worked on — the newer of its latest Claude Code session activity and its latest git operation (commit/checkout/pull). Within each project, rows sort most-recent-first; `--recent` drops the project grouping and sorts the whole list most-recent-first instead, which is handy after a reboot to see what you had open. Recent activity shows as relative time (`14m ago`, `2d ago`), older activity as a date (`Jun 12`), and a blank means no signal (never used with Claude, no local git activity).

### Agent status

Each workspace's Claude Code session reports what it's doing, so you can glance across your workspaces and see which one is waiting on you. The status shows up in two places.

**In the tmux session chooser** (`prefix + s`) — usually where you decide what to jump into next:

```
(0) + ● tract-main: 2 windows
(1) + ▲ epub-appraisal: 2 windows (attached)
(2) + ○ epub-support-plan: 2 windows
```

**In `workspace list`**, as a Status column:

```
Project  Workspace   Branch     Host                  Tmux     Last active  Status
-----------------------------------------------------------------------------------
myapp    main        main       main.myapp.test       running  2m ago       ● working
myapp    checkout    checkout   checkout.myapp.test   running  8m ago       ▲ needs you
myapp    search      search-ui  search.myapp.test     running  1h ago       ○ idle
myapp    invoices    invoices   invoices.myapp.test            Jun 12
```

- **● working** — a prompt is being worked on
- **▲ needs you** — blocked on a permission prompt, or the turn just finished
- **○ idle** — session started, nothing in flight
- *(blank)* — no live session, or no Claude session reporting

#### How it works

Install the hooks once (requires `jq`):

```bash
workspace install-hooks
```

This merges a small set of hooks into `~/.claude/settings.json` — non-destructively (existing hooks are preserved) and idempotently (re-running won't duplicate). Each Claude session then records its state in its tmux session's `@agent_status` user option. Nothing is written to disk, and nothing happens when `claude` runs outside tmux.

`workspace list` reads that option automatically. To also show it in the tmux session chooser, add the binding `install-hooks` prints to your `~/.tmux.conf`:

```tmux
bind s choose-tree -Zs -F "#{?#{@agent_status},#{@agent_status} ,}#{session_name}: #{session_windows} windows#{?session_attached, (attached),}"
```

Only sessions **started after** installing the hooks report status — restart `claude` in any already-running workspace to pick it up.

### Show port allocations

```bash
workspace ports              # All workspaces
workspace ports --running    # Only workspaces with an active tmux session
```

Shows Rails port, Vite port, Redis DB, and hostname for all workspaces. Use `--running` to limit the table to workspaces that currently have a running tmux session.

## Hostnames

A port number doesn't tell you which project or workspace you're looking at. So on top of `http://localhost:<port>`, every workspace also answers at a readable hostname:

| Workspace                      | Hostname                       |
|--------------------------------|--------------------------------|
| `workspace new myapp my-feature` | `http://my-feature.myapp.test` |
| `workspace new myapp main`       | `http://main.myapp.test`       |

The hostname is a layer on top of the port — ports are assigned exactly as before and remain the source of truth. The hostname key is the worktree directory name (the same key the tmux session uses), lowercased and reduced to `[a-z0-9-]`, so a branch called `Feature/Foo_bar` becomes `feature-foo-bar.myapp.test`.

Two pieces make this work:

1. **DNS** — dnsmasq answers `127.0.0.1` for every `*.test` name (a wildcard; `/etc/hosts` can't do that).
2. **Routing** — Caddy listens on `:80` and picks the workspace's Rails port from the `Host` header. The tool writes one small snippet per workspace into `~/.workspaces/caddy/` and reloads Caddy whenever a workspace is created, resumed, or deleted.

Caddy being absent or stopped is only ever a warning: the port URL keeps working, and the snippets get written regardless so they're ready when Caddy is.

### Setup

Once per machine:

```bash
# 1. Wildcard DNS for .test (skip if `dscacheutil -q host -a name foo.test` already says 127.0.0.1)
brew install dnsmasq
echo 'address=/.test/127.0.0.1' >> /opt/homebrew/etc/dnsmasq.conf
sudo brew services start dnsmasq
sudo mkdir -p /etc/resolver
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/test

# 2. Caddy, importing the tool's snippet directory
brew install caddy            # or `brew upgrade caddy` if it's old
cat > /opt/homebrew/etc/Caddyfile << 'EOF'
import /Users/<you>/.workspaces/caddy/*.caddy
EOF
brew services start caddy     # user-level service; macOS lets it bind :80 without root

# 3. Generate snippets for the workspaces you already have
workspace caddy-sync
```

Then, once per Rails app, allow `.test` hostnames in `config/environments/development.rb`:

```ruby
config.hosts << /\A[a-z0-9.-]+\.test\z/i   # <feature>.<project>.test
```

It has to be a regex: a leading-dot string like `".test"` only allows one subdomain level (`foo.test`), and workspace hostnames have two. Without the line Rails answers with its "Blocked host" page — which at least proves the request reached the right app.

If the app uses Vite (via `vite_ruby`), also point the HMR client at localhost in `vite.config.*`:

```js
server: {
  hmr: { host: 'localhost' },
}
```

Assets already go through Rails' Vite proxy, which rewrites the host, but the HMR websocket connects straight to the Vite port using the page's hostname. Vite 5.4.12+/6.0.9+ rejects that connection unless the host is localhost or listed in `server.allowedHosts`, so without this line the page renders but hot reload silently stops working on `.test` URLs.

Things that need real domains (Wistia's domain allowlist, for one) won't be satisfied by `.test`; for those, keep using an `/etc/hosts` entry plus the app's trusted-host env var by hand.

### Keeping snippets in sync

```bash
workspace caddy-sync
```

Regenerates every snippet from the worktrees on disk (reading each one's `RAILS_PORT`), removes snippets for workspaces that no longer exist, and reloads Caddy. It never touches the worktrees themselves. Run it after setting Caddy up for the first time, or any time hostnames and ports seem out of step. Snippets carry a `# Managed by workspace` header; any other `.caddy` file you put in the directory is left alone.

### Rollback

```bash
brew services stop caddy
```

Everything is exactly as it was: workspaces keep running on their ports, and the tool just prints a one-line warning when it can't reach Caddy. Delete `~/.workspaces/caddy/` and the `import` line if you want the config gone too.

## Workspace Layout

Each workspace gets:

```
~/projects/myapp/my-feature/
├── .env                      # Copied from main + workspace settings
├── .env.test                 # Forces Vite to compile in test env
├── config/master.key         # Copied from main if it exists there (gitignored)
├── Procfile.workspace        # Copied from project or generated from default
└── tmp/
    └── my-feature.md         # Feature scratchpad (throwaway)
```

### Feature scratchpad (`tmp/<feature>.md`)

Each feature workspace gets a notes file under `tmp/` that opens in vim when the workspace starts. Living in `tmp/` keeps it out of git, away from committed docs in `docs/`, and out of the delete-time `docs/local` rescue prompt — it's torn down with the worktree, no questions asked. Older workspaces that still have a scratchpad in `docs/local/` (or `docs/`) keep working; the existing file is found and opened there.

Use it as a scratchpad for AI-assisted development: add context about what you're building, questions, tasks, reminders, and decisions made along the way. Point Claude at it so it has context for your feature.

When the feature is complete, ask Claude to convert the scratchpad into real documentation under `docs/` that can serve as memory/context for future changes or as a reference if you need a reminder of how something works.

## Environment Variables

Each workspace automatically gets:
- `RAILS_PORT` - unique Rails server port
- `VITE_RUBY_PORT` - unique Vite port (RAILS_PORT + 2)
- `SESSION_COOKIE_NAME` - unique cookie name (`<project>_cookie_<port>`)
- `REDIS_URL` - unique Redis DB (`redis://localhost:6379/<N>`)

This allows running multiple workspaces simultaneously without conflicts.

The hostname is not written to `.env` — it's derived from the project and workspace names, and Caddy maps it to `RAILS_PORT`.
