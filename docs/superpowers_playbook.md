# Tao x Superpowers 操作指引

本文件提供團隊可直接複用的操作方式，說明如何在 Tao 流程中呼叫 `skills/superpowers/*`。

## 1) 何時用 Tao、何時用 Superpowers

- Tao (`skills/tao-of-coding/SKILL.md`) 是「角色編排與路由層」：先判斷該請哪位神祇。
- Superpowers (`skills/superpowers/*`) 是「執行技能層」：進到具體流程（TDD、debug、review...）。
- 實務上採兩段式：先用 Tao 定位任務，再把對應的 Superpowers skill 當成執行規格。

## 2) 已導入可用技能 (Phase 1)

- `skills/superpowers/brainstorming/SKILL.md`
- `skills/superpowers/writing-plans/SKILL.md`
- `skills/superpowers/executing-plans/SKILL.md`
- `skills/superpowers/test-driven-development/SKILL.md`
- `skills/superpowers/systematic-debugging/SKILL.md`
- `skills/superpowers/verification-before-completion/SKILL.md`
- `skills/superpowers/requesting-code-review/SKILL.md`
- `skills/superpowers/receiving-code-review/SKILL.md`

對照與分工請看 `docs/celestial_skill_mapping.md`。

## 3) 標準呼叫流程 (Team SOP)

### Step A: 先決定路由

參考 `skills/tao-of-coding/SKILL.md` 的「技能路由表」，判斷本次任務主責神祇與優先技能。

### Step B: 載入角色天書 + 技能天書

建議把「角色天書」與「superpowers skill」一起送進模型，讓角色與流程同時生效。

```bash
# 範例：除錯任務（魯班 + systematic-debugging）
cat skills/tao-of-coding/references/fixer.md \
    skills/superpowers/systematic-debugging/SKILL.md \
| gemini --model "gemini-3-flash-preview" \
  -p "魯班祖師，請依 systematic-debugging 四階段流程追查這個測試失敗的根因，先不要給修補方案。"
```

### Step C: 若技能有 reference，按需追加

例如 `systematic-debugging` 可依情境再附：
- `skills/superpowers/systematic-debugging/root-cause-tracing.md`
- `skills/superpowers/systematic-debugging/defense-in-depth.md`
- `skills/superpowers/systematic-debugging/condition-based-waiting.md`

## 4) 常見任務範本（可直接貼）

### A. 需求發想/方案比較

```bash
cat skills/tao-of-coding/references/oracle.md \
    skills/superpowers/brainstorming/SKILL.md \
| gemini --model "gemini-3-pro-preview" \
  -p "太上老君在上，請先用 brainstorming 流程澄清需求，再提出 2-3 種方案與取捨。"
```

### B. 先寫計畫，再執行

```bash
# 先產生計畫
cat skills/tao-of-coding/references/oracle.md \
    skills/superpowers/writing-plans/SKILL.md \
| gemini --model "gemini-3-pro-preview" \
  -p "請為此需求輸出可執行的 implementation plan，存放到 docs/plans。"

# 再按計畫執行
cat skills/tao-of-coding/references/explorer.md \
    skills/superpowers/executing-plans/SKILL.md \
| gemini --model "gemini-3-flash-preview" \
  -p "請讀取 docs/plans/XXX.md，按 executing-plans 方式分批執行並在檢查點回報。"
```

### C. 功能或 Bug 修復（TDD）

```bash
cat skills/tao-of-coding/references/fixer.md \
    skills/superpowers/test-driven-development/SKILL.md \
| gemini --model "gemini-3-flash-preview" \
  -p "請用 TDD（RED-GREEN-REFACTOR）修復這個 bug，先寫會失敗的測試再實作。"
```

### D. 送審與回覆審查

```bash
# 請求 code review
cat skills/tao-of-coding/references/librarian.md \
    skills/superpowers/requesting-code-review/SKILL.md \
| gemini --model "gemini-3-flash-preview" \
  -p "請依 requesting-code-review 流程整理本次變更的 review 請求。"

# 接收 code review
cat skills/tao-of-coding/references/fixer.md \
    skills/superpowers/receiving-code-review/SKILL.md \
| gemini --model "gemini-3-flash-preview" \
  -p "請依 receiving-code-review 規範處理 reviewer 意見，先釐清再實作。"
```

## 5) 提示詞寫法建議

- 明確指定「角色 + skill + 產出格式」。
- 對於 debug 類任務，務必加上「先根因、後修復」。
- 對於完成宣告前，務必補 `verification-before-completion`。

建議模板：

```text
你是[角色]，請嚴格遵循 [skill-name]。
目標：[你要達成的結果]
限制：[不能做什麼 / 必須先做什麼]
輸出：[預期格式，例如步驟、diff、checklist]
```

## 6) 團隊落地規範（建議）

- PR 描述中新增欄位：`Routing: <role> + <skill>`。
- 每個修復 PR 至少標記一次 `systematic-debugging` 或 `test-driven-development`。
- 合併前確認：是否已做 `verification-before-completion`。

## 7) 版本追溯

- 本地 superpowers 來源追溯：`skills/superpowers/SOURCE.md`
- 技能對照表：`docs/celestial_skill_mapping.md`
- 技能分析：`docs/superpowers_skills_analysis.md`
