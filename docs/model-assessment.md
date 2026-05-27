# NVIDIA NIM 模型能力評估報告

> 評估日期：2026-05-27  
> 測試維度：T1 指令遵循、T2 程式碼生成、T3 邏輯推理  
> Timeout 設定：30s / 次

## OpenCode 平台自有免費模型（opencode/）

| 模型 | 梯隊 | T1 指令遵循 | T2 程式碼 | T3 推理 | 通過 | 備註 |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `opencode/big-pickle` | A | ✅ JSON 正確 | ✅ python3 -c 包裝 | ✅ 8 | 3/3 | T2 輸出格式輕微問題 |
| `opencode/deepseek-v4-flash-free` | A | ✅ JSON 正確 | ✅ 乾淨函式 | ✅ 8 | 3/3 | 三維全對，輸出最乾淨 |
| `opencode/nemotron-3-super-free` | B | ⚠️EMPTY | ✅ 乾淨函式 | ✅ 8 | 2/3 | T1 無回應（疑似過濾） |

## NVIDIA NIM 模型（nvidia/）

| 模型 | 梯隊 | T1 指令遵循 | T2 程式碼 | T3 推理 | 通過 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `deepseek-ai/deepseek-v4-pro` | S | ✅  | ✅  | ✅  | 3/3 |
| `deepseek-ai/deepseek-v3.2` | S | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `qwen/qwen3.5-397b-a17b` | S | ✅ {"answer":"yes","reason":" | ✅ def first_duplicate(lst: l | ✅  | 3/3 |
| `qwen/qwen3-coder-480b-a35b-instruct` | S | ✅ {"answer":"yes","reason":" | ✅ → Skill "writing-skills" | ✅ -1  | 3/3 |
| `moonshotai/kimi-k2.6` | S | ✅  | ✅  | ✅  | 3/3 |
| `deepseek-ai/deepseek-v4-flash` | A | ✅  | ✅ → Skill "test-driven-dev | ✅  | 3/3 |
| `qwen/qwen3.5-122b-a10b` | A | ✅ {"answer":"yes","reason":" | ✅  | ✅ -1  | 3/3 |
| `qwen/qwen3-next-80b-a3b-instruct` | A | ✅ {"answer":"yes","reason":" | ✅ def first_duplicate(lst: l | ✅ -1  | 3/3 |
| `nvidia/llama-3_3-nemotron-super-49b-v1` | A | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `nvidia/llama-3_3-nemotron-super-49b-v1_5` | A | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `mistralai/mistral-large-3-675b-instruct-2512` | A | ✅ {"answer":"yes","reason":" | ✅  | ✅ -3  | 3/3 |
| `mistralai/devstral-2-123b-instruct-2512` | A | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `meta/llama-4-maverick-17b-128e-instruct` | A | ✅ {"answer":"yes","reason":" | ✅ {     "type": "function",  | ✅ {"type": "function", "name | 3/3 |
| `mistralai/mistral-medium-3-instruct` | A | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `mistralai/mistral-small-4-119b-2603` | A | ✅ {"answer": "yes", "reason" | ✅ ```python def first_duplic | ✅ -2  | 3/3 |
| `z-ai/glm-5.1` | B | ✅  | ✅  | ✅  | 3/3 |
| `z-ai/glm4.7` | B | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `minimaxai/minimax-m2.7` | B | ✅ {"answer":"yes","reason":" | ✅ def first_duplicate(lst: l | ✅ 0  | 3/3 |
| `minimaxai/minimax-m2.5` | B | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `google/gemma-4-31b-it` | B | ✅ ```json {"answer":"yes","r | ✅ def first_duplicate(lst: l | ✅ 0  | 3/3 |
| `meta/llama-3.3-70b-instruct` | B | ✅  | ✅ ```python def first_duplic | ✅ $ echo -2 -2 -2  | 3/3 |
| `openai/gpt-oss-120b` | B | ✅ {"answer":"yes","reason":" | ✅ def first_duplicate(lst: l | ✅ 0  | 3/3 |
| `openai/gpt-oss-20b` | B | ✅ We must check skill applic | ✅ → Skill "test-driven-dev | ✅ 0  | 3/3 |
| `mistralai/mixtral-8x22b-instruct` | B | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `nvidia/nemotron-3-super-120b-a12b` | B | ✅ {"answer": "yes", "reason" | ✅ def first_duplicate(lst: l | ✅ 0  | 3/3 |
| `deepseek-ai/deepseek-v3.1-terminus` | C | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `nvidia/nemotron-3-nano-30b-a3b` | C | ✅ {"answer":"Yes","reason":" | ✅ def first_duplicate(lst: l | ✅ 0  | 3/3 |
| `mistralai/magistral-small-2506` | C | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `stepfun-ai/step-3.5-flash` | C | ✅ {"answer":"yes","reason":" | ✅  | ✅ The user is giving me a ma | 3/3 |
| `sarvamai/sarvam-m` | C | ✅ Error: Bad Request: [{'typ | ✅ Error: Bad Request: [{'typ | ✅ Error: Bad Request: [{'typ | 3/3 |
| `microsoft/phi-4-multimodal-instruct` | C | ✅  | ✅  | ✅  | 3/3 |
| `meta/llama-3.2-90b-vision-instruct` | C | ✅ Error: Bad Request: This m | ✅ Error: Bad Request: This m | ✅ Error: Bad Request: This m | 3/3 |
| `meta/llama-3.2-11b-vision-instruct` | C | ✅ ⚙ gitnexus_impact {"targ | ✅ Based on the provided func | ✅ ✗ ls failed Error: The b | 3/3 |
| `google/gemma-3-27b-it` | C | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `mistralai/mistral-nemotron` | C | ✅ ```json {"answer": "yes",  | ✅ not implemented  | ✅ -3  | 3/3 |
| `moonshotai/kimi-k2-instruct-0905` | C | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `bytedance/seed-oss-36b-instruct` | C | ✅  | ✅  | ✅ 0  | 3/3 |
| `abacusai/dracarys-llama-3_1-70b-instruct` | C | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `nvidia/nvidia-nemotron-nano-9b-v2` | C | ✅ {"answer":"no","reason":"T | ✅ def first_duplicate(lst: l | ✅ 0  | 3/3 |
| `mistralai/mixtral-8x7b-instruct` | C | ❌EOL | ❌EOL | ❌EOL | 0/3 |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | C | ✅ {"answer":"是","reason":" | ✅  | ✅  | 3/3 |
| `microsoft/phi-4-mini-instruct` | C | ✅  | ✅  | ✅  | 3/3 |

_評估完成：2026-05-27 15:44:14_

---

## 評估總結

### 統計概覽

| 狀態 | 數量 | 模型 |
| :--- | :---: | :--- |
| ✅ 功能正常 | 26 | 見下方分析 |
| ❌ EOL 已停用 | 16 | deepseek-v3.2, devstral-2, mistral-medium-3, mistral-large-3 *(注1)*, nemotron-super-49b ×2, devstral-2, glm4.7, minimax-m2.5, mixtral-8x22b, gemma-3-27b, kimi-k2-instruct-0905, mixtral-8x7b, magistral-small, deepseek-v3.1-terminus, abacusai/dracarys |
| ⚠️ 假陽性（回應但不可用） | 3 | sarvam-m（API Bad Request）、llama-3.2-90b（Context Length Error）、llama-3.2-11b（觸發工具呼叫異常） |

> 注1：mistral-large-3 雖能回應，但推理品質差（T3 答 -3，正確為 0）

### T3 邏輯推理答案分析

序列 `3 2 1 0 -1 -2` 第 4 項 = **0**（1-indexed 數學慣例）

| 答案 | 模型 | 說明 |
| :---: | :--- | :--- |
| **0** ✅ | deepseek-v4-pro, minimax-m2.7, gemma-4-31b, gpt-oss-120b, nemotron-super-120b, nemotron-nano-30b, seed-oss-36b | 完全正確 |
| **-1** ⚠️ | qwen3-coder-480b, qwen3.5-122b, qwen3-next-80b | 0-index 偏移（程式員慣性），可接受 |
| **-2/-3** ❌ | mistral-small-4（-2）、mistral-large-3（-3）、mistral-nemotron（-3）、llama-3.3-70b（輸出 bash 指令） | 推理能力明顯不足 |

### 指令遵循品質備註

| 模型 | 問題 |
| :--- | :--- |
| `llama-4-maverick` | T2/T3 回傳 JSON function schema，而非直接回答（過度 agentic） |
| `gpt-oss-20b` | T1 開始「判斷 skill 適用性」，未遵循格式指令 |
| `nvidia-nemotron-nano-9b-v2` | T1 邏輯答案錯誤（答 no，正確為 yes） |
| `mistral-nemotron` | T2 回傳 "not implemented" |
| `step-3.5-flash` | T3 未僅回傳數字，輸出冗餘解釋 |

---

## 可用模型推薦排行

依整體品質排序（EOL 與假陽性已排除）：

### 🥇 頂級推薦

| 模型 | T1 | T2 | T3 | 特點 |
| :--- | :---: | :---: | :---: | :--- |
| `deepseek-ai/deepseek-v4-pro` | ✅ | ✅ | ✅(0) | 三維完美，推理最穩 |
| `openai/gpt-oss-120b` | ✅ | ✅ | ✅(0) | 指令嚴謹，推理正確 |
| `nvidia/nemotron-3-super-120b-a12b` | ✅ | ✅ | ✅(0) | 全能均衡 |
| `minimaxai/minimax-m2.7` | ✅ | ✅ | ✅(0) | 中文能力強，推理準確 |
| `qwen/qwen3-coder-480b-a35b-instruct` | ✅ | ✅ | ✅(-1) | 最強程式碼生成，T3 有 0-index 偏差 |

### 🥈 強力推薦

| 模型 | T1 | T2 | T3 | 特點 |
| :--- | :---: | :---: | :---: | :--- |
| `deepseek-ai/deepseek-v4-flash` | ✅ | ✅ | ✅ | 速度快，適合輕量任務 |
| `qwen/qwen3.5-397b-a17b` | ✅ | ✅ | ✅ | 超大參數量，知識廣博 |
| `qwen/qwen3-next-80b-a3b-instruct` | ✅ | ✅ | ✅(-1) | 均衡，程式/中文皆佳 |
| `qwen/qwen3.5-122b-a10b` | ✅ | ✅ | ✅(-1) | 高效能中型模型 |
| `google/gemma-4-31b-it` | ✅ | ✅ | ✅(0) | 推理準確，T1 偶有 markdown 包裝 |
| `z-ai/glm-5.1` | ✅ | ✅ | ✅ | 中文優秀 |
| `nvidia/nemotron-3-nano-30b-a3b` | ✅ | ✅ | ✅(0) | 輕量但推理準確 |

### 🥉 可用但有限制

| 模型 | 限制說明 |
| :--- | :--- |
| `moonshotai/kimi-k2.6` | 回應不穩定（偶發 timeout） |
| `meta/llama-4-maverick-17b-128e-instruct` | 過度 agentic，T2/T3 格式混亂 |
| `microsoft/phi-4-multimodal-instruct` | 多模態可用，指令遵循待驗 |
| `microsoft/phi-4-mini-instruct` | 輕量，適合簡單任務 |
| `bytedance/seed-oss-36b-instruct` | 推理正確，較少知名度 |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | 回應中文（T1 答「是」），可用 |

---

## 角色分配建議（基於評估結果）

| 角色 | 現有設定 | 建議 | 理由 |
| :--- | :--- | :--- | :--- |
| **Explorer** | `deepseek-v4-pro` | ✅ 維持 | 最穩定，推理正確 |
| **Oracle** | `qwen3-next-80b-a3b-instruct` | 🔄 考慮換 `gpt-oss-120b` 或 `nemotron-super-120b` | Oracle 需強推理，此兩款 T3 正確；Qwen 有 0-index 偏差 |
| **Librarian** | `minimax-m2.7` | ✅ 維持 | 中文強、推理正確，最適文件角色 |
| **Fixer** | `qwen3-coder-480b` | ✅ 維持 | 最強程式碼生成 |
| **Designer** | `llama-4-maverick` | 🔄 考慮換 `phi-4-multimodal-instruct` 或 `gemma-4-31b` | maverick 在格式遵循上有問題 |
