# Claude Configuration File

## Guidelines

### Problem Solving - CRITICAL

**When something doesn't work, STOP and THINK before acting:**

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

6. **Code from a place of insecurity.** Work is delegated to you to save time, not to outsource expertise. When your solution is getting complex and out of scope, stop and ask the user first. The user always knows better.

### SQL

Whenever the user directly asks you for a SQL query, always indicate the tables fully by database. The database is not always implicit, especially in cross-database queries.

### Docker

- If there is a dockerfile present, use docker to run commands on the codebase.
- Only build images with `--no-cache` when you explicitly need to bypass the cache
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

Whenever you add to an UI and translation helpers are already present in the project:

- Continue to use the helpers for all UI labels that you add.
- Create an agent to add all translations for the newly added labels.

### Chezmoi

When deleting files in a directory that is NOT a git repo but IS managed by chezmoi:

- Use `chezmoi remove <file>` instead of `rm` to keep the source state in sync.
- Check if a directory is chezmoi-managed with `chezmoi managed --include=files | grep -q <path>`.

#### Dotfiles structure

Chezmoi source: `~/.local/share/chezmoi` → remote `git@github.com:Phaen/dotfiles.git` (autoCommit + autoPush enabled).

Shell config loads in this order:
1. `~/.zshrc` / `~/.bashrc` (chezmoi-tracked) — loads Oh My Zsh / Bash-it, sources `~/.custom`
2. `~/.custom` (chezmoi-tracked) — defines helpers (`source_local`, `source_optional`, `command_exists`), sources all `~/.custom.d/*.sh`, then sources `~/.custom.local`
3. `~/.custom.d/` (chezmoi-tracked, `exact_dot_custom.d`) — modular scripts: `docker.sh`, `environment.sh`, `misc.sh`, `provision.sh`
4. `~/.zshrc.local` / `~/.bashrc.local` — machine-specific overrides (not tracked, sourced via `source_local`)
5. `~/.custom.local` — machine-specific extras (not tracked, optional)

Key conventions:
- **`.local` files** = machine-specific, never in git.
- **`exact_dot_` prefix** in chezmoi = directory contents are fully controlled (extra files get deleted on `chezmoi apply`). Used for `~/.custom.d/` and `~/.claude/`.
- **`.chezmoiignore`** selectively tracks `~/.claude/`: only `CLAUDE.md`, `settings.json`, `commands/`, and `hooks/` are synced.
- **`.chezmoiexternal.toml`** pulls Oh My Zsh, plugins (zsh-syntax-highlighting, laravel-sail), powerlevel10k theme, bash-it, and tmux config from upstream archives/repos with weekly refresh.

### Git

- Before amending a commit, check if it's already pushed with `git status` (look for "Your branch is ahead of").
- If the commit is already pushed, create a new commit instead of amending.
- When a user mentions a pipeline, this automatically implies that the commit was already pushed.

## Useful shortcuts

### Docker

These commands will automatically identify the relevant docker container for you. They only exist in my environment, so do not reference them in documentation or anywhere else, but do use them whenever possible.
`d` - Execute the proceeding command in docker
`da` - Execute the proceeding artisan command in docker
`dstan` - Run phpstan in docker

Examples:
`d ls vendor`
`da migrate:fresh`
`dstan --generate-baseline`
