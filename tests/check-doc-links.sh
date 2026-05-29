#!/usr/bin/env bash
# check-doc-links.sh — 檢查追蹤中 Markdown 的「本地相對連結」是否指向存在的檔案。
#
# 只檢查 ](相對路徑) 形式的本地連結；略過 http(s)/mailto、純錨點 (#...)，
# 並剝除路徑尾端的 #anchor。任一連結指向不存在的檔案即失敗（exit 1）。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail=0

# 取得追蹤中的 .md（排除 superpowers 上游本地化目錄，其連結對應上游結構不在本檢查範圍）
mapfile -t md_files < <(git ls-files '*.md' ':!:**/superpowers/**')

for f in "${md_files[@]}"; do
  dir="$(dirname "$f")"
  # 抽出 ](target) 內的 target
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    # 略過外部連結與純錨點
    case "$target" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    # 剝除 #anchor 與 ?query
    path="${target%%#*}"
    path="${path%%\?*}"
    [[ -z "$path" ]] && continue
    # 絕對路徑（/...）相對 repo root；否則相對檔案所在目錄
    if [[ "$path" == /* ]]; then
      resolved="$REPO_ROOT$path"
    else
      resolved="$dir/$path"
    fi
    if [[ ! -e "$resolved" ]]; then
      printf '❌ %s -> 連結失效: %s\n' "$f" "$target" >&2
      fail=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
done

if [[ "$fail" -eq 0 ]]; then
  echo "✅ 所有本地 Markdown 連結均指向存在的檔案。"
fi
exit "$fail"
