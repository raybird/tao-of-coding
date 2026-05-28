#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  parallel-dispatch.sh --tasks-file <path> [options]
  parallel-dispatch.sh --tasks-json '<json>' [options]

Tasks input (pick one):
  --tasks-file <path>       JSON file: array of task objects
  --tasks-json '<json>'     Inline JSON array

Task object schema:
  {
    "role":    "explorer|oracle|librarian|fixer|designer",
    "skill":   "<skill-name>",
    "prompt":  "<task prompt>",
    "task_id": "<optional override>"   // defaults to <role>-<index>
  }

Execution options:
  --parallelism <n>         Max concurrent dispatches (default: 4)
  --request-id <id>         Parent request id (default: generated)
  --runner-cmd <cmd>        Passed to each skill-dispatch.sh
  --fallback-runner-cmd <c> Passed to each skill-dispatch.sh
  --max-retries <n>         Per-task retries (default: 1)
  --isolate-workspace       Each task gets its own worktree
  --no-validate             Skip envelope validation
  --runs-dir <path>         Base dir for run artifacts (default: .tao/runs)
  --task-timeout <s>        Per-task wall-clock timeout in seconds (default: 180)

Output:
  --summary-file <path>     Write JSON summary of all tasks to file
  --quiet                   Suppress per-task progress lines

  -h, --help
USAGE
}

fail() { printf '%s: %s\n' "$1" "$2" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH_SCRIPT="$SCRIPT_DIR/skill-dispatch.sh"
[[ -x "$DISPATCH_SCRIPT" ]] || fail "E_MISSING" "skill-dispatch.sh not found or not executable"

TASKS_FILE=""
TASKS_JSON=""
PARALLELISM=4
REQUEST_ID="preq-$(date +%Y%m%d-%H%M%S)-$$"
RUNNER_CMD=""
FALLBACK_RUNNER_CMD=""
MAX_RETRIES=1
ISOLATE_WORKSPACE=0
NO_VALIDATE=0
RUNS_DIR=".tao/runs"
TASK_TIMEOUT=180
SUMMARY_FILE=""
QUIET=0

while (($#)); do
  case "$1" in
    --tasks-file)          TASKS_FILE="${2:-}";         shift 2 ;;
    --tasks-json)          TASKS_JSON="${2:-}";         shift 2 ;;
    --parallelism)         PARALLELISM="${2:-}";        shift 2 ;;
    --request-id)          REQUEST_ID="${2:-}";         shift 2 ;;
    --runner-cmd)          RUNNER_CMD="${2:-}";         shift 2 ;;
    --fallback-runner-cmd) FALLBACK_RUNNER_CMD="${2:-}"; shift 2 ;;
    --max-retries)         MAX_RETRIES="${2:-}";        shift 2 ;;
    --isolate-workspace)   ISOLATE_WORKSPACE=1;         shift ;;
    --no-validate)         NO_VALIDATE=1;               shift ;;
    --runs-dir)            RUNS_DIR="${2:-}";           shift 2 ;;
    --task-timeout)        TASK_TIMEOUT="${2:-}";       shift 2 ;;
    --summary-file)        SUMMARY_FILE="${2:-}";       shift 2 ;;
    --quiet)               QUIET=1;                     shift ;;
    -h|--help)             usage; exit 0 ;;
    *) fail "E_BAD_ARG" "unknown argument: $1" ;;
  esac
done

[[ -n "$RUNNER_CMD" ]] || fail "E_REQUIRED" "--runner-cmd is required"
[[ -z "$TASKS_FILE" && -z "$TASKS_JSON" ]] && fail "E_REQUIRED" "--tasks-file or --tasks-json required"
[[ -n "$TASKS_FILE" && -n "$TASKS_JSON" ]] && fail "E_BAD_ARG" "use --tasks-file or --tasks-json, not both"

if [[ -n "$TASKS_FILE" ]]; then
  [[ -f "$TASKS_FILE" ]] || fail "E_MISSING_FILE" "tasks file not found: $TASKS_FILE"
  TASKS_JSON="$(<"$TASKS_FILE")"
fi

# Validate + parse tasks JSON.
task_count=$(printf '%s' "$TASKS_JSON" | python3 -c "
import json,sys
tasks=json.load(sys.stdin)
if not isinstance(tasks,list): raise SystemExit('tasks must be a JSON array')
for t in tasks:
    for f in ('role','skill','prompt'):
        if f not in t: raise SystemExit(f'missing field \"{f}\" in task: {t}')
print(len(tasks))
" 2>&1) || fail "E_BAD_TASKS" "$task_count"

[[ "$task_count" -gt 0 ]] || fail "E_BAD_TASKS" "tasks array is empty"

log() { [[ "$QUIET" -eq 0 ]] && printf '%s\n' "$*" >&2 || true; }

SCRIPT_REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUNS_ROOT="$SCRIPT_REPO_ROOT/$RUNS_DIR/$REQUEST_ID"
PARALLEL_DIR="$RUNS_ROOT/parallel"
mkdir -p "$PARALLEL_DIR"

log "=== parallel-dispatch $REQUEST_ID (tasks=$task_count parallelism=$PARALLELISM) ==="

# Spawn one background job per task, respecting --parallelism.
pids=()
task_ids=()
out_files=()
err_files=()

running=0
task_idx=0

dispatch_one() {
  local idx="$1"
  local role skill prompt task_id
  role=$(printf '%s' "$TASKS_JSON" | python3 -c "import json,sys; t=json.load(sys.stdin)[$idx]; print(t['role'])")
  skill=$(printf '%s' "$TASKS_JSON" | python3 -c "import json,sys; t=json.load(sys.stdin)[$idx]; print(t['skill'])")
  prompt=$(printf '%s' "$TASKS_JSON" | python3 -c "import json,sys; t=json.load(sys.stdin)[$idx]; print(t['prompt'])")
  task_id=$(printf '%s' "$TASKS_JSON" | python3 -c "
import json,sys
t=json.load(sys.stdin)[$idx]
print(t.get('task_id', t['role']+'-'+str($idx)))
")
  local sub_req="${REQUEST_ID}-t${idx}"
  local out="$PARALLEL_DIR/${task_id}.json"
  local err="$PARALLEL_DIR/${task_id}.log"

  task_ids+=("$task_id")
  out_files+=("$out")
  err_files+=("$err")

  local dispatch_args=(
    --role       "$role"
    --skill      "$skill"
    --prompt     "$prompt"
    --request-id "$sub_req"
    --runner-cmd "$RUNNER_CMD"
    --max-retries "$MAX_RETRIES"
    --runs-dir   "$RUNS_DIR"
  )
  [[ -n "$FALLBACK_RUNNER_CMD" ]] && dispatch_args+=(--fallback-runner-cmd "$FALLBACK_RUNNER_CMD")
  [[ "$ISOLATE_WORKSPACE" -eq 1 ]] && dispatch_args+=(--isolate-workspace)
  [[ "$NO_VALIDATE"       -eq 1 ]] && dispatch_args+=(--no-validate)

  log "  → spawning [$task_id] role=$role skill=$skill"

  (
    timeout "$TASK_TIMEOUT" bash "$DISPATCH_SCRIPT" "${dispatch_args[@]}" \
      > "$out" 2>> "$err"
  ) &
  pids+=($!)
}

# Fan-out with parallelism cap via a simple slot counter.
slot_pids=()
slot_task_idx=()

for (( i = 0; i < task_count; i++ )); do
  # Wait if at capacity.
  while (( ${#slot_pids[@]} >= PARALLELISM )); do
    new_slot_pids=()
    new_slot_idx=()
    for (( j = 0; j < ${#slot_pids[@]}; j++ )); do
      if kill -0 "${slot_pids[$j]}" 2>/dev/null; then
        new_slot_pids+=("${slot_pids[$j]}")
        new_slot_idx+=("${slot_task_idx[$j]}")
      fi
    done
    slot_pids=("${new_slot_pids[@]+"${new_slot_pids[@]}"}")
    slot_task_idx=("${new_slot_idx[@]+"${new_slot_idx[@]}"}")
    (( ${#slot_pids[@]} >= PARALLELISM )) && sleep 1
  done

  dispatch_one "$i"
  slot_pids+=("${pids[-1]}")
  slot_task_idx+=("$i")
done

# Wait for all jobs.
exit_codes=()
for pid in "${pids[@]}"; do
  wait "$pid" && exit_codes+=(0) || exit_codes+=($?)
done

log ""
log "=== results ==="

pass=0; fail_count=0
summary_entries=()

for (( i = 0; i < ${#task_ids[@]}; i++ )); do
  tid="${task_ids[$i]}"
  out="${out_files[$i]}"
  ec="${exit_codes[$i]}"

  if [[ "$ec" -eq 0 && -s "$out" ]]; then
    status=$(python3 -c "import json,sys; d=json.load(open('$out')); print(d.get('status','?'))" 2>/dev/null || echo "parse-error")
    summary=$(python3 -c "
import json,sys
d=json.load(open('$out'))
s=d.get('outputs',{}).get('summary','')
print(s[:120].replace('\n',' '))
" 2>/dev/null || echo "")
    if [[ "$status" == "ok" || "$status" == "partial" ]]; then
      log "  ✓ [$tid] status=$status  $(printf '%.80s' "$summary")"
      pass=$((pass+1))
    else
      log "  ✗ [$tid] status=$status"
      fail_count=$((fail_count+1))
    fi
    summary_entries+=("{\"task_id\":$(python3 -c "import json; print(json.dumps('$tid'))"),\"status\":\"$status\",\"envelope\":$(python3 -c "import json; print(json.dumps('$out'))")}")
  else
    log "  ✗ [$tid] runner exit=$ec (no valid envelope)"
    fail_count=$((fail_count+1))
    summary_entries+=("{\"task_id\":$(python3 -c "import json; print(json.dumps('$tid'))"),\"status\":\"failed\",\"envelope\":null}")
  fi
done

log ""
log "pass=$pass fail=$fail_count total=$task_count"
log "artifacts: $PARALLEL_DIR"

if [[ -n "$SUMMARY_FILE" ]]; then
  {
    printf '{\n'
    printf '  "request_id": "%s",\n' "$REQUEST_ID"
    printf '  "pass": %d,\n' "$pass"
    printf '  "fail": %d,\n' "$fail_count"
    printf '  "total": %d,\n' "$task_count"
    printf '  "parallel_dir": "%s",\n' "$PARALLEL_DIR"
    printf '  "tasks": [\n'
    for (( i = 0; i < ${#summary_entries[@]}; i++ )); do
      [[ $i -lt $(( ${#summary_entries[@]} - 1 )) ]] \
        && printf '    %s,\n' "${summary_entries[$i]}" \
        || printf '    %s\n'  "${summary_entries[$i]}"
    done
    printf '  ]\n}\n'
  } > "$SUMMARY_FILE"
  log "summary written: $SUMMARY_FILE"
fi

[[ "$fail_count" -eq 0 ]]
