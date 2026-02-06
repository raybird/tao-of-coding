# 仙界神祇職能與技能對照表 (Celestial Skill Mapping)

本文件將 [Superpowers Skills](superpowers_skills_analysis.md) 映射至 [Tao of Coding](../skills/tao-of-coding/SKILL.md) 的神祇角色，並標記技能是否已在本專案本地化。

## 本地化來源

- 上游來源：`obra/superpowers`
- 來源 commit：`a98c5dfc9de0df5318f4980d91d24780a566ee60` (v4.2.0)
- 本地技能根目錄：`skills/superpowers/`

## 1. 太上老君 (Oracle) —— 丹道宗師 (策略與核心設計)

**核心職能**: 架構設計、高階決策、重構、解惑。

| 技能 (Skill) | 分工 | 功能 (Function) | 本地化狀態 | 對應理由 |
| :--- | :--- | :--- | :--- | :--- |
| **`brainstorming`** | 主責 | Socratic design refinement | 已本地化 | 透過蘇格拉底式對話（煉丹）提煉架構設計。 |
| **`writing-plans`** | 主責 | Detailed implementation plans | 已本地化 | 規劃詳盡實作計畫，運籌帷幄。 |
| **`finishing-a-development-branch`** | 主責 | Merge/PR decision workflow | 僅映射 | 決定何時「開爐」（Merge）的高階決策。 |
| **`subagent-driven-development`** | 主責 | Fast iteration | 僅映射 | 統御多個子代理進行快速迭代與審查。 |
| **`dispatching-parallel-agents`** | 主責 | Concurrent subagent workflows | 僅映射 | 調度各路神仙並行作業。 |

## 2. 魯班 (Fixer) —— 巧匠祖師 (實作與修復)

**核心職能**: 程式實作、單元測試、除錯修復。

| 技能 (Skill) | 分工 | 功能 (Function) | 本地化狀態 | 對應理由 |
| :--- | :--- | :--- | :--- | :--- |
| **`test-driven-development`** | 主責 | RED-GREEN-REFACTOR | 已本地化 | 重視規矩（測試），確保每一步精準無誤。 |
| **`systematic-debugging`** | 主責 | 4-phase root cause process | 已本地化 | 運用系統化流程修復崩壞的機關。 |
| **`verification-before-completion`** | 主責 | Ensure it's actually fixed | 已本地化 | 確保修復後的機關真實可用，而非虛應故事。 |
| **`using-git-worktrees`** | 協作 | Parallel development branches | 僅映射 | 如同千手觀音，同時處理多個工件（分支）。 |
| **`receiving-code-review`** | 主責 | Responding to feedback | 已本地化 | 虛心接受指教並打磨作品的匠人精神。 |

## 3. 文曲星 (Librarian) —— 智慧文書 (文件與元知識)

**核心職能**: 文件撰寫、知識傳承、流程規範。

| 技能 (Skill) | 分工 | 功能 (Function) | 本地化狀態 | 對應理由 |
| :--- | :--- | :--- | :--- | :--- |
| **`writing-skills`** | 主責 | Create new skills | 僅映射 | 撰寫「天書」（Skill 文件），傳承最佳實踐。 |
| **`using-superpowers`** | 主責 | Introduction to the system | 僅映射 | 引導信徒入門，傳授系統使用之法。 |
| **`requesting-code-review`** | 主責 | Pre-review checklist | 已本地化 | 整理奏摺（PR 描述），確保條理分明。 |

## 4. 千里眼 / 順風耳 (Explorer) —— 洞察天眼 (分析與監控)

**核心職能**: 專案掃描、進度監控、根因追蹤。

| 技能 (Skill) | 分工 | 功能 (Function) | 本地化狀態 | 對應理由 |
| :--- | :--- | :--- | :--- | :--- |
| **`executing-plans`** | 主責 | Batch execution & Monitoring | 已本地化 | 監控計畫執行進度，確認檢查點 (Checkpoints)。 |
| **`systematic-debugging`** | 協作 | Root Cause Tracing | 已本地化 | 掃描依賴關係，追蹤錯誤源頭。 |

## 5. 織女 (Designer) —— 雲錦天衣 (設計與體驗)

**核心職能**: UI/UX 設計、前端體驗。

| 技能 (Skill) | 分工 | 功能 (Function) | 本地化狀態 | 對應理由 |
| :--- | :--- | :--- | :--- | :--- |
| **`brainstorming`** | 協作 | Design focused | 已本地化 | 針對使用者體驗與介面美感的發想與優化。 |

---

## 總結對照表

| 角色 (Role) | 核心職能 | 主責技能 | 協作技能 |
| :--- | :--- | :--- | :--- |
| **太上老君** | **大腦 (Strategy)** | `brainstorming`, `writing-plans` | `finishing-a-development-branch`, `subagent-driven-development`, `dispatching-parallel-agents` |
| **魯班** | **雙手 (Execution)** | `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `receiving-code-review` | `using-git-worktrees` |
| **文曲星** | **紀錄 (Meta/Docs)** | `requesting-code-review` | `writing-skills`, `using-superpowers` |
| **千里眼/順風耳** | **雙眼 (Observation)** | `executing-plans` | `systematic-debugging` |
| **織女** | **美感 (Design)** | - | `brainstorming` |

## 導入階段狀態

### Phase 1 (已完成，本次導入)

- `brainstorming`
- `writing-plans`
- `executing-plans`
- `test-driven-development`
- `systematic-debugging`
- `verification-before-completion`
- `requesting-code-review`
- `receiving-code-review`

### Phase 2 (待導入)

- `using-git-worktrees`
- `finishing-a-development-branch`
- `subagent-driven-development`
- `dispatching-parallel-agents`
- `writing-skills`
- `using-superpowers`
