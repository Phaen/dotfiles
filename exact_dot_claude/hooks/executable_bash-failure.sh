#!/usr/bin/env bash
# PostToolUse: Bash
# Re-locks the edit gate when a test or build command fails during implementation.
# Only fires when state is "resolved" (actively implementing) — failures during
# investigation within a solve tree are expected and do not re-lock.

INPUT=$(cat)
SESSION=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)

if [ -z "$SESSION" ]; then
  exit 0
fi

STATE_FILE="${PWD}/.claude/solve_state_${SESSION}"

# Only care if we're actively implementing (resolved state)
if [ ! -f "$STATE_FILE" ] || [ "$(cat "$STATE_FILE" 2>/dev/null)" != "resolved" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // empty' 2>/dev/null)
OUTPUT=$(echo "$INPUT" | jq -r '(.tool_response.output // "") | tostring' 2>/dev/null)

# Only trigger on test/build/lint commands
if ! echo "$COMMAND" | grep -qiE '(test|phpunit|jest|pytest|make|build|artisan test|npm test|yarn test|cargo test|go test|rspec|mocha|phpstan|eslint|tsc |composer|sail test)'; then
  exit 0
fi

FAILED=0

if [ -n "$EXIT_CODE" ] && [ "$EXIT_CODE" != "0" ]; then
  FAILED=1
fi

if echo "$OUTPUT" | grep -qiE '(FAILED|FAIL:|Tests:.*failed|Build failed|fatal error|Compilation failed|assertion.*failed|error\[E[0-9]+\]|PHPStan.*error)'; then
  FAILED=1
fi

if [ "$FAILED" -eq 1 ]; then
  mkdir -p "${PWD}/.claude" 2>/dev/null
  echo "required" > "$STATE_FILE"
  echo "FAILURE DETECTED: Edit gate re-locked. A new solve tree is required before further changes. Invoke /solve with the failure as input."
fi

exit 0
