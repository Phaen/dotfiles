#!/bin/bash
# Auto-approve writes to the session-handoff file
# Triggered by PreToolUse hook for Write tool

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *"/.claude/session-handoff.md" ]]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow"
    }
  }'
fi

exit 0
