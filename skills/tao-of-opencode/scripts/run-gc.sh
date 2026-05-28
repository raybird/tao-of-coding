#!/usr/bin/env bash
set -euo pipefail

# Prune stale run directories and their associated git worktrees under .tao/runs/.
# Usage:
#   run-gc.sh                        # dry-run: list what would be removed
#   run-gc.sh --execute              # remove runs older than MAX_AGE_DAYS
#   run-gc.sh --execute --max-age 1  # custom age threshold (days)
#   run-gc.sh --request-id <id>      # remove one specific run (with --execute)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

EXECUTE=0
MAX_AGE_DAYS=7
TARGET_ID=""

while (($#)); do
  case "$1" in
    --execute)    EXECUTE=1; shift ;;
    --max-age)    MAX_AGE_DAYS="${2:-}"; shift 2 ;;
    --request-id) TARGET_ID="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<'HELP'
Usage:
  run-gc.sh [--execute] [--max-age <days>] [--request-id <id>]

Without --execute, prints what would be removed (dry-run).
HELP
      exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

RUNS_ROOT="$REPO_ROOT/.tao/runs"

if [[ ! -d "$RUNS_ROOT" ]]; then
  printf 'no runs directory found: %s\n' "$RUNS_ROOT"
  exit 0
fi

# Collect candidate run dirs.
mapfile -t candidates < <(
  if [[ -n "$TARGET_ID" ]]; then
    echo "$RUNS_ROOT/$TARGET_ID"
  else
    find "$RUNS_ROOT" -mindepth 1 -maxdepth 1 -type d \
      -not -newer "$RUNS_ROOT" \
      | while IFS= read -r d; do
          # mtime older than MAX_AGE_DAYS
          if [[ $(find "$d" -maxdepth 0 -mmin "+$((MAX_AGE_DAYS * 1440))") == "$d" ]]; then
            echo "$d"
          fi
        done
  fi
)

if [[ ${#candidates[@]} -eq 0 ]]; then
  printf 'nothing to prune (max-age=%d days)\n' "$MAX_AGE_DAYS"
  exit 0
fi

removed=0
for run_dir in "${candidates[@]}"; do
  [[ -d "$run_dir" ]] || continue
  run_id="$(basename "$run_dir")"
  workspace="$run_dir/workspace"

  if [[ "$EXECUTE" -eq 1 ]]; then
    # Remove worktree first (git tracks it separately).
    if git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
        | grep -qF "worktree $workspace"; then
      git -C "$REPO_ROOT" worktree remove --force "$workspace" 2>/dev/null || true
    fi
    rm -rf "$run_dir"
    printf 'removed  %s\n' "$run_id"
    removed=$((removed + 1))
  else
    # Dry-run: just list.
    workspace_info="no workspace"
    if [[ -d "$workspace" ]]; then
      workspace_info="has workspace"
    fi
    msg_count=$(find "$run_dir/messages" -name "*.json" 2>/dev/null | wc -l)
    printf 'would remove  %s  (%s, %d message(s))\n' \
      "$run_id" "$workspace_info" "$msg_count"
  fi
done

if [[ "$EXECUTE" -eq 1 ]]; then
  printf '\npruned %d run(s)\n' "$removed"
  # Prune any dangling worktree refs.
  git -C "$REPO_ROOT" worktree prune 2>/dev/null || true
else
  printf '\n(dry-run) pass --execute to delete\n'
fi
