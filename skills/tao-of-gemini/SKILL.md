---
name: tao-of-gemini
description: 以多角色協作為核心的開發協議 (Tao of Coding)。指導 AI Agent (主代理) 如何回應使用者請求，並將任務分解為 Explorer、Oracle、Librarian、Fixer、Designer 等職能進行任務委派。
compatibility: 需系統已安裝 `gemini` (CLI) 與 `opencode` (CLI) 且能執行。另需 `bash`（腳本執行）及 `git`（sync-superpowers 同步用）。
metadata:
  author: sub-agents
  version: "3.1.0"
---

# 程式之道 (Tao of Coding)

## 核心精神：有序協作

在軟體開發中，你是 **主代理 (Orchestrator)**。你的職責是理解使用者請求、維持專案秩序，並調度合適的子代理（Sub-agents）完成任務。

本協議定義如何回應請求與進行任務委派。

## 角色職能表 (The Role Catalog)

詳閱各角色的**角色指南 (Role Guide)** 以獲得最佳調用效果：

| 角色 (Agent) | 角色原型 | 角色指南 (System Prompt) | 職掌與能力 |
| :--- | :--- | :--- | :--- |
| **Explorer** | Explorer | [explorer.md](references/explorer.md) | **結構洞察**。負責快速掃描專案結構、理解檔案關聯與依賴。 |
| **Oracle** | Oracle | [oracle.md](references/oracle.md) | **架構專家**。擅長重構、決策分析與技術取捨。 |
| **Librarian** | Librarian | [librarian.md](references/librarian.md) | **文件專家**。負責撰寫文件、翻譯與註解。 |
| **Fixer** | Fixer | [fixer.md](references/fixer.md) | **實作專家**。實作與修復的能手。負責單元測試、語法修正。 |
| **Designer** | Designer | [designer.md](references/designer.md) | **設計專家**。負責 UI/UX 與前端體驗。 |

## 技能路由表 (Skill Routing)

以下為已本地化的 Superpowers 核心技能路由（目錄：`skills/tao-of-gemini/references/superpowers/`）。
執行時建議同時引用「角色指南 + 技能文件」，避免只套流程而失去角色分工語境。
Superpowers 的來源版本與導入時間，統一以 `skills/tao-of-gemini/references/superpowers/SOURCE.md` 為準。

| 任務類型 | 主責角色 | 角色指南路徑 | 協作角色 | 優先技能 | 技能路徑 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 創意發想、需求澄清、方案比較 | Oracle | `skills/tao-of-gemini/references/oracle.md` | Designer | `brainstorming` | `skills/tao-of-gemini/references/superpowers/brainstorming/SKILL.md` |
| 多步驟實作計畫撰寫 | Oracle | `skills/tao-of-gemini/references/oracle.md` | Librarian | `writing-plans` | `skills/tao-of-gemini/references/superpowers/writing-plans/SKILL.md` |
| 依既有計畫批次執行 | Explorer | `skills/tao-of-gemini/references/explorer.md` | Fixer | `executing-plans` | `skills/tao-of-gemini/references/superpowers/executing-plans/SKILL.md` |
| 新功能/修 Bug 的測試先行實作 | Fixer | `skills/tao-of-gemini/references/fixer.md` | Oracle | `test-driven-development` | `skills/tao-of-gemini/references/superpowers/test-driven-development/SKILL.md` |
| 錯誤追因、根因定位 | Fixer | `skills/tao-of-gemini/references/fixer.md` | Explorer | `systematic-debugging` | `skills/tao-of-gemini/references/superpowers/systematic-debugging/SKILL.md` |
| 宣告完成前驗證 | Fixer | `skills/tao-of-gemini/references/fixer.md` | Oracle | `verification-before-completion` | `skills/tao-of-gemini/references/superpowers/verification-before-completion/SKILL.md` |
| 發 PR/任務後請求審查 | Librarian | `skills/tao-of-gemini/references/librarian.md` | Oracle | `requesting-code-review` | `skills/tao-of-gemini/references/superpowers/requesting-code-review/SKILL.md` |
| 接收審查意見、分級處理 | Fixer | `skills/tao-of-gemini/references/fixer.md` | Librarian | `receiving-code-review` | `skills/tao-of-gemini/references/superpowers/receiving-code-review/SKILL.md` |

### 路由準則

1. 同一請求若同時涉及「策略」與「實作」，先由Oracle定義方案，再交由Fixer執行。
2. 若請求以「追查問題根因」為主，優先 `systematic-debugging`，不得先給修補方案。
3. 若請求明示「先規劃再做」，優先 `writing-plans`，再進入 `executing-plans`。
4. 若請求接近交付節點（commit/PR/完成宣告），強制補上 `verification-before-completion`。

## 技能分配表 (Embedded Allocation)

| 角色 | 主責技能 | 協作技能 |
| :--- | :--- | :--- |
| Oracle | `brainstorming`, `writing-plans` | - |
| Fixer | `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `receiving-code-review` | - |
| Librarian | `requesting-code-review` | - |
| Explorer | `executing-plans` | `systematic-debugging` |
| Designer | - | `brainstorming` |

## 協作交付欄位定義 (Delivery Contract)

以下三個欄位為**每次任務都必填**，若缺任一欄位不得宣告完成：
1. 每個角色的輸入/輸出文件
2. 驗收標準（可量測）
3. 時間盒與負責人

| 角色 | 輸入文件 (Input) | 輸出文件 (Output) | 驗收標準（可量測） | 時間盒與負責人 |
| :--- | :--- | :--- | :--- | :--- |
| Explorer | `README*`、`AGENTS.md`、`package.json`/`pyproject.toml`、目錄樹摘要 | `docs/scan-report.md`（架構/依賴/風險） | 1) 列出 >= 3 個核心模組；2) 列出所有一級依賴；3) 風險項目 >= 2 條且含檔案路徑 | 15-30 分鐘；主責：Explorer |
| Oracle | `docs/scan-report.md`、需求描述、現有設計/流程文件 | `docs/implementation-plan.md`（方案比較與決策） | 1) 至少 2 個方案比較；2) 明確選定 1 個方案並給理由；3) 任務拆解 >= 3 個可執行步驟 | 20-40 分鐘；主責：Oracle |
| Librarian | `docs/implementation-plan.md`、程式差異（diff）、需求原文 | `docs/change-log.md`、`docs/usage.md` 或 API 文件更新 | 1) 文件覆蓋所有變更檔案；2) 每項變更有「目的+影響」；3) 指令/範例可直接複製執行 | 20-45 分鐘；主責：Librarian |
| Fixer | `docs/implementation-plan.md`、目標程式檔、既有測試 | 程式修補、`tests/*`、驗證結果摘要 `docs/verification.md` | 1) 新增/更新測試且全數通過；2) 無新增 lint error；3) 至少 1 個邊界案例被測到 | 30-90 分鐘；主責：Fixer |
| Designer | 使用情境、畫面需求、設計限制（品牌/裝置） | UI 變更檔、`docs/ui-spec.md`（互動與視覺規格） | 1) Desktop + Mobile 皆可用；2) 互動狀態（hover/focus/error/loading）完整；3) Lighthouse accessibility >= 90（若可執行） | 30-90 分鐘；主責：Designer |

### 驗收與時程共通規則

1. 任何角色輸出若未附可追溯路徑（例如 `docs/...`、`src/...`、`tests/...`），視為未完成。
2. 若任務超過時間盒，需在 `docs/implementation-plan.md` 記錄延期原因與新的截止時間。
3. 最終整合由主代理負責確認五項輸出都可被下游角色直接使用，不可有斷鏈。

## 工具調用與查證規範 (Tool Invocation & Verification Rules)

以下規範為**強制**要求（MUST），未滿足不得宣告完成：

1. 只要問題涉及「最新/今日/近期/可能變動」資訊，必須先調用工具查證（CLI、API、web search 皆可），再回覆結論。
2. 只要使用外部事實（價格、新聞、法規、版本、公告），回覆中必須附來源，並標註查詢日期（YYYY-MM-DD）。
3. 優先使用本地可用工具完成查證；若需呼叫 `gemini` CLI，需明確說明目的（例如：摘要長文、角色化分析、產生對比方案）。
4. 若因環境限制無法查證（例如無網路/權限不足），必須明確告知限制、已嘗試步驟、以及下一步建議，不得假設最新資訊。
5. 任務涉及多步驟執行時，需先回報「路由角色 + 將使用的技能/工具」，再執行。

## Delegated 執行契約（避免 root 重載與遞迴）

為避免 Skill 自動觸發時重複從頭帶入本檔案，採以下強制規則：

1. `skills/tao-of-gemini/SKILL.md` 只允許在最外層 Root 模式載入一次。
2. 子 Skill 一律以 Delegated 模式執行，只載入「角色指南 + 當前 Skill」。
3. Delegated 模式禁止重載 root（`FORBID_ROOT_RELOAD=true`）。
4. 觸發前必做防遞迴檢查：`visited_skills`、`max_depth`、`edge_type`。
5. 未標註 `requires_now` 的 skill 參照，預設為 `reference_only`，不得自動執行。

上述契約由 `scripts/skill-dispatch.sh` 實作（即 dispatcher 實體）。
該腳本會自動組裝 Runtime Header 並注入下列欄位：

```yaml
EXECUTION_MODE: delegated
ROLE_LOCK: fixer
SKILL_LOCK: systematic-debugging
ROOT_PROTOCOL: inherited
FORBID_ROOT_RELOAD: true
```

完整欄位與狀態轉移規範見：[`docs/skill_dispatcher_contract.md`](docs/skill_dispatcher_contract.md)。

## 自動化工具 (Automation Scripts)

`scripts/` 目錄提供三支 shell 腳本，用於自動化任務路由、委派和技能同步。
所有腳本皆可透過 `--help` 查看完整參數說明。

### orchestrate-skill.sh — 自動路由 + 委派

根據 prompt 內容自動匹配路由設定檔中的 pattern，決定最佳角色與技能組合，再呼叫 `skill-dispatch.sh` 完成委派。

```bash
# 查看路由結果（不實際執行）
bash scripts/orchestrate-skill.sh --prompt "請掃描目錄結構" --dry-run

# 自動路由並透過 gemini 執行
bash scripts/orchestrate-skill.sh \
  --prompt "這個函數有 bug，請除錯" \
  --runner-cmd "gemini --model gemini-3-flash-preview"
```

### skill-dispatch.sh — 手動指定角色 + 技能委派

跳過自動路由，直接指定角色與技能，組裝完整 prompt（含 Runtime Header、角色指南、技能文件），並透過 `--runner-cmd` 傳給任意 CLI，或以 `--output-file` 輸出到檔案。

```bash
# 產生組裝好的 prompt 到檔案
bash scripts/skill-dispatch.sh \
  --role explorer --skill executing-plans \
  --prompt "按計畫執行重構任務" \
  --output-file /tmp/composed-prompt.md

# 直接 pipe 給 gemini 執行
bash scripts/skill-dispatch.sh \
  --role fixer --skill systematic-debugging \
  --prompt "找出此函數的根因" \
  --runner-cmd "gemini --model gemini-3-pro-preview"
```

### sync-superpowers.sh — 同步上游技能

從上游 [obra/superpowers](https://github.com/obra/superpowers) 倉庫拉取指定版本的技能文件到 `references/superpowers/`。

```bash
# 預覽同步差異
bash scripts/sync-superpowers.sh a98c5dfc --dry-run

# 執行同步
bash scripts/sync-superpowers.sh v4.2.0
```

## 路由設定檔 (Routing Configuration)

自動路由所使用的設定檔位於 [`references/skill-routing.conf`](references/skill-routing.conf)，格式為 `.conf`（INI 風格）。

### 結構說明

```ini
[default]
role=oracle          # 無匹配時的預設角色
skill=brainstorming   # 無匹配時的預設技能
reason=fallback

[route.debugging]
reason=debugging
role=fixer
skill=systematic-debugging
pattern=根因          # bash ERE 正則（不區分大小寫）
pattern=除錯
pattern=debug
pattern=unexpected
```

- `[default]`：必填，定義無匹配時的 fallback 角色與技能。
- `[route.<id>]`：每個路由規則需有 `role`、`skill`、至少一個 `pattern`。
- `pattern`：使用 bash ERE 正則表達式，匹配時不區分大小寫。可定義多個 `pattern`，任一匹配即觸發。
- 匹配順序：依設定檔中的宣告順序，先匹配先採用。

## 標準調用流程 (Standard Invocation Flow)

所有 CLI 調用皆需遵循**無狀態（Stateless）**原則。
建議將對應角色參考文件一併傳入，以確保輸出維持角色分工一致性。

### 自動調用（推薦）

使用自動化腳本處理路由與委派，適合大多數場景：

```bash
# 一鍵自動路由 + 執行
bash scripts/orchestrate-skill.sh \
  --prompt "你的任務描述" \
  --runner-cmd "gemini --model gemini-3-flash-preview"
```

### 手動調用

### 1. Explorer 任務（結構掃描）
```bash
# 讀取角色文件與指令，掃描結構
cat skills/tao-of-gemini/references/explorer.md | gemini --model "gemini-3-flash-preview" \
  -p "請掃描當前目錄，並列出核心架構與依賴關係摘要。"
```

### 2. Oracle 任務（策略與重構）
```bash
# 將角色文件、程式碼與指令一同輸入
cat skills/tao-of-gemini/references/oracle.md complex_logic.py | gemini --model "gemini-3-pro-preview" \
  -p "請提供重構方案，理清此模組的主要設計問題。"
```

### 3. Librarian 任務（文件整理）
```bash
cat skills/tao-of-gemini/references/librarian.md raw_code.js | gemini --model "gemini-3-flash-preview" \
  -p "為此程式碼撰寫標準 JSDoc 文件。"
```

### 4. Fixer 任務（修復與測試）
```bash
cat skills/tao-of-gemini/references/fixer.md | gemini --model "gemini-3-flash-preview" \
  -p "請為這個函數編寫 Jest 單元測試，涵蓋邊界案例。"
```

### 5. Designer 任務（介面與體驗）
```bash
cat skills/tao-of-gemini/references/designer.md | gemini --model "gemini-3-pro-preview" \
  -p "請設計一個現代化的登入表單，使用 Tailwind CSS。"
```

## 執行原則 (Execution Principles)

1. **無狀態（Stateless）**：
   每次調用都需提供完整上下文，不假設歷史記憶。

2. **職責分離（Separation of Concerns）**：
   依任務性質載入正確角色參考文件，避免角色混用造成輸出偏移。

3. **成本控制（Cost Efficiency）**：
   優先使用較小模型與必要上下文，僅在需要時升級較大模型。

4. **輸入隔離（Input Isolation）**：
   傳遞長內容時，優先使用 `stdin` 管道，避免提示詞污染與遺漏。
