---
allowed-tools: Read(*/.claude/session-handoff-*.md), Read(*.jsonl), Glob(.claude/session-handoff-*.md)
---

# Pickup Session Handoff

Pick up a handoff from a previous session.

## Steps

1. Glob for `.claude/session-handoff-*.md` in the project root. If `$ARGUMENTS` is provided, pick the handoff whose subject matches. Otherwise pick the most recent one (Glob results are sorted by modification time, so the last result is the newest).
2. Read it and use its contents to understand the context and objectives from the previous session.
3. Extract the `<!-- previous_session: <id> -->` and `<!-- previous_project: <dir> -->` metadata. The transcript lives at `~/.claude/projects/<slug>/<id>.jsonl` where `<slug>` is `<dir>` with `/` replaced by `-`. If it exists, keep it in mind — but do NOT read it broadly. The previous session may have gone down wrong paths. Only consult specific sections when you need to look up a concrete detail (e.g. an error message, a file path, a specific decision). Form your own approach based on the handoff summary.
4. Greet the user with a brief summary of what you picked up and what you'll focus on.
5. When the objective described in the handoff appears to be complete, ask the user if they would like you to delete the handoff file.
