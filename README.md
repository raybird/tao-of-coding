# 程式之道 (Tao of Coding)

> *「有序協作，穩定交付。」*

[![Status: Active](https://img.shields.io/badge/Status-Active-blue)](#核心精神有序協作)
[![Concept: Multi-Agent](https://img.shields.io/badge/Concept-Multi_Agent-gold)](#角色目錄-the-role-catalog)

---

## 🚀 快速開始

純 bash，需 `curl` 與 `tar`（不需 git；Windows 需 WSL / git-bash）：

```bash
# 1. 一行安裝，全域取得 tao 指令（直接下載解壓，不 clone）
curl -fsSL https://raw.githubusercontent.com/raybird/tao-of-coding/main/install.sh | bash

# 2. 在你的專案資料夾啟用
cd ~/projects/your-project
tao link        # 把 tao-of-opencode skill 連進宿主（首次）
tao enable      # 寫入 orchestrator 受管區塊（自動偵測 CLAUDE.md / AGENTS.md）
```

完成後，你的 agent 讀取宿主檔即以 orchestrator 身分運作。升級用 `tao upgrade`、卸載用 `tao remove`。

詳細選項、手動安裝與底層腳本見 [〈安裝配置〉](#安裝配置-installation)。

---

## 簡介

這是一套專為 AI 代理設計的**多代理協作框架 (Multi-Agent Orchestration Framework)**，將開發任務的混亂轉化為有條不紊的秩序。

我們繼承了 [`oh-my-opencode-slim`](https://github.com/alvinunreal/oh-my-opencode-slim) 的輕量化精神，並用角色分工方式打造可落地的開發協作系統。

---

## 核心精神：有序協作

在軟體開發中，混亂是常態。本專案的初衷在於透過明確的**職責分工**與**上下文卸載 (Context Offloading)**，讓開發過程更可控且高效。

身為開發者的你，在此系統中是 **使用者 (User)**。你提出需求後，由 **主代理 (Orchestrator, 即 AI Agent)** 統籌全局，調度適合的子代理執行。

---

## 角色目錄 (The Role Catalog)

我們將 AI 職能拆分為不同角色，確保每一項任務都由最合適的「專家」處理：

| 角色 | 角色原型 | 預設模型 (OpenCode) | 職掌與能力 |
| :--- | :--- | :--- | :--- |
| **👁️ Explorer** | Explorer | `opencode/deepseek-v4-flash-free` | 專精於專案偵查。瞬間掃描檔案結構、追蹤依賴關係，揭開陌生程式碼的面紗。 |
| **🍶 Oracle** | Oracle | `nvidia/openai/gpt-oss-120b` | 專注架構分析與重構策略。當架構混壞或 Bug 難解時，提供可執行方案。 |
| **🖊️ Librarian** | Librarian | `nvidia/minimaxai/minimax-m2.7` | 掌管文運。負責撰寫文件、API 註解與國際化翻譯，條理分明。 |
| **🛠️ Fixer** | Fixer | `nvidia/qwen/qwen3-coder-480b-a35b-instruct` | 實作與修復的能手。負責程式碼修正、單元測試補全，以最高效率敲正每一行程式碼。 |
| **🧵 Designer** | Designer | `nvidia/microsoft/phi-4-multimodal-instruct` | 專注 UI/UX 設計。負責介面結構、互動與視覺一致性。 |

---

## Slim 原則：成本與效率

本專案深度實踐「輕量化 (Slim)」原則，旨在降低 Token 消耗並提升反應速度：

1.  **分級調用**：能用小模型（Flash）解決的任務，避免直接使用大模型（Pro），以節省成本。
2.  **無狀態原則 (Stateless)**：所有代理皆運行於獨立、無記憶環境，確保上下文清潔。
3.  **提示詞優化 (Prompt Fine-tuning)**：透過高度優化的指令集，讓 AI 以最少的詞彙達成最精準的產出。

---

## 標準使用方式 (Usage)

安裝後（見〈安裝配置〉），當前 agent 讀取 `SKILL.md`（或宿主 `AGENTS.md` 的受管區塊）即以 orchestrator 身分運作。**沒有 CLI 入口**——你（agent 本體）直接依協議調度角色：

1. **路由**：依 `SKILL.md` 的「技能路由表」判斷該找哪個角色、用什麼技能。
2. **委派（host-agnostic）**：
   - **優先**用宿主原生 subagent/task（如 Claude Code 的 Task、opencode 的 agent），為角色開子代理，交付「角色卡 + 任務 + 必要上下文」，取得隔離與無狀態。
   - 宿主無此能力時，於同一對話內讀取角色卡、**in-context 切換**該角色視角，再切回 orchestrator 整合。
3. **交付**：角色的長輸出寫到 `docs/...`、`src/...`、`tests/...` 並附可追溯路徑。

> 早期的 shell 編排機制（`orchestrate-skill.sh`、`skill-dispatch.sh`、`parallel-dispatch.sh`、`loop-dispatch.sh`、Agent Message envelope、dispatcher 契約等）已於 2026-05-29 全面移除。角色調度不再經由任何 shell 包裝或 `opencode run` 子進程；背景見 [`docs/orchestrator-identity-and-portable-install.md`](docs/orchestrator-identity-and-portable-install.md)。

### 工具調用與查證規範（摘要）

以下規範與 `skills/tao-of-opencode/SKILL.md` 一致，未滿足不應宣告任務完成：

1. 只要任務涉及「最新/近期/可能變動」資訊，必須先用工具查證再回覆。
2. 使用外部事實（價格、新聞、法規、版本、公告）時，需附來源與查詢日期（YYYY-MM-DD）。
3. 若無法查證（網路或權限限制），需明確說明限制與已嘗試步驟，不得假設最新資訊。
4. 多步驟任務應先說明「角色路由 + 將使用的技能/工具」再執行。

更多詳細規範與指令範例，請參閱：
-   [Tao of OpenCode Protocol](skills/tao-of-opencode/SKILL.md)
-   [Orchestrator 身份確立與可攜安裝設計](docs/orchestrator-identity-and-portable-install.md)
-   [宿主整合指南（Claude Code / Codex / Antigravity）](docs/host-integration.md)
-   [Case Study：第一次真實 orchestration 運行](docs/case-studies/2026-05-30-orchestration-dogfood.md)
-   [Tao x Superpowers 操作指引](docs/superpowers_playbook.md)
-   [SemVer 版本決策樹](docs/semver_decision_tree.md)
-   [Release Note 模板](docs/release_note_template.md)
-   [角色職能與技能對照表](docs/celestial_skill_mapping.md)
-   [專案精神深度分析](docs/project-spirit-analysis.md)
-   [模型維護 SOP](docs/model-maintenance-sop.md)

## 已導入 Superpowers 技能 (Phase 1)

目前已在 `skills/tao-of-opencode/references/superpowers/` 本地導入以下技能：

角色技能（依任務路由給對應角色）：
- `brainstorming`
- `writing-plans`
- `executing-plans`
- `test-driven-development`
- `systematic-debugging`
- `verification-before-completion`
- `requesting-code-review`
- `receiving-code-review`

調度技能（orchestrator 自用，宿主有原生 subagent 時適用）：
- `subagent-driven-development`
- `dispatching-parallel-agents`

推薦流程：先依 `skills/tao-of-opencode/SKILL.md` 做角色路由，再載入對應 `references/superpowers/<skill>/SKILL.md` 執行。

### 升級維護（Superpowers）

- 同步腳本：`skills/tao-of-opencode/scripts/sync-superpowers.sh`
- 先乾跑：`skills/tao-of-opencode/scripts/sync-superpowers.sh <commit-or-tag> --dry-run`
- 再正式同步：`skills/tao-of-opencode/scripts/sync-superpowers.sh <commit-or-tag>`
- 同步來源與版本追蹤：`skills/tao-of-opencode/references/superpowers/SOURCE.md`

### 模型能力評估（Model Assessment）

當 NVIDIA NIM 模型有異動（新模型上線、舊模型 EOL）時，執行評估腳本重新檢驗：

```bash
# 預覽將測試的模型（不實際呼叫）
bash skills/tao-of-opencode/scripts/assess-models.sh --dry-run

# 只評估 S、A 梯隊
bash skills/tao-of-opencode/scripts/assess-models.sh --tier S,A

# 全量評估（約 25–40 分鐘）
bash skills/tao-of-opencode/scripts/assess-models.sh

# 驗證單一模型
bash skills/tao-of-opencode/scripts/assess-models.sh --model nvidia/deepseek-ai/deepseek-v4-pro
```

- 模型清單與梯隊定義：`skills/tao-of-opencode/references/model-registry.conf`
- 評估報告輸出：`docs/model-assessment.md`

當有新模型上線或懷疑某模型已 EOL，先執行 refresh 確認差異：

```bash
# 對比 opencode models 與 registry，顯示新增／消失的模型
bash skills/tao-of-opencode/scripts/refresh-model-registry.sh

# 自動將新模型補入 registry（tier 標為 ?，待人工分級）
bash skills/tao-of-opencode/scripts/refresh-model-registry.sh --add-new
```

標準維護流程：

```
refresh-model-registry.sh   →   手動設定 tier / 標記 EOL
        ↓
assess-models.sh --tier ?   →   評估新模型
        ↓
手動更新角色分配（SKILL.md / references/*.md）
```

---

## 環境需求

本專案以 Markdown 指令集為主，協議與角色調度由宿主 agent 本體執行，**不需任何 CLI 即可運作**。下列工具僅維護腳本選用：

| 工具 | 用途 | 安裝確認 |
| :--- | :--- | :--- |
| **Bash** | 執行維護腳本（`install-orchestrator` / `sync-superpowers` / `assess-models` 等）。 | `bash --version` |
| **curl + tar** | `install.sh` / `tao upgrade` 下載解壓內容（取代 git clone）。 | `curl --version` |
| **Git** | 選用：同步上游 superpowers 技能、維護者 clone。 | `git --version` |
| **tao CLI** | 選用：全域入口（`tao enable` / `upgrade` 等），由 `install.sh` 安裝。 | `tao version` |
| **OpenCode CLI** | 選用：僅 `assess-models.sh` 評估模型時需要。 | `opencode --version` |

---

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

安裝器會下載 tarball 解壓到 `~/.local/share/tao-of-coding`、把 `tao` 連進 `~/.local/bin`。若 `~/.local/bin` 不在 `PATH`，依提示加一行到你的 shell rc。升級 `tao upgrade` 會重抓最新 tarball。

### 在任意專案資料夾啟用

```bash
cd ~/projects/your-project
tao link        # 首次：把 tao-of-opencode skill symlink 進已偵測到的宿主
tao enable      # 偵測/建立 AGENTS.md（或既有 CLAUDE.md），寫入 orchestrator 受管區塊
```

常用：

```bash
tao enable --dry-run   # 預覽不寫檔
tao check              # 檢查狀態（exit 0=最新/1=過時/2=未安裝）
tao remove             # 卸載受管區塊
tao upgrade            # 升級 tao 本體（git pull）
```

`tao enable` 會自動偵測宿主檔：`--target` 指定 > 既有 `CLAUDE.md` > 既有 `AGENTS.md` > 否則建立 `AGENTS.md`。它等同呼叫下方 `install-orchestrator.sh`，差別在免記腳本路徑、用絕對路徑、自動偵測目標。

### 進階：直接用底層腳本

不想裝 `tao` 也可直接呼叫維護腳本（設計仿 GitNexus `gitnexus analyze`，冪等、非破壞；細節見 [`docs/orchestrator-identity-and-portable-install.md`](docs/orchestrator-identity-and-portable-install.md)）：

```bash
S=skills/tao-of-opencode/scripts/install-orchestrator.sh

bash "$S" --dry-run                          # 預覽（不寫檔）
bash "$S" --target workspace/AGENTS.md       # 寫入宿主實際讀的那份 AGENTS.md
bash "$S" --target workspace/AGENTS.md --remove   # 卸載
```

skill 連結也可不經 `tao link`，手動 symlink（依宿主調整 skills 目錄）：

```bash
mkdir -p ~/.gemini/antigravity/skills
ln -s ~/.local/share/tao-of-coding/skills/tao-of-opencode ~/.gemini/antigravity/skills/tao-of-opencode
```

或指定目標目錄交給 `tao link`：`tao link ~/.gemini/antigravity/skills`。

受管區塊以 `<!-- tao:start -->` / `<!-- tao:end -->` 包夾，只放「名冊摘要 + 調度準則」；全文角色卡永遠留在 `skills/`，標記以外的內容不會被動到。每次寫入前會建立時間戳備份。

---

## 測試 (Tests)

維護腳本有自動化測試與 CI（GitHub Actions，見 `.github/workflows/ci.yml`）：

```bash
# 安裝器行為測試（需 bats）
bats tests/install-orchestrator.bats

# Markdown 本地連結檢查（無依賴）
bash tests/check-doc-links.sh
```

CI 三個 job：`bash -n` + `shellcheck`（lint）、`bats`（安裝器冪等/非破壞/remove）、死連結檢查（docs）。

---

## 目錄結構

```text
.
├── README.md
├── install.sh                       # curl|bash bootstrap 安裝器
├── bin/
│   └── tao                          # 派發 CLI（enable/link/upgrade/check/remove）
├── docs/
│   ├── orchestrator-identity-and-portable-install.md
│   ├── superpowers_playbook.md
│   ├── semver_decision_tree.md
│   ├── release_note_template.md
│   ├── celestial_skill_mapping.md
│   └── project-spirit-analysis.md
└── skills/
    └── tao-of-opencode/
        ├── SKILL.md
        ├── scripts/                      # 純維護工具（非角色調度）
        │   ├── install-orchestrator.sh   # 模式 B：受管區塊寫進宿主 AGENTS.md
        │   ├── sync-superpowers.sh       # 同步上游 Superpowers 技能
        │   ├── assess-models.sh          # 模型能力評估
        │   └── refresh-model-registry.sh # 模型清單同步
        └── references/
            ├── model-registry.conf       # 模型清單與梯隊定義
            ├── explorer.md
            ├── oracle.md
            ├── librarian.md
            ├── fixer.md
            ├── designer.md
            └── superpowers/
                ├── SOURCE.md
                ├── brainstorming/
                ├── writing-plans/
                ├── executing-plans/
                ├── test-driven-development/
                ├── systematic-debugging/
                ├── verification-before-completion/
                ├── requesting-code-review/
                └── receiving-code-review/
```

---

## 致謝

本專案的靈感來源：
-   [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim) by @alvinunreal
-   [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) by @code-yeongyu

---

*版本更新日期：2026-05-28*
