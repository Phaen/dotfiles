#!/bin/bash
# Session handoff: renames handoff file and points agent to it
# Triggered by SessionStart hook

HANDOFF_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/session-handoff.md"

if [ ! -f "$HANDOFF_FILE" ]; then
  exit 0
fi

# Read hook input
INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')

# Only apply on new sessions and /clear, not resume or compact
if [ "$SOURCE" != "startup" ] && [ "$SOURCE" != "clear" ]; then
  exit 0
fi

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Extract previous session ID from handoff metadata
PREV_SESSION_ID=$(sed -n 's/.*<!-- previous_session: \(.*\) -->/\1/p' "$HANDOFF_FILE")
PREV_TRANSCRIPT=""
if [ -n "$PREV_SESSION_ID" ] && [ -n "$TRANSCRIPT_PATH" ]; then
  PREV_TRANSCRIPT="$(dirname "$TRANSCRIPT_PATH")/${PREV_SESSION_ID}.jsonl"
fi

# Rename the handoff file so it's not picked up again
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S)
ARCHIVED_FILE="${HANDOFF_FILE%.md}-${TIMESTAMP}.md"
mv "$HANDOFF_FILE" "$ARCHIVED_FILE"

# Get the relative path for the agent
RELATIVE_PATH=".claude/$(basename "$ARCHIVED_FILE")"

# Build context message
CONTEXT="A session handoff file from a previous session exists at ${RELATIVE_PATH}. Read this file immediately to understand the context and objectives from the previous session."

if [ -n "$PREV_TRANSCRIPT" ] && [ -f "$PREV_TRANSCRIPT" ]; then
  CONTEXT="${CONTEXT} The previous session transcript is at ${PREV_TRANSCRIPT}. WARNING: Do NOT read it broadly — the previous session may have gone down wrong paths. Only consult specific sections of the transcript when you need to look up a concrete detail (e.g. an error message, a file path, a specific decision). Form your own approach based on the handoff summary, not the previous session's approach."
fi

CONTEXT="${CONTEXT} When the objective described in the handoff appears to be complete, ask the user if they would like you to delete the handoff file."

# Point agent to the renamed file (don't embed contents)
jq -n \
  --arg context "$CONTEXT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": $context
    }
  }'

exit 0
