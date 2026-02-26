# Session Handoff

Create a handoff summary for the next session context, written to `.claude/session-handoff.md` in the project root.

## Arguments

`$ARGUMENTS` = The user's description of what matters. This is the PRIMARY input. Structure the entire handoff around what the user tells you here.

## How to write the summary

Start from the user's arguments. They tell you what the task is, what's important, what to focus on next. Use that as the backbone of the summary.

Then supplement with technical details from the conversation that support the user's description:
- File paths, class names, method names that were discussed or modified
- Key decisions or constraints that were established
- Errors or blockers encountered
- Code patterns or approaches agreed upon

Be specific: use actual paths and names, not vague descriptions. Include short code snippets only when they capture a critical pattern.

## Output format

Write the summary as a clear, scannable markdown file. No rigid template - structure it in whatever way best serves the user's description. Keep it concise but complete.

## Context

The handoff file is automatically picked up by the next session via a SessionStart hook.
