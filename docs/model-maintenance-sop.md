# 模型維護 SOP

本文件說明如何維護 NVIDIA NIM 模型清單、執行能力評估、以及更新角色分配。

---

## 觸發時機

以下任一情況發生時，執行本 SOP：

| 情況 | 建議動作 |
| :--- | :--- |
| NVIDIA NIM 有新模型上線 | 全流程（Step 1 → 5） |
| 某角色模型出現 timeout / 回應異常 | 從 Step 2 開始 |
| 季度定期保養 | 全流程 |

---

## 相關檔案

| 檔案 | 用途 |
| :--- | :--- |
| `skills/tao-of-opencode/references/model-registry.conf` | 模型清單，含梯隊、EOL 記錄、備註 |
| `skills/tao-of-opencode/scripts/refresh-model-registry.sh` | 比對平台清單與 registry 的差異 |
| `skills/tao-of-opencode/scripts/assess-models.sh` | 三維能力評估，輸出 Markdown 報告 |
| `docs/model-assessment.md` | 最新一次評估報告（由腳本自動覆寫） |
| `skills/tao-of-opencode/SKILL.md` | 角色預設 / 備援模型表格 |
| `skills/tao-of-opencode/references/*.md` | 各角色指南的 `model:` frontmatter |

---

## Step 1：取得平台最新清單

### 免費模型來源

本專案追蹤兩個來源的免費模型，可手動查看：

```bash
# 來源一：NVIDIA NIM 免費模型
opencode models nvidia

# 來源二：OpenCode 平台自有免費模型
opencode models opencode
```

`opencode models opencode` 目前提供：
- `opencode/big-pickle` — OpenCode 旗艦模型
- `opencode/deepseek-v4-flash-free` — DeepSeek V4 Flash 免費版
- `opencode/nemotron-3-super-free` — Nemotron Super 免費版

執行 refresh 腳本會自動合併兩個來源，對比 registry：

```bash
bash skills/tao-of-opencode/scripts/refresh-model-registry.sh
```

**輸出解讀：**

```
🆕 新出現的模型（共 N 個，尚未登記）：
   + nvidia/xxx/yyy

⚠️  從 opencode models 消失的模型（共 N 個，可能已 EOL）：
   - [A] nvidia/xxx/yyy
```

- **🆕 新出現**：平台新增，尚未在 registry 中登記
- **⚠️ 消失**：上次還在，現在不見了，很可能已 EOL

---

## Step 2：更新 model-registry.conf

### 2a. 消失的模型 → 標記 EOL

找到 `model-registry.conf` 中對應的行，加上 `#` 註解並標注日期：

```diff
- nvidia/xxx/yyy|A|原本的備註
+ # nvidia/xxx/yyy|EOL|YYYY-MM-DD 停用
```

### 2b. 新出現的模型 → 加入待評估

可手動加，或用 `--add-new` 自動附加（tier 設為 `?`）：

```bash
bash skills/tao-of-opencode/scripts/refresh-model-registry.sh --add-new
```

自動附加後，`model-registry.conf` 尾端會多出：

```ini
# ── 待分級（YYYY-MM-DD refresh-model-registry.sh 自動加入）──
nvidia/xxx/yyy|?|待評估
```

接著手動判斷這些新模型屬於哪個梯隊，填入 `S / A / B / C`，或若確定無用則直接刪除。

**梯隊判斷依據：**

| 梯隊 | 適用條件 |
| :---: | :--- |
| S | 旗艦模型、業界排名前段、適合最複雜推理任務 |
| A | 效能強勁、均衡性能、可信賴的生產用途 |
| B | 特定場景表現佳（中文、輕量、視覺）、或效能略遜 A |
| C | 輕量 / 小型 / 特殊用途，不適合複雜任務 |

---

## 附錄 A：評估提示詞全文

`assess-models.sh` 使用以下三道固定題目。若需更新測試題，請同步修改腳本與本節。

---

### T1 — 指令遵循

**完整 prompt：**
```
Reply with ONLY valid JSON, no extra text: {"answer":"yes or no","reason":"one sentence"}
Q: If all cats are animals and all animals need food, do cats need food?
```

**預期正確回應：**
```json
{"answer":"yes","reason":"<任意一句邏輯說明>"}
```

**評分關鍵字：** `yes`

**考核重點：**
1. 是否嚴格輸出純 JSON（不加 markdown fence、不加解釋文字）
2. 邏輯答案是否正確（三段論推導）
3. 結構是否符合指定 schema

**常見失敗模式：**
- 加了 ` ```json ` 包裝 → 格式不嚴謹（輕微扣分）
- 回應先「判斷 skill 是否適用」→ 訓練資料污染，行為不可信
- 答 `no` → 邏輯錯誤

---

### T2 — 程式碼生成

**完整 prompt：**
```
Write ONLY a Python function, no markdown fences, no explanation:
def first_duplicate(lst: list):
    """Return the first item appearing more than once, or None."""
```

**預期正確回應（範例）：**
```python
def first_duplicate(lst: list):
    """Return the first item appearing more than once, or None."""
    seen = set()
    for item in lst:
        if item in seen:
            return item
        seen.add(item)
    return None
```

**評分關鍵字：** `def first_duplicate`

**考核重點：**
1. 是否直接輸出函式本體（不加 markdown、不加解釋）
2. 邏輯是否正確（第一個重複、不是所有重複）
3. 有無語法錯誤

**常見失敗模式：**
- 回傳 JSON function schema → 過度 agentic，誤解為工具呼叫
- 加了 ` ```python ` 包裝 → 格式不嚴謹
- 回應 "not implemented" → 完全不可用

---

### T3 — 邏輯推理

**完整 prompt：**
```
John has twice as many apples as Mary. Mary has 6 apples. John gives 4 apples to Mary. How many apples does John have now? Reply with ONLY a number.
```

**推導過程：**
1. Mary 有 6 顆
2. John 有 Mary 的兩倍 = 12 顆
3. John 給出 4 顆後剩 12 - 4 = **8**

**預期正確回應：** `8`

**評分關鍵字：** `8`

**考核重點：**
1. 三步驟推導是否正確
2. 是否只回傳數字（不加解釋）

**為何選擇算術而非數列題：**
前一版測試使用「數列第 4 項」，但「第 4 項」在數學（1-indexed）和程式（0-indexed）語境下有歧義，導致 Qwen 系列模型全部答 `-1`（0-indexed 解讀），難以判斷是真的推理錯誤還是語境差異。現版算術題無此歧義。

---

## 附錄 B：梯隊分層決策規則

### 分層輸入來源

分層需同時參考兩個資訊來源：

| 來源 | 取得方式 | 說明 |
| :--- | :--- | :--- |
| **外部 benchmark** | web search（見下方查詢語句） | 提供先驗排名，作為初始梯隊假設 |
| **本地三維測試** | `assess-models.sh` | 實際驗證行為，作為最終依據 |

**外部 benchmark 建議查詢語句（每次維護前執行一次）：**
```
<model-family-name> benchmark 2026 coding reasoning MMLU HumanEval SWE-bench
```
例如：`qwen3.5 benchmark 2026 coding reasoning`

> **opencode/ 模型補充說明：**
> `opencode/big-pickle`、`opencode/deepseek-v4-flash-free`、`opencode/nemotron-3-super-free`
> 為 OpenCode 平台封裝的免費模型，底層對應 deepseek / nemotron 系列。
> 查詢 benchmark 時以底層模型名稱搜尋（如 `deepseek v4 flash benchmark 2026`）。

---

### 梯隊評分矩陣

| 測試結果 | 外部 benchmark 排名 | 建議梯隊 |
| :--- | :--- | :---: |
| 3/3 全通過，T3 答對 | 業界前段（top quartile） | **S** |
| 3/3 全通過，T3 答對 | 中等或未知 | **A** |
| 3/3 全通過，T3 有輕微偏差（如數列 0-index） | 任意 | **A** |
| 3/3 全通過，但有格式問題（加 markdown、解釋冗長） | 任意 | **B** |
| 2/3 通過，T3 明顯答錯 | 任意 | **B** |
| 1/3 或以下 | 任意 | **C** |
| ⏱TIMEOUT 或 ⚠️API_ERR | — | 不登記或標記 BAD |
| ❌EOL | — | 標記 EOL |

**補充原則：**
- 若模型參數量 < 10B（估計），上限為 **B**，除非有特殊優化
- 若模型為 safety / content-moderation 專用途，歸入 **C** 並標注用途
- 若模型為 vision-only（無文字對話），排除於 registry 之外

---

### AI Agent 分層提示詞

當需要讓 AI agent 自動判斷梯隊時，使用以下 prompt（可直接傳給任何角色執行）：

````
你是一個 LLM 能力分類專家。請根據以下資訊，判斷模型應歸入哪個梯隊，並輸出 JSON。

## 輸入資訊

模型 ID：{model_id}
參數規模（若已知）：{params_info}

### 三維測試結果
- T1 指令遵循：{t1_result}（預期包含 "yes" 的 JSON）
- T2 程式碼生成：{t2_result}（預期包含 "def first_duplicate"）
- T3 邏輯推理：{t3_result}（預期回答 "8"）

### 外部 benchmark 資訊（若有）
{benchmark_info}

## 梯隊定義

- **S**：3/3 通過且推理正確，業界前段排名，適合最複雜推理/架構任務
- **A**：3/3 通過（允許輕微格式問題），生產環境可信賴，均衡性能
- **B**：有回應但存在品質疑慮（格式偏差、推理輕微錯誤、特定場景才佳）
- **C**：小型/輕量/特殊用途，不適合複雜任務
- **EOL**：模型回傳 HTTP 410 或「end of life」錯誤
- **BAD**：有回應但實際為 API 錯誤（Bad Request、context length exceeded 等）

## 輸出格式（只輸出此 JSON，不加任何說明）

```json
{
  "tier": "S|A|B|C|EOL|BAD",
  "score": "N/3",
  "reason": "一句說明分層理由",
  "notes": "適合填入 model-registry.conf 的備註（20 字以內）",
  "role_fit": ["適合擔任的角色，如 Oracle / Fixer / Librarian / Explorer / Designer"]
}
```
````

**使用範例（帶入實際測試結果）：**

```
模型 ID：nvidia/openai/gpt-oss-120b
參數規模：120B
T1：✅ {"answer":"yes","reason":"Cats are animals and all animals need food."}
T2：✅ def first_duplicate(lst: list): ...
T3：✅ 0（舊版題目）/ ✅ 8（新版題目）
benchmark：業界 B 梯隊，通用能力均衡
```

→ 預期輸出：`{"tier":"A","score":"3/3","reason":"三維全通過，推理正確，指令嚴謹","notes":"推理最準確，指令嚴謹","role_fit":["Oracle","Fixer"]}`

---

## Step 3：執行能力評估

### 只測新模型（快速）

```bash
# 先確認哪些模型 tier 是 ?
grep '|?|' skills/tao-of-opencode/references/model-registry.conf

# 在 assess-models.sh 中目前需手動臨時改 tier，或直接用 --model 逐一測試
bash skills/tao-of-opencode/scripts/assess-models.sh \
  --model nvidia/xxx/yyy \
  --output /tmp/new-model-test.md
```

### 全量評估（季度保養或大批異動時）

```bash
bash skills/tao-of-opencode/scripts/assess-models.sh
```

預估時間：約 25–40 分鐘（依 timeout 次數而定）。結果寫入 `docs/model-assessment.md`。

### 只評估指定梯隊

```bash
# 只跑 S、A 梯隊（主力模型）
bash skills/tao-of-opencode/scripts/assess-models.sh --tier S,A
```

---

## Step 4：解讀評估報告

開啟 `docs/model-assessment.md`，重點看以下欄位：

| 符號 | 意義 |
| :---: | :--- |
| ✅ | 回應正確，包含預期內容 |
| ⚠️ | 有回應但答案偏差或格式不符 |
| ❌EOL | 模型已停用（HTTP 410） |
| ⏱TIMEOUT | 30 秒內無回應 |
| ⚠️API_ERR | 回應為 API 錯誤（假陽性，實際不可用） |

**三個測試維度：**

| 維度 | 題目重點 | 關鍵判斷 |
| :--- | :--- | :--- |
| T1 指令遵循 | 要求嚴格 JSON 格式回答邏輯題 | 有無按格式、答案是否正確 |
| T2 程式碼生成 | 實作 `first_duplicate(lst)` | 有無輸出合法 Python 函式 |
| T3 邏輯推理 | 多步驟算術（答案應為 8） | 是否答對，答案是否只有數字 |

**常見品質問題（注意排除）：**

- 回應為 `Bad Request` / `context length exceeded` → 假陽性，不可用
- T2 回傳 JSON function schema 而非程式碼 → 過度 agentic
- T1 開始「判斷 skill 適用性」→ 行為受訓練資料污染
- T3 以 bash 指令格式回應 → 推理混亂

---

## Step 5：更新角色分配

若評估後有更合適的模型，依序更新以下位置（四個地方必須同步）：

### 5a. 角色指南 frontmatter

```bash
# 範例：更新 Oracle 角色
vim skills/tao-of-opencode/references/oracle.md
```

```yaml
---
role: Oracle (Oracle)
model: nvidia/<new-model-id>   # ← 修改這行
---
```

### 5b. SKILL.md 模型表格

```bash
vim skills/tao-of-opencode/SKILL.md
```

找到角色分配表，更新預設模型與備援模型：

```markdown
| Oracle | `nvidia/<new-model>` | `nvidia/<fallback>` | 說明文字 |
```

同時更新文末的「品質優先推薦」說明文字。

### 5c. README.md

更新角色目錄表格與 CLI 範例指令中的模型名稱。

### 5d. CLAUDE.md

更新角色分工表格中的預設模型欄位。

---

## 完整流程示意

```
opencode models
      ↓
refresh-model-registry.sh        ← 取得 diff
      ↓
手動更新 model-registry.conf     ← EOL 標記 / 新模型設 tier
      ↓
assess-models.sh                 ← 能力測試（輸出 model-assessment.md）
      ↓
解讀報告，確認有無假陽性 / 品質問題
      ↓
更新 oracle.md / designer.md 等角色指南
更新 SKILL.md / README.md / CLAUDE.md
```

---

## 快速參考指令

```bash
# 1. 查差異
bash skills/tao-of-opencode/scripts/refresh-model-registry.sh

# 2. 自動補入新模型（tier=?）
bash skills/tao-of-opencode/scripts/refresh-model-registry.sh --add-new

# 3. 全量評估
bash skills/tao-of-opencode/scripts/assess-models.sh

# 4. 只測 S/A 梯隊
bash skills/tao-of-opencode/scripts/assess-models.sh --tier S,A

# 5. 測單一模型
bash skills/tao-of-opencode/scripts/assess-models.sh --model nvidia/xxx/yyy

# 6. 預覽將測試的模型（不呼叫 API）
bash skills/tao-of-opencode/scripts/assess-models.sh --dry-run
```
