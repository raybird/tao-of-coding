# Agent Message Contract (v1.0)

每個 agent 呼叫都**必須**回傳一段符合 [`agent-message.schema.json`](agent-message.schema.json) 的 JSON。
這是讓 orchestrator 能夠 fan-out / 合流 / 重建 run state 的基礎，沒有它就沒有真正的 multi-agent。

## 為什麼要 JSON

純 markdown 輸出無法被機械解析：orchestrator 不知道 agent 有沒有成功、產出了哪些檔、建議下一步做什麼。
JSON envelope 把這些訊號標準化，markdown / 程式碼 / 報告等長內容寫到 `outputs.artifacts` 指向的檔案，**不要塞進 JSON 字串裡**。

## 強制欄位

- `schema_version`：固定 `"1.0"`。
- `task_id`：本次呼叫唯一 ID。慣例 `<role>-<step>-<slug>`，例：`explorer-01-scan-src`。
- `role` / `skill`：必須對應已定義的角色與技能。
- `status`：見 schema enum；`partial` 表示產出可用但未完成，`blocked` 表示需要外部輸入。
- `outputs.summary`：≤ 2000 字的人類摘要。**長內容寫進 artifact 檔，不要塞 JSON。**

## 選用但建議填的欄位

- `outputs.artifacts[]`：產出檔案的路徑（相對 run workspace）+ kind 分類。
- `outputs.findings[]`：結構化發現（bug、風險、待辦），方便 reducer agent 合併去重。
- `outputs.next_actions[]`：建議的後續呼叫。**只是建議**，orchestrator 有最終決定權。
  - `depends_on` 為空 → 該 action 可與同層其他 action 並行。
- `confidence`：0–1，給 orchestrator 判斷是否要叫第二個 agent 交叉驗證。

## 輸出格式（給 LLM 的硬規則）

agent 的最終回覆**只能**是一段 JSON，包在 ` ```json ` … ` ``` ` 的 fenced code block 內，前後不得有任何文字（思考過程寫到 artifact 檔）。dispatcher 會用以下指令抽出：

```bash
awk '/^```json$/{flag=1; next} /^```$/{flag=0} flag' <agent-output>
```

## 範例：Explorer 掃描完一個目錄

```json
{
  "schema_version": "1.0",
  "task_id": "explorer-01-scan-skills",
  "request_id": "req-20260527-001",
  "role": "explorer",
  "skill": "executing-plans",
  "status": "ok",
  "confidence": 0.9,
  "inputs": {
    "prompt": "掃描 skills/tao-of-opencode 並列出核心模組與依賴",
    "artifacts": []
  },
  "outputs": {
    "summary": "skills/tao-of-opencode 由 SKILL.md 主協議、5 個角色指南、8 個 superpowers 技能與 5 支 bash 腳本組成。最大依賴是 opencode CLI 與 jq。",
    "artifacts": [
      {
        "path": ".tao/runs/req-20260527-001/artifacts/explorer-01-scan.md",
        "kind": "report",
        "description": "完整掃描樹與依賴圖（mermaid）"
      }
    ],
    "findings": [
      {
        "id": "f-001",
        "severity": "medium",
        "message": "skill-routing.conf 與 SKILL.md 技能清單可能不同步",
        "location": "skills/tao-of-opencode/references/skill-routing.conf"
      }
    ],
    "next_actions": [
      {
        "role": "oracle",
        "skill": "brainstorming",
        "prompt": "根據 f-001，提出讓 routing 與 SKILL.md 自動同步的方案",
        "depends_on": [],
        "parallelizable": true
      }
    ]
  },
  "metrics": {
    "model": "opencode/deepseek-v4-flash-free",
    "started_at": "2026-05-27T19:40:00+08:00",
    "finished_at": "2026-05-27T19:40:12+08:00"
  }
}
```

## 驗證

```bash
bash skills/tao-of-opencode/scripts/validate-agent-message.sh <agent-output.json>
```

驗證失敗 → orchestrator 將該次呼叫標記為 `status=malformed`，最多重試 1 次後跳過。

## 升級規則

- `schema_version` 採 SemVer。
- 加新選用欄位 → minor（1.1）。
- 改強制欄位或語意 → major（2.0），舊版 agent 需另跑 adapter。
