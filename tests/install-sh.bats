#!/usr/bin/env bats
# install.sh 連結/卸載行為測試（--link-only，免網路）
# 執行：bats tests/install-sh.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  INSTALL="$REPO_ROOT/install.sh"
  TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/tao-install.XXXXXX")"
  export HOME="$TMP"          # 重導 ~/.local/bin 到暫存
  export TAO_HOME="$REPO_ROOT"
}

teardown() {
  rm -rf "$TMP"
}

@test "--link-only 建立 ~/.local/bin/tao symlink 指向 TAO_HOME/bin/tao" {
  run bash "$INSTALL" --link-only
  [ "$status" -eq 0 ]
  [ -L "$TMP/.local/bin/tao" ]
  [ "$(readlink "$TMP/.local/bin/tao")" = "$REPO_ROOT/bin/tao" ]
}

@test "--link-only 冪等（重跑仍成功且為 symlink）" {
  bash "$INSTALL" --link-only
  run bash "$INSTALL" --link-only
  [ "$status" -eq 0 ]
  [ -L "$TMP/.local/bin/tao" ]
}

@test "--uninstall 移除 symlink、不刪內容" {
  bash "$INSTALL" --link-only
  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$TMP/.local/bin/tao" ]
  [ -f "$REPO_ROOT/bin/tao" ]
}

@test "未知參數 exit 1" {
  run bash "$INSTALL" --bogus
  [ "$status" -eq 1 ]
}

@test "連結後可經 PATH 呼叫 tao path" {
  bash "$INSTALL" --link-only
  run env PATH="$TMP/.local/bin:$PATH" tao path
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO_ROOT" ]
}
