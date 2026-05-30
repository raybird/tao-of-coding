# Case Study：第一次真實 orchestration 運行（dogfood）

> **日期**：2026-05-30　**宿主**：Claude Code　**協議版本**：tao-of-opencode v5.0.0
> **目的**：驗證「agent 即 orchestrator、用宿主原生 subagent 調度」這個 v5 主張，能否在真實宿主把一個真實任務端到端跑完——而不只是文件上的口號。

## 任務
給 `skills/tao-of-opencode/scripts/install-orchestrator.sh` 新增 `--check` 唯讀狀態檢查模式（exit 0=最新／1=過時／2=未安裝），供 CI 與宿主安裝腳本判讀。

## 路由決策（依 SKILL.md）
「新功能實作」屬多步驟、且有獨立子任務（recon → 實作 → 審查）→ 採 `subagent-driven-development`：**每個子任務開一個全新原生 subagent，派完做審查**。模型選擇交由宿主（Claude Code）決定，未使用建議模型附錄。

## 運行紀錄

| 階段 | 角色 / 機制 | 載入 | 產出 |
| :--- | :--- | :--- | :--- |
| 1. Recon | **Explorer**（Claude Code `Explore` 子代理，唯讀） | explorer.md | 精確的 file:line 結構圖、`--check` 最自然接入點、可重用的 `has_markers`/`replace_block`/`cmp -s` |
| 2. 實作 | **Fixer**（`general-purpose` 子代理）+ `test-driven-development` | fixer.md + TDD skill | RED：先加 8 個 bats 測試並貼失敗輸出；GREEN：實作 `--check` 至 22/22 通過 |
| 3. 審查 | **Reviewer**（`general-purpose` 子代理）+ code-review 嚴謹度 | — | 判定**通過**（無 critical/major）；提出 1 個 minor（最新路徑唯讀未顯式驗證）+ nits |
| 4. 驗證/整合 | **Orchestrator**（本體）+ `verification-before-completion` / `receiving-code-review` | — | **不採信子代理貼的輸出**，自己重跑 bats + 冒煙三種 exit code；採納 minor，補 2 個測試 → 23/23 |

## 成果
- `install-orchestrator.sh` 新增 `--check`（唯讀、三段 exit code、與 `--remove`/`--dry-run` 互斥），usage 與頂部註解同步。
- `tests/install-orchestrator.bats`：15 → 23 個測試，新增涵蓋 exit 0/1/2、唯讀（最新與過時兩條路徑皆驗）、衝突、狀態字串。
- shellcheck（CI）、bats、死連結檢查全綠。

## 這次 orchestration 真正驗證到什麼

**有效（v5 主張成立的證據）**
- **原生 subagent + 角色視角真的有用**：Explorer 戴上角色卡後產出的不是泛泛掃描，而是「Fixer 可直接照做」的接入點與行號——隔離與精準上下文帶來聚焦輸出。
- **orchestrator 保持協調者**：把細節下放給子代理，本體 context 留給路由與整合，正是 subagent-driven-development 的核心。
- **驗證紀律是關鍵**：orchestrator 沒有採信 Fixer 貼的「22/22」，自己重跑才算數——`verification-before-completion` 不是裝飾。
- **審查抓到測試覆蓋盲點**：Reviewer 指出「最新路徑的唯讀沒被測」，這是 tests 本身不會自己發現的。完整的「實作→審查→處理回饋」迴圈確實提升了品質。

**摩擦 / 誠實的限制**
- **tao 角色 ≠ 宿主 subagent 類型**：Claude Code 沒有名為 Explorer/Fixer 的子代理類型，是我把 Explorer→`Explore`、Fixer/Reviewer→`general-purpose`，再用 prompt 注入角色卡。角色「視角」靠 prompt 約定、非宿主強制——協議仍是君子協定。
- **兩階段審查被壓成一段**：小改動下把 spec + quality 合成單一 Reviewer，是務實取捨、非教條照搬。
- **模型建議未生效**：宿主自行決定子代理模型，附錄的角色↔模型表在此宿主上不起作用（正如其「非綁定」定位）。

## 結論
這是 v5「agent 即 orchestrator、原生 subagent 調度」**第一次被真實運行證明可行**——一個真任務、三個真子代理、完整的 TDD + 審查 + 驗證迴圈、可驗證的產出。先前評析裡「核心編排能力從未被真實運行證明」的最大缺口，至此有了第一個反例。

**下一步**：更大的多任務計畫（真正壓測 subagent-driven-development 的連續執行）、以及在 Codex / Antigravity 重跑同一流程，驗證跨宿主的可攜性。
