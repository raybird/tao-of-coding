#!/usr/bin/env bats
# install-orchestrator.sh 的行為測試
# 執行：bats tests/install-orchestrator.bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/skills/tao-of-opencode/scripts/install-orchestrator.sh"
  TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/tao-test.XXXXXX")"
  TARGET="$TMP/AGENTS.md"
}

teardown() {
  rm -rf "$TMP"
}

# 以手寫憲法包住現有受管區塊（在區塊前插入手寫內容），模擬人機共存
prepend_constitution() {
  { printf '# 宿主憲法\n靈魂原則\n\n'; cat "$TARGET"; } > "$TMP/x" && mv "$TMP/x" "$TARGET"
}

@test "dry-run 不寫檔" {
  run bash "$SCRIPT" --target "$TARGET" --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$TARGET" ]
}

@test "建檔並寫入受管區塊（含起訖標記）" {
  run bash "$SCRIPT" --target "$TARGET"
  [ "$status" -eq 0 ]
  grep -q "<!-- tao:start -->" "$TARGET"
  grep -q "<!-- tao:end -->" "$TARGET"
}

@test "冪等：第二次執行內容完全不變" {
  bash "$SCRIPT" --target "$TARGET"
  cp "$TARGET" "$TMP/first"
  bash "$SCRIPT" --target "$TARGET"
  diff "$TMP/first" "$TARGET"
}

@test "非破壞：標記外手寫內容於重跑後保留" {
  bash "$SCRIPT" --target "$TARGET"
  prepend_constitution
  bash "$SCRIPT" --target "$TARGET"
  grep -q "靈魂原則" "$TARGET"
}

@test "無標記檔：append 區塊且保留既有內容" {
  printf '既有內容\n' > "$TMP/plain.md"
  run bash "$SCRIPT" --target "$TMP/plain.md"
  [ "$status" -eq 0 ]
  grep -q "既有內容" "$TMP/plain.md"
  grep -q "<!-- tao:start -->" "$TMP/plain.md"
}

@test "remove：移除區塊但保留標記外內容" {
  bash "$SCRIPT" --target "$TARGET"
  prepend_constitution
  bash "$SCRIPT" --target "$TARGET" --remove
  ! grep -q "<!-- tao:start -->" "$TARGET"
  grep -q "靈魂原則" "$TARGET"
}

@test "--skill-ref 注入路徑，且變更時就地替換、不產生重複區塊" {
  bash "$SCRIPT" --target "$TARGET" --skill-ref "OLD/path"
  prepend_constitution
  bash "$SCRIPT" --target "$TARGET" --skill-ref "NEW/path"
  grep -q "NEW/path" "$TARGET"
  ! grep -q "OLD/path" "$TARGET"
  grep -q "靈魂原則" "$TARGET"
  [ "$(grep -c '<!-- tao:start -->' "$TARGET")" -eq 1 ]
}

@test "建檔後 dry-run 顯示 up to date 且不改檔" {
  bash "$SCRIPT" --target "$TARGET"
  cp "$TARGET" "$TMP/before"
  run bash "$SCRIPT" --target "$TARGET" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* || "$output" == *"無變更"* ]]
  diff "$TMP/before" "$TARGET"
}

@test "remove 一個沒有區塊的檔：安全 no-op" {
  printf '只有手寫內容\n' > "$TMP/plain.md"
  run bash "$SCRIPT" --target "$TMP/plain.md" --remove
  [ "$status" -eq 0 ]
  grep -q "只有手寫內容" "$TMP/plain.md"
  ! grep -q "<!-- tao:start -->" "$TMP/plain.md"
}
