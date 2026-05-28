# 程式之道 (Tao of Coding)

> *「有序協作，穩定交付。」*

[![Status: Active](https://img.shields.io/badge/Status-Active-blue)](#核心精神有序協作)
[![Concept: Multi-Agent](https://img.shields.io/badge/Concept-Multi_Agent-gold)](#角色目錄-the-role-catalog)

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

本系統透過 `opencode` CLI 進行請求。以下為常見的請求範例：

```bash
# 讓 Fixer 撰寫測試
cat component.js | opencode run --model "nvidia/qwen/qwen3-coder-480b-a35b-instruct" \
  "請為此組件編寫測試案例。"

# 讓 Oracle 分析架構
cat architecture.md | opencode run --model "nvidia/openai/gpt-oss-120b" \
  "Oracle請根據工程原則提供更好的架構設計。"

# 讓 Librarian 撰寫 README
opencode run --model "nvidia/minimaxai/minimax-m2.7" \
  "為本專案撰寫一份清晰易懂的 README。"
```

### 自動 Orchestration（建議）

若希望由對話內容自動觸發對應 skill，可用以下入口：

```bash
# 對話自動路由 -> 角色 + skill -> 套用防遞迴執行層
skills/tao-of-opencode/scripts/orchestrate-skill.sh \
  --prompt "這個測試一直失敗，先找根因不要修" \
  --depth 0 \
  --runner-cmd 'opencode run --model "nvidia/deepseek-ai/deepseek-v4-pro" "$(cat)"'

# 直接指定角色與技能（進階）
skills/tao-of-opencode/scripts/skill-dispatch.sh \
  --role fixer \
  --skill systematic-debugging \
  --execution-mode delegated \
  --depth 1 \
  --parent-skill executing-plans \
  --edge-type requires_now \
  --visited-skills writing-plans,executing-plans \
  --prompt "請先做根因分析，暫不提修補方案" \
  --runner-cmd 'opencode run --model "nvidia/deepseek-ai/deepseek-v4-pro" "$(cat)"'
```

### Multi-Agent 並行執行

```bash
# 定義 tasks（JSON array），同時觸發多個 agent
bash skills/tao-of-opencode/scripts/parallel-dispatch.sh \
  --tasks-file tasks.json \
  --parallelism 3 \
  --runner-cmd "opencode run --model opencode/deepseek-v4-flash-free" \
  --isolate-workspace \
  --summary-file /tmp/summary.json

# 合流多個 envelope，oracle 合成行動清單
bash skills/tao-of-opencode/scripts/reduce-envelopes.sh \
  --summary-file /tmp/summary.json \
  --runner-cmd "opencode run --model nvidia/openai/gpt-oss-120b"
```

tasks.json 格式：
```json
[
  { "role": "explorer", "skill": "executing-plans", "prompt": "掃描 src/ 模組結構" },
  { "role": "fixer",    "skill": "systematic-debugging", "prompt": "追查 parse_date 的 None 錯誤" }
]
```

### 自動迴圈執行（Phase 3）

`loop-dispatch.sh` 串接 parallel-dispatch + reduce-envelopes，讀取每輪 reducer 的 `next_actions` 自動組成下一輪任務，直到收斂或達到 `--max-iterations`：

```bash
bash skills/tao-of-opencode/scripts/loop-dispatch.sh \
  --tasks-file tasks.json \
  --runner-cmd "opencode run --model opencode/deepseek-v4-flash-free" \
  --reduce-runner-cmd "opencode run --model nvidia/openai/gpt-oss-120b" \
  --max-iterations 3 \
  --parallelism 3 \
  --isolate-workspace \
  --summary-dir /tmp/my-loop-run
```

每輪在 `<summary-dir>/iter-NN/` 下產生 `summary.json` 與 `reduced.json`；最終 reduced envelope 輸出到 stdout。

### Envelope 驗證

```bash
# 驗證 agent 輸出是否符合 Agent Message v1.0 schema
bash skills/tao-of-opencode/scripts/validate-agent-message.sh <message.json>

# 從 agent 完整輸出中自動抽取 ```json block 再驗證
bash skills/tao-of-opencode/scripts/validate-agent-message.sh --extract <agent-output.txt>
```

### 執行記錄維護

每次 `skill-dispatch.sh` 或 `parallel-dispatch.sh` 執行，會在 `.tao/runs/<request-id>/` 下產生 raw 輸出與 envelope。使用 `run-gc.sh` 定期清理：

```bash
# 乾跑：列出 7 天前的過期 run
bash skills/tao-of-opencode/scripts/run-gc.sh

# 執行清理（連同 git worktree 一起移除）
bash skills/tao-of-opencode/scripts/run-gc.sh --execute

# 只清特定 run
bash skills/tao-of-opencode/scripts/run-gc.sh --request-id <id> --execute

# 自訂保留天數
bash skills/tao-of-opencode/scripts/run-gc.sh --max-age 3 --execute
```

### 工具調用與查證規範（摘要）

以下規範與 `skills/tao-of-opencode/SKILL.md` 一致，未滿足不應宣告任務完成：

1. 只要任務涉及「最新/近期/可能變動」資訊，必須先用工具查證再回覆。
2. 使用外部事實（價格、新聞、法規、版本、公告）時，需附來源與查詢日期（YYYY-MM-DD）。
3. 若無法查證（網路或權限限制），需明確說明限制與已嘗試步驟，不得假設最新資訊。
4. 多步驟任務應先說明「角色路由 + 將使用的技能/工具」再執行。

更多詳細規範與指令範例，請參閱：
-   [Tao of OpenCode Protocol](skills/tao-of-opencode/SKILL.md)
-   [Tao x Superpowers 操作指引](docs/superpowers_playbook.md)
-   [Skill Dispatcher Contract](docs/skill_dispatcher_contract.md)
-   [Skill Routing 格式](docs/skill_routing_format.md)
-   [SemVer 版本決策樹](docs/semver_decision_tree.md)
-   [Release Note 模板](docs/release_note_template.md)
-   [角色職能與技能對照表](docs/celestial_skill_mapping.md)
-   [專案精神深度分析](docs/project-spirit-analysis.md)
-   [模型維護 SOP](docs/model-maintenance-sop.md)

## 已導入 Superpowers 技能 (Phase 1)

目前已在 `skills/tao-of-opencode/references/superpowers/` 本地導入以下核心技能：

- `brainstorming`
- `writing-plans`
- `executing-plans`
- `test-driven-development`
- `systematic-debugging`
- `verification-before-completion`
- `requesting-code-review`
- `receiving-code-review`

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

本專案以 Markdown 指令集為主，若要使用自動 orchestration 腳本，需具備基礎 CLI 環境。

建議安裝以下工具：

| 工具 | 用途 | 安裝確認 |
| :--- | :--- | :--- |
| **Bash** | 執行 `scripts/*.sh`（dispatch / orchestrate / sync）。 | `bash --version` |
| **Git** | 同步上游 superpowers 技能。 | `git --version` |
| **OpenCode CLI** | `tao-of-opencode` 執行入口。 | `opencode --version` |

---

## 安裝配置 (Installation)

### 1. Clone

建議將本專案放在 `~/Documents/AgentSkills`：

```bash
git clone https://github.com/raybird/tao-of-coding.git ~/Documents/AgentSkills/tao-of-coding
```

### 2. 建立連結 (Linking)

推薦使用 `npx` 調用 `skill-linker` 進行互動式連結：

```bash
npx skill-linker
```

啟動後：
1.  按 `L` 進入列表。
2.  選擇 `tao-of-opencode`。
3.  選擇要連結的 Agent (如 Antigravity, Windsurf) 並確認。

**備用方案：手動連結**

若無法使用 npx，可手動建立連結：

```bash
# Antigravity
mkdir -p ~/.gemini/antigravity/skills
ln -s ~/Documents/AgentSkills/tao-of-coding/skills/tao-of-opencode ~/.gemini/antigravity/skills/tao-of-opencode

# Windsurf
mkdir -p ~/.codeium/windsurf/skills
ln -s ~/Documents/AgentSkills/tao-of-coding/skills/tao-of-opencode ~/.codeium/windsurf/skills/tao-of-opencode
```

---

## 目錄結構

```text
.
├── README.md
├── docs/
│   ├── semver_decision_tree.md
│   ├── release_note_template.md
│   ├── superpowers_playbook.md
│   ├── skill_dispatcher_contract.md
│   ├── skill_routing_format.md
│   ├── superpowers_skills_analysis.md
│   ├── celestial_skill_mapping.md
│   └── project-spirit-analysis.md
└── skills/
    └── tao-of-opencode/
        ├── SKILL.md
        ├── scripts/
        │   ├── sync-superpowers.sh
        │   ├── skill-dispatch.sh
        │   └── orchestrate-skill.sh
        └── references/
            ├── explorer.md
            ├── oracle.md
            ├── librarian.md
            ├── fixer.md
            ├── designer.md
            ├── skill-routing.conf
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

*版本更新日期：2026-05-27*
