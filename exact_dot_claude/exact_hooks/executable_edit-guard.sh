#!/usr/bin/env bash
# PreToolUse: Edit, Write, MultiEdit
# Blocks edits when a solve tree is required or in progress.

INPUT=$(cat)
SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)

if [ -z "$SESSION" ]; then
  exit 0
fi

STATE_FILE="${PWD}/.claude/solve_state_${SESSION}"

if [ ! -f "$STATE_FILE" ]; then
  exit 0  # No active solve session — allow freely
fi

STATE=$(cat "$STATE_FILE" 2>/dev/null)

case "$STATE" in
  resolved)
    exit 0
    ;;
  solving*)
    echo "EDIT BLOCKED: Solve tree is in progress. Complete investigation and reach a <resolved> branch before making any changes." >&2
    exit 2
    ;;
  required)
    echo "EDIT BLOCKED: A failure was detected during implementation. Run /solve on the new problem before making further changes." >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
