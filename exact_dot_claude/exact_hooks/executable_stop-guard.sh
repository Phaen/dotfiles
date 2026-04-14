#!/usr/bin/env bash
# Stop event
# Blocks stopping when a solve tree is incomplete.
# Also catches laziness, permission-seeking, and ownership-dodging phrases.

INPUT=$(cat)
SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
MESSAGE=$(echo "$INPUT" | jq -r '.assistant_response // .message // ""' 2>/dev/null)


if [ -z "$MESSAGE" ]; then
  exit 0
fi

LOWER=$(echo "$MESSAGE" | tr '[:upper:]' '[:lower:]')

# Permission-seeking
if echo "$LOWER" | grep -qE "(should i continue|want me to (continue|keep going|proceed)|shall i (continue|proceed)|would you like me to continue|do you want me to|is it okay if i|may i proceed)"; then
  echo "STOP BLOCKED: Do not ask for permission to continue. Complete the task autonomously." >&2
  exit 2
fi

# Premature stopping
if echo "$LOWER" | grep -qE "(good (stopping|pause) point|natural (checkpoint|stopping|break)|i.ll stop here|stopping here for now|this is a good place to (stop|pause))"; then
  echo "STOP BLOCKED: Do not declare stopping points mid-task. Continue working." >&2
  exit 2
fi

# Ownership dodging
if echo "$LOWER" | grep -qE "(not caused by my (changes|code|edit)|this (is|was) (an )?existing (issue|bug|problem)|not (related to|my) (change|edit)|pre-existing|was already (broken|there) before)"; then
  echo "STOP BLOCKED: Do not dodge ownership. Fix the problem or surface it explicitly to the user." >&2
  exit 2
fi

# Session-length excuses
if echo "$LOWER" | grep -qE "(continue in a new (session|conversation)|context (is getting|getting) (long|large)|session (is|getting) (too |very )?long)"; then
  echo "STOP BLOCKED: Do not use session length as a reason to stop." >&2
  exit 2
fi

exit 0
