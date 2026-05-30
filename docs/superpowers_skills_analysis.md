# Superpowers Skills Analysis

Based on the investigation of the [obra/superpowers](https://github.com/obra/superpowers) repository, here is the organized analysis of the available skills.

## 🧪 Testing (測試)

| Skill | Description | Function |
| :--- | :--- | :--- |
| **test-driven-development** | RED-GREEN-REFACTOR cycle | 指導 TDD 開發流程：先寫測試(紅)、實作通過(綠)、重構優化。包含測試反模式參考。 |

## 🐞 Debugging (除錯)

| Skill | Description | Function |
| :--- | :--- | :--- |
| **systematic-debugging** | 4-phase root cause process | 系統化除錯流程，包含根因追蹤 (Root Cause Tracing)、縱深防禦 (Defense-in-Depth) 與條件式等待 (Condition-based Waiting) 技術。 |
| **verification-before-completion** | Ensure it's actually fixed | 強制驗證機制，防止「以為修好了但其實沒有」的情況，確保修復有效性。 |

## 🤝 Collaboration (協作與流程)

| Skill | Description | Function |
| :--- | :--- | :--- |
| **brainstorming** | Socratic design refinement | 透過蘇格拉底式對話進行設計優化，激發更好的解決方案。 |
| **writing-plans** | Detailed implementation plans | 指導如何撰寫詳盡的實作計畫，確保開發前思緒清晰。 |
| **executing-plans** | Batch execution with checkpoints | 批次執行計畫，並設有檢查點 (Checkpoints) 以確保進度受控。 |
| **dispatching-parallel-agents** | Concurrent subagent workflows | 並行處理工作流，調度多個子代理同時執行任務以加速開發。 |
| **requesting-code-review** | Pre-review checklist | 提交代碼審查前的自我檢查清單，提升 PR 品質。 |
| **receiving-code-review** | Responding to feedback | 接收與回應代碼審查意見的標準流程。 |
| **using-git-worktrees** | Parallel development branches | 利用 Git Worktree 技術進行並行分支開發，無需頻繁切換 Context。 |
| **finishing-a-development-branch** | Merge/PR decision workflow | 開發分支完成後的決策流程，決定是合併、發 PR 或繼續迭代。 |
| **subagent-driven-development** | Fast iteration with two-stage review | 雙階段審查的快速迭代法：先審查規格合規性 (Spec Compliance)，再審查代碼品質。 |

## 🧠 Meta (元技能)

| Skill | Description | Function |
| :--- | :--- | :--- |
| **writing-skills** | Create new skills | 創造新 Skill 的最佳實踐指南，包含測試方法論。 |
| **using-superpowers** | Introduction to the skills system | 系統入門指南，介紹如何使用這套 Superpowers 框架。 |

## 本地化註記

- 上游來源：`obra/superpowers`
- 來源 commit：`f2cbfbefebbfef77321e4c9abc9e949826bea9d7` (v5.1.0；以 `superpowers/SOURCE.md` 為準)
- 本地導入目錄：`skills/tao-of-opencode/references/superpowers/`
- 導入狀態：已導入 10 項——8 項角色技能 + 2 項 orchestrator 調度技能（`subagent-driven-development`、`dispatching-parallel-agents`）；其餘上游技能保留映射待後續導入
