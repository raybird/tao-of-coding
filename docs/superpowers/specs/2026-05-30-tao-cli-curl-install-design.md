# 設計：`tao` CLI 與 curl | bash 安裝器（簡化全域安裝 / 升級 / 逐專案啟用）

- 日期：2026-05-30
- 狀態：設計定稿，待實作
- 取代：`2026-05-30-tao-enable-new-folder-install-design.md`（alias + tao-enable 版本；已被本案的 `tao enable` 子指令吸收）
- 相關：[`docs/orchestrator-identity-and-portable-install.md`](../../orchestrator-identity-and-portable-install.md)、[`docs/host-integration.md`](../../host-integration.md)、`skills/tao-of-opencode/scripts/install-orchestrator.sh`

## 1. 問題

兩個獨立但相關的痛點：

1. **逐專案啟用的壞連結（核心 bug）**：`install-orchestrator.sh` 的 `--skill-ref` 預設是相對路徑 `skills/tao-of-opencode/references`。在新資料夾用 `--target ./AGENTS.md` 寫入後，受管區塊裡的 `${SKILL_REF}/<role>.md` 相對於 target 資料夾解析，指向不存在的位置（壞連結）。
2. **缺少全域入口 / 升級流程**：要在新資料夾啟用得「clone 到指定資料夾 → 記住長腳本路徑 → 手動跑」，升級要自己 `git pull`。沒有「裝一次，之後任何資料夾一指令、`tao upgrade` 升級」的體驗。

## 2. 目標 / 非目標

**目標**
- 一條 `curl | bash` 指令裝好，全域取得 `tao` 指令；之後任何專案資料夾 `tao enable` 一鍵啟用、`tao upgrade` 一鍵升級。
- 受管區塊角色卡引用在任何資料夾都成立、AGENTS.md 可進 git 共享（可攜、不含家目錄絕對路徑）。
- 保持專案**純 Markdown + Bash 本性**：不引入 node 依賴。

**非目標**
- 不引入 `package.json` / npm 發佈（純 bash 路線，npm 會硬塞 node 依賴）。
- 不自架網域：install.sh 直接掛 GitHub raw URL。
- 不改角色調度協議、不動全文角色卡內容。
- 不取代 `npx skill-linker`（`tao link` 包裝它或做手動 symlink，不重寫其功能）。
- 不保證 Windows 原生支援（核心為 bash，需 WSL / git-bash，明文標註）。

## 3. 架構

三層，由上而下：

```
curl -fsSL <raw-url>/install.sh | bash      # ① bootstrap 安裝器（一次性）
        ↓ clone/更新到 TAO_HOME，symlink tao 進 PATH
tao <subcommand>                            # ② 派發 CLI（日常入口）
        ↓ enable / link / upgrade / check / remove
install-orchestrator.sh（既有）             # ③ 原語：寫受管區塊（不重寫）
```

### 3.1 受管區塊改用 skill 名稱引用角色卡（治本，沿用前案）

`install-orchestrator.sh` heredoc 內：

> 現：`並調度合適的子代理完成任務。詳細角色卡見 ${SKILL_REF}/<role>.md。`

改為變數 `ROLE_CARD_HINT`，預設 **skill 名稱式**（不含檔案系統路徑）：

> `詳細角色卡見已連結的 \`tao-of-opencode\` skill 的 \`references/<role>.md\`（Explorer / Oracle / Librarian / Fixer / Designer）。`

- 預設不帶旗標 → skill 名稱式，可攜、不可能變壞連結、可進 git。
- `--skill-ref <path>` 保留：帶旗標時改回路徑式 `見 <path>/<role>.md`。
- 前提：skill 已連結進宿主（`tao link` 負責；`tao enable` 偵測並提示）。

### 3.2 `install.sh`（repo 根，curl | bash bootstrap）

```bash
curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh | bash
```

行為（冪等，可重跑＝升級）：
1. **決定 `TAO_HOME`**：環境變數 `TAO_HOME` > `--dir <path>` > 預設 `~/.local/share/tao-of-coding`（XDG）。
2. **取得內容**：`TAO_HOME` 已是本 repo 的 git clone → `git pull`（升級）；否則 `git clone`（可 `--ref <branch/tag>` 指定版本，預設 main）。git 為必要相依（專案本就依賴）。
3. **連 `tao` 進 PATH**：symlink `TAO_HOME/bin/tao` → `~/.local/bin/tao`（目錄不存在則建立）。
4. **PATH 提示**：若 `~/.local/bin` 不在 `$PATH`，印出該加進哪個 shell rc（偵測 bash/zsh）；不自動改 rc（非破壞）。
5. **收尾**：印安裝位置、`tao` 路徑、下一步（`tao enable` / `npx skill-linker`）。

安全：README 同時提供「先下載、檢視、再執行」兩步版本：
```bash
curl -fsSL <raw-url>/install.sh -o /tmp/tao-install.sh
less /tmp/tao-install.sh        # 檢視
bash /tmp/tao-install.sh
```

旗標：`install.sh [--dir <path>] [--ref <branch|tag>] [--uninstall] [-h]`。
- `--uninstall`：移除 `~/.local/bin/tao` symlink（保留 `TAO_HOME` 內容，提示如何手動刪）。

### 3.3 `bin/tao`（派發 CLI）

自定位（依 `BASH_SOURCE` 解出 repo 根與 `scripts/`），子指令：

| 子指令 | 行為 |
| :--- | :--- |
| `tao enable [--target <p>] [--dry-run] [--remove] [--check]` | 逐專案啟用（取代前案 tao-enable）。宿主檔偵測：`--target` > 既有 `./CLAUDE.md` > 既有 `./AGENTS.md` > 建立 `./AGENTS.md`。內部以絕對路徑呼叫 `install-orchestrator.sh`（不傳 `--skill-ref`，走 3.1 預設）。收尾偵測 skill 連結狀態並提示。`--dry-run/--remove/--check` 直通底層。 |
| `tao link` | 把 `skills/tao-of-opencode` 連進宿主 skills 目錄。優先委派 `npx skill-linker`；不可用時對已知宿主路徑做手動 symlink 並印結果。 |
| `tao upgrade` | `cd $TAO_HOME && git pull` 後重連 `tao` symlink；印新版本（git describe / 短 hash）。 |
| `tao check` | 對當前資料夾偵測到的宿主檔做 `install-orchestrator.sh --check`（exit 0/1/2 透傳）。 |
| `tao remove` | 等同 `tao enable --remove`。 |
| `tao help` / `tao version` / `tao path` | 說明 / 版本（git describe）/ 印 `TAO_HOME`。 |

未知子指令 → 印 usage、exit 1。

### 3.4 文件更新

- **README 〈安裝配置〉重寫**：主路徑＝`curl | bash` 一行（＋兩步安全版）→ `tao enable` 逐專案 → `tao upgrade` 升級。保留 `install-orchestrator.sh` 為進階/維護者用法。更新目錄結構樹（加 `install.sh`、`bin/tao`）。
- **`docs/host-integration.md`**：各宿主「安裝啟用」段補 `tao enable` 一鍵替代寫法（底層 `install-orchestrator.sh` 進階用法保留）。
- **CLAUDE.md 常用指令**：補 `tao` CLI 入口與子指令。

## 4. 測試

- **新增 `tests/tao-cli.bats`**（直接跑 `bash bin/tao ...` 於暫存 HOME / 暫存資料夾）：
  - `enable` 全新空資料夾 → 建立含標記的 `AGENTS.md`。
  - `enable` 既有 `CLAUDE.md` → 寫 `CLAUDE.md`（優先於 AGENTS.md）。
  - `enable` 既有 `AGENTS.md`（無 CLAUDE.md）→ 寫 `AGENTS.md`。
  - `enable --target` 覆寫偵測。
  - `enable` 冪等（第二次回報無變更）。
  - `enable --remove` 移除受管區塊。
  - `enable --dry-run` 不寫檔。
  - `check` 對未安裝資料夾 exit 2、已安裝 exit 0。
  - 未知子指令 exit 1。
- **`tests/install-orchestrator.bats` 補**：
  - 預設受管區塊**不含**相對路徑 `skills/tao-of-opencode/references`，含 skill 名稱式字句（grep 斷言）。
  - `--skill-ref <path>` 覆寫時，區塊含該路徑式引用。
- **`tests/install-sh.bats`（盡力，免網路）**：`TAO_HOME` 指向既有本地 clone + 暫存 HOME → install.sh 不重新 clone、建立 `~/.local/bin/tao` symlink、冪等重跑、`--uninstall` 移除 symlink。網路相關（實際 clone）不在單測涵蓋。
- **CI（`.github/workflows/ci.yml`）**：`install.sh`、`bin/tao` 納入 `bash -n` + `shellcheck`；新 bats 檔納入測試 job；死連結檢查涵蓋新 spec。

## 5. 風險與緩解

| 風險 | 緩解 |
| :--- | :--- |
| `curl \| bash` 安全觀感 | 同時提供「下載→檢視→執行」兩步版；install.sh 不自動改 shell rc（只提示） |
| skill 名稱式引用依賴「skill 已連結」 | `tao enable` 偵測提示；README 把 `tao link` / `npx skill-linker` 列前置步驟 |
| 既有 AGENTS.md 仍是舊路徑式區塊 | 受管區塊冪等替換——重跑 `tao enable` 即升級為新字句 |
| `~/.local/bin` 不在 PATH | install.sh 偵測並印出對應 shell rc 的設定行（不自動寫） |
| Windows 原生不支援 bash | 明文標註需 WSL / git-bash |
| 宿主 skills 目錄路徑隨版本/宿主而異 | 偵測為盡力提示，偵測不到只提示不阻斷 |

## 6. 交付物

- `install.sh`（新，repo 根）
- `bin/tao`（新，派發 CLI）
- `skills/tao-of-opencode/scripts/install-orchestrator.sh`（改：`ROLE_CARD_HINT`）
- `tests/tao-cli.bats`（新）、`tests/install-sh.bats`（新）、`tests/install-orchestrator.bats`（補）
- README.md、docs/host-integration.md、CLAUDE.md（文件）
- `.github/workflows/ci.yml`（納入新腳本與測試）
