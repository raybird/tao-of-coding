#!/usr/bin/env bash
# install.sh — tao-of-coding curl|bash bootstrap 安裝器。
#   curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh | bash
# 行為冪等（重跑＝升級）。直接下載 tarball 解壓，不需 git；需 curl 或 wget，以及 tar。
# （維護者若已 git clone，install.sh 偵測到 .git 會改用 git pull。）Windows 需 WSL / git-bash。
set -euo pipefail

REPO_SLUG="raybird/tao-of-coding"
DEFAULT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/tao-of-coding"
BIN_DIR="$HOME/.local/bin"

TAO_HOME="${TAO_HOME:-$DEFAULT_HOME}"
REF="main"
UNINSTALL=0
LINK_ONLY=0
PURGE=0

while (($#)); do
  case "$1" in
    --dir)  TAO_HOME="$2"; shift 2 ;;
    --ref)  REF="$2"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    --purge) PURGE=1; shift ;;
    --link-only) LINK_ONLY=1; shift ;;   # 跳過 clone/pull，只連結（測試 / 維護者用）
    -h|--help)
      echo "用法：install.sh [--dir <path>] [--ref <branch|tag>] [--uninstall [--purge]] [--link-only]"
      echo "預設以 GitHub tarball 下載安裝，不需 git clone；既有 .git 安裝才用 git pull。"
      echo "--uninstall 只移除 tao 指令連結；加 --purge 會一併刪除 TAO_HOME。"
      exit 0 ;;
    *) echo "install.sh: 未知參數 '$1'" >&2; exit 1 ;;
  esac
done

if [[ "$PURGE" -eq 1 && "$UNINSTALL" -ne 1 ]]; then
  echo "install.sh: --purge 只能搭配 --uninstall 使用。" >&2
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "install.sh: 缺少必要工具 '$1'。請先安裝後再重跑。" >&2
    exit 127
  }
}

download_file() {
  local src="$1" dst="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dst" "$src"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$dst" "$src"
  else
    echo "install.sh: 缺少必要工具 'curl' 或 'wget'。請先安裝其中之一後再重跑。" >&2
    exit 127
  fi
}

require_cmd mkdir
require_cmd rm
require_cmd ln

if [[ "$UNINSTALL" -ne 1 ]]; then
  require_cmd chmod
  if [[ "$LINK_ONLY" -ne 1 ]]; then
    require_cmd mktemp
    require_cmd tar
    require_cmd find
    require_cmd head
    require_cmd mv
  fi
fi

if [[ "$UNINSTALL" -eq 1 ]]; then
  rm -f "$BIN_DIR/tao"
  if [[ "$PURGE" -eq 1 ]]; then
    if [[ -f "$TAO_HOME/bin/tao" && -d "$TAO_HOME/skills/tao-of-opencode" ]]; then
      rm -rf "$TAO_HOME"
      echo "已移除 $BIN_DIR/tao，並刪除 $TAO_HOME。"
    else
      echo "拒絕刪除：$TAO_HOME 看起來不像 tao-of-coding 安裝目錄。" >&2
      exit 1
    fi
  else
    echo "已移除 $BIN_DIR/tao。內容仍在 $TAO_HOME（乾淨移除：加 --purge）"
  fi
  exit 0
fi

if [[ "$LINK_ONLY" -ne 1 ]]; then
  if [[ -d "$TAO_HOME/.git" ]]; then
    # 維護者既有 git clone：用 git 更新，不重抓 tarball。
    require_cmd git
    echo "偵測到 git clone，用 git 更新：$TAO_HOME"
    git -C "$TAO_HOME" pull --ff-only
  else
    # 直接下載 tarball 解壓（不需 git）。archive/<ref> 同時支援分支/標籤/commit。
    tarball_url="https://github.com/$REPO_SLUG/archive/$REF.tar.gz"
    echo "下載並解壓到：$TAO_HOME（$tarball_url）"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/tao-dl.XXXXXX")"
    cleanup() { rm -rf "$tmp"; }
    trap cleanup EXIT
    staging_payload="$tmp/tao-of-coding.tar.gz"
    if ! download_file "$tarball_url" "$staging_payload"; then
      echo "下載失敗：$tarball_url" >&2
      exit 1
    fi
    if ! tar -xzf "$staging_payload" -C "$tmp"; then
      echo "解壓失敗：$tarball_url" >&2
      exit 1
    fi
    extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [[ -d "$extracted" ]] || { echo "解壓失敗：$tarball_url" >&2; exit 1; }
    rm -rf "$TAO_HOME"
    mkdir -p "$(dirname "$TAO_HOME")"
    mv "$extracted" "$TAO_HOME"
    trap - EXIT
    rm -rf "$tmp"
    printf '%s\n' "$REF" > "$TAO_HOME/.tao-ref"
  fi
fi

[[ -f "$TAO_HOME/bin/tao" ]] || { echo "找不到 $TAO_HOME/bin/tao" >&2; exit 1; }
chmod +x "$TAO_HOME/bin/tao"
mkdir -p "$BIN_DIR"
ln -sf "$TAO_HOME/bin/tao" "$BIN_DIR/tao"
echo "已連結指令：$BIN_DIR/tao -> $TAO_HOME/bin/tao"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo ""
     echo "提醒：$BIN_DIR 不在 PATH。加到你的 shell rc（~/.bashrc 或 ~/.zshrc）："
     echo "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

echo ""
echo "安裝完成。下一步：cd 你的專案 && tao enable（首次可先 tao link 連結 skill）"
