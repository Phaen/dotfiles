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

### Tests

- Never mention passing tests unprompted. A complete implementation already assumes that all related tests passed. Things like "all tests green" is just noise.

### SQL

- Whenever the user directly asks you for a SQL query, always indicate the tables fully by database. The database is not always implicit, especially in cross-database queries.

### Comments

- NEVER write imperatives in code comments. This is not StackOverflow where you're providing context alongside the code. The context belongs in the session, while the code and its comments should remain self-contained.

### Docker

- If there is a dockerfile present, use docker to run commands on the codebase.
- Only build images with `--no-cache` when you explicitly need to bypass the cache.
- Start containers with `--wait`, to make sure they're fully bootstrapped before taking actions on them.

### Tinkerwell

When asked to create a Tinkerwell script:

- Use Log over echo so the output can be streamed back to the IDE.
- Always create the scripts in the Tinkerwell folder in the project root (this folder is gitignored).
- Do not prefix the script with `declare(strict_types=1);` — it does not work in Tinkerwell.

### Databases

Whenever you want to perform any action on a database:

- Use `.env` files to figure out database connections.
- Use configuration files to additionally relate connection names to the actual database names.

### Translations

Whenever you add to a UI and translation helpers are already present in the project:

- Continue to use the helpers for all UI labels that you add.
- When wrapping up an implementation (on commit, etc.) create an agent to add all translations for all newly added labels.

### Git

- Before amending a commit, check if it's already pushed with `git status` (look for "Your branch is ahead of").
- If the commit is already pushed, create a new commit instead of amending.
- When a user mentions CI, this automatically implies that the commit was already pushed.

### Chezmoi

When deleting files managed by chezmoi (any file in the dotfiles structure below):

- Use `chezmoi remove <file>` instead of `rm` to keep the source state in sync.
- Check if a file is managed with `chezmoi managed --include=files | grep -q <path>`.

## Code Delegation — Architect/Builder Protocol

Expensive-model (Fable) output tokens are the scarce resource; input tokens and cheap-model output are not. Fable architects and verifies; cheaper models write the code.

**Trigger — the compression test.** Before writing any code, estimate whether a spec (decisions + signatures + edge cases) would be much smaller than the finished code. High ratio — boilerplate, tests, CRUD, migrations, markup, repetitive multi-file edits — means delegate. Ratio near 1 — novel algorithms, subtle logic — means no savings, so write it yourself. Also skip delegation when the edit is so small that dispatch overhead dominates (under ~20 lines), when diagnosis is the actual work, when the code is security-critical enough that review costs as much as authorship, or when the design is still churning with the user.

1. **Architect.** Close every decision that has more than one plausible answer: files, signatures with types, data flow, edge cases, error behavior, what not to touch. Anything left open comes back as a wrong guess or a round-trip.
2. **Spec.** Minified pseudocode, zero prose: `CREATE|MODIFY <path>` per unit; signatures; compact control flow; edge cases as one-liners; pattern refs instead of restated conventions ("mirror `app/.../UserController.php`" transfers house style for a few tokens); end with a `VERIFY:` line listing the risk points to check after the build — written now, while the risks are fresh.
3. **Dispatch.** Agent tool, one builder per independent unit, partitioned by file — parallel builders must never share a file. Model: Sonnet by default, Opus when the unit needs local judgment, Haiku for purely mechanical sweeps (renames, translation fills).
4. **Builder contract** (goes in the prompt): read the pattern-ref files first; follow the spec exactly; decide nothing architectural — if the spec is ambiguous, return `QUESTION: …` instead of guessing; report only changed paths, deviations, and questions — never echo code back.
5. **Q&A.** Answer a `QUESTION:` via SendMessage to the same agent — its context is warm. Never re-dispatch a fresh agent just to answer one.
6. **Verify cheap-first.** Machine checks first (tests, static analysis), then read the diff only at the spec's `VERIFY:` points. Boring code that passes checks does not get re-read line by line.
7. **Repair.** Small miss: fix it with a targeted edit yourself. Structural miss: correct the spec and re-dispatch the same agent. Two failed rounds: write that unit yourself (consistent with the problem-solving rule above).

Example spec:

```
MODIFY app/Models/Invoice.php: + scopeOverdue($q) => due_at < now(), status != paid
CREATE app/Http/Controllers/InvoiceReminderController.php:
  __invoke(Request): authorize 'remind' else 403; Invoice::overdue()->chunkById(500, dispatch SendReminder each); return 202 {queued: n}
CREATE tests/Feature/InvoiceReminderTest.php: happy, 403, zero-overdue => {queued: 0}; mirror tests/Feature/InvoiceArchiveTest.php
VERIFY: chunkById not get() (memory); count accurate across chunks; 403 before any dispatch
```

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

### PATH

The following dirs are automatically prepended to `$PATH` if they exist: `~/.local/bin`, `~/bin`, `~/.npm-global/bin`, `~/.cargo/bin`, `~/.composer/vendor/bin`, `~/.config/composer/vendor/bin`, `~/.yarn/bin`, `~/.pyenv/bin`, `~/.rbenv/bin`, `~/.deno/bin`.

### Dotfiles

Shell config loads in this order:

1. `~/.zshrc` / `~/.bashrc` — framework (Oh My Zsh / Bash-it), activates mise, sources `~/.custom`
2. `~/.custom` — defines helpers (`source_local`, `source_optional`, `command_exists`), sources `~/.custom.d/*`, then `~/.custom.local`
3. `~/.custom.d/*.sh` — the shell environment scripts above (`environment.sh`, `docker.sh`, `misc.sh`, `provision.sh`)
4. `~/.custom.local` / `~/.zshrc.local` / `~/.bashrc.local` — machine-local overrides, untracked

This file and everything above is managed by chezmoi (`~/.local/share/chezmoi` → `git@github.com:Phaen/dotfiles.git`, autoCommit + autoPush). Also tracked: `~/.config/kitty/`, `~/.config/nvim/`, `~/.config/tmux/tmux.conf.local`, and `~/.claude/CLAUDE.md`. External tools — Oh My Zsh, Bash-it, Powerlevel10k, tmux base config — are pulled via `.chezmoiexternal.toml` and refreshed weekly; don't edit them directly.

## Context

This is a multi-machine `CLAUDE.md` and may run across both MacOS and Linux.

### Lento

Lento projects reside in ~/Lento, for these apply the following:

- Never use docker for the project itself. The projects are served raw on the command line and proxied through Valet.
- Its resources are served through a docker compose stack at ~/lento/docker-compose

### Cage Undefined

Cage Undefined projects reside in ~/CU, for these apply the following:

- I'm the executive director. My actions regularly bypass the regular chain (e.g. pushing directly to main, etc.)
- These are animal rights projects and their impact saves lives.
