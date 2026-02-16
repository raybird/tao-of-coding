#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  orchestrate-skill.sh [options]

Prompt input (pick one):
  --prompt <text>
  --prompt-file <path>
  (or pipe prompt from stdin)

Routing / execution options:
  --depth <n>                   Current depth (default: 0)
  --max-depth <n>               Max allowed depth (default: 1)
  --execution-mode <mode>       root|delegated (default derived from --depth)
  --parent-skill <name>         Parent skill for delegated flows
  --edge-type <type>            requires_now|requires_later|reference_only (default: requires_now)
  --request-id <id>             Trace id (default: generated)
  --skill-stack <csv>           Existing stack (comma-separated)
  --visited-skills <csv>        Existing visited skills (comma-separated)
  --allow-reentry <bool>        true|false (default: false)
  --forbid-root-reload <bool>   true|false (default: true)
  --route-config <path>         Routing rule conf path

Runner / output options:
  --runner-cmd <cmd>            Pass composed prompt to command stdin
  --output-file <path>          Save composed prompt
  --dry-run                     Show routed role/skill and dispatch state
  -h, --help                    Show this help

Notes:
  - This script auto-routes dialogue to role+skill, then delegates to skill-dispatch.sh.
  - For custom routing overrides, call skill-dispatch.sh directly.
USAGE
}

fail() {
  local code="$1"
  local msg="$2"
  printf '%s: %s\n' "$code" "$msg" >&2
  exit 1
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

flush_route() {
  if [[ -z "$CUR_ROUTE_ID" ]]; then
    return 0
  fi
  if [[ -z "$CUR_ROUTE_ROLE" || -z "$CUR_ROUTE_SKILL" ]]; then
    fail "E_BAD_ROUTE_CONFIG" "route '$CUR_ROUTE_ID' missing role/skill"
  fi
  ROUTE_IDS+=("$CUR_ROUTE_ID")
  ROUTE_REASONS+=("${CUR_ROUTE_REASON:-$CUR_ROUTE_ID}")
  ROUTE_ROLES+=("$CUR_ROUTE_ROLE")
  ROUTE_SKILLS+=("$CUR_ROUTE_SKILL")
  ROUTE_PATTERNS+=("$CUR_ROUTE_PATTERNS")
}

load_route_config() {
  local cfg_path="$1"
  local line section key value

  if [[ "$cfg_path" =~ \.ya?ml$ ]]; then
    fail "E_UNSUPPORTED_ROUTE_FORMAT" "yaml route config is no longer supported; use .conf"
  fi

  [[ -f "$cfg_path" ]] || fail "E_MISSING_FILE" "route config not found: $cfg_path"

  DEFAULT_ROLE=""
  DEFAULT_SKILL=""
  DEFAULT_REASON="fallback"
  ROUTE_IDS=()
  ROUTE_REASONS=()
  ROUTE_ROLES=()
  ROUTE_SKILLS=()
  ROUTE_PATTERNS=()
  CUR_ROUTE_ID=""
  CUR_ROUTE_REASON=""
  CUR_ROUTE_ROLE=""
  CUR_ROUTE_SKILL=""
  CUR_ROUTE_PATTERNS=""
  section=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      flush_route
      section="${BASH_REMATCH[1]}"
      CUR_ROUTE_ID=""
      CUR_ROUTE_REASON=""
      CUR_ROUTE_ROLE=""
      CUR_ROUTE_SKILL=""
      CUR_ROUTE_PATTERNS=""
      if [[ "$section" =~ ^route\.(.+)$ ]]; then
        CUR_ROUTE_ID="${BASH_REMATCH[1]}"
      fi
      continue
    fi

    if [[ "$line" != *=* ]]; then
      fail "E_BAD_ROUTE_CONFIG" "invalid line in route config: $line"
    fi

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    case "$section" in
      default)
        case "$key" in
          role) DEFAULT_ROLE="$value" ;;
          skill) DEFAULT_SKILL="$value" ;;
          reason) DEFAULT_REASON="$value" ;;
        esac
        ;;
      route.*)
        case "$key" in
          role) CUR_ROUTE_ROLE="$value" ;;
          skill) CUR_ROUTE_SKILL="$value" ;;
          reason) CUR_ROUTE_REASON="$value" ;;
          pattern)
            if [[ -z "$CUR_ROUTE_PATTERNS" ]]; then
              CUR_ROUTE_PATTERNS="$value"
            else
              CUR_ROUTE_PATTERNS+=$'\n'
              CUR_ROUTE_PATTERNS+="$value"
            fi
            ;;
        esac
        ;;
      *)
        fail "E_BAD_ROUTE_CONFIG" "entry outside [default] or [route.*]: $line"
        ;;
    esac
  done < "$cfg_path"

  flush_route

  if [[ -z "$DEFAULT_ROLE" || -z "$DEFAULT_SKILL" ]]; then
    fail "E_BAD_ROUTE_CONFIG" "missing default role/skill"
  fi
}

match_route() {
  local prompt="$1"
  local i patterns pattern
  shopt -s nocasematch
  for i in "${!ROUTE_IDS[@]}"; do
    patterns="${ROUTE_PATTERNS[$i]}"
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
      [[ -z "$pattern" ]] && continue
      if [[ "$prompt" =~ $pattern ]]; then
        printf '%s\t%s\t%s' "${ROUTE_ROLES[$i]}" "${ROUTE_SKILLS[$i]}" "${ROUTE_REASONS[$i]}"
        shopt -u nocasematch
        return 0
      fi
    done <<< "$patterns"
  done
  shopt -u nocasematch
  printf '%s\t%s\t%s' "$DEFAULT_ROLE" "$DEFAULT_SKILL" "${DEFAULT_REASON:-fallback}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
DISPATCH_SCRIPT="$SCRIPT_DIR/skill-dispatch.sh"

[[ -x "$DISPATCH_SCRIPT" ]] || fail "E_MISSING_DISPATCH" "dispatcher not executable: $DISPATCH_SCRIPT"

PROMPT_TEXT=""
PROMPT_FILE=""
DEPTH=0
MAX_DEPTH=1
EXECUTION_MODE=""
PARENT_SKILL=""
EDGE_TYPE="requires_now"
REQUEST_ID="req-$(date +%Y%m%d-%H%M%S)-$$"
SKILL_STACK=""
VISITED_SKILLS=""
ALLOW_REENTRY="false"
FORBID_ROOT_RELOAD="true"
ROUTE_CONFIG_PATH="skills/tao-of-opencode/references/skill-routing.conf"
RUNNER_CMD=""
OUTPUT_FILE=""
DRY_RUN=0

while (($#)); do
  case "$1" in
    --prompt)
      PROMPT_TEXT="${2:-}"
      shift 2
      ;;
    --prompt-file)
      PROMPT_FILE="${2:-}"
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
    --execution-mode)
      EXECUTION_MODE="${2:-}"
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
    --allow-reentry)
      ALLOW_REENTRY="${2:-}"
      shift 2
      ;;
    --forbid-root-reload)
      FORBID_ROOT_RELOAD="${2:-}"
      shift 2
      ;;
    --route-config)
      ROUTE_CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --runner-cmd)
      RUNNER_CMD="${2:-}"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="${2:-}"
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

if [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" ]] || fail "E_MISSING_FILE" "prompt file not found: $PROMPT_FILE"
  PROMPT_TEXT="$(<"$PROMPT_FILE")"
elif [[ -z "$PROMPT_TEXT" && ! -t 0 ]]; then
  PROMPT_TEXT="$(cat)"
fi

[[ -n "$PROMPT_TEXT" ]] || fail "E_REQUIRED" "prompt required: use --prompt, --prompt-file, or stdin"

ROUTE_CONFIG_ABS="$REPO_ROOT/$ROUTE_CONFIG_PATH"
load_route_config "$ROUTE_CONFIG_ABS"

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

route_line="$(match_route "$PROMPT_TEXT")"

IFS=$'\t' read -r route_role route_skill route_reason <<< "$route_line"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'route.role=%s\n' "$route_role"
  printf 'route.skill=%s\n' "$route_skill"
  printf 'route.reason=%s\n' "$route_reason"
  printf 'route.config=%s\n' "$ROUTE_CONFIG_PATH"
fi

dispatch_args=(
  --role "$route_role"
  --skill "$route_skill"
  --execution-mode "$EXECUTION_MODE"
  --depth "$DEPTH"
  --max-depth "$MAX_DEPTH"
  --edge-type "$EDGE_TYPE"
  --allow-reentry "$ALLOW_REENTRY"
  --forbid-root-reload "$FORBID_ROOT_RELOAD"
  --request-id "$REQUEST_ID"
  --prompt "$PROMPT_TEXT"
)

if [[ -n "$PARENT_SKILL" ]]; then
  dispatch_args+=(--parent-skill "$PARENT_SKILL")
fi
if [[ -n "$SKILL_STACK" ]]; then
  dispatch_args+=(--skill-stack "$SKILL_STACK")
fi
if [[ -n "$VISITED_SKILLS" ]]; then
  dispatch_args+=(--visited-skills "$VISITED_SKILLS")
fi
if [[ -n "$OUTPUT_FILE" ]]; then
  dispatch_args+=(--output-file "$OUTPUT_FILE")
fi
if [[ -n "$RUNNER_CMD" ]]; then
  dispatch_args+=(--runner-cmd "$RUNNER_CMD")
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
  dispatch_args+=(--dry-run)
fi

"$DISPATCH_SCRIPT" "${dispatch_args[@]}"
