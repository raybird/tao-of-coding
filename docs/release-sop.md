# Release SOP

本文件定義 tao-of-coding 的標準發版流程，從本地驗證到 GitHub Release。每次發版照本 SOP 執行，確保版本一致、可追溯、不破壞使用者安裝。

> 建立日期：2026-06-02（首次固化自 v5.0.2 發版流程）。

---

## 前置概念

| 主題 | 參考 |
| :--- | :--- |
| 版本號怎麼定（major / minor / patch） | `docs/semver_decision_tree.md` |
| Release note 怎麼寫 | `docs/release_note_template.md` |
| 安裝如何取得新版 | `install.sh`（預設抓 `archive/main.tar.gz`；鎖版本用 `--ref vX.Y.Z`） |

**重要規則**：commit 訊息與 tag 訊息**絕不可包含 `Co-Authored-By: Claude` 或任何 AI 署名**（見 `CLAUDE.md`）。

---

## 觸發時機

| 情況 | 版本類型 |
| :--- | :--- |
| 破壞性變更（行為/介面不相容、需遷移） | MAJOR `vX.0.0` |
| 向下相容的新功能 | MINOR `vX.Y.0` |
| 純修補（bug、文件、不影響行為） | PATCH `vX.Y.Z` |

不確定時查 `docs/semver_decision_tree.md`。

---

## Step 1：確認工作樹與待釋出範圍

```bash
git status -s                      # 確認要釋出的變更
git tag --sort=-creatordate | head # 看最新 tag，決定下一版號
git log --oneline <最新tag>..HEAD  # 確認自上版以來累積了什麼
```

- 確認當前在 `main`、與 `origin/main` 無未推送落差（或落差正是本次要釋出的）。
- 依變更內容決定版本號（Step 0 的版本類型）。

---

## Step 2：本地驗證（對齊 CI）

CI（`.github/workflows/ci.yml`）會跑 lint / bats / doc 三個 job；發版前先在本地過一遍，避免 tag 後才發現紅燈。

```bash
# 2a) 語法檢查（全部腳本）
for s in install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh; do bash -n "$s"; done

# 2b) shellcheck（error 級；本機沒裝就靠 CI）
command -v shellcheck >/dev/null && \
  shellcheck -S error install.sh bin/tao skills/tao-of-opencode/scripts/*.sh tests/*.sh

# 2c) bats 測試
command -v bats >/dev/null && bats tests/*.bats

# 2d) 文件連結檢查
bash tests/check-doc-links.sh
```

涉及安裝行為變更時，**額外做隔離實測**（不污染本機正式安裝）：

```bash
# 在臨時 TAO_HOME 跑完整安裝鏈，驗證 tarball 安裝 + link + enable
bash install.sh --dir /tmp/tao-test/home
# … 在空目錄測 tao link .agents/skills && tao enable
# 測完還原 ~/.local/bin/tao symlink、清掉 /tmp 測試檔
```

> 驗證未通過不得進入 Step 3。任何「跳過的步驟」要在 release note 的 Verification 註明。

---

## Step 3：Commit

```bash
git add <files>
git commit -m "<type>(<scope>): <一句話描述>

<必要時補充細節，說明為什麼這樣改>"
```

- 遵守 Conventional Commits（`feat` / `fix` / `docs` / `chore` …）。
- **不附任何 AI 署名尾行**。

---

## Step 4：建立 annotated tag

```bash
git tag -a vX.Y.Z -m "vX.Y.Z: <一句話摘要>"
git tag --sort=-creatordate | head -3   # 確認 tag 已建立且版號正確
```

---

## Step 5：推送

```bash
git push origin main
git push origin vX.Y.Z
```

推送後 CI 會在 push 上自動跑。需要時 `gh run watch` 盯到綠燈。

---

## Step 6：建立 GitHub Release

依 `docs/release_note_template.md` 對應版本類型填好 notes，再建立：

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z — <一句話標題>" \
  --notes "<依模板填寫的 release note>"

gh release list | head -3   # 確認標記為 Latest
```

> 自 v5.0.2 起採「每個 tag 一併建立 GitHub Release」的慣例。

---

## 發版後檢查清單

- [ ] CI 全綠（lint / bats / doc）。
- [ ] GitHub Release 頁面內容正確、標記 Latest。
- [ ] 一行安裝（`curl … | bash`）會取得新版（預設抓 `main` tarball）。
- [ ] 若有破壞性變更，README / 相關 docs 已同步更新遷移說明。

---

## 相關檔案

| 檔案 | 用途 |
| :--- | :--- |
| `docs/semver_decision_tree.md` | 版本類型決策 |
| `docs/release_note_template.md` | release note 模板（major/minor/patch） |
| `docs/releases/` | 各版本 release note 存檔 |
| `.github/workflows/ci.yml` | CI 定義（lint / bats / doc） |
| `install.sh` / `bin/tao` | 安裝與升級行為，影響使用者取得新版的方式 |
