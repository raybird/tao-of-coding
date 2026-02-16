#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  skill-dispatch.sh --role <role> --skill <skill> [options]

Required:
  --role <role>                 explorer|oracle|librarian|fixer|designer
  --skill <skill>               Skill name (e.g. systematic-debugging)

Prompt input (pick one):
  --prompt <text>               Inline prompt text
  --prompt-file <path>          Prompt text file
  (or pipe prompt from stdin)

Execution options:
  --execution-mode <mode>       root|delegated (default derived from --depth)
  --depth <n>                   Current depth (default: 0)
  --max-depth <n>               Max allowed depth (default: 1)
  --parent-skill <name>         Parent skill name
  --edge-type <type>            requires_now|requires_later|reference_only (default: requires_now)
  --allow-reentry <bool>        true|false (default: false)
  --forbid-root-reload <bool>   true|false (default: true)
  --request-id <id>             Trace id (default: generated)
  --skill-stack <csv>           Existing stack (comma-separated)
  --visited-skills <csv>        Existing visited skills (comma-separated)

Path override options:
  --root-skill-path <path>      Default: skills/tao-of-gemini/SKILL.md
  --role-guide-path <path>      Override role guide path
  --skill-file <path>           Override target skill file path
  --skill-root <path>           Default: skills/tao-of-gemini/references/superpowers

Output / runner:
  --output-file <path>          Save composed prompt to file
  --runner-cmd <cmd>            Pipe composed prompt to command stdin
  --dry-run                     Print resolved dispatch state and exit
  -h, --help                    Show this help

Errors:
  E_ROOT_RELOAD_BLOCKED
  E_SKILL_REENTRY_BLOCKED
  E_DEPTH_LIMIT
  E_EDGE_NOT_EXECUTABLE
USAGE
}

fail() {
  local code="$1"
  local msg="$2"
  printf '%s: %s\n' "$code" "$msg" >&2
  exit 1
}

to_bool() {
  local raw="${1:-}"
  case "$raw" in
    true|TRUE|1|yes|YES) printf 'true' ;;
    false|FALSE|0|no|NO) printf 'false' ;;
    *) fail "E_BAD_BOOL" "invalid boolean: $raw" ;;
  esac
}

csv_has() {
  local csv="$1"
  local needle="$2"
  local item
  IFS=',' read -r -a _items <<< "$csv"
  for item in "${_items[@]}"; do
    item="${item// /}"
    [[ -z "$item" ]] && continue
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

csv_add_unique() {
  local csv="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    printf '%s' "$csv"
    return 0
  fi
  if [[ -z "$csv" ]]; then
    printf '%s' "$value"
    return 0
  fi
  if csv_has "$csv" "$value"; then
    printf '%s' "$csv"
  else
    printf '%s,%s' "$csv" "$value"
  fi
}

append_stack() {
  local stack="$1"
  local value="$2"
  if [[ -z "$stack" ]]; then
    printf '%s' "$value"
  else
    printf '%s,%s' "$stack" "$value"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

ROLE=""
SKILL=""
PROMPT_TEXT=""
PROMPT_FILE=""
EXECUTION_MODE=""
DEPTH=0
MAX_DEPTH=1
PARENT_SKILL=""
EDGE_TYPE="requires_now"
ALLOW_REENTRY="false"
FORBID_ROOT_RELOAD="true"
REQUEST_ID="req-$(date +%Y%m%d-%H%M%S)-$$"
SKILL_STACK=""
VISITED_SKILLS=""
ROOT_SKILL_PATH="skills/tao-of-gemini/SKILL.md"
ROLE_GUIDE_PATH=""
SKILL_FILE=""
SKILL_ROOT="skills/tao-of-gemini/references/superpowers"
OUTPUT_FILE=""
RUNNER_CMD=""
DRY_RUN=0

while (($#)); do
  case "$1" in
    --role)
      ROLE="${2:-}"
      shift 2
      ;;
    --skill)
      SKILL="${2:-}"
      shift 2
      ;;
    --prompt)
      PROMPT_TEXT="${2:-}"
      shift 2
      ;;
    --prompt-file)
      PROMPT_FILE="${2:-}"
      shift 2
      ;;
    --execution-mode)
      EXECUTION_MODE="${2:-}"
      shift 2
      ;;
    --depth)
      DEPTH="${2:-}"
      shift 2
      ;;
    --max-depth)
      MAX_DEPTH="${2:-}"
      shift 2
      ;;
    --parent-skill)
      PARENT_SKILL="${2:-}"
      shift 2
      ;;
    --edge-type)
      EDGE_TYPE="${2:-}"
      shift 2
      ;;
    --allow-reentry)
      ALLOW_REENTRY="$(to_bool "${2:-}")"
      shift 2
      ;;
    --forbid-root-reload)
      FORBID_ROOT_RELOAD="$(to_bool "${2:-}")"
      shift 2
      ;;
    --request-id)
      REQUEST_ID="${2:-}"
      shift 2
      ;;
    --skill-stack)
      SKILL_STACK="${2:-}"
      shift 2
      ;;
    --visited-skills)
      VISITED_SKILLS="${2:-}"
      shift 2
      ;;
    --root-skill-path)
      ROOT_SKILL_PATH="${2:-}"
      shift 2
      ;;
    --role-guide-path)
      ROLE_GUIDE_PATH="${2:-}"
      shift 2
      ;;
    --skill-file)
      SKILL_FILE="${2:-}"
      shift 2
      ;;
    --skill-root)
      SKILL_ROOT="${2:-}"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --runner-cmd)
      RUNNER_CMD="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "E_BAD_ARG" "unknown argument: $1"
      ;;
  esac
done

[[ -z "$ROLE" ]] && fail "E_REQUIRED" "--role is required"
[[ -z "$SKILL" ]] && fail "E_REQUIRED" "--skill is required"

case "$ROLE" in
  explorer|oracle|librarian|fixer|designer) ;;
  *) fail "E_BAD_ROLE" "unsupported role: $ROLE" ;;
esac

if ! [[ "$DEPTH" =~ ^[0-9]+$ ]]; then
  fail "E_BAD_DEPTH" "--depth must be a non-negative integer"
fi
if ! [[ "$MAX_DEPTH" =~ ^[0-9]+$ ]]; then
  fail "E_BAD_DEPTH" "--max-depth must be a non-negative integer"
fi

if [[ -z "$EXECUTION_MODE" ]]; then
  if [[ "$DEPTH" -eq 0 ]]; then
    EXECUTION_MODE="root"
  else
    EXECUTION_MODE="delegated"
  fi
fi

case "$EXECUTION_MODE" in
  root|delegated) ;;
  *) fail "E_BAD_MODE" "--execution-mode must be root or delegated" ;;
esac

case "$EDGE_TYPE" in
  requires_now|requires_later|reference_only) ;;
  *) fail "E_BAD_EDGE" "--edge-type must be requires_now|requires_later|reference_only" ;;
esac

if [[ "$EXECUTION_MODE" == "root" && "$DEPTH" -ne 0 ]]; then
  fail "E_BAD_MODE" "root mode requires --depth 0"
fi
if [[ "$EXECUTION_MODE" == "delegated" && "$DEPTH" -eq 0 ]]; then
  fail "E_BAD_MODE" "delegated mode requires --depth > 0"
fi
if [[ "$DEPTH" -gt "$MAX_DEPTH" ]]; then
  fail "E_DEPTH_LIMIT" "depth ($DEPTH) exceeds max-depth ($MAX_DEPTH)"
fi

if [[ "$EXECUTION_MODE" == "delegated" ]]; then
  if [[ "$FORBID_ROOT_RELOAD" == "true" && "$SKILL" == "tao-of-gemini" ]]; then
    fail "E_ROOT_RELOAD_BLOCKED" "delegated mode cannot target tao-of-gemini root"
  fi
  if [[ "$EDGE_TYPE" != "requires_now" ]]; then
    fail "E_EDGE_NOT_EXECUTABLE" "auto-dispatch only executes requires_now edges"
  fi
  if [[ "$ALLOW_REENTRY" == "false" && -n "$VISITED_SKILLS" ]] && csv_has "$VISITED_SKILLS" "$SKILL"; then
    fail "E_SKILL_REENTRY_BLOCKED" "skill '$SKILL' already visited"
  fi
fi

if [[ -z "$ROLE_GUIDE_PATH" ]]; then
  ROLE_GUIDE_PATH="skills/tao-of-gemini/references/${ROLE}.md"
fi
if [[ -z "$SKILL_FILE" ]]; then
  if [[ "$SKILL" == "tao-of-gemini" ]]; then
    SKILL_FILE="$ROOT_SKILL_PATH"
  else
    SKILL_FILE="$SKILL_ROOT/$SKILL/SKILL.md"
  fi
fi

ROOT_SKILL_ABS="$REPO_ROOT/$ROOT_SKILL_PATH"
ROLE_GUIDE_ABS="$REPO_ROOT/$ROLE_GUIDE_PATH"
SKILL_FILE_ABS="$REPO_ROOT/$SKILL_FILE"

[[ -f "$ROLE_GUIDE_ABS" ]] || fail "E_MISSING_FILE" "role guide not found: $ROLE_GUIDE_PATH"
[[ -f "$SKILL_FILE_ABS" ]] || fail "E_MISSING_FILE" "skill file not found: $SKILL_FILE"
if [[ "$EXECUTION_MODE" == "root" ]]; then
  [[ -f "$ROOT_SKILL_ABS" ]] || fail "E_MISSING_FILE" "root skill not found: $ROOT_SKILL_PATH"
fi

if [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" ]] || fail "E_MISSING_FILE" "prompt file not found: $PROMPT_FILE"
  PROMPT_TEXT="$(<"$PROMPT_FILE")"
elif [[ -z "$PROMPT_TEXT" && ! -t 0 ]]; then
  PROMPT_TEXT="$(cat)"
fi

if [[ -z "$PROMPT_TEXT" ]]; then
  fail "E_REQUIRED" "prompt required: use --prompt, --prompt-file, or stdin"
fi

if [[ -z "$SKILL_STACK" ]]; then
  if [[ -n "$PARENT_SKILL" ]]; then
    SKILL_STACK="$PARENT_SKILL"
  fi
fi
SKILL_STACK="$(append_stack "$SKILL_STACK" "$SKILL")"
VISITED_SKILLS="$(csv_add_unique "$VISITED_SKILLS" "$SKILL")"

ROOT_PROTOCOL="root"
if [[ "$EXECUTION_MODE" == "delegated" ]]; then
  ROOT_PROTOCOL="inherited"
fi

read_file_block() {
  local abs_path="$1"
  local rel_path="$2"
  printf '### FILE: %s\n' "$rel_path"
  printf '```markdown\n'
  cat "$abs_path"
  printf '\n```\n\n'
}

RUNTIME_HEADER=$(cat <<EOF
EXECUTION_MODE: $EXECUTION_MODE
REQUEST_ID: $REQUEST_ID
DEPTH: $DEPTH
MAX_DEPTH: $MAX_DEPTH
ROLE_LOCK: $ROLE
SKILL_LOCK: $SKILL
ORIGIN_SKILL: ${PARENT_SKILL:-none}
ROOT_PROTOCOL: $ROOT_PROTOCOL
FORBID_ROOT_RELOAD: $FORBID_ROOT_RELOAD
EDGE_TYPE: $EDGE_TYPE
ALLOW_REENTRY: $ALLOW_REENTRY
SKILL_STACK: [$SKILL_STACK]
VISITED_SKILLS: [$VISITED_SKILLS]
EOF
)

FINAL_PROMPT=""
FINAL_PROMPT+="# Runtime Header\n\n"
FINAL_PROMPT+="\`\`\`yaml\n$RUNTIME_HEADER\n\`\`\`\n\n"
FINAL_PROMPT+="# Execution Contract\n\n"
FINAL_PROMPT+="You are in delegated skill execution. If DEPTH > 0, do not reload tao-of-gemini root protocol.\n\n"
FINAL_PROMPT+="# Context Files\n\n"

if [[ "$EXECUTION_MODE" == "root" ]]; then
  FINAL_PROMPT+="$(read_file_block "$ROOT_SKILL_ABS" "$ROOT_SKILL_PATH")"
fi
FINAL_PROMPT+="$(read_file_block "$ROLE_GUIDE_ABS" "$ROLE_GUIDE_PATH")"
if [[ "$SKILL_FILE_ABS" != "$ROOT_SKILL_ABS" ]]; then
  FINAL_PROMPT+="$(read_file_block "$SKILL_FILE_ABS" "$SKILL_FILE")"
fi

FINAL_PROMPT+="# Task\n\n$PROMPT_TEXT\n"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'dispatch.mode=%s\n' "$EXECUTION_MODE"
  printf 'dispatch.depth=%s\n' "$DEPTH"
  printf 'dispatch.max_depth=%s\n' "$MAX_DEPTH"
  printf 'dispatch.role=%s\n' "$ROLE"
  printf 'dispatch.skill=%s\n' "$SKILL"
  printf 'dispatch.parent_skill=%s\n' "${PARENT_SKILL:-none}"
  printf 'dispatch.edge_type=%s\n' "$EDGE_TYPE"
  printf 'dispatch.skill_stack=%s\n' "$SKILL_STACK"
  printf 'dispatch.visited_skills=%s\n' "$VISITED_SKILLS"
  printf 'dispatch.role_guide=%s\n' "$ROLE_GUIDE_PATH"
  printf 'dispatch.skill_file=%s\n' "$SKILL_FILE"
  exit 0
fi

if [[ -n "$OUTPUT_FILE" ]]; then
  printf '%s' "$FINAL_PROMPT" > "$OUTPUT_FILE"
fi

if [[ -n "$RUNNER_CMD" ]]; then
  printf '%s' "$FINAL_PROMPT" | bash -lc "$RUNNER_CMD"
else
  printf '%s' "$FINAL_PROMPT"
fi
