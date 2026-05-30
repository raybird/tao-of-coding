#!/usr/bin/env bats
# bin/tao 派發 CLI 行為測試
# 執行：bats tests/tao-cli.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TAO="$REPO_ROOT/bin/tao"
  TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/tao-cli.XXXXXX")"
  export HOME="$TMP"     # 讓 skill 連結偵測有確定結果（未連結）
  cd "$TMP"
}

teardown() {
  cd /
  rm -rf "$TMP"
}

@test "enable 全新空資料夾建立 AGENTS.md 含標記" {
  run bash "$TAO" enable
  [ "$status" -eq 0 ]
  [ -f "$TMP/AGENTS.md" ]
  grep -q "<!-- tao:start -->" "$TMP/AGENTS.md"
}

@test "enable 既有 CLAUDE.md 優先寫 CLAUDE.md" {
  printf '# c\n' > "$TMP/CLAUDE.md"
  run bash "$TAO" enable
  [ "$status" -eq 0 ]
  grep -q "<!-- tao:start -->" "$TMP/CLAUDE.md"
  [ ! -f "$TMP/AGENTS.md" ]
}

@test "enable 既有 AGENTS.md（無 CLAUDE.md）寫 AGENTS.md" {
  printf '# a\n' > "$TMP/AGENTS.md"
  run bash "$TAO" enable
  [ "$status" -eq 0 ]
  grep -q "<!-- tao:start -->" "$TMP/AGENTS.md"
  [ ! -f "$TMP/CLAUDE.md" ]
}

@test "enable --target 覆寫偵測" {
  run bash "$TAO" enable --target "$TMP/custom.md"
  [ "$status" -eq 0 ]
  grep -q "<!-- tao:start -->" "$TMP/custom.md"
}

@test "enable 冪等（第二次內容不變）" {
  bash "$TAO" enable
  cp "$TMP/AGENTS.md" "$TMP/first"
  bash "$TAO" enable
  diff "$TMP/first" "$TMP/AGENTS.md"
}

@test "enable --dry-run 不寫檔" {
  run bash "$TAO" enable --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$TMP/AGENTS.md" ]
}

@test "remove 移除受管區塊" {
  bash "$TAO" enable
  bash "$TAO" remove
  ! grep -q "<!-- tao:start -->" "$TMP/AGENTS.md"
}

@test "check 未安裝資料夾 exit 2" {
  run bash "$TAO" check
  [ "$status" -eq 2 ]
}

@test "check 已安裝 exit 0" {
  bash "$TAO" enable
  run bash "$TAO" check
  [ "$status" -eq 0 ]
}

@test "version 不報錯" {
  run bash "$TAO" version
  [ "$status" -eq 0 ]
}

@test "path 印 TAO_HOME（= repo 根）" {
  run bash "$TAO" path
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO_ROOT" ]
}

@test "未知子指令 exit 1" {
  run bash "$TAO" frobnicate
  [ "$status" -eq 1 ]
}
