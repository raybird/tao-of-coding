#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  loop-dispatch.sh --tasks-file <path> [options]
  loop-dispatch.sh --tasks-json '<json>' [options]

Input (pick one):
  --tasks-file <path>         Initial tasks JSON file (array of task objects)
  --tasks-json '<json>'       Initial tasks inline JSON

Execution options:
  --runner-cmd <cmd>          Runner for worker agents (required)
  --reduce-runner-cmd <cmd>   Runner for oracle reducer (default: same as --runner-cmd)
  --max-iterations <n>        Max loop iterations (default: 3)
  --parallelism <n>           Max concurrent agent dispatches per iteration (default: 4)
  --fallback-runner-cmd <cmd> Fallback runner passed to parallel-dispatch.sh
  --max-retries <n>           Per-task retries (default: 1)
  --isolate-workspace         Isolate each agent in a git worktree
  --no-validate               Skip envelope validation
  --task-timeout <s>          Per-task timeout in seconds (default: 300)
  --runs-dir <path>           Base dir for run artifacts (default: .tao/runs)
  --summary-dir <path>        Directory to write per-iteration summaries (default: /tmp/loop-<id>)
  --request-id <id>           Trace id (default: generated)
  --quiet                     Suppress progress output

  -h, --help

Task object schema:
  { "role": "explorer|oracle|librarian|fixer|designer",
    "skill": "<skill-name>",
    "prompt": "<task prompt>",
    "task_id": "<optional>" }
USAGE
}

fail() { printf '%s: %s\n' "$1" "$2" >&2; exit 1; }
log()  { [[ "$QUIET" -eq 0 ]] && printf '%s\n' "$*" >&2 || true; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARALLEL_SCRIPT="$SCRIPT_DIR/parallel-dispatch.sh"
REDUCE_SCRIPT="$SCRIPT_DIR/reduce-envelopes.sh"

SELF_NAME="$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
version() {
  local ver
  if command -v git >/dev/null 2>&1; then
    ver="$(git -C "$REPO_ROOT" describe --tags --always --dirty 2>/dev/null || echo 'unknown')"
  else
    ver="unknown"
  fi
  echo "$SELF_NAME version $ver"
  exit 0
}
[[ -x "$PARALLEL_SCRIPT" ]] || fail "E_MISSING" "parallel-dispatch.sh not found or not executable"
[[ -x "$REDUCE_SCRIPT"   ]] || fail "E_MISSING" "reduce-envelopes.sh not found or not executable"

TASKS_FILE=""
TASKS_JSON=""
RUNNER_CMD=""
REDUCE_RUNNER_CMD=""
MAX_ITERATIONS=3
PARALLELISM=4
FALLBACK_RUNNER_CMD=""
MAX_RETRIES=1
ISOLATE_WORKSPACE=0
NO_VALIDATE=0
TASK_TIMEOUT=300
RUNS_DIR=".tao/runs"
SUMMARY_DIR=""
REQUEST_ID="loop-$(date +%Y%m%d-%H%M%S)-$$"
QUIET=0

while (($#)); do
  case "$1" in
    --tasks-file)          TASKS_FILE="${2:-}";          shift 2 ;;
    --tasks-json)          TASKS_JSON="${2:-}";          shift 2 ;;
    --runner-cmd)          RUNNER_CMD="${2:-}";          shift 2 ;;
    --reduce-runner-cmd)   REDUCE_RUNNER_CMD="${2:-}";   shift 2 ;;
    --max-iterations)      MAX_ITERATIONS="${2:-}";      shift 2 ;;
    --parallelism)         PARALLELISM="${2:-}";         shift 2 ;;
    --fallback-runner-cmd) FALLBACK_RUNNER_CMD="${2:-}"; shift 2 ;;
    --max-retries)         MAX_RETRIES="${2:-}";         shift 2 ;;
    --isolate-workspace)   ISOLATE_WORKSPACE=1;          shift ;;
    --no-validate)         NO_VALIDATE=1;                shift ;;
    --task-timeout)        TASK_TIMEOUT="${2:-}";        shift 2 ;;
    --runs-dir)            RUNS_DIR="${2:-}";            shift 2 ;;
    --summary-dir)         SUMMARY_DIR="${2:-}";         shift 2 ;;
    --request-id)          REQUEST_ID="${2:-}";          shift 2 ;;
    --quiet)               QUIET=1;                      shift ;;
    -h|--help)             usage; exit 0 ;;
    --version)             version ;;
    *) fail "E_BAD_ARG" "unknown argument: $1" ;;
  esac
done

[[ -n "$RUNNER_CMD" ]]                          || fail "E_REQUIRED" "--runner-cmd is required"
[[ -z "$TASKS_FILE" && -z "$TASKS_JSON" ]]      && fail "E_REQUIRED" "--tasks-file or --tasks-json required"
[[ -n "$TASKS_FILE" && -n "$TASKS_JSON" ]]      && fail "E_BAD_ARG"  "use --tasks-file or --tasks-json, not both"
[[ -n "$TASKS_FILE" ]] && { [[ -f "$TASKS_FILE" ]] || fail "E_MISSING_FILE" "tasks file not found: $TASKS_FILE"; }

REDUCE_RUNNER_CMD="${REDUCE_RUNNER_CMD:-$RUNNER_CMD}"

if [[ -z "$SUMMARY_DIR" ]]; then
  SUMMARY_DIR="/tmp/loop-${REQUEST_ID}"
fi
mkdir -p "$SUMMARY_DIR"

# Read initial tasks JSON.
if [[ -n "$TASKS_FILE" ]]; then
  CURRENT_TASKS_JSON="$(<"$TASKS_FILE")"
else
  CURRENT_TASKS_JSON="$TASKS_JSON"
fi

# Validate initial tasks array.
python3 -c "
import json, sys
tasks = json.loads(sys.stdin.read())
if not isinstance(tasks, list): raise SystemExit('tasks must be a JSON array')
for t in tasks:
    for f in ('role', 'skill', 'prompt'):
        if f not in t: raise SystemExit(f'missing field \"{f}\" in task: {t}')
print(len(tasks))
" <<< "$CURRENT_TASKS_JSON" > /dev/null || fail "E_BAD_TASKS" "invalid initial tasks JSON"

log "=== loop-dispatch $REQUEST_ID (max_iterations=$MAX_ITERATIONS) ==="

iteration=0
final_envelope=""
prev_next_tasks_json=""

while (( iteration < MAX_ITERATIONS )); do
  iteration=$(( iteration + 1 ))
  iter_label="iter-$(printf '%02d' "$iteration")"
  iter_dir="$SUMMARY_DIR/$iter_label"
  mkdir -p "$iter_dir"

  task_count=$(python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" <<< "$CURRENT_TASKS_JSON")
  log ""
  log "--- $iter_label (tasks=$task_count) ---"

  summary_file="$iter_dir/summary.json"
  iter_req_id="${REQUEST_ID}-${iter_label}"

  # Build parallel-dispatch args.
  pd_args=(
    --tasks-json     "$CURRENT_TASKS_JSON"
    --runner-cmd     "$RUNNER_CMD"
    --parallelism    "$PARALLELISM"
    --request-id     "$iter_req_id"
    --max-retries    "$MAX_RETRIES"
    --task-timeout   "$TASK_TIMEOUT"
    --runs-dir       "$RUNS_DIR"
    --summary-file   "$summary_file"
  )
  [[ -n "$FALLBACK_RUNNER_CMD" ]] && pd_args+=(--fallback-runner-cmd "$FALLBACK_RUNNER_CMD")
  [[ "$ISOLATE_WORKSPACE" -eq 1 ]] && pd_args+=(--isolate-workspace)
  [[ "$NO_VALIDATE"       -eq 1 ]] && pd_args+=(--no-validate)
  [[ "$QUIET"             -eq 1 ]] && pd_args+=(--quiet)

  if ! bash "$PARALLEL_SCRIPT" "${pd_args[@]}"; then
    log "  [warn] parallel-dispatch reported failures — continuing to reduce"
  fi

  # Reduce envelopes.
  reduced_file="$iter_dir/reduced.json"
  reduce_req_id="${REQUEST_ID}-${iter_label}-reduce"

  if ! bash "$REDUCE_SCRIPT" \
      --summary-file  "$summary_file" \
      --runner-cmd    "$REDUCE_RUNNER_CMD" \
      --request-id    "$reduce_req_id" \
      --runs-dir      "$RUNS_DIR" \
      --output-file   "$reduced_file"; then
    log "  [warn] reduce-envelopes failed — creating fallback envelope"
    python3 - "$summary_file" "$reduce_req_id" <<'PYEOF' > "$reduced_file"
import json, sys, os

summary = json.load(open(sys.argv[1]))
tasks = summary.get("tasks", [])
findings = []
for t in tasks:
    ep = t.get("envelope")
    if ep and os.path.isfile(ep):
        try:
            env = json.load(open(ep))
            task_findings = env.get("outputs", {}).get("findings", [])
            findings.extend(task_findings)
        except Exception:
            pass

fallback = {
    "schema_version": "1.0",
    "task_id": sys.argv[2],
    "role": "oracle",
    "skill": "writing-plans",
    "status": "partial",
    "confidence": 0.5,
    "outputs": {
        "summary": f"{summary.get('pass', 0)} of {summary.get('total', 0)} tasks passed; reducer failed",
        "findings": findings[:20],
        "artifacts": [],
        "next_actions": []
    }
}
json.dump(fallback, sys.stdout, indent=2, ensure_ascii=False)
PYEOF
    final_envelope="$reduced_file"
    break
  fi

  final_envelope="$reduced_file"
  log "  reduced envelope: $reduced_file"

  # Extract next_actions from reduced envelope.
  next_tasks_json=$(python3 - "$reduced_file" <<'PYEOF'
import json, sys

reduced = json.load(open(sys.argv[1]))
next_actions = reduced.get("outputs", {}).get("next_actions", [])

tasks = []
for i, a in enumerate(next_actions):
    role  = a.get("role", "oracle")
    skill = a.get("skill", "brainstorming")
    prompt = a.get("prompt", "")
    task_id = f"loop-{role}-{i+1}"
    tasks.append({"role": role, "skill": skill, "prompt": prompt, "task_id": task_id})

print(json.dumps(tasks))
PYEOF
)

  # Convergence check: same next_actions as previous iteration → loop detected.
  if [[ -n "$prev_next_tasks_json" && "$next_tasks_json" == "$prev_next_tasks_json" ]]; then
    log "  next_actions unchanged — converged after $iteration iteration(s)"
    break
  fi
  prev_next_tasks_json="$next_tasks_json"

  next_count=$(python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" <<< "$next_tasks_json")

  if [[ "$next_count" -eq 0 ]]; then
    log "  next_actions empty — converged after $iteration iteration(s)"
    break
  fi

  if (( iteration >= MAX_ITERATIONS )); then
    log "  reached max_iterations=$MAX_ITERATIONS — stopping"
    break
  fi

  log "  $next_count next_action(s) queued for next iteration"
  CURRENT_TASKS_JSON="$next_tasks_json"
done

log ""
log "=== loop complete: $iteration iteration(s), summary_dir=$SUMMARY_DIR ==="

if [[ -n "$final_envelope" && -f "$final_envelope" ]]; then
  cat "$final_envelope"
else
  log "[warn] no final envelope produced"
  exit 1
fi
