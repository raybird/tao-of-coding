# Skill Dispatcher Contract

本文件定義「自動 Skill 觸發」的最小執行契約，目標是：

1. 子 Skill 明確知道自己的身份（角色與當前 Skill）
2. 不重載 `skills/tao-of-coding/SKILL.md`
3. 防止 Skill 觸發遞迴

## 1) 執行模式

- **Root 模式**：只在最外層請求啟動，載入一次 `skills/tao-of-coding/SKILL.md`
- **Delegated 模式**：由 Skill 觸發子 Skill 時使用；只載入「角色指南 + 目標 Skill」

## 2) Runtime Header（每次調用必帶）

以下欄位是 dispatcher 傳給模型的 runtime context，不屬於 Agent Skills frontmatter。

```yaml
execution_mode: delegated            # root | delegated
identity:
  role: fixer                        # explorer | oracle | librarian | fixer | designer
  current_skill: systematic-debugging
  origin_skill: executing-plans
  root_loaded: true
policy:
  forbid_root_reload: true
  max_depth: 3
  allow_reentry: false
trace:
  request_id: req-2026-02-15-001
  depth: 2
  skill_stack:
    - writing-plans
    - executing-plans
    - systematic-debugging
  visited_skills:
    - writing-plans
    - executing-plans
```

## 3) 邊類型 (Edge Type)

Skill 參照需先分類，不能看見 skill 名稱就直接觸發。

- `requires_now`：當下必須執行（例如明確的 REQUIRED SUB-SKILL）
- `requires_later`：流程下一階段才執行（例如「完成後再做」）
- `reference_only`：僅參考，不自動觸發

建議預設：**未標註一律視為 `reference_only`**。

## 4) 防遞迴規則

執行前依序檢查：

1. `root_loaded == true` 且 `forbid_root_reload == true` 時，禁止再次載入 root skill。
2. 若 `target_skill` 已在 `visited_skills` 且 `allow_reentry == false`，拒絕觸發。
3. 若 `depth + 1 > max_depth`，拒絕觸發。
4. `edge_type != requires_now` 時，不自動觸發。

## 5) Dispatcher Pseudocode

```text
dispatch(request):
  if request.identity.root_loaded == false:
    load(tao_root_skill)
    request.identity.root_loaded = true

  next_edges = resolve_skill_edges(request.identity.current_skill)

  for edge in next_edges:
    if edge.type != requires_now:
      continue
    if request.policy.forbid_root_reload and edge.target == "tao-of-coding":
      continue
    if !request.policy.allow_reentry and edge.target in request.trace.visited_skills:
      continue
    if request.trace.depth + 1 > request.policy.max_depth:
      continue

    child = clone(request)
    child.execution_mode = "delegated"
    child.identity.origin_skill = request.identity.current_skill
    child.identity.current_skill = edge.target
    child.trace.depth += 1
    child.trace.skill_stack.append(edge.target)
    child.trace.visited_skills.add(edge.target)

    load(role_guide_for(child.identity.role))
    load(skill_file(edge.target))
    run(child)
```

## 6) 錯誤策略

- `E_ROOT_RELOAD_BLOCKED`：delegated 模式試圖重載 root
- `E_SKILL_REENTRY_BLOCKED`：命中 visited/reentry 規則
- `E_DEPTH_LIMIT`：超過 `max_depth`
- `E_EDGE_NOT_EXECUTABLE`：參照類 edge 嘗試自動執行

回傳錯誤時，應附：`request_id`, `current_skill`, `target_skill`, `depth`, `skill_stack`。

## 7) 與 Agent Skills Spec 的關係

- 本契約是 **runtime orchestration policy**，不改動 Agent Skills frontmatter 規格。
- `SKILL.md` 仍維持標準欄位（`name`, `description`, 可選 `metadata` 等）。
- 身份鎖定與遞迴防護資訊應由 dispatcher 注入，不建議塞入 frontmatter 自訂頂層欄位。

## 8) 參考實作

- 入口腳本：`skills/tao-of-coding/scripts/skill-dispatch.sh`
- 建議所有自動 skill 觸發都經過此入口，避免子流程直接呼叫模型 CLI。
- 對話自動路由：`skills/tao-of-coding/scripts/orchestrate-skill.sh`
- 路由規則檔：`skills/tao-of-coding/references/skill-routing.yaml`

`orchestrate-skill.sh` 會先依對話內容選擇 role+skill，再轉呼叫 `skill-dispatch.sh`。
調整自動觸發行為時，優先修改 `skill-routing.yaml`，可避免直接改腳本邏輯。

範例：

```bash
skills/tao-of-coding/scripts/skill-dispatch.sh \
  --role fixer \
  --skill systematic-debugging \
  --execution-mode delegated \
  --depth 1 \
  --parent-skill executing-plans \
  --edge-type requires_now \
  --visited-skills writing-plans,executing-plans \
  --prompt "請依技能流程追查根因，先不要提出修復" \
  --runner-cmd 'gemini --model "gemini-3-flash-preview" -p "$(cat)"'
```
