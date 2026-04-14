#!/usr/bin/env bash
# Writes solve state for the current project + session.
# Usage: solve-state.sh <session_id> <state>
# States: solving, resolved
#
# When writing "resolved", validates the session transcript to ensure the solve
# tree is structurally complete before unlocking the edit gate.
#
# Bypass note: echo:* and python3:* are allow-listed in settings.json and can
# write state files directly. This is intentional — the threat model is shallow
# thinking, not deliberate sabotage. A motivated Claude could bypass this system
# trivially; the guard only compensates for reasoning depth regression.

SESSION="$1"
STATE="$2"

if [ -z "$SESSION" ] || [ -z "$STATE" ]; then
  echo "Usage: solve-state.sh <session_id> <state>" >&2
  exit 1
fi

if [ "$STATE" = "resolved" ]; then
  PROJECT_SLUG=$(echo "$PWD" | tr '/' '-')
  TRANSCRIPT="$HOME/.claude/projects/${PROJECT_SLUG}/${SESSION}.jsonl"

  if [ ! -f "$TRANSCRIPT" ]; then
    echo "RESOLVE BLOCKED: Transcript not found at $TRANSCRIPT — cannot verify solve tree. Ensure the session was started from the correct project directory." >&2
    exit 1
  fi

  # Read start line from state file (written by solve-trigger.sh)
  STATE_FILE="${PWD}/.claude/solve_state_${SESSION}"
  START_LINE=0
  if [ -f "$STATE_FILE" ]; then
    STATE_CONTENT=$(cat "$STATE_FILE")
    START_LINE="${STATE_CONTENT#*:}"
    if ! echo "$START_LINE" | grep -qE '^[0-9]+$'; then
      START_LINE=0
    fi
  fi

  TMPPY=$(mktemp /tmp/solve_check_XXXXXX.py)
  cat > "$TMPPY" << 'PYEOF'
import sys, json, re, xml.etree.ElementTree as ET

transcript_path = sys.argv[1]
start_line = int(sys.argv[2])

entries = []
with open(transcript_path) as f:
    for i, line in enumerate(f):
        line = line.strip()
        if line:
            entries.append((i, json.loads(line)))

# Scope to entries after the trigger line
entries = [obj for (i, obj) in entries if i >= start_line]

# Build XML and combined text by iterating entries block by block:
#   - assistant text block  → extract structural tags, accumulate text
#   - assistant tool_use    → append <tool/> (only when inside <investigate>)
#
# Container tracking: once inside investigate/resolved/selected/blocked, stop
# extracting structural tags from text until the matching closing tag is seen.
# This prevents prose references like "<resolved id="1">: reason" inside a
# <selected> block from being extracted as structural elements.
#
# ID filter: only opening tags with numeric IDs (e.g. id="1", id="1.1") are
# extracted. Template examples use letters like "N" or "M" and are ignored.
TAG_RE = re.compile(r'<(/?)(problem|solution|investigate|resolved|selected|cull|blocked|compare)(\s[^>]*)?\s*/?>')
ID_RE  = re.compile(r'\bid=["\']?([\d.]+)["\']?')

xml_parts = ['<root>']
text_parts = []
current_container = None  # name of the currently open container tag, or None
tree_done = False          # True once </selected> is seen — tree is complete

for obj in entries:
    if tree_done or obj.get('type') != 'assistant':
        continue
    for block in obj.get('message', {}).get('content', []):
        if tree_done or not isinstance(block, dict):
            continue
        if block.get('type') == 'text':
            text = block.get('text', '')
            text_parts.append(text)
            for m in TAG_RE.finditer(text):
                slash = m.group(1)
                name  = m.group(2)
                attrs = m.group(3) or ''
                if current_container:
                    # Inside a container: only look for its closing tag
                    if slash and name == current_container:
                        xml_parts.append(m.group(0))
                        if name in ('selected', 'blocked'):
                            tree_done = True
                        current_container = None
                else:
                    # At root level.
                    # compare/blocked have no id — emit unconditionally.
                    # All other tags require a numeric id (filters template examples).
                    if slash:
                        continue  # stray closing tag — skip
                    if name not in ('compare', 'blocked', 'problem') and not ID_RE.search(attrs):
                        continue
                    xml_parts.append(m.group(0))
                    # cull and selected are self-closing; don't enter container mode
                    is_self_closing = name in ('cull', 'selected') or m.group(0).rstrip().endswith('/>')
                    if not is_self_closing:
                        current_container = name
        elif block.get('type') == 'tool_use':
            # Only inject <tool/> inside <investigate> blocks
            if current_container == 'investigate':
                xml_parts.append('<tool/>')

xml_parts.append('</root>')
combined = '\n'.join(text_parts)

xml_str = ''.join(xml_parts)
try:
    root = ET.fromstring(xml_str)
except ET.ParseError as e:
    _, col = e.position
    snippet = xml_str[max(0, col - 40):col + 40]
    print(f'PARSE_ERROR: Structural tags produced invalid XML at col {col}: ...{snippet}...')
    sys.exit()

# Deduplicate: keep only the last occurrence of each (tag, id).
# This allows the agent to correct a broken block by rewriting it with the same ID.
for tag in ('solution', 'investigate', 'resolved', 'cull', 'selected'):
    seen = {}
    for el in root.findall(tag):
        key = el.get('id', '')
        if key in seen:
            root.remove(seen[key])
        seen[key] = el

solution_els     = root.findall('solution')
investigated_els = root.findall('investigate')
resolved_els     = root.findall('resolved')
culled_els       = root.findall('cull')
selected_els     = root.findall('selected')
compare_els      = root.findall('compare')
blocked_el       = root.find('blocked')

solution_ids     = {el.get('id') for el in solution_els}
investigated_ids = {el.get('id') for el in investigated_els}
resolved_ids     = {el.get('id') for el in resolved_els}
culled_ids       = {el.get('id') for el in culled_els}

# Check 0a: a culled solution must have been investigated, have at least one sub-problem,
# and at least one of those sub-problems must be fully exhausted — meaning it has solutions
# declared and every one of those solutions is itself culled.
# (Early exit is allowed: other sub-problems may be left uninvestigated once a fatal one is found.)
def all_solutions_culled(problem_id):
    """True if problem_id is unsolvable: either no solutions could be proposed,
    or all proposed solutions were themselves culled."""
    prefix = problem_id + '.'
    child_solutions = {sid for sid in solution_ids
                       if sid.startswith(prefix) and '.' not in sid[len(prefix):]}
    return not child_solutions or child_solutions.issubset(culled_ids)

invalid_culls = []
for cid in culled_ids:
    if cid not in investigated_ids:
        invalid_culls.append(cid)
        continue
    prefix = cid + '.'
    direct_subproblems = [pid for pid in problem_ids
                          if pid.startswith(prefix) and '.' not in pid[len(prefix):]]
    if not direct_subproblems:
        invalid_culls.append(cid)
        continue
    # At least one sub-problem must be fully exhausted (has solutions, all culled)
    if not any(all_solutions_culled(pid) for pid in direct_subproblems):
        invalid_culls.append(cid)
if invalid_culls:
    print('INVALID_CULL:' + ','.join(sorted(invalid_culls)))
    sys.exit()

# Check 0: every solution (at any level) must be culled or resolved
if solution_ids:
    unaccounted = solution_ids - resolved_ids - culled_ids
    if unaccounted:
        print('UNACCOUNTED:' + ','.join(sorted(unaccounted)))
        sys.exit()

# Check 0b: every sub-problem under an active (non-culled) solution must have at
# least one resolved direct-child solution. Sub-problems under culled solutions
# are irrelevant — skip them. This check recurses implicitly: a solution can only
# be <resolved> if its own sub-problems already passed this check.
problem_els = root.findall('problem')
problem_ids = {el.get('id') for el in problem_els if el.get('id')}
unresolvable_problems = []
for pid in sorted(problem_ids):  # sorted so errors are deterministic
    # Find parent solution ID: problem 1.1 → parent solution 1; 1.1.1.1 → 1.1.1
    parent_solution = pid.rsplit('.', 1)[0] if '.' in pid else None
    # Skip if parent solution is culled (dead branch — sub-problem is irrelevant)
    if parent_solution in culled_ids:
        continue
    prefix = pid + '.'
    direct_children = {sid for sid in solution_ids
                       if sid.startswith(prefix) and '.' not in sid[len(prefix):]}
    # Fail if: no solutions declared at all, or all declared solutions were culled
    if not direct_children or not (direct_children & resolved_ids):
        unresolvable_problems.append(pid)
if unresolvable_problems:
    print('UNRESOLVABLE_PROBLEM:' + ','.join(sorted(unresolvable_problems)))
    sys.exit()

# Check 1: at least one resolved
if not resolved_ids:
    print('NO_RESOLVED')
    sys.exit()

# Check 2: every resolved has a corresponding investigate
missing_investigate = resolved_ids - investigated_ids
if missing_investigate:
    print('MISSING_INVESTIGATE:' + ','.join(sorted(missing_investigate)))
    sys.exit()

# Check 2b: every investigate has a corresponding solution
orphan_investigate = investigated_ids - solution_ids
if orphan_investigate:
    print('ORPHAN_INVESTIGATE:' + ','.join(sorted(orphan_investigate)))
    sys.exit()

# Check 3: every investigate contains at least one <tool/>
no_tools = [el.get('id') for el in investigated_els if el.find('tool') is None]
if no_tools:
    print('NO_TOOLS_IN_INVESTIGATE:' + ','.join(sorted(no_tools)))
    sys.exit()

# Check 4 & 5: selection and comparison (only for top-level resolved)
top_level_resolved = {rid for rid in resolved_ids if '.' not in rid}
if len(top_level_resolved) > 1:
    if not selected_els:
        print('NO_SELECTED')
        sys.exit()
    if len(selected_els) > 1:
        print('MULTIPLE_SELECTED:' + ','.join(el.get('id') for el in selected_els))
        sys.exit()

    # <compare> block must exist and mention every non-selected resolved ID
    selected_id = selected_els[0].get('id')
    other_resolved = top_level_resolved - {selected_id}
    if not compare_els:
        print('NO_COMPARE')
        sys.exit()
    # Content check: use last <compare> block from raw text
    compare_match = None
    for compare_match in re.finditer(r'<compare>(.*?)</compare>', combined, re.DOTALL):
        pass  # keep last
    compare_content = compare_match.group(1) if compare_match else ''
    unmentioned = [rid for rid in other_resolved if rid not in compare_content]
    if unmentioned:
        print('MISSING_COMPARISON:' + ','.join(sorted(unmentioned)))
        sys.exit()

print('OK')
PYEOF

  RESULT=$(python3 "$TMPPY" "$TRANSCRIPT" "$START_LINE" 2>/tmp/solve_check_err.txt)
  PY_EXIT=$?
  rm -f "$TMPPY"

  if [ $PY_EXIT -ne 0 ]; then
    echo "RESOLVE BLOCKED: Validator crashed — $(cat /tmp/solve_check_err.txt)" >&2
    exit 1
  fi

  case "$RESULT" in
    INVALID_CULL:*)
      IDS="${RESULT#INVALID_CULL:}"
      echo "RESOLVE BLOCKED: Solution(s) [${IDS}] were culled without being investigated or without declaring a sub-problem. Culling requires a concrete blocker — investigate first, declare the sub-problem, then cull." >&2
      exit 1 ;;
    UNACCOUNTED:*)
      IDS="${RESULT#UNACCOUNTED:}"
      echo "RESOLVE BLOCKED: Solution(s) [${IDS}] from <solutions> were never marked <cull> or <resolved>. Every solution must be explicitly accounted for." >&2
      exit 1 ;;
    NO_RESOLVED)
      echo "RESOLVE BLOCKED: No <resolved id=\"N\"> tags found. Complete the solve tree before unlocking." >&2
      exit 1 ;;
    MISSING_INVESTIGATE:*)
      IDS="${RESULT#MISSING_INVESTIGATE:}"
      echo "RESOLVE BLOCKED: Solution(s) [${IDS}] marked <resolved> without a corresponding <investigate> block." >&2
      exit 1 ;;
    UNRESOLVABLE_PROBLEM:*)
      IDS="${RESULT#UNRESOLVABLE_PROBLEM:}"
      echo "RESOLVE BLOCKED: Sub-problem(s) [${IDS}] have no resolved solution — all child solutions were culled. The parent solution cannot be resolved." >&2
      exit 1 ;;
    ORPHAN_INVESTIGATE:*)
      IDS="${RESULT#ORPHAN_INVESTIGATE:}"
      echo "RESOLVE BLOCKED: <investigate> block(s) [${IDS}] have no corresponding <solution>. Every investigation must match a declared solution." >&2
      exit 1 ;;
    NO_TOOLS_IN_INVESTIGATE:*)
      IDS="${RESULT#NO_TOOLS_IN_INVESTIGATE:}"
      echo "RESOLVE BLOCKED: Investigation of solution(s) [${IDS}] contained no tool calls. Investigations must use Read, Grep, Glob, or Bash — not just prose." >&2
      exit 1 ;;
    NO_SELECTED)
      echo "RESOLVE BLOCKED: Multiple resolved branches exist but no <selected id=\"N\"/> tag found." >&2
      exit 1 ;;
    NO_COMPARE)
      echo "RESOLVE BLOCKED: Multiple resolved branches exist but no <compare> block found. Compare all resolved options before selecting." >&2
      exit 1 ;;
    MULTIPLE_SELECTED:*)
      IDS="${RESULT#MULTIPLE_SELECTED:}"
      echo "RESOLVE BLOCKED: Multiple <selected> tags found [${IDS}]. Only one solution may be selected." >&2
      exit 1 ;;
    MISSING_COMPARISON:*)
      IDS="${RESULT#MISSING_COMPARISON:}"
      echo "RESOLVE BLOCKED: <selected> block does not compare against resolved alternative(s) [${IDS}]. Every resolved alternative must be explicitly rejected with a reason." >&2
      exit 1 ;;
    PARSE_ERROR:*)
      MSG="${RESULT#PARSE_ERROR:}"
      echo "RESOLVE BLOCKED: ${MSG}" >&2
      exit 1 ;;
  esac
fi

mkdir -p ".claude"
echo "$STATE" > ".claude/solve_state_${SESSION}"
