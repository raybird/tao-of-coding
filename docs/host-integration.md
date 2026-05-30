# 宿主整合指南 (Host Integration)

本文件示範如何在三個宿主把 tao-of-coding 落地：**Claude Code**、**OpenAI Codex CLI**、**Google Antigravity**。每節包含「安裝啟用 → 委派如何對應 → 端到端範例 → 注意事項與來源」。

> 三者皆同時支援「`AGENTS.md` 受管區塊（模式 B）」與「原生 subagent 並行委派」，因此 tao-of-coding 的兩層分工（角色身份 = skill / 根身份 = AGENTS.md / 調度 = 原生子代理）可完整落地。宿主能力或路徑細節會隨版本變動，**落地前請以各宿主官方文件為準**（資料查詢日：2026-05-30）。

通用協議見 [`../skills/tao-of-opencode/SKILL.md`](../skills/tao-of-opencode/SKILL.md) 的〈調度方式 (Delegation)〉。若某宿主無原生子代理，一律退回 in-context 角色切換。

---

## 通用端到端情境（三節共用）

以「**某單元測試一直失敗，請修好**」為例，orchestrator（agent 本體）依 SKILL.md 路由表處理：

1. **路由**：「錯誤追因」→ Fixer + `systematic-debugging`（協作 Explorer）。
2. **委派 Fixer 子代理**：載入 `references/fixer.md` + `references/superpowers/systematic-debugging/SKILL.md`，指示「先追根因、暫不修」。
3. **修復**：同一 Fixer 角色改用 `test-driven-development`，先寫會失敗的測試再實作。
4. **交付前驗證**：套 `verification-before-completion`，跑測試確認全綠才宣告完成。
5. **整合**：orchestrator 收斂各子代理結果，輸出摘要 + artifact 路徑。

以下三節示範同一情境在各宿主的落地差異。

---

## 1. Claude Code

### 安裝啟用
- **一鍵（推薦）**：`tao link && tao enable --target CLAUDE.md`——Claude Code 預設讀 `CLAUDE.md`，故明確指定它（`tao enable` 預設寫 `AGENTS.md`）。底層仍是下方 `install-orchestrator.sh`。
- **角色身份（skill）**：把 `skills/tao-of-opencode` 連結進 Claude Code 的 skills（`tao link` 或手動 symlink）。
- **根身份（模式 B）**：把受管區塊寫進專案 `CLAUDE.md`（Claude Code 預設讀取）或 `AGENTS.md`：
  ```bash
  bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target CLAUDE.md
  ```

### 委派如何對應
- **原生子代理（首選）**：用 **Task 工具**派發子代理；或在 `.claude/agents/<role>.md` 定義角色子代理。子代理是**無狀態、獨立 context**，正好對應 tao-of-coding 的「無狀態原則」。
- 委派時把「角色卡 + 技能文件 + 任務 + 必要上下文」作為子代理 prompt。

### 端到端範例
```
你（orchestrator）：路由 → Fixer + systematic-debugging。
→ Task(subagent) 帶 fixer.md + systematic-debugging/SKILL.md：「追根因，先別修。」
→ Task(subagent) 帶 fixer.md + test-driven-development/SKILL.md：「依根因寫 failing test 再修。」
→ Task(subagent)：verification-before-completion，跑測試確認全綠。
→ 你整合：回報修復摘要，diff/測試輸出寫到 tests/、docs/verification.md。
```

### 注意事項
- 子代理回傳即釋放，無記憶——每次委派都要帶完整上下文。
- 若不想用 Task，亦可 in-context 依序戴帽子。

來源：Claude Code 官方文件（subagents / skills / CLAUDE.md）— https://docs.claude.com/en/docs/claude-code

---

## 2. OpenAI Codex CLI

> **✅ 已實測（2026-05-30，`codex` v0.135.0，`codex exec --sandbox read-only`）**：把受管區塊寫進工作目錄 `AGENTS.md` 後，`codex exec` **自動從 cwd 載入**（無需任何額外旗標），並**完整採納本協議**——自稱「以 orchestrator（統籌者）身分運作」、列出 5 個 tao 角色、把「測試失敗找根因」**路由到 Fixer + systematic-debugging**、逐字引用調度準則。**三宿主中 headless 模式最乾淨**（不像 Antigravity headless 需 `--add-dir`）。詳見 `docs/case-studies/2026-05-30-orchestration-dogfood.md`。

### 安裝啟用
- **一鍵（推薦）**：`tao link && tao enable`（新資料夾預設寫 `AGENTS.md`）。底層仍是下方 `install-orchestrator.sh`。
- **根身份（模式 B）**：Codex 會把 `AGENTS.md` 從 repo 根往下串接，**越接近工作目錄者優先覆寫**，總大小上限 `project_doc_max_bytes`（預設 32 KiB；本受管區塊很小，無虞）。寫入 agent 實際工作目錄那份：
  ```bash
  bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target AGENTS.md
  ```
- **角色身份**：可另以 Codex 的 Agent Skills 安裝技能文件。

### 委派如何對應
- **原生子代理（首選）**：把五個角色定義為**自訂 agent TOML**，放 `.codex/agents/<role>.toml`（專案層）或 `~/.codex/agents/`（個人層），每檔一個 agent，於其中引用對應角色卡的指引。
- Codex 可並行 spawn 子代理再彙整結果；當 `delegation_mode = "skill_auto"` 且 repo 指示/技能明確路由、任務可切分、且存在對應的專案層自訂 agent（或有 documented fallback role）時，會自動派工。
- `agents.max_depth` 預設 **1**（只允許一層子代理），需要更深巢狀才調高（會增加 token/延遲）。

### 端到端範例
```
.codex/agents/fixer.toml  → 引用 references/fixer.md 的職掌與守則
AGENTS.md（受管區塊）      → 宣告 orchestrator 身份 + 路由準則

你（orchestrator）：路由 → fixer。
→ 派 fixer 子代理：「依 systematic-debugging 追根因，先別修。」
→ 派 fixer 子代理：「依 test-driven-development 寫 failing test 再修。」
→ verification-before-completion 後彙整結果。
```
> TOML 的確切欄位（model、prompt、tools 等）以 Codex 官方文件為準；本專案角色卡為 Markdown，建議在 TOML 內以 prompt/instructions 欄位引入對應 `references/<role>.md` 的內容或路徑。

### 注意事項
- 受管區塊要寫進「agent 實際 cwd 會讀到」的那份 `AGENTS.md`（近 cwd 者覆寫遠者）。
- **precedence**：Codex 視「越後面的內容優先級越高」。若你希望**專案自訂規則覆寫本協議**，安裝時用 `--position prepend` 把區塊放檔頭，讓你後面的內容勝出：
  ```bash
  bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target AGENTS.md --position prepend
  ```
  反之要讓本協議當基礎框架（多數情況），用預設 `append`（檔尾）即可。
- `max_depth=1` 表示預設不支援子代理再開子代理；多階流程由 orchestrator 逐段派發。

來源（查詢日 2026-05-30）：
- Subagents — https://developers.openai.com/codex/subagents
- AGENTS.md — https://developers.openai.com/codex/guides/agents-md
- Agent Skills — https://developers.openai.com/codex/skills

---

## 3. Google Antigravity

> **✅ 已實測（2026-05-30，`agy` v1.0.3）**：把受管區塊寫進工作目錄的 `AGENTS.md` 並以 `agy --add-dir <ws>` 載入後，agy **完整採納本協議**——自稱「以 Orchestrator（統籌者）身分運作」、正確列出 5 個 tao 角色、把「測試失敗找根因」**路由到 Fixer + systematic-debugging**，並逐字引用受管區塊的調度準則。Mode B 在 Antigravity 上**可運作**。詳見 `docs/case-studies/2026-05-30-orchestration-dogfood.md`。

### 安裝啟用
- **一鍵（推薦）**：`tao link && tao enable`（新資料夾預設寫 `AGENTS.md`）。底層仍是下方 `install-orchestrator.sh`。
- **根身份（模式 B）**：把受管區塊寫進 Antigravity 工作目錄的 `AGENTS.md`：
  ```bash
  bash skills/tao-of-opencode/scripts/install-orchestrator.sh --target AGENTS.md
  ```
- **角色身份（skill）**：Antigravity 的 Skill 為目錄式套件（`SKILL.md` + 資產），放 `.agents/skills/`——與本專案 `skills/tao-of-opencode/` 結構一致，可直接連結或複製進去。

### 委派如何對應
- **原生子代理（首選）**：**Async Subagent Mode** 由 manager agent 把任務拆成子任務，spawn 多個專長子代理並行（寫碼／跑指令／測試各一），完成後回傳 diff。Skill 內可含 nested subagent 定義。
- 把五個角色對應成各自的專長子代理，由 orchestrator/manager 依路由表分派。

### 端到端範例
```
.agents/skills/tao-of-opencode/SKILL.md → 角色庫與路由表
AGENTS.md（受管區塊）                    → orchestrator 身份 + 調度準則

你（orchestrator / manager）：路由 → Fixer。
→ Async Subagent：Fixer「systematic-debugging 追根因」。
→ Async Subagent：Fixer「TDD 寫 failing test 再修」。
→ 驗證子代理：verification-before-completion。
→ manager 收斂並回傳 diff/摘要。
```

### 注意事項
- **⚠️ headless 模式要 `--add-dir`（實測 gotcha）**：`agy -p`（非互動 `--print`）**不會自動載入**工作目錄的 `AGENTS.md`；實測未加 `--add-dir` 時，agy 完全退回它的原生 subagent 模型（`research`/`self`/`define_subagent`），Mode B **不生效**。必須 `agy --add-dir <工作目錄> -p ...`（且該目錄為 git repo 有幫助），agy 才會把 `AGENTS.md` 吃進它的 brain 上下文。互動/IDE 模式是否自動載入未在此測。
- Antigravity 的原生角色是 `research`/`self`/自訂子代理，與 tao 的五角色是**概念對應**；agy 會以這些原生機制去「扮演」協議裡的角色，而非真有名為 Explorer 的子代理。
- **版本敏感**：`AGENTS.md` + `.agents/skills/` 為 Antigravity 2.0 慣例；舊版用 `~/.gemini/antigravity/skills/`（本 repo README 安裝範例即舊式）。請依你的 Antigravity 版本選擇路徑。
- Async Subagent Mode 為背景並行，注意成本與結果彙整。

來源（查詢日 2026-05-30）：
- Antigravity Agent 文件 — https://antigravity.google/docs/agent
- 子代理討論 — https://discuss.ai.google.dev/t/antigravity-sub-agents/114381
- Skills 教學 — https://medium.com/google-cloud/tutorial-getting-started-with-antigravity-skills-864041811e0d
- 自主開發流程 codelab — https://codelabs.developers.google.com/autonomous-ai-developer-pipelines-antigravity

---

## 對照速查

| 宿主 | 根身份（模式 B）目標 | 角色身份（skill） | 原生子代理機制 | 無狀態隔離 |
| :--- | :--- | :--- | :--- | :--- |
| Claude Code | `CLAUDE.md` 或 `AGENTS.md` | skill 連結 | Task 工具 / `.claude/agents/*.md` | ✅ |
| Codex CLI | `AGENTS.md`（近 cwd 覆寫，≤32 KiB；headless 自動載入，✅2026-05-30 實測） | Agent Skills | `.codex/agents/*.toml`，`max_depth=1` | ✅（並行彙整） |
| Antigravity | 工作目錄 `AGENTS.md`（headless 需 `--add-dir`，✅2026-05-30 實測） | `.agents/skills/`（目錄式） | Async Subagent Mode | ✅（背景並行） |

任一宿主若無原生子代理，退回 in-context 角色切換（同一 session 輪流戴帽子，無真隔離）。
