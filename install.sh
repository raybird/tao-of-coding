#!/usr/bin/env bash
# install.sh — tao-of-coding curl|bash bootstrap 安裝器。
#   curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh | bash
# 行為冪等（重跑＝升級）。直接下載 tarball 解壓，不需 git；只需 curl 與 tar。
# （維護者若已 git clone，install.sh 偵測到 .git 會改用 git pull。）Windows 需 WSL / git-bash。
set -euo pipefail

REPO_SLUG="raybird/tao-of-coding"
DEFAULT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/tao-of-coding"
BIN_DIR="$HOME/.local/bin"

TAO_HOME="${TAO_HOME:-$DEFAULT_HOME}"
REF="main"
UNINSTALL=0
LINK_ONLY=0

while (($#)); do
  case "$1" in
    --dir)  TAO_HOME="$2"; shift 2 ;;
    --ref)  REF="$2"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    --link-only) LINK_ONLY=1; shift ;;   # 跳過 clone/pull，只連結（測試 / 維護者用）
    -h|--help)
      echo "用法：install.sh [--dir <path>] [--ref <branch|tag>] [--uninstall] [--link-only]"
      exit 0 ;;
    *) echo "install.sh: 未知參數 '$1'" >&2; exit 1 ;;
  esac
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  rm -f "$BIN_DIR/tao"
  echo "已移除 $BIN_DIR/tao。內容仍在 $TAO_HOME（手動刪除：rm -rf \"$TAO_HOME\"）"
  exit 0
fi

if [[ "$LINK_ONLY" -ne 1 ]]; then
  if [[ -d "$TAO_HOME/.git" ]]; then
    # 維護者既有 git clone：用 git 更新，不重抓 tarball。
    echo "偵測到 git clone，用 git 更新：$TAO_HOME"
    git -C "$TAO_HOME" pull --ff-only
  else
    # 直接下載 tarball 解壓（不需 git）。archive/<ref> 同時支援分支/標籤/commit。
    tarball_url="https://github.com/$REPO_SLUG/archive/$REF.tar.gz"
    echo "下載並解壓到：$TAO_HOME（$tarball_url）"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/tao-dl.XXXXXX")"
    curl -fsSL "$tarball_url" | tar -xz -C "$tmp"
    extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [[ -d "$extracted" ]] || { echo "解壓失敗：$tarball_url" >&2; rm -rf "$tmp"; exit 1; }
    rm -rf "$TAO_HOME"
    mkdir -p "$(dirname "$TAO_HOME")"
    mv "$extracted" "$TAO_HOME"
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
