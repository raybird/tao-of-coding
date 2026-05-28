#!/usr/bin/env bash
set -euo pipefail

# Validates an agent message JSON against agent-message.schema.json.
# Strategy:
#   1. Prefer python3 + jsonschema (full Draft 2020-12 validation).
#   2. Fallback to jq structural lint (required fields + enums only).
# Exit codes:
#   0 = valid
#   2 = malformed (schema violation)
#   3 = file not found / unreadable
#   4 = no validator available

usage() {
  cat <<'USAGE'
Usage:
  validate-agent-message.sh <message.json>
  validate-agent-message.sh --stdin   # read JSON from stdin
  validate-agent-message.sh --extract <agent-output>   # pull ```json block first

Options:
  --schema <path>   Override schema path
  --quiet           Suppress success output (errors still printed)
  -h, --help
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="$SCRIPT_DIR/../references/agent-message.schema.json"

INPUT=""
MODE="file"
QUIET=0

while (($#)); do
  case "$1" in
    --stdin) MODE="stdin"; shift ;;
    --extract) MODE="extract"; INPUT="${2:-}"; shift 2 ;;
    --schema) SCHEMA="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
    *) INPUT="$1"; shift ;;
  esac
done

[[ -f "$SCHEMA" ]] || { printf 'schema not found: %s\n' "$SCHEMA" >&2; exit 3; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

case "$MODE" in
  stdin)
    cat > "$TMP"
    ;;
  extract)
    [[ -f "$INPUT" ]] || { printf 'input not found: %s\n' "$INPUT" >&2; exit 3; }
    awk '
      /^```json[[:space:]]*$/ { if (!done) { flag=1; next } }
      /^```[[:space:]]*$/     { if (flag)  { flag=0; done=1; next } }
      flag                    { print }
    ' "$INPUT" > "$TMP"
    [[ -s "$TMP" ]] || { printf 'no ```json block found in %s\n' "$INPUT" >&2; exit 2; }
    ;;
  file)
    [[ -n "$INPUT" ]] || { usage >&2; exit 1; }
    [[ -f "$INPUT" ]] || { printf 'input not found: %s\n' "$INPUT" >&2; exit 3; }
    cp "$INPUT" "$TMP"
    ;;
esac

# Always start with JSON well-formedness check (cheap, clearer errors).
if ! jq -e . "$TMP" > /dev/null 2>&1; then
  printf 'invalid JSON\n' >&2
  jq . "$TMP" 2>&1 | head -5 >&2 || true
  exit 2
fi

if command -v python3 > /dev/null 2>&1 && python3 -c 'import jsonschema' 2>/dev/null; then
  python3 - "$SCHEMA" "$TMP" <<'PY' || exit 2
import json, sys
from jsonschema import Draft202012Validator
schema = json.load(open(sys.argv[1]))
data = json.load(open(sys.argv[2]))
errors = sorted(Draft202012Validator(schema).iter_errors(data), key=lambda e: e.path)
if errors:
    for e in errors:
        loc = "/".join(str(p) for p in e.absolute_path) or "(root)"
        print(f"  {loc}: {e.message}", file=sys.stderr)
    sys.exit(1)
PY
  [[ "$QUIET" -eq 1 ]] || printf 'ok (full schema)\n'
  exit 0
fi

# Fallback: jq-only structural lint.
required_top='["schema_version","task_id","role","skill","status","outputs"]'
missing=$(jq -r --argjson req "$required_top" '$req - (keys) | join(",")' "$TMP")
if [[ -n "$missing" ]]; then
  printf 'missing required fields: %s\n' "$missing" >&2
  exit 2
fi

role=$(jq -r .role "$TMP")
case "$role" in explorer|oracle|librarian|fixer|designer) ;; *)
  printf 'invalid role: %s\n' "$role" >&2; exit 2 ;;
esac

status=$(jq -r .status "$TMP")
case "$status" in ok|partial|blocked|malformed|failed) ;; *)
  printf 'invalid status: %s\n' "$status" >&2; exit 2 ;;
esac

if ! jq -e '.outputs.summary | type == "string"' "$TMP" > /dev/null; then
  printf 'outputs.summary missing or not a string\n' >&2; exit 2
fi

[[ "$QUIET" -eq 1 ]] || printf 'ok (jq lint, install python3-jsonschema for full validation)\n'
exit 0
