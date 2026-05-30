# tao CLI 與 curl|bash 安裝器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 tao-of-coding 可用一條 `curl | bash` 全域安裝、取得 `tao` 指令，逐專案 `tao enable` 一鍵啟用、`tao upgrade` 升級，同時根治受管區塊角色卡的壞連結。

**Architecture:** 三層——`install.sh`（bootstrap，clone 到 TAO_HOME + symlink `tao` 進 PATH）→ `bin/tao`（派發 CLI：enable/link/upgrade/check/remove/version/path）→ 既有 `install-orchestrator.sh`（寫受管區塊，不重寫）。受管區塊角色卡改為 skill 名稱式引用（可攜、不再有檔案路徑壞連結）。全程純 bash，零 node 依賴。

**Tech Stack:** Bash、bats（測試）、shellcheck（lint）、GitHub Actions（CI）。

**設計來源：** `docs/superpowers/specs/2026-05-30-tao-cli-curl-install-design.md`

---

## 檔案結構

| 檔案 | 責任 | 動作 |
| :--- | :--- | :--- |
| `skills/tao-of-opencode/scripts/install-orchestrator.sh` | 寫受管區塊 | 改：角色卡引用變數 `ROLE_CARD_HINT` |
| `bin/tao` | 派發 CLI | 新建 |
| `install.sh` | curl\|bash bootstrap | 新建（repo 根） |
| `tests/install-orchestrator.bats` | 既有腳本測試 | 補：skill 名稱式預設 / `--skill-ref` 覆寫斷言 |
| `tests/tao-cli.bats` | `bin/tao` 行為測試 | 新建 |
| `tests/install-sh.bats` | `install.sh` 連結/卸載測試 | 新建 |
| `.github/workflows/ci.yml` | CI | 改：納入新腳本與所有 bats |
| `README.md` / `docs/host-integration.md` / `CLAUDE.md` | 文件 | 改 |

---

## Task 1: 受管區塊改用 skill 名稱式引用角色卡

**Files:**
- Modify: `skills/tao-of-opencode/scripts/install-orchestrator.sh`（heredoc 區、約 line 122-146；及預設 `SKILL_REF` 區 line 63）
- Test: `tests/install-orchestrator.bats`

- [ ] **Step 1: 補失敗測試（預設用 skill 名稱式、不含相對路徑；--skill-ref 仍走路徑式）**

在 `tests/install-orchestrator.bats` 末尾新增：

```bash
@test "預設受管區塊用 skill 名稱式引用、不含相對路徑 skills/tao-of-opencode/references" {
  bash "$SCRIPT" --target "$TARGET"
  grep -q '`tao-of-opencode` skill' "$TARGET"
  ! grep -q 'skills/tao-of-opencode/references' "$TARGET"
}

@test "--skill-ref 覆寫時改回路徑式引用（含該路徑）" {
  bash "$SCRIPT" --target "$TARGET" --skill-ref "CUSTOM/refs"
  grep -q "CUSTOM/refs/<role>.md" "$TARGET"
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `bats tests/install-orchestrator.bats -f "skill 名稱式|路徑式引用"`
Expected: FAIL（預設區塊目前含 `skills/tao-of-opencode/references`）

- [ ] **Step 3: 改 install-orchestrator.sh 加入 ROLE_CARD_HINT**

把預設 `SKILL_REF` 的語意改為「未顯式指定」哨兵。將 line 63：

```bash
SKILL_REF="skills/tao-of-opencode/references"
```

改為：

```bash
SKILL_REF=""   # 空 = 未顯式指定 → 用 skill 名稱式 ROLE_CARD_HINT
```

在 heredoc（`cat > "$BLOCK_FILE"` 之前）插入 `ROLE_CARD_HINT` 計算：

```bash
# 角色卡引用：預設用 skill 名稱式（可攜、不含檔案路徑）；--skill-ref 覆寫成路徑式。
if [[ -n "$SKILL_REF" ]]; then
  ROLE_CARD_HINT="詳細角色卡見 ${SKILL_REF}/<role>.md。"
else
  ROLE_CARD_HINT="詳細角色卡見已連結的 \`tao-of-opencode\` skill 的 \`references/<role>.md\`（Explorer / Oracle / Librarian / Fixer / Designer）。"
fi
```

把 heredoc 內這一行（原 line 127 附近）：

```
並調度合適的子代理完成任務。詳細角色卡見 ${SKILL_REF}/<role>.md。
```

改為：

```
並調度合適的子代理完成任務。${ROLE_CARD_HINT}
```

- [ ] **Step 4: 跑全套 install-orchestrator 測試確認通過**

Run: `bats tests/install-orchestrator.bats`
Expected: 全數 PASS（含既有的 `--skill-ref 注入路徑` 與 `--check 過時` 測試——後者用 `--skill-ref OLD/path` 仍走路徑式分支，行為不變）

- [ ] **Step 5: Commit**

```bash
git add skills/tao-of-opencode/scripts/install-orchestrator.sh tests/install-orchestrator.bats
git commit -m "fix(install-orchestrator): 受管區塊預設改用 skill 名稱式引用角色卡，根治新資料夾壞連結"
```

---

## Task 2: `bin/tao` 派發 CLI

**Files:**
- Create: `bin/tao`
- Test: `tests/tao-cli.bats`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/tao-cli.bats`：

```bash
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
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `bats tests/tao-cli.bats`
Expected: FAIL（`bin/tao` 不存在）

- [ ] **Step 3: 建立 `bin/tao`**

```bash
#!/usr/bin/env bash
# tao — tao-of-coding 派發 CLI。
# 子指令：enable / link / upgrade / check / remove / version / path / help。
set -euo pipefail

# 解析自身真實位置（可能經由 ~/.local/bin/tao symlink 呼叫；不依賴 GNU readlink -f）。
_self="${BASH_SOURCE[0]}"
while [ -L "$_self" ]; do
  _link="$(readlink "$_self")"
  case "$_link" in
    /*) _self="$_link" ;;
    *)  _self="$(dirname "$_self")/$_link" ;;
  esac
done
BIN_DIR_SELF="$(cd "$(dirname "$_self")" && pwd)"
TAO_HOME="$(cd "$BIN_DIR_SELF/.." && pwd)"
INSTALL_ORCH="$TAO_HOME/skills/tao-of-opencode/scripts/install-orchestrator.sh"
SKILL_SRC="$TAO_HOME/skills/tao-of-opencode"

usage() {
  cat <<'USAGE'
用法：tao <子指令> [選項]

子指令：
  enable [--target <p>] [--dry-run] [--remove] [--check]
                  在當前資料夾寫入 orchestrator 受管區塊。
                  宿主檔偵測：--target > 既有 CLAUDE.md > 既有 AGENTS.md > 建立 AGENTS.md。
  link            把 tao-of-opencode skill 連結進宿主（委派 npx skill-linker）。
  upgrade         更新 tao（git pull）並顯示版本。
  check           檢查當前資料夾受管區塊狀態（exit 0=最新/1=過時/2=未安裝）。
  remove          移除當前資料夾受管區塊。
  version         顯示版本（git describe）。
  path            顯示 TAO_HOME。
  help            顯示本說明。
USAGE
}

detect_target() {
  if [[ -f "./CLAUDE.md" ]]; then echo "./CLAUDE.md"
  elif [[ -f "./AGENTS.md" ]]; then echo "./AGENTS.md"
  else echo "./AGENTS.md"; fi
}

skill_linked() {
  local d
  for d in \
    "$HOME/.claude/skills/tao-of-opencode" \
    "$HOME/.gemini/antigravity/skills/tao-of-opencode" \
    "$HOME/.codeium/windsurf/skills/tao-of-opencode"; do
    [[ -e "$d" ]] && return 0
  done
  return 1
}

cmd_enable() {
  local target="" passthru=()
  while (($#)); do
    case "$1" in
      --target)
        [[ $# -ge 2 ]] || { echo "tao enable: --target 需要值" >&2; return 1; }
        target="$2"; shift 2 ;;
      --dry-run|--remove|--check) passthru+=("$1"); shift ;;
      -h|--help) usage; return 0 ;;
      *) echo "tao enable: 未知參數 '$1'" >&2; return 1 ;;
    esac
  done
  [[ -n "$target" ]] || target="$(detect_target)"
  bash "$INSTALL_ORCH" --target "$target" ${passthru[@]+"${passthru[@]}"}
  # 僅在實際寫入（無 dry-run/check/remove）時提示 skill 連結
  local p only_write=1
  for p in ${passthru[@]+"${passthru[@]}"}; do
    case "$p" in --dry-run|--check|--remove) only_write=0 ;; esac
  done
  if [[ "$only_write" -eq 1 ]] && ! skill_linked; then
    echo "提示：尚未偵測到 tao-of-opencode skill 連結；角色卡需 skill 連結才載得到。" >&2
    echo "      執行：tao link（或 npx skill-linker）" >&2
  fi
}

cmd_link() {
  if command -v npx >/dev/null 2>&1; then
    npx skill-linker
  else
    echo "找不到 npx。請手動 symlink，例如：" >&2
    echo "  ln -s \"$SKILL_SRC\" ~/.gemini/antigravity/skills/tao-of-opencode" >&2
    return 1
  fi
}

cmd_version() {
  git -C "$TAO_HOME" describe --tags --always 2>/dev/null || echo "unknown"
}

cmd_upgrade() {
  git -C "$TAO_HOME" pull --ff-only
  echo "tao 現為：$(cmd_version)"
}

main() {
  local sub="${1:-help}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    enable)  cmd_enable "$@" ;;
    link)    cmd_link "$@" ;;
    upgrade) cmd_upgrade "$@" ;;
    check)   cmd_enable --check "$@" ;;
    remove)  cmd_enable --remove "$@" ;;
    version) cmd_version ;;
    path)    echo "$TAO_HOME" ;;
    help|-h|--help) usage ;;
    *) echo "tao: 未知子指令 '$sub'" >&2; usage >&2; exit 1 ;;
  esac
}

main "$@"
```

- [ ] **Step 4: 設可執行並跑測試**

Run: `chmod +x bin/tao && bats tests/tao-cli.bats`
Expected: 全數 PASS

- [ ] **Step 5: Commit**

```bash
git add bin/tao tests/tao-cli.bats
git commit -m "feat(tao-cli): 新增 tao 派發 CLI（enable/link/upgrade/check/remove/version/path）"
```

---

## Task 3: `install.sh` curl|bash bootstrap

**Files:**
- Create: `install.sh`（repo 根）
- Test: `tests/install-sh.bats`

- [ ] **Step 1: 寫失敗測試（用 `--link-only` 免網路）**

建立 `tests/install-sh.bats`：

```bash
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
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `bats tests/install-sh.bats`
Expected: FAIL（`install.sh` 不存在）

- [ ] **Step 3: 建立 `install.sh`**

```bash
#!/usr/bin/env bash
# install.sh — tao-of-coding curl|bash bootstrap 安裝器。
#   curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh | bash
# 行為冪等（重跑＝升級）。純 bash，需 git；Windows 需 WSL / git-bash。
set -euo pipefail

REPO_URL="https://github.com/raybird/tao-of-coding.git"
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
    echo "更新既有安裝：$TAO_HOME"
    git -C "$TAO_HOME" pull --ff-only
  else
    echo "下載到：$TAO_HOME"
    mkdir -p "$(dirname "$TAO_HOME")"
    git clone --branch "$REF" "$REPO_URL" "$TAO_HOME"
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
echo "安裝完成。下一步：cd 你的專案 && tao enable（首次可先 tao link / npx skill-linker）"
```

- [ ] **Step 4: 跑測試確認通過**

Run: `chmod +x install.sh && bats tests/install-sh.bats`
Expected: 全數 PASS

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/install-sh.bats
git commit -m "feat(install): 新增 curl|bash bootstrap 安裝器（clone + symlink tao 進 PATH）"
```

---

## Task 4: CI 納入新腳本與所有 bats

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: 改 lint 與 test job**

把 `.github/workflows/ci.yml` 的 lint job 兩個 step 改為（明列 `install.sh`、`bin/tao`，因不在原 glob 範圍）：

```yaml
      - name: bash -n（語法檢查，全部腳本）
        run: |
          for s in install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh; do
            bash -n "$s"
          done
      - name: shellcheck（error 級；審完既有腳本後可調至 warning）
        run: shellcheck -S error install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh
```

把 test job 的 run bats step 改為跑全部 bats：

```yaml
      - name: run bats
        run: bats tests/*.bats
```

- [ ] **Step 2: 本地驗證 lint 與全測試**

Run:
```bash
for s in install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh; do bash -n "$s"; done
shellcheck -S error install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh
bats tests/*.bats
```
Expected: 三者皆無錯、全 PASS。若 shellcheck 對 `${passthru[@]+...}` 等回報 error，依其建議修正後重跑。

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: lint 納入 install.sh 與 bin/tao，bats 改跑 tests/*.bats"
```

---

## Task 5: 文件更新（README / host-integration / CLAUDE.md）

**Files:**
- Modify: `README.md`（〈安裝配置〉、〈環境需求〉、〈目錄結構〉）
- Modify: `docs/host-integration.md`（各宿主「安裝啟用」段）
- Modify: `CLAUDE.md`（〈常用指令〉）

- [ ] **Step 1: 改寫 README〈安裝配置〉**

把 README「## 安裝配置 (Installation)」整節（步驟 1-3）替換為下列內容（保留 `install-orchestrator.sh` 為進階用法）：

````markdown
## 安裝配置 (Installation)

### 快速安裝（推薦）

一條指令裝好，全域取得 `tao` 指令（純 bash，需 `git`；Windows 需 WSL / git-bash）：

```bash
curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh | bash
```

> **偏好先檢視再執行？** 下載後看過再跑：
> ```bash
> curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh -o /tmp/tao-install.sh
> less /tmp/tao-install.sh
> bash /tmp/tao-install.sh
> ```

安裝器會把內容放到 `~/.local/share/tao-of-coding`、把 `tao` 連進 `~/.local/bin`。若 `~/.local/bin` 不在 `PATH`，依提示加一行到你的 shell rc。

### 在任意專案資料夾啟用

```bash
cd ~/projects/your-project
tao link        # 首次：把 tao-of-opencode skill 連進宿主（委派 npx skill-linker）
tao enable      # 偵測/建立 AGENTS.md（或既有 CLAUDE.md），寫入 orchestrator 受管區塊
```

常用：

```bash
tao enable --dry-run   # 預覽不寫檔
tao check              # 檢查狀態（exit 0=最新/1=過時/2=未安裝）
tao remove             # 卸載受管區塊
tao upgrade            # 升級 tao 本體（git pull）
```

### 進階：直接用底層腳本

不想裝 `tao` 也可直接呼叫維護腳本（細節見〈確立 orchestrator 根身份〉與下方各文件）：

```bash
bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target AGENTS.md
```

受管區塊以 `<!-- tao:start -->` / `<!-- tao:end -->` 包夾，只放「名冊摘要 + 調度準則」；全文角色卡永遠留在 `skills/`。每次寫入前會建立時間戳備份。
````

- [ ] **Step 2: 改 README〈環境需求〉表格補 tao 一列、目錄結構補新檔**

在〈環境需求〉表格 `Git` 列下方新增：

```markdown
| **tao CLI** | 全域入口（`tao enable` / `upgrade` 等）；由 `install.sh` 安裝。 | `tao version` |
```

在〈目錄結構〉的樹狀圖最上層補入兩個新檔（README 末段 `├── README.md` 附近）：

```text
├── install.sh                       # curl|bash bootstrap 安裝器
├── bin/
│   └── tao                          # 派發 CLI（enable/link/upgrade/check/remove）
```

- [ ] **Step 3: 改 `docs/host-integration.md` 各宿主「安裝啟用」段**

在三個宿主（Claude Code / Codex / Antigravity）的「### 安裝啟用」段最前面，各加一行一鍵替代寫法。Claude Code 段加：

```markdown
- **一鍵（推薦）**：`tao link && tao enable`（`enable` 會偵測既有 `CLAUDE.md` 優先寫入）。底層仍是下方 `install-orchestrator.sh`。
```

Codex 段與 Antigravity 段各加：

```markdown
- **一鍵（推薦）**：`tao link && tao enable`（新資料夾預設寫 `AGENTS.md`）。底層仍是下方 `install-orchestrator.sh`。
```

- [ ] **Step 4: 改 `CLAUDE.md`〈常用指令〉補 tao CLI 區塊**

在 `CLAUDE.md`「## 常用指令」開頭、緊接該節說明段之後，新增：

````markdown
### tao CLI（全域入口）

由 `install.sh` 安裝後可用（`curl -fsSL .../install.sh | bash`）：

```bash
tao enable     # 當前資料夾寫入受管區塊（偵測 CLAUDE.md > AGENTS.md > 建 AGENTS.md）
tao check      # 狀態檢查（exit 0/1/2）
tao remove     # 卸載受管區塊
tao link       # 連 skill 進宿主（委派 npx skill-linker）
tao upgrade    # 升級 tao 本體（git pull）
```

`tao enable` 等同呼叫下方 `install-orchestrator.sh`，差別在自動偵測宿主檔、用絕對路徑、免記腳本位置。
````

- [ ] **Step 5: 死連結檢查 + 提交**

Run: `bash tests/check-doc-links.sh`
Expected: PASS（無死連結）

```bash
git add README.md docs/host-integration.md CLAUDE.md
git commit -m "docs: README/host-integration/CLAUDE.md 改寫安裝流程為 tao CLI + curl|bash"
```

---

## Self-Review

**Spec coverage：**
- §3.1 skill 名稱式引用 → Task 1 ✅
- §3.2 install.sh（TAO_HOME/clone/symlink/PATH 提示/uninstall/兩步安全版）→ Task 3 + README（兩步版）✅
- §3.3 bin/tao 各子指令 → Task 2 ✅（link 委派 npx、upgrade git pull）
- §3.4 文件 → Task 5 ✅
- §4 測試（tao-cli / install-sh / install-orchestrator 補）→ Task 1-3 ✅；CI → Task 4 ✅
- §5 風險緩解（兩步版、不自動改 rc、PATH 提示、skill 連結提示、Windows 標註）→ Task 3 + Task 5 README ✅

**Placeholder scan：** 無 TBD/TODO；每段含完整碼與指令。

**Type/介面一致性：** `cmd_enable` 旗標集（--target/--dry-run/--remove/--check）與 `tao-cli.bats`、`install-orchestrator.sh` 旗標一致；`ROLE_CARD_HINT` 變數名在 Task 1 step 3 定義並使用一致；`--link-only` 在 install.sh 與 install-sh.bats 一致；symlink 目標 `$TAO_HOME/bin/tao` 在 install.sh 與測試斷言一致。

**已知前提：** install.sh 的 `git clone` 路徑未進單測（需網路），由 README 手動驗證與 `bash -n`/shellcheck 涵蓋——符合 spec §4「網路相關不在單測涵蓋」。
````
