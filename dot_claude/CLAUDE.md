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

### SQL

Whenever the user directly asks you for a SQL query, always indicate the tables fully by database. The database is not always implicit, especially in cross-database queries.

### Docker

- If there is a dockerfile present, use docker to run commands on the codebase.

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

### Git

- Before amending a commit, check if it's already pushed with `git status` (look for "Your branch is ahead of").
- If the commit is already pushed, create a new commit instead of amending.

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
