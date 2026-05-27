# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ 最重要規則

**Git commit 訊息絕對不可包含 `Co-Authored-By: Claude` 或任何 AI 署名資訊。** 只寫功能描述，不附加任何尾行。

## 專案概覽

本倉庫是「程式之道 (Tao of Coding)」，一套以 Markdown 指令集為核心的**多代理協作框架 (Multi-Agent Orchestration Framework)**，透過 OpenCode CLI 執行，將開發任務路由給適合的角色子代理。

## 核心架構

### 角色分工

| 角色 | 職掌 | 預設模型 |
| :--- | :--- | :--- |
| **Explorer** | 快速掃描專案結構、追蹤依賴 | `opencode/deepseek-v4-flash-free` |
| **Oracle** | 架構分析、重構策略、方案決策 | `nvidia/openai/gpt-oss-120b` |
| **Librarian** | 文件撰寫、翻譯、API 註解 | `nvidia/minimaxai/minimax-m2.7` |
| **Fixer** | 程式碼實作、修復、測試補全 | `nvidia/qwen/qwen3-coder-480b-a35b-instruct` |
| **Designer** | UI/UX 設計、前端體驗 | `nvidia/microsoft/phi-4-multimodal-instruct` |

角色指南位於 `skills/tao-of-opencode/references/<role>.md`。

### 目錄結構重點

```
skills/tao-of-opencode/
├── SKILL.md                    # 主協議（Root Skill）
├── references/
│   ├── *.md                    # 各角色指南（explorer, oracle, librarian, fixer, designer）
│   ├── skill-routing.conf      # 自動路由規則（INI 格式，bash ERE pattern）
│   └── superpowers/            # 本地化 Superpowers 技能集
└── scripts/
    ├── orchestrate-skill.sh    # 自動路由 + 委派（推薦入口）
    ├── skill-dispatch.sh       # 手動指定角色 + 技能委派
    └── sync-superpowers.sh     # 同步上游 superpowers 技能
```

### Skill 路由機制

`skill-routing.conf` 定義 pattern → role/skill 的路由規則。`orchestrate-skill.sh` 讀取此設定檔，依 prompt 內容自動選擇角色與技能，再呼叫 `skill-dispatch.sh` 組裝完整 prompt（Runtime Header + 角色指南 + 技能文件），最終透過 `--runner-cmd` 送入 OpenCode。

防遞迴機制靠 `visited_skills`、`max_depth`、`edge_type` 三層守衛，所有子 Skill 在 Delegated 模式下執行，不得重載 root `SKILL.md`。詳見 `docs/skill_dispatcher_contract.md`。

## 常用指令

### 自動路由執行（推薦）
```bash
bash skills/tao-of-opencode/scripts/orchestrate-skill.sh \
  --prompt "你的任務描述" \
  --runner-cmd "opencode run --model nvidia/deepseek-ai/deepseek-v4-pro"

# 預覽路由結果（不實際執行）
bash skills/tao-of-opencode/scripts/orchestrate-skill.sh \
  --prompt "這個測試一直失敗" --dry-run
```

### 手動指定角色與技能委派
```bash
bash skills/tao-of-opencode/scripts/skill-dispatch.sh \
  --role fixer --skill systematic-debugging \
  --execution-mode delegated --depth 1 \
  --parent-skill executing-plans --edge-type requires_now \
  --visited-skills writing-plans,executing-plans \
  --prompt "請追查根因，暫不提修補方案" \
  --runner-cmd "opencode run --model nvidia/deepseek-ai/deepseek-v4-pro"

# 輸出組裝好的 prompt 到檔案而不執行
bash skills/tao-of-opencode/scripts/skill-dispatch.sh \
  --role explorer --skill executing-plans \
  --prompt "按計畫執行重構" \
  --output-file /tmp/composed-prompt.md
```

### 模型能力評估
```bash
# 預覽（不呼叫 API）
bash skills/tao-of-opencode/scripts/assess-models.sh --dry-run

# 只測 S/A 梯隊（約 10–15 分鐘）
bash skills/tao-of-opencode/scripts/assess-models.sh --tier S,A

# 全量（約 25–40 分鐘，結果寫入 docs/model-assessment.md）
bash skills/tao-of-opencode/scripts/assess-models.sh
```
模型清單：`skills/tao-of-opencode/references/model-registry.conf`

### 同步上游 Superpowers 技能
```bash
# 預覽差異
bash skills/tao-of-opencode/scripts/sync-superpowers.sh <commit-or-tag> --dry-run

# 執行同步
bash skills/tao-of-opencode/scripts/sync-superpowers.sh v4.2.0
```
版本追蹤：`skills/tao-of-opencode/references/superpowers/SOURCE.md`

### 安裝技能連結
```bash
# 互動式（推薦）
npx skill-linker

# 手動連結範例
ln -s ~/Documents/AgentSkills/tao-of-coding/skills/tao-of-opencode ~/.gemini/antigravity/skills/tao-of-opencode
```

## 修改路由規則

調整自動觸發行為，優先修改 `skills/tao-of-opencode/references/skill-routing.conf`，避免直接改腳本邏輯。格式為 INI，`pattern` 使用 bash ERE 正則（不區分大小寫），同一 `[route.*]` 下可定義多個 pattern，任一匹配即觸發。

## 重要規範

- `SKILL.md` 只允許在最外層 Root 模式載入一次；子 Skill 以 Delegated 模式執行，禁止重載。
- 任何角色輸出若未附可追溯路徑（`docs/...`、`src/...`、`tests/...`），視為未完成。
- 多步驟任務需先回報「路由角色 + 將使用的技能/工具」再執行。
- 涉及外部事實時，需附來源與查詢日期（YYYY-MM-DD）。
