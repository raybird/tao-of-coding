# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ 最重要規則

**Git commit 訊息絕對不可包含 `Co-Authored-By: Claude` 或任何 AI 署名資訊。** 只寫功能描述，不附加任何尾行。

## 專案概覽

本倉庫是「程式之道 (Tao of Coding)」，一套以 Markdown 指令集為核心、**host-agnostic 的多代理協作框架 (Multi-Agent Orchestration Framework)**。當前 agent 讀取宿主 `AGENTS.md` 的受管區塊（或 skill）後**自己就是 orchestrator 本體**，依任務性質把工作委派給角色——優先用宿主原生 subagent/task 機制，無則 in-context 角色切換。**不再透過任何 shell 包裝或 opencode 子進程啟動。**

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
├── SKILL.md                    # 主協議（agent 即 orchestrator）
├── references/
│   ├── *.md                    # 各角色指南（explorer, oracle, librarian, fixer, designer）
│   ├── model-registry.conf     # 模型清單
│   └── superpowers/            # 本地化 Superpowers 技能集
└── scripts/                    # 純維護工具（非角色調度）
    ├── install-orchestrator.sh # 模式 B 安裝：受管區塊寫進宿主 AGENTS.md
    ├── sync-superpowers.sh     # 同步上游 superpowers 技能
    ├── assess-models.sh        # 模型能力評估
    └── refresh-model-registry.sh
```

### 調度機制

路由意圖以 `SKILL.md` 的「技能路由表」（markdown）呈現，由 agent 本體閱讀後判斷。委派方式 host-agnostic：**優先用宿主原生 subagent/task**（如 Claude Code 的 Task）取得隔離與無狀態；宿主無此能力時於同一對話內 **in-context 角色切換**。委派前載入對應角色卡與所需技能。詳見 `SKILL.md` 的〈調度方式 (Delegation)〉，各宿主（Claude Code / Codex / Antigravity）落地範例見 `docs/host-integration.md`。

> 早期的 shell 編排機制（orchestrate-skill / skill-dispatch / parallel-dispatch / loop-dispatch、Agent Message envelope、dispatcher 契約）已於 2026-05-29 全面移除。背景見 `docs/orchestrator-identity-and-portable-install.md`。

## 常用指令

> 角色調度沒有 CLI 入口——你（agent 本體）直接依 `SKILL.md` 的〈調度方式〉以宿主原生 subagent 或 in-context 委派。以下僅為維護用腳本。

### tao CLI（全域入口）

由 `install.sh` 安裝後可用（`curl -fsSL .../install.sh | bash`）：

```bash
tao enable     # 當前資料夾寫入受管區塊（偵測 CLAUDE.md > AGENTS.md > 建 AGENTS.md）
tao check      # 狀態檢查（exit 0/1/2）
tao remove     # 卸載受管區塊
tao link       # symlink skill 進宿主（自動偵測，或 tao link <skills-dir>）
tao upgrade    # 升級 tao 本體（git pull）
```

`tao enable` 等同呼叫下方 `install-orchestrator.sh`，差別在自動偵測宿主檔、用絕對路徑、免記腳本位置。

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
bash skills/tao-of-opencode/scripts/sync-superpowers.sh v5.1.0
```
版本追蹤：`skills/tao-of-opencode/references/superpowers/SOURCE.md`

### 安裝技能連結
```bash
# 推薦：自動偵測已安裝宿主並 symlink
tao link

# 指定宿主 skills 目錄
tao link ~/.gemini/antigravity/skills

# 手動連結範例（不經 tao）
ln -s ~/.local/share/tao-of-coding/skills/tao-of-opencode ~/.gemini/antigravity/skills/tao-of-opencode
```

### 確立 orchestrator 根身份（模式 B — Persistent）
角色身份靠 skill 連結即可；orchestrator 根身份若要常駐，用 `install-orchestrator.sh` 把受管區塊冪等寫進宿主 `AGENTS.md`（仿 GitNexus，非破壞、可重跑）。設計見 `docs/orchestrator-identity-and-portable-install.md`。
```bash
# 預覽（不寫檔）
bash skills/tao-of-opencode/scripts/install-orchestrator.sh --dry-run

# 寫入宿主實際讀的 AGENTS.md（預設 ./AGENTS.md，可 --target 覆寫）
bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target workspace/AGENTS.md

# 卸載（移除區塊，標記外手寫內容保留）
bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target workspace/AGENTS.md --remove

# 唯讀檢查狀態（exit 0=最新／1=過時／2=未安裝；供 CI 判讀）
bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target workspace/AGENTS.md --check
```
受管區塊以 `<!-- tao:start -->` / `<!-- tao:end -->` 包夾，只放名冊摘要與調度準則；全文角色卡永遠留在 `skills/`。

## 修改路由規則

調整角色/技能路由，修改 `SKILL.md` 的「技能路由表」（markdown 表格）與「路由準則」。agent 本體閱讀此表後判斷該找誰、用什麼技能。

## 重要規範

- 角色調度走宿主原生 subagent 或 in-context，不再經由任何 shell 包裝。
- 任何角色輸出若未附可追溯路徑（`docs/...`、`src/...`、`tests/...`），視為未完成。
- 多步驟任務需先回報「路由角色 + 將使用的技能/工具」再執行。
- 涉及外部事實時，需附來源與查詢日期（YYYY-MM-DD）。
