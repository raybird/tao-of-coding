# Skill Dispatcher Contract

本文件定義「自動 Skill 觸發」的最小執行契約，目標是：

1. 子 Skill 明確知道自己的身份（角色與當前 Skill）
2. 不重載 `skills/tao-of-opencode/SKILL.md`
3. 防止 Skill 觸發遞迴

## 1) 執行模式

- **Root 模式**：只在最外層請求啟動，載入一次 `skills/tao-of-opencode/SKILL.md`
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
  max_depth: 1
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
    if request.policy.forbid_root_reload and edge.target == "tao-of-opencode":
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

腳本層級（由簡至複）：

| 腳本 | 職掌 |
| :--- | :--- |
| `skill-dispatch.sh` | 單一 agent 委派；組裝 prompt、重試、workspace 隔離 |
| `orchestrate-skill.sh` | 依 prompt 內容自動路由 role+skill，再呼叫 skill-dispatch |
| `parallel-dispatch.sh` | 多 agent 並行 fan-out，輸出 summary JSON |
| `reduce-envelopes.sh` | 讀取多個 envelope，呼叫 Oracle 合流為單一行動清單 |
| `loop-dispatch.sh` | 串接 parallel + reduce 成迴圈，支援 depends_on wave 排序與 fingerprint 擺盪偵測 |
| `validate-agent-message.sh` | 驗證 envelope 是否符合 Agent Message v1.0 schema |
| `run-gc.sh` | 清理 `.tao/runs/` 過期執行記錄與 git worktree |

建議所有自動 skill 觸發都經過 `skill-dispatch.sh`，避免子流程直接呼叫模型 CLI。
調整自動路由行為時，優先修改 `references/skill-routing.conf`，可避免直接改腳本邏輯。

單一 agent 範例：

```bash
skills/tao-of-opencode/scripts/skill-dispatch.sh \
  --role fixer \
  --skill systematic-debugging \
  --execution-mode delegated \
  --depth 1 \
  --parent-skill executing-plans \
  --edge-type requires_now \
  --visited-skills writing-plans,executing-plans \
  --prompt "請依技能流程追查根因，先不要提出修復" \
  --runner-cmd 'opencode run --model "nvidia/deepseek-ai/deepseek-v4-pro"'
```

多 agent 迴圈範例：

```bash
skills/tao-of-opencode/scripts/loop-dispatch.sh \
  --tasks-file tasks.json \
  --runner-cmd "opencode run --model opencode/deepseek-v4-flash-free" \
  --reduce-runner-cmd "opencode run --model nvidia/openai/gpt-oss-120b" \
  --max-iterations 3 --parallelism 3 --isolate-workspace
```
