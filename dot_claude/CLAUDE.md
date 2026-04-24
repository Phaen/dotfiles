# Claude Configuration File

## Guidelines

### Problem Solving - CRITICAL

**When something doesn't work as expected, take a step back and re-evaluate.**

1. **Try the simplest fix first.** If that doesn't work, try ONE more simple thing. If that fails, STOP and ASK.

2. **Never spiral into complexity.** If you find yourself:
   - Adding more code to work around a problem you just created
   - Reimplementing framework functionality with raw PHP/SQL/shell commands
   - Writing "clever" solutions that bypass the normal way of doing things
   - Adding more than 10-15 lines to fix what should be a simple issue

   **STOP IMMEDIATELY.** You are going down the wrong path. Revert and ask for help.

3. **The right solution is almost always simpler than your current approach.** If your fix is getting complicated, you're missing something obvious. Step back, or ask.

4. **When you hit an error after a change:**
   - First: Can you just remove/revert the problematic code?
   - Second: Is there a one-line fix?
   - Third: ASK. Do not iterate through increasingly insane workarounds.

5. **Never write code that fights the framework.** If Laravel/PHP/whatever doesn't want you to do something, that's a sign you shouldn't be doing it - not a challenge to work around.

### SQL

Whenever the user directly asks you for a SQL query, always indicate the tables fully by database. The database is not always implicit, especially in cross-database queries.

### Docker

- If there is a dockerfile present, use docker to run commands on the codebase.
  - The exception are projects by Lento. Those are managed through Herd.
- Only build images with `--no-cache` when you explicitly need to bypass the cache.
- Start containers with `--wait`, to make sure they're fully bootstrapped before taking actions on them.

### Tinkerwell

When asked to create a Tinkerwell script:

- Use Log over echo so the output can be streamed back to the IDE.
- Always create the scripts in the Tinkerwell folder in the project root (this folder is gitignored).

### Databases

Whenever you want to perform any action on a database:

- Use `.env` files to figure out database connections.
- Use configuration files to additionally relate connection names to the actual database names.
- Always do this instead of guessing the details.

### Translations

Whenever you add to a UI and translation helpers are already present in the project:

- Continue to use the helpers for all UI labels that you add.
- Create an agent to add all translations for the newly added labels.

### Git

- Before amending a commit, check if it's already pushed with `git status` (look for "Your branch is ahead of").
- If the commit is already pushed, create a new commit instead of amending.
- When a user mentions a pipeline, this automatically implies that the commit was already pushed.

### Chezmoi

When deleting files managed by chezmoi (any file in the dotfiles structure below):

- Use `chezmoi remove <file>` instead of `rm` to keep the source state in sync.
- Check if a file is managed with `chezmoi managed --include=files | grep -q <path>`.

## Shell environment

These commands and utilities are always available in this environment.

### Docker shortcuts

> Use these whenever possible. Never reference them in documentation or project scripts — they only exist in this environment.

- `d <cmd>` — exec `<cmd>` in the project container (auto-detected via git root + mounted volume)
- `dlog` — follow project container logs
- `da <cmd>` — `d php artisan <cmd>`
- `dstan [args]` — `d php vendor/bin/phpstan --memory-limit=2G [args]`
- `fdex <query>` / `fdlog <query>` — fzf-select a container by name, then exec/log
- `dserv [-p]` — stop containers on ports 80/465, fzf-select and start another; `-p` starts the full Compose project

### Utilities

- `cdf [query]` — fzf-select an immediate subdirectory and cd into it
- `persistent <cmd>` — auto-restart a command on exit with a 1s delay
- `venv` — `source venv/bin/activate`
- `sudou` — `sudo TERM=xterm-256color -iu` (avoids kitty terminal type issues when sudoing)

### PATH

The following dirs are automatically prepended to `$PATH` if they exist: `~/.local/bin`, `~/bin`, `~/.npm-global/bin`, `~/.cargo/bin`, `~/.composer/vendor/bin`, `~/.config/composer/vendor/bin`, `~/.yarn/bin`, `~/.pyenv/bin`, `~/.rbenv/bin`, `~/.deno/bin`.

## Dotfiles

Shell config loads in this order:

1. `~/.zshrc` / `~/.bashrc` — framework (Oh My Zsh / Bash-it), activates mise, sources `~/.custom`
2. `~/.custom` — defines helpers (`source_local`, `source_optional`, `command_exists`), sources `~/.custom.d/*`, then `~/.custom.local`
3. `~/.custom.d/*.sh` — the shell environment scripts above (`environment.sh`, `docker.sh`, `misc.sh`, `provision.sh`)
4. `~/.custom.local` / `~/.zshrc.local` / `~/.bashrc.local` — machine-local overrides, untracked

This file and everything above is managed by chezmoi (`~/.local/share/chezmoi` → `git@github.com:Phaen/dotfiles.git`, autoCommit + autoPush). Also tracked: `~/.config/kitty/`, `~/.config/nvim/`, `~/.config/tmux/tmux.conf.local`, and `~/.claude/CLAUDE.md`. External tools — Oh My Zsh, Bash-it, Powerlevel10k, tmux base config — are pulled via `.chezmoiexternal.toml` and refreshed weekly; don't edit them directly.
