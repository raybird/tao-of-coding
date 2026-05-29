# Orchestrator 身份確立與可攜安裝設計

> **文件狀態**: 定稿 (Accepted)
> **負責角色**: Oracle — 架構決策 / Librarian — 文件整理
> **日期**: 2026-05-29
> **主題**: tao-of-coding 如何在「不被任何宿主綁死」的前提下，可靠地確立 orchestrator 根身份

---

## 0. TL;DR

- **角色身份**（Explorer / Oracle / Librarian / Fixer / Designer）天生適合當 skill：可攜、可單測、無副作用。
- **orchestrator 根身份**（「你是統籌者，手上有這份名冊，何時找誰」）**沒辦法只靠 skill 確立**——skill 是「可被查閱的能力」，不是「你現在就是隊長」的宣告。確立根身份必須動到宿主的根設定（`AGENTS.md` / 系統 prompt）。
- 這正是 tao-of-coding 當初最難的著力點。為了維持**可攜性**（不要求每個宿主改自己的 `AGENTS.md`），早期選擇用 bash 包一層（`orchestrate-skill.sh`）**在 runtime 把根協議灌進 prompt**。
- **關鍵啟發**：GitNexus 在 `gitnexus analyze` 時，用「標記包夾的受管區塊」(`<!-- gitnexus:start -->…<!-- gitnexus:end -->`) 冪等地把指引寫進宿主 `AGENTS.md`。這個模式是**非破壞、可重複執行、人機共存**的——它讓「動宿主 AGENTS.md」這件事從禁忌變成安全操作。
- **結論**：tao-of-coding 不必二選一。提供**兩種安裝/啟用模式**：
  1. **Ephemeral（瞬時）**：沿用既有 bash 包裝，runtime 注入根身份，**零宿主足跡**，適合臨時 CLI 使用。
  2. **Persistent（常駐）**：仿 GitNexus，由安裝/同步動作把一段受管區塊冪等寫進宿主 `AGENTS.md`，**根身份常駐**，適合希望 orchestrator 永遠在線的宿主。
- 這個設計讓 tao-of-coding **真正釋放成一個可攜、host-agnostic 的編排技能**，而不是被吸收進任何單一宿主（如 TeleNexus）內。它自帶的 superpowers 自更新子技能（`sync-superpowers.sh`）正是「這是一個獨立、會自我維護的活套件」的佐證。

---

## 1. 前因：這層東西的身世

tao-of-coding 不是憑空長出來的，它的演進脈絡是：

```
oh-my-opencode-slim（上游靈感：輕量化、角色分工）
        │
        ▼  TeleNexus 的 AI agent 自己參考、做成「中國風」的 skill 層，
           目的是讓 TeleNexus 擁有「一層自己的 AI agent 助理」
        │
   tao-of-coding（被抽出來獨立發展的多代理協作框架）
        │
        ▼  再精簡 / 演進
     taonix（精簡版 AI Task Runtime）
```

也就是說，tao-of-coding 的初衷，就是「**讓宿主擁有一支自己的 AI 角色班底為它服務**」。它被從 TeleNexus 抽出來獨立養大，本身就帶著「可被任何宿主安裝」的企圖。

---

## 2. 核心難題：skill 給得了「角色」，給不了「隊長」

把角色拆成一張張 skill 卡（`references/explorer.md`、`oracle.md`、`fixer.md`…）很容易，也很乾淨。但這裡有一個結構性的缺口：

- 角色卡只回答「**有哪些專家、各自會什麼**」。
- **沒有任何一張角色卡會說「你是老闆」。** 所以光把角色掛成 skill，沒有任何一方知道「誰該指揮誰」。

在 tao-of-coding 內，這個「印信」其實放在 **root `SKILL.md`**——CLAUDE.md 明訂：

> `SKILL.md` 只允許在最外層 Root 模式載入一次；子 Skill 以 Delegated 模式執行，禁止重載。

root `SKILL.md` 就是那張「你是 orchestrator」的委任狀；角色卡是「兵」，root SKILL.md 是「印信」。

**問題在於：誰、在什麼時機，把這張印信交到 agent 手上？** skill 被動地躺在 workspace 裡「可供查閱」，不等於 agent「這一回合就以統籌者身分運作」。要讓根身份生效，必須有人在最外層**主動把根協議灌進 prompt 或寫進宿主憲法**。

---

## 3. 為何早期走 bash 包裝：可攜性 vs 動宿主憲法

確立根身份只有兩條路，而它們互相矛盾：

| 路徑 | 優點 | 代價 |
| :--- | :--- | :--- |
| 改宿主的根設定（`AGENTS.md` / 系統 prompt） | 根身份常駐、最乾淨 | 對「想到處安裝」的 skill 是**侵入性要求**——等於要動別人家的憲法 |
| runtime 臨時注入（bash 包一層） | **零宿主足跡**、可攜 | 多一層 bash、observability 較弱、會 opencode 套 opencode |

對一個**可攜**的 skill 而言，「安裝我就請你改 `AGENTS.md`」是很重的負擔。所以 tao-of-coding 選了後者：由 `orchestrate-skill.sh` 在最外層**強制把 root `SKILL.md` 灌進 prompt**，安裝時只要 symlink skill、完全不碰宿主憲法。

**關鍵認知**：那層 bash 的存在理由，不是「為了執行」，而是「**在不污染宿主根設定的前提下，臨時注入 orchestrator 身份**」。它是「可攜性」與「根身份」這對矛盾的折衷產物。這就是當初最難的著力點。

---

## 4. 關鍵啟發：GitNexus 的受管區塊模式

[GitNexus](https://github.com/abhigyanpatwari/GitNexus) 在執行 `gitnexus analyze` 時，會把一段指引**冪等地**寫進宿主的 `AGENTS.md`（與 `CLAUDE.md`），形式為：

```markdown
<!-- gitnexus:start -->
# GitNexus — Code Intelligence
...（自動維護的內容）...
<!-- gitnexus:end -->
```

這個「**標記包夾的受管區塊 (marker-delimited managed block)**」有三個性質：

- **冪等**：每次重跑只重寫 `start`/`end` 之間，跑幾次結果一致。
- **非破壞**：標記以外的內容（宿主手寫的靈魂原則）完全不動。
- **人機共存**：同一份 `AGENTS.md`，上半是人寫的憲法，下半是工具維護的區塊，井水不犯河水。

**這個模式把「動宿主 `AGENTS.md`」從禁忌變成安全、可自動化的操作**——它正好瓦解了第 3 節那對矛盾。換句話說：tao-of-coding 不再需要 bash 繞路來迴避碰憲法，它可以**正當地、非侵入地把根身份寫進宿主憲法**。

---

## 5. 結論：兩種安裝/啟用模式（不必二選一）

tao-of-coding 應同時提供兩種模式，讓宿主依需求選擇：

### 模式 A — Ephemeral（瞬時注入，沿用現狀）
- 由 `orchestrate-skill.sh` 在 runtime 把 root 協議灌進 prompt。
- **零宿主足跡**，安裝只需 symlink skill。
- 適合：臨時 CLI 使用、不想在宿主留任何常駐設定的場景。

### 模式 B — Persistent（受管區塊常駐，新增）
- 提供一個安裝/同步動作（概念上等同 `gitnexus analyze`），把一段受管區塊冪等寫進宿主 `AGENTS.md`：

```markdown
<!-- tao:start -->
# Tao of Coding — Orchestrator 協議
你是本工作環境的 orchestrator（統籌者）。你手上有以下角色班底，
詳細角色卡見 skills/tao-of-opencode/references/<role>.md：
- Explorer / Oracle / Librarian / Fixer / Designer
調度準則：
- 簡單、單步任務 → 直接回答，不召集團隊。
- 複雜或多步驟工作 → 依任務性質選用對應角色與技能再執行。
- 多步驟任務需先回報「路由角色 + 將使用的技能/工具」再動手。
<!-- tao:end -->
```

- **根身份常駐**，每次 agent run 都讀得到，不靠 runtime 包裝。
- 必須沿用 GitNexus 的冪等寫法：有標記就替換、沒有就 append、標記外不碰。
- 適合：希望 orchestrator 永遠在線的宿主（如 TeleNexus）。

### 分工原則（兩模式共用）
- **角色身份** → skill references（可攜、可單獨維護）。
- **orchestrator 根身份** → 模式 A 的 runtime 注入，或模式 B 的 `AGENTS.md` 受管區塊。
- **詳細角色卡全文** → 永遠留在 `skills/`，受管區塊只放「名冊摘要 + 調度準則」，避免憲法肥大。

---

## 6. 對宿主的落地：以 TeleNexus 為例（但不限於此）

TeleNexus 是模式 B 的典型消費者，但它**只是其中一個 host**，不是 tao-of-coding 的歸宿。落地要點：

1. **目標檔案是宿主 agent 實際讀的那份 `AGENTS.md`，不是 repo 根那份。**
   - TeleNexus 的 opencode 工作目錄是 `workspace/`（`src/core/opencode.ts`，`cwd: workspacePath`），所以執行時 agent 讀的是 `workspace/AGENTS.md`（目前為空檔），**不是** repo 根的 `AGENTS.md`（那份是開發時 Claude Code 讀的）。
   - 若照 GitNexus 預設寫進 repo 根 `AGENTS.md`，受管區塊可能到不了真正幹活的 runtime agent。
2. **要讓它持久化**：由宿主的同步機制（TeleNexus 是 `scripts/sync-skills.mjs`）在每次啟動時把受管區塊寫進 `workspace/AGENTS.md`，與它生成 `skills-summary.md` 同一管線，確保容器重建後仍在、且進版控。
3. **回家後 bash 可選**：對能正當擁有自己 `AGENTS.md` 的宿主而言，模式 A 的遞迴 bash 不再必要（它存在的理由——迴避碰宿主憲法——已消失）。

> **待驗證 (Open Question)**：opencode 解析 `AGENTS.md` 的規則——是否只讀 cwd、或會往上層目錄合併？這決定模式 B 在 opencode 宿主上「只需寫一處」還是「必須寫 cwd 那處」。落地前需實測確認。

---

## 7. 本方案解到什麼、沒解到什麼

- **解到**：orchestrator **根身份**的確立——這正是 tao-of-coding 當初最難的著力點，現在有兩條乾淨的路（A/B），且 B 不犧牲可攜性。
- **沒解到**：**真正的隔離**。模式 A/B 確立的都是「身份」，本質仍是同一個 agent session 輪流戴帽子（一人分飾多角），不是獨立、無狀態的子 agent。要拿回 tao-of-coding 自豪的「無狀態原則」，仍需真正的分進程/分 context：
  - 保留遞迴 bash 派工（opencode 套 opencode），或
  - 改用宿主原生的 subagent/task 機制，或
  - 由宿主的 pipeline 層親自派工。
  - 這屬於另一份「執行隔離」設計的範疇，本文件不涵蓋。

---

## 8. 與 superpowers 自更新子技能的關係

tao-of-coding 內建 `skills/tao-of-opencode/scripts/sync-superpowers.sh`，可從上游 `obra/superpowers` 同步技能（版本追蹤見 `references/superpowers/SOURCE.md`，目前鎖定 v4.2.0 / commit `a98c5df`）。

這個自更新能力本身就說明：**tao-of-coding 是一個會自我維護、持續演進的活套件**，理應以**獨立、可攜**的形式釋放，而不是被冷凍進任何單一宿主。模式 B 的受管區塊安裝法，正好讓它能像 GitNexus 那樣「裝進任何宿主、又保持自己持續更新」——這才是它能力真正釋放的形態。

---

## 9. 後續行動 (Next Steps)

1. 設計模式 B 的安裝/同步指令（冪等寫入受管區塊；參考 `gitnexus analyze` 行為）。
2. 定稿 `<!-- tao:start --><!-- tao:end -->` 受管區塊的標準內容（委任狀 + 名冊摘要 + 調度準則）。
3. 實測 opencode 的 `AGENTS.md` 解析規則（第 6 節 Open Question）。
4. 文件化兩種安裝模式到 `README.md` / `docs/skill_dispatcher_contract.md`，供宿主選用。
