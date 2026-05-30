# 設計：簡化「在新專案資料夾啟用 orchestrator」的安裝體驗

- 日期：2026-05-30
- 狀態：設計定稿，待實作
- 相關：[`docs/orchestrator-identity-and-portable-install.md`](../../orchestrator-identity-and-portable-install.md)、[`docs/host-integration.md`](../../host-integration.md)、`skills/tao-of-opencode/scripts/install-orchestrator.sh`

## 1. 問題

使用者要在**任意一個新專案資料夾**啟用 tao orchestrator（模式 B），目前流程不友善：

1. **壞連結（核心 bug）**：`install-orchestrator.sh` 的 `--skill-ref` 預設值是相對路徑 `skills/tao-of-opencode/references`。在新資料夾（如 `~/projects/foo`）用 `--target ./AGENTS.md` 寫入後，受管區塊裡的 `${SKILL_REF}/<role>.md` 是相對 target 資料夾解析的——那個資料夾下根本沒有 `skills/...`，連結指向不存在的位置。
2. **流程分兩段又要打長路徑**：`npx skill-linker`（連 skill）＋ 手動 `bash <repo>/.../install-orchestrator.sh --target ...`（要記腳本絕對路徑、要記正確 target）。對「換到新資料夾起步」很折騰。

## 2. 目標 / 非目標

**目標**
- 受管區塊的角色卡引用在任何資料夾都成立、且 AGENTS.md 可進 git 共享（可攜，不含使用者家目錄絕對路徑）。
- 「在新資料夾啟用」收斂成一條可從任何資料夾執行的指令。

**非目標**
- 不引入 npm 套件 / `npx tao init`（本 repo 無 `package.json`，發佈到 npm 過重，且不符純 Markdown+Bash 的專案性質）。
- 不改角色調度協議本身、不動全文角色卡內容。
- 不取代 `npx skill-linker`（skill 連結仍由它或手動 symlink 負責；本案只負責偵測與提示）。

## 3. 設計

### 3.1 受管區塊改用 skill 名稱引用角色卡（治本）

`install-orchestrator.sh` heredoc 內目前這句：

> `並調度合適的子代理完成任務。詳細角色卡見 ${SKILL_REF}/<role>.md。`

改為一個變數 `ROLE_CARD_HINT`，預設值為 **skill 名稱式**引用：

> `詳細角色卡見已連結的 \`tao-of-opencode\` skill 的 \`references/<role>.md\`（Explorer / Oracle / Librarian / Fixer / Designer）。`

- 預設（不帶旗標）→ 用 skill 名稱式字句，**不含任何檔案系統路徑**，因此不可能變壞連結、可攜、可進 git。
- `--skill-ref <path>` 旗標**保留**：帶旗標時 `ROLE_CARD_HINT` 改回路徑式 `見 <path>/<role>.md`，給想要明確可點擊路徑的人覆寫。
- 依賴前提：skill 已連結進宿主全域 skills（agent 透過 skill 機制即可載到角色卡）。`tao-enable` 會偵測並提示此前提（見 3.2）。

> 設計理由：最符合專案「host-agnostic / skill-based」哲學——角色卡的真實來源是「已連結的 skill」，而非某個資料夾下的相對路徑。

### 3.2 新增 `tao-enable.sh` 零參數包裝

新檔 `skills/tao-of-opencode/scripts/tao-enable.sh`，預期**在目標資料夾內執行**。

**宿主檔偵測優先序**（決定 target）：
1. `--target <path>` 明確指定 → 用它。
2. 否則，目標資料夾已存在 `./CLAUDE.md` → 用 `CLAUDE.md`。
3. 否則，已存在 `./AGENTS.md` → 用 `AGENTS.md`。
4. 否則（全新空資料夾）→ 建立並寫入 `./AGENTS.md`（最 host-agnostic，預設）。

**行為**
- 算出自身位置 → 得 `REPO_ROOT`，以**絕對路徑**呼叫底層 `install-orchestrator.sh`，傳入偵測到的 target。
- 不傳 `--skill-ref`（讓底層走 3.1 的 skill 名稱式預設）。
- 旗標直通底層：`--dry-run`、`--remove`、`--check` 原樣轉交 `install-orchestrator.sh`。
- 收尾輸出：
  - 寫入了哪個宿主檔（含完整路徑）。
  - **skill 連結狀態提示**：檢查常見宿主 skills 目錄是否已有 `tao-of-opencode`（symlink）；若無，提示「角色卡需要 skill 連結才載得到，請執行 `npx skill-linker` 或手動 symlink」。此為提示性質，不阻斷。

**參數面**
- `tao-enable.sh [--target <path>] [--dry-run] [--remove] [--check] [-h|--help]`
- 不另設 `--position`：新資料夾預設 append 即可；需要 prepend 的進階情境仍可直接用底層 `install-orchestrator.sh`。

**使用方式（README 教學）**
```bash
# 一次性設 alias（指向你 clone 的位置）
alias tao-enable='bash ~/Documents/AgentSkills/tao-of-coding/skills/tao-of-opencode/scripts/tao-enable.sh'

# 之後在任何新專案資料夾
cd ~/projects/foo
tao-enable            # 偵測 / 建立 AGENTS.md，寫入受管區塊
tao-enable --check    # 唯讀檢查狀態
tao-enable --remove   # 卸載受管區塊
```

### 3.3 文件更新

- **README 〈安裝配置〉**：新增「在新專案資料夾啟用」小節（alias + `tao-enable` 一鍵），並修正/移除會導致壞連結的舊相對路徑敘述。更新目錄結構樹加入 `tao-enable.sh`。
- **`docs/host-integration.md`**：各宿主「安裝啟用」段落補上 `tao-enable` 一鍵替代寫法（仍保留底層 `install-orchestrator.sh` 進階用法）。
- **CLAUDE.md 常用指令**：補 `tao-enable` 入口說明。

## 4. 測試

- 新增 `tests/tao-enable.bats`：
  - 全新空資料夾 → 建立 `AGENTS.md` 並含受管標記。
  - 已存在 `CLAUDE.md` → 寫入 `CLAUDE.md`（優先於 AGENTS.md）。
  - 已存在 `AGENTS.md`（無 CLAUDE.md）→ 寫入 `AGENTS.md`。
  - `--target` 覆寫偵測。
  - 冪等：連跑兩次第二次回報無變更。
  - `--remove` 移除受管區塊。
  - `--dry-run` 不寫檔。
- 既有 `tests/install-orchestrator.bats` 補：
  - 預設受管區塊**不含**相對路徑 `skills/tao-of-opencode/references`，改含 skill 名稱式字句（grep 斷言）。
  - `--skill-ref <path>` 覆寫時，區塊含該路徑式引用。
- CI（`.github/workflows/ci.yml`）：`tao-enable.sh` 納入 `bash -n` + `shellcheck`；新 bats 檔納入測試 job；死連結檢查涵蓋新 spec 文件。

## 5. 風險與緩解

| 風險 | 緩解 |
| :--- | :--- |
| skill 名稱式引用依賴「skill 已連結」前提 | `tao-enable` 偵測並提示；README 把「連 skill」列為前置步驟 |
| 既有使用者的 AGENTS.md 仍是舊路徑式區塊 | 受管區塊冪等替換——重跑 `tao-enable` / `install-orchestrator.sh` 即升級為新字句 |
| 宿主 skills 目錄路徑因版本/宿主而異，偵測可能不全 | 偵測為「盡力提示」，偵測不到只提示、不阻斷；列出已知路徑清單 |

## 6. 交付物

- `skills/tao-of-opencode/scripts/tao-enable.sh`（新）
- `skills/tao-of-opencode/scripts/install-orchestrator.sh`（改：`ROLE_CARD_HINT`）
- `tests/tao-enable.bats`（新）、`tests/install-orchestrator.bats`（補）
- README.md、docs/host-integration.md、CLAUDE.md（文件）
- `.github/workflows/ci.yml`（納入新腳本與測試）
