#!/usr/bin/env bash
# UserPromptSubmit: auto-write "solving" state when /solve is invoked.

INPUT=$(cat)
SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

if [ -z "$SESSION" ]; then
  exit 0
fi

if ! echo "$PROMPT" | grep -qE '^\s*/solve(\s|$)'; then
  exit 0
fi

PROJECT_SLUG=$(echo "$PWD" | tr '/' '-')
TRANSCRIPT="$HOME/.claude/projects/${PROJECT_SLUG}/${SESSION}.jsonl"
LINE_COUNT=0
if [ -f "$TRANSCRIPT" ]; then
  LINE_COUNT=$(wc -l < "$TRANSCRIPT" | tr -d ' ')
fi

mkdir -p "${PWD}/.claude"
echo "solving:${LINE_COUNT}" > "${PWD}/.claude/solve_state_${SESSION}"
