# Installation Friendliness Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the latest tao-of-coding installer clearly support no-clone installation, reduce first-run friction, and keep README/CLI/help text consistent with actual behavior.

**Architecture:** Keep the existing three-layer installer architecture: `install.sh` bootstraps tao from a GitHub tarball, `bin/tao` dispatches daily commands, and `install-orchestrator.sh` maintains the host managed block. This plan avoids introducing new dependencies and only adds small Bash guardrails, help-text fixes, and documentation updates.

**Tech Stack:** Bash, bats, shellcheck, Markdown, GitHub Actions.

---

## File Structure

| File | Responsibility | Planned Change |
| :--- | :--- | :--- |
| `install.sh` | Global `curl | bash` bootstrap installer | Add dependency preflight and clearer install/upgrade wording. |
| `bin/tao` | Daily CLI entry point | Fix misleading `upgrade` help text, make `link` guidance friendlier, optionally detect `.agents/skills`. |
| `tests/install-sh.bats` | Installer behavior tests | Add tests for missing dependency messaging where practical and help text expectations. |
| `tests/tao-cli.bats` | CLI behavior tests | Add tests for help text, `.agents/skills` link detection, and no-host guidance. |
| `README.md` | Primary user-facing install docs | Remove git/no-git contradiction, add host-specific quick-start notes, clarify upgrade semantics. |
| `docs/host-integration.md` | Host-specific install guidance | Align Antigravity skill path guidance with `tao link` behavior and current README wording. |
| `CLAUDE.md` | Maintainer-facing command notes | Align common commands with actual tarball upgrade behavior. |

---

### Task 1: Lock Current Expected UX With Tests

**Files:**
- Modify: `tests/tao-cli.bats`
- Modify: `tests/install-sh.bats`

- [ ] **Step 1: Add CLI help text test for no-clone upgrade wording**

Append this test to `tests/tao-cli.bats`:

```bash
@test "help describes upgrade without implying git is required" {
  run bash "$TAO" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"upgrade"* ]]
  [[ "$output" == *"tarball"* || "$output" == *"重新下載"* || "$output" == *"既有 clone"* ]]
  [[ "$output" != *"更新 tao（git pull）"* ]]
}
```

- [ ] **Step 2: Add `.agents/skills` auto-link detection test**

Append this test to `tests/tao-cli.bats`:

```bash
@test "link 偵測到 .agents 時自動連結到 .agents/skills" {
  mkdir -p "$TMP/.agents"
  run bash "$TAO" link
  [ "$status" -eq 0 ]
  [ -L "$TMP/.agents/skills/tao-of-opencode" ]
  [ "$(readlink "$TMP/.agents/skills/tao-of-opencode")" = "$REPO_ROOT/skills/tao-of-opencode" ]
}
```

- [ ] **Step 3: Add friendlier no-host guidance test**

Append this test to `tests/tao-cli.bats`:

```bash
@test "link 無宿主時提示常見 skills 目錄" {
  run bash "$TAO" link
  [ "$status" -eq 1 ]
  [[ "$output" == *"tao link <宿主的 skills 目錄>"* ]]
  [[ "$output" == *".agents/skills"* ]]
  [[ "$output" == *".claude/skills"* ]]
}
```

- [ ] **Step 4: Add installer help test for no-git requirement**

Append this test to `tests/install-sh.bats`:

```bash
@test "help mentions tarball/no clone path" {
  run bash "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"tarball"* || "$output" == *"不需 git"* || "$output" == *"不 clone"* ]]
}
```

- [ ] **Step 5: Run the targeted tests and confirm they fail before implementation**

Run:

```bash
bats tests/tao-cli.bats tests/install-sh.bats
```

Expected: FAIL on the newly added expectations, because help text and `.agents/skills` behavior are not implemented yet.

---

### Task 2: Improve `bin/tao` Help And Link Detection

**Files:**
- Modify: `bin/tao`
- Test: `tests/tao-cli.bats`

- [ ] **Step 1: Update `upgrade` help text**

In `bin/tao`, replace the current usage line:

```bash
  upgrade         更新 tao（git pull）並顯示版本。
```

with:

```bash
  upgrade         更新 tao；tarball 安裝會重新下載，既有 git clone 才 git pull。
```

- [ ] **Step 2: Add `.agents/skills` to linked-skill detection**

In `skill_linked()`, extend the checked paths to include:

```bash
    "$PWD/.agents/skills/tao-of-opencode" \
    "$HOME/.agents/skills/tao-of-opencode" \
```

Keep existing paths intact.

- [ ] **Step 3: Add `.agents/skills` to automatic host link targets**

In `cmd_link()`, extend the auto-detected target list to include project-local `.agents/skills` when `.agents` exists:

```bash
    "$PWD/.agents/skills" \
```

Keep the current `$HOME/.claude/skills`, `$HOME/.gemini/antigravity/skills`, and `$HOME/.codeium/windsurf/skills` behavior.

- [ ] **Step 4: Improve no-host guidance output**

Replace the no-host block in `cmd_link()` with output that gives concrete paths:

```bash
  if [[ "$linked" -eq 0 ]]; then
    echo "未偵測到已安裝的宿主。請指定目標 skills 目錄：" >&2
    echo "  tao link <宿主的 skills 目錄>" >&2
    echo "常見範例：" >&2
    echo "  tao link .agents/skills" >&2
    echo "  tao link ~/.claude/skills" >&2
    echo "  tao link ~/.gemini/antigravity/skills" >&2
    return 1
  fi
```

- [ ] **Step 5: Run CLI tests**

Run:

```bash
bats tests/tao-cli.bats
```

Expected: PASS.

- [ ] **Step 6: Run syntax check**

Run:

```bash
bash -n bin/tao
```

Expected: no output, exit 0.

---

### Task 3: Improve `install.sh` Preflight And Help Text

**Files:**
- Modify: `install.sh`
- Test: `tests/install-sh.bats`

- [ ] **Step 1: Update installer help text**

In `install.sh`, replace the help output:

```bash
echo "用法：install.sh [--dir <path>] [--ref <branch|tag>] [--uninstall] [--link-only]"
```

with:

```bash
echo "用法：install.sh [--dir <path>] [--ref <branch|tag>] [--uninstall] [--link-only]"
echo "預設以 GitHub tarball 下載安裝，不需 git clone；既有 .git 安裝才用 git pull。"
```

- [ ] **Step 2: Add dependency preflight helper**

After argument parsing and before uninstall handling, add:

```bash
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "install.sh: 缺少必要工具 '$1'。請先安裝後再重跑。" >&2
    exit 127
  }
}

require_cmd mkdir
require_cmd rm
require_cmd ln

if [[ "$UNINSTALL" -ne 1 ]]; then
  require_cmd chmod
  if [[ "$LINK_ONLY" -ne 1 ]]; then
    require_cmd mktemp
    require_cmd curl
    require_cmd tar
    require_cmd find
    require_cmd head
    require_cmd mv
  fi
fi
```

Rationale: `git` is intentionally not required for tarball installs. The existing `.git` branch still invokes `git`; Task 3 Step 3 handles that separately.

- [ ] **Step 3: Guard git-only update path**

Inside the `if [[ -d "$TAO_HOME/.git" ]]; then` branch, before `git -C "$TAO_HOME" pull --ff-only`, add:

```bash
require_cmd git
```

- [ ] **Step 4: Run installer tests**

Run:

```bash
bats tests/install-sh.bats
```

Expected: PASS.

- [ ] **Step 5: Run syntax check**

Run:

```bash
bash -n install.sh
```

Expected: no output, exit 0.

---

### Task 4: Fix README Install Narrative

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Fix quick install requirement contradiction**

In `README.md:189-195`, replace the sentence that says quick install needs git with wording consistent with implementation:

```markdown
一條指令裝好，全域取得 `tao` 指令（純 bash，需 `curl` 與 `tar`；不需 git clone；Windows 需 WSL / git-bash）：
```

- [ ] **Step 2: Fix upgrade command comment**

In the common commands block around `README.md:214-221`, replace:

```bash
tao upgrade            # 升級 tao 本體（git pull）
```

with:

```bash
tao upgrade            # 升級 tao 本體（tarball 安裝會重抓；既有 clone 才 git pull）
```

- [ ] **Step 3: Add host-specific enable note near quick start**

After the quick-start command block near `README.md:14-22`, add:

```markdown
宿主目標檔提醒：`tao enable` 預設寫 `AGENTS.md`，適合 Codex / Antigravity 等 host-agnostic 流程；Claude Code 專案建議改用 `tao enable --target CLAUDE.md`。
```

- [ ] **Step 4: Clarify `tao link` paths**

In the manual symlink section around `README.md:237-244`, include `.agents/skills` as the first modern example:

```bash
tao link .agents/skills
tao link ~/.claude/skills
tao link ~/.gemini/antigravity/skills
```

- [ ] **Step 5: Update README modified date**

At the bottom of `README.md`, replace:

```markdown
*版本更新日期：2026-05-28*
```

with:

```markdown
*版本更新日期：2026-06-01*
```

- [ ] **Step 6: Run local doc link check**

Run:

```bash
bash tests/check-doc-links.sh
```

Expected: PASS.

---

### Task 5: Align Host Integration And Maintainer Docs

**Files:**
- Modify: `docs/host-integration.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update Antigravity skill path guidance**

In `docs/host-integration.md:105-112`, keep the existing `.agents/skills/` guidance and add the exact CLI command:

```markdown
- **角色身份（skill）**：Antigravity 的 Skill 為目錄式套件（`SKILL.md` + 資產），新版建議放 `.agents/skills/`。可用 `tao link .agents/skills` 直接連結；舊版或個人全域安裝可改用 `tao link ~/.gemini/antigravity/skills`。
```

- [ ] **Step 2: Fix maintainer command docs for upgrade semantics**

In `CLAUDE.md`, replace any wording that implies `tao upgrade` always uses `git pull` with:

```markdown
tao upgrade    # 升級 tao 本體（tarball 安裝會重抓；既有 clone 才 git pull）
```

- [ ] **Step 3: Search for remaining misleading install claims**

Run:

```bash
rg "需 `git`|git pull|git clone|不需 git|tarball|不 clone" README.md CLAUDE.md docs/host-integration.md bin/tao install.sh
```

Expected: Remaining `git pull` / `git clone` mentions are explicitly scoped to existing clone or maintainer workflows.

- [ ] **Step 4: Run doc link check**

Run:

```bash
bash tests/check-doc-links.sh
```

Expected: PASS.

---

### Task 6: Full Verification

**Files:**
- No code changes expected.

- [ ] **Step 1: Run shell syntax checks**

Run:

```bash
for s in install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh; do bash -n "$s"; done
```

Expected: no output, exit 0.

- [ ] **Step 2: Run bats tests**

Run:

```bash
bats tests/*.bats
```

Expected: all tests PASS.

- [ ] **Step 3: Run doc link check**

Run:

```bash
bash tests/check-doc-links.sh
```

Expected: PASS.

- [ ] **Step 4: Optional shellcheck if installed**

Run:

```bash
shellcheck -S error install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh
```

Expected: no error-level findings. If `shellcheck` is not installed, record that it was skipped.

- [ ] **Step 5: Review final diff**

Run:

```bash
git diff -- install.sh bin/tao tests/install-sh.bats tests/tao-cli.bats README.md docs/host-integration.md CLAUDE.md
```

Expected: Diff only contains installer friendliness fixes, no unrelated formatting churn.

---

## Self-Review

- Spec coverage: Covers no-clone install clarity, README/CLI contradiction, host-specific quick start, `.agents/skills` support, dependency preflight, and verification.
- Placeholder scan: No TBD/TODO/fill-in placeholders remain; each task has exact files, commands, and expected results.
- Type/signature consistency: Bash function names and command names match existing files: `require_cmd`, `cmd_link`, `skill_linked`, `tao link`, `tao upgrade`.
