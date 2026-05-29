# Tao x Superpowers 操作指引

本文件提供團隊可直接複用的操作方式，說明如何在 Tao 流程中呼叫 `skills/tao-of-opencode/references/superpowers/*`。

## 1) 何時用 Tao、何時用 Superpowers

- Tao (`skills/tao-of-opencode/SKILL.md`) 是「角色編排與路由層」：先判斷該請哪位角色。
- Superpowers (`skills/tao-of-opencode/references/superpowers/*`) 是「執行技能層」：進到具體流程（TDD、debug、review...）。
- 實務上採兩段式：先用 Tao 定位任務，再把對應的 Superpowers skill 當成執行規格。

### 強制查證規範（與 SKILL.md 對齊）

以下規範為執行前提；若未滿足，不應宣告完成：

1. 涉及「最新/今日/近期/可能變動」資訊時，必須先調用工具查證（CLI/API/web search）再回覆。
2. 使用外部事實（價格、新聞、法規、版本、公告）時，必須附來源與查詢日期（YYYY-MM-DD）。
3. 優先使用本地可用工具；若委派角色子代理協助，需明確說明用途（摘要、分析、對比）。
4. 若受限於網路或權限而無法查證，需說明限制與已嘗試步驟，不得假設最新資訊。
5. 多步驟任務先回報「路由角色 + 將使用技能/工具」再執行。

## 2) 已導入可用技能 (Phase 1)

- `skills/tao-of-opencode/references/superpowers/brainstorming/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/writing-plans/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/executing-plans/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/test-driven-development/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/systematic-debugging/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/verification-before-completion/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/requesting-code-review/SKILL.md`
- `skills/tao-of-opencode/references/superpowers/receiving-code-review/SKILL.md`

對照與分工請看 `docs/celestial_skill_mapping.md`。

## 3) 標準呼叫流程 (Team SOP)

### Step A: 先決定路由

參考 `skills/tao-of-opencode/SKILL.md` 的「技能路由表」，判斷本次任務主責角色與優先技能。

### Step B: 載入角色指南 + 技能文件

委派該角色時，先載入「角色指南 + 對應 superpowers skill」，讓角色與流程同時生效。

例如除錯任務（Fixer + systematic-debugging）：載入 `references/fixer.md` 與 `references/superpowers/systematic-debugging/SKILL.md`，委派給 Fixer 子代理（宿主無原生 subagent 時則 in-context 切換），指示：「依 systematic-debugging 四階段流程追查根因，先不要給修補方案。」

### Step C: 若技能有 reference，按需追加

例如 `systematic-debugging` 可依情境再附：
- `.../superpowers/systematic-debugging/root-cause-tracing.md`
- `.../superpowers/systematic-debugging/defense-in-depth.md`
- `.../superpowers/systematic-debugging/condition-based-waiting.md`

## 4) 常見任務範本

每則 =「載入哪些檔 + 委派給誰 + 指示」。委派方式 host-agnostic（原生 subagent 優先，否則 in-context）。

### A. 需求發想/方案比較
載入 `oracle.md` + `brainstorming/SKILL.md`，委派 Oracle：「先用 brainstorming 流程澄清需求，再提出 2-3 種方案與取捨。」

### B. 先寫計畫，再執行
1. 載入 `oracle.md` + `writing-plans/SKILL.md`，委派 Oracle：「為此需求輸出可執行的 implementation plan，存到 `docs/plans`。」
2. 載入 `explorer.md` + `executing-plans/SKILL.md`，委派 Explorer：「讀取 `docs/plans/XXX.md`，按 executing-plans 分批執行並在檢查點回報。」

### C. 功能或 Bug 修復（TDD）
載入 `fixer.md` + `test-driven-development/SKILL.md`，委派 Fixer：「用 TDD（RED-GREEN-REFACTOR）修復，先寫會失敗的測試再實作。」

### D. 送審與回覆審查
- 載入 `librarian.md` + `requesting-code-review/SKILL.md`，委派 Librarian：「依 requesting-code-review 整理本次變更的 review 請求。」
- 載入 `fixer.md` + `receiving-code-review/SKILL.md`，委派 Fixer：「依 receiving-code-review 處理 reviewer 意見，先釐清再實作。」

## 5) 提示詞寫法建議

- 明確指定「角色 + skill + 產出格式」。
- debug 類務必「先根因、後修復」。
- 完成宣告前務必補 `verification-before-completion`。

委派指示模板：

```text
你是[角色]，請嚴格遵循 [skill-name]。
目標：[要達成的結果]
限制：[不能做什麼 / 必須先做什麼]
輸出：[預期格式；長內容寫到 docs/... 並附路徑]
```

## 5.1) 委派方式（host-agnostic）

角色調度不經由任何 shell 包裝或 `opencode run` 子進程：

- **優先：宿主原生 subagent/task**（如 Claude Code 的 Task、opencode 的 agent）。為角色開一個子代理，交付「角色卡 + 目標 skill + 任務 + 必要上下文」，藉此取得隔離與無狀態。
- **次選：in-context 角色切換**。宿主無子代理機制時，於同一對話讀取角色卡、以該角色視角完成該段，再切回 orchestrator 整合。

共通：委派前載入角色卡與 skill；多步驟任務先回報「路由角色 + 技能」；簡單任務直接做。完整協議見 `skills/tao-of-opencode/SKILL.md` 的〈調度方式 (Delegation)〉。

## 6) 團隊落地規範（建議）

- PR 描述中新增欄位：`Routing: <role> + <skill>`。
- 每個修復 PR 至少標記一次 `systematic-debugging` 或 `test-driven-development`。
- 合併前確認：是否已做 `verification-before-completion`。

## 7) 版本追溯

- 本地 superpowers 來源追溯：`skills/tao-of-opencode/references/superpowers/SOURCE.md`
- 技能對照表：`docs/celestial_skill_mapping.md`
- 技能分析：`docs/superpowers_skills_analysis.md`

## 8) 升級同步（單一 Skill 內化版）

- 同步腳本：`skills/tao-of-opencode/scripts/sync-superpowers.sh`
- 乾跑檢查：
  `skills/tao-of-opencode/scripts/sync-superpowers.sh <commit-or-tag> --dry-run`
- 正式同步：
  `skills/tao-of-opencode/scripts/sync-superpowers.sh <commit-or-tag>`
- 同步完成後，會更新 `skills/tao-of-opencode/references/superpowers/SOURCE.md` 並保留舊版備份目錄。
