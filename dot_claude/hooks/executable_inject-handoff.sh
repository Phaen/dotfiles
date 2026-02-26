#!/bin/bash
# Injects session-handoff.md contents into Claude's context after /clear
# Triggered by SessionStart hook

HANDOFF_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/session-handoff.md"

if [ ! -f "$HANDOFF_FILE" ]; then
  exit 0
fi

CONTEXT=$(cat "$HANDOFF_FILE")

# Archive the handoff file with a timestamp so it's only injected once
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S)
mv "$HANDOFF_FILE" "${HANDOFF_FILE%.md}-${TIMESTAMP}.md"

jq -n \
  --arg context "# Session Handoff (from previous session)

$CONTEXT

---
This handoff was written by the previous session. The file is at .claude/session-handoff.md. Delete it when the task is complete." \
  '{
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": $context
    }
  }'

exit 0
