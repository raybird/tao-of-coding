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

@test "help mentions tarball/no clone path" {
  run bash "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"tarball"* || "$output" == *"不需 git"* || "$output" == *"不 clone"* ]]
}

@test "tarball 安裝先下載到 staging 檔再解壓" {
  unset TAO_HOME

  mkdir -p "$TMP/src/tao-of-coding-main/bin" "$TMP/fakebin"
  printf '#!/usr/bin/env bash\necho installed-tao\n' > "$TMP/src/tao-of-coding-main/bin/tao"
  chmod +x "$TMP/src/tao-of-coding-main/bin/tao"
  tar -czf "$TMP/payload.tar.gz" -C "$TMP/src" tao-of-coding-main

  cat > "$TMP/fakebin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -euo pipefail
dst=""
while (($#)); do
  case "$1" in
    -o)
      dst="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -z "$dst" ]]; then
  echo "fake curl expected -o staging file" >&2
  exit 64
fi
cp "$PAYLOAD" "$dst"
FAKE_CURL
  chmod +x "$TMP/fakebin/curl"

  run env PATH="$TMP/fakebin:$PATH" PAYLOAD="$TMP/payload.tar.gz" TAO_HOME="$TMP/target" bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMP/target/bin/tao" ]
  [ -L "$TMP/.local/bin/tao" ]
  [ "$(readlink "$TMP/.local/bin/tao")" = "$TMP/target/bin/tao" ]
}

@test "tarball 安裝沒有 curl 時可用 wget 下載 staging 檔" {
  unset TAO_HOME

  mkdir -p "$TMP/src/tao-of-coding-main/bin" "$TMP/fakebin"
  printf '#!/usr/bin/env bash\necho installed-tao\n' > "$TMP/src/tao-of-coding-main/bin/tao"
  chmod +x "$TMP/src/tao-of-coding-main/bin/tao"
  tar -czf "$TMP/payload.tar.gz" -C "$TMP/src" tao-of-coding-main

  for cmd in bash mkdir rm ln chmod mktemp tar gzip find head mv dirname cp; do
    ln -s "$(command -v "$cmd")" "$TMP/fakebin/$cmd"
  done
  cat > "$TMP/fakebin/wget" <<'FAKE_WGET'
#!/usr/bin/env bash
set -euo pipefail
dst=""
while (($#)); do
  case "$1" in
    -O)
      dst="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -z "$dst" ]]; then
  echo "fake wget expected -O staging file" >&2
  exit 64
fi
cp "$PAYLOAD" "$dst"
FAKE_WGET
  chmod +x "$TMP/fakebin/wget"

  run /usr/bin/env PATH="$TMP/fakebin" PAYLOAD="$TMP/payload.tar.gz" TAO_HOME="$TMP/target" /bin/bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMP/target/bin/tao" ]
}
