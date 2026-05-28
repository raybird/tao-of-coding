#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  reduce-envelopes.sh --summary-file <path> [options]
  reduce-envelopes.sh --envelopes-dir <path> [options]

Input (pick one):
  --summary-file <path>     JSON summary written by parallel-dispatch.sh
  --envelopes-dir <path>    Directory of *.json envelope files

Options:
  --runner-cmd <cmd>        opencode invocation for the reducer oracle
                            (default: opencode run --model opencode/deepseek-v4-flash-free)
  --request-id <id>         Trace id (default: generated)
  --runs-dir <path>         Base dir for output (default: .tao/runs)
  --output-file <path>      Write reduced envelope to file (also printed to stdout)
  --max-findings <n>        Max findings to include per task (default: 5)
  -h, --help
USAGE
}

fail() { printf '%s: %s\n' "$1" "$2" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-agent-message.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SUMMARY_FILE=""
ENVELOPES_DIR=""
RUNNER_CMD="opencode run --model opencode/deepseek-v4-flash-free"
REQUEST_ID="reduce-$(date +%Y%m%d-%H%M%S)-$$"
RUNS_DIR=".tao/runs"
OUTPUT_FILE=""
MAX_FINDINGS=5

while (($#)); do
  case "$1" in
    --summary-file)   SUMMARY_FILE="${2:-}";  shift 2 ;;
    --envelopes-dir)  ENVELOPES_DIR="${2:-}"; shift 2 ;;
    --runner-cmd)     RUNNER_CMD="${2:-}";    shift 2 ;;
    --request-id)     REQUEST_ID="${2:-}";    shift 2 ;;
    --runs-dir)       RUNS_DIR="${2:-}";      shift 2 ;;
    --output-file)    OUTPUT_FILE="${2:-}";   shift 2 ;;
    --max-findings)   MAX_FINDINGS="${2:-}";  shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *) fail "E_BAD_ARG" "unknown argument: $1" ;;
  esac
done

[[ -z "$SUMMARY_FILE" && -z "$ENVELOPES_DIR" ]] && fail "E_REQUIRED" "--summary-file or --envelopes-dir required"

# Collect envelope paths.
mapfile -t envelope_paths < <(python3 - <<PYEOF
import json, sys, os, glob

summary_file = """$SUMMARY_FILE"""
envelopes_dir = """$ENVELOPES_DIR"""

if summary_file:
    data = json.load(open(summary_file))
    for t in data.get("tasks", []):
        ep = t.get("envelope")
        if ep and os.path.isfile(ep):
            print(ep)
else:
    for f in sorted(glob.glob(os.path.join(envelopes_dir, "*.json"))):
        print(f)
PYEOF
)

[[ ${#envelope_paths[@]} -gt 0 ]] || fail "E_NO_ENVELOPES" "no valid envelope files found"

# Build a compact digest of all envelopes for the reducer prompt.
digest=$(python3 - "${envelope_paths[@]}" <<PYEOF
import json, sys, textwrap

max_findings = $MAX_FINDINGS
paths = sys.argv[1:]
out = []

for p in paths:
    try:
        d = json.load(open(p))
    except Exception as e:
        out.append(f"[PARSE ERROR: {p}: {e}]")
        continue

    task_id = d.get("task_id", "?")
    role    = d.get("role", "?")
    skill   = d.get("skill", "?")
    status  = d.get("status", "?")
    outputs = d.get("outputs", {})
    summary = outputs.get("summary", "")
    findings = outputs.get("findings", [])[:max_findings]
    next_actions = outputs.get("next_actions", [])

    block = [f"### [{task_id}] role={role} skill={skill} status={status}"]
    block.append(f"**Summary**: {summary}")
    if findings:
        block.append("**Findings**:")
        for f in findings:
            loc = f"  @ {f['location']}" if f.get('location') else ""
            block.append(f"  - [{f['severity'].upper()}] {f['id']}: {f['message']}{loc}")
    if next_actions:
        block.append("**Next actions suggested**:")
        for a in next_actions:
            dep = f" (depends_on: {a['depends_on']})" if a.get('depends_on') else ""
            block.append(f"  - {a['role']}/{a['skill']}: {a['prompt'][:80]}{dep}")
    out.append("\n".join(block))

print("\n\n---\n\n".join(out))
PYEOF
)

NL=$'\n'
FENCE='```'
role_guide="$REPO_ROOT/skills/tao-of-opencode/references/oracle.md"
few_shot=$(awk '/^```json[[:space:]]*$/{flag=1;next} /^```[[:space:]]*$/{flag=0} flag' "$role_guide")

prompt="你是 Tao-of-Coding 的 Oracle agent，本次使用 skill: brainstorming。${NL}${NL}"
prompt+="# 任務：合併多個 agent 回報並產出行動清單${NL}${NL}"
prompt+="以下是 ${#envelope_paths[@]} 個 agent 的執行摘要。請：${NL}"
prompt+="1. 合併所有 findings，去除重複，按嚴重度排序${NL}"
prompt+="2. 給出 3–5 條具體可行的 next_actions（包含適合的 role/skill）${NL}"
prompt+="3. summary 寫一段整體評估（≤300 字）${NL}${NL}"
prompt+="# Agent 回報摘要${NL}${NL}"
prompt+="${digest}${NL}${NL}"
prompt+="# 輸出格式：唯一規則${NL}${NL}"
prompt+="回覆只能是一段 fenced JSON block，包在 ${FENCE}json 與 ${FENCE} 之間，前後不得有任何文字。${NL}${NL}"
prompt+="# 範例（完全比照這個 JSON 結構，只替換內容）${NL}${NL}"
prompt+="${FENCE}json${NL}${few_shot}${NL}${FENCE}${NL}${NL}"
prompt+="# 結構硬規則${NL}"
prompt+="- summary、artifacts、findings、next_actions 都是 outputs 的子欄位，必須巢狀在 outputs 物件內。${NL}"
prompt+="- role 必須是 oracle，task_id 以 'reduce-' 開頭，status 為 ok 或 partial。${NL}"
prompt+="- findings 裡每條 id 格式：reduce-f-NNN。${NL}"
prompt+="- 不要新增 schema 沒有的欄位。${NL}"

RUN_DIR="$REPO_ROOT/$RUNS_DIR/$REQUEST_ID"
RAW_FILE="$RUN_DIR/reduce.raw"
JSON_FILE="$RUN_DIR/reduce.json"
mkdir -p "$RUN_DIR"

printf '=== reducer %s (envelopes=%d) ===\n' "$REQUEST_ID" "${#envelope_paths[@]}" >&2

timeout 180 bash -lc "$RUNNER_CMD" <<< "$prompt" > "$RAW_FILE" 2>&1

awk '
  /^```json[[:space:]]*$/ { if (!done) { flag=1; next } }
  /^```[[:space:]]*$/     { if (flag)  { flag=0; done=1; next } }
  flag                    { print }
' "$RAW_FILE" > "$JSON_FILE"

if [[ ! -s "$JSON_FILE" ]]; then
  fail "E_NO_JSON" "no ${FENCE}json block in reducer output (see $RAW_FILE)"
fi

if ! bash "$VALIDATE_SCRIPT" "$JSON_FILE" --quiet 2>/dev/null; then
  printf 'validation errors:\n' >&2
  bash "$VALIDATE_SCRIPT" "$JSON_FILE" 2>&1 | sed 's/^/  /' >&2
  fail "E_INVALID_ENVELOPE" "reducer output failed schema validation"
fi

printf '=== ok: reduced envelope at %s ===\n' "$JSON_FILE" >&2

if [[ -n "$OUTPUT_FILE" ]]; then
  cp "$JSON_FILE" "$OUTPUT_FILE"
fi

cat "$JSON_FILE"
