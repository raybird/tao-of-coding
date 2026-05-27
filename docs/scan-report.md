# 專案掃描報告 (Project Scan Report)

- **掃描日期**: 2026-05-27
- **執行角色**: Explorer (專案探查者)
- **報告狀態**: 已完成

## 1. 核心模組 (Core Modules)

本專案是一個專為 AI 代理設計的**多代理協作框架**。經掃描，專案包含以下 3 個核心模組：

1. **`skills/tao-of-opencode/` (OpenCode 協作模組)**:
   - 包含以 OpenCode CLI 為主的路由設定（[skill-routing.conf](file:///home/kevin/Documents/RCodes/tao-of-coding/skills/tao-of-opencode/references/skill-routing.conf)）、調度腳本（`scripts/`）、角色指南（`references/`）以及本地化的 Superpowers 核心技能。
2. **`docs/` (系統文件與規範)**:
   - 存放多代理框架的架構規格、決策樹、分析報告與操作指引（如 [superpowers_playbook.md](file:///home/kevin/Documents/RCodes/tao-of-coding/docs/superpowers_playbook.md)、[skill_dispatcher_contract.md](file:///home/kevin/Documents/RCodes/tao-of-coding/docs/skill_dispatcher_contract.md) 等）。
3. **`.serena/` (Serena 專案配置)**:
   - 用於 Serena 代理工具的專案設定，定義語言環境（目前設定為 `bash`）與專案中繼資料（[project.yml](file:///home/kevin/Documents/RCodes/tao-of-coding/.serena/project.yml)）。

---

## 2. 一級依賴關係 (First-Level Dependencies)

本專案主要基於 Markdown 協議與 Bash 腳本，無傳統的 package.json 依賴，其運作依賴系統中的以下 CLI 工具與環境：

1. **`opencode` (OpenCode CLI)**: 用於 `tao-of-opencode` 執行入口與任務調用。
2. **`bash` (Bash Shell, >= 4.0)**: 用於執行 `scripts/` 目錄下的自動路由、分發與同步腳本（例如 [orchestrate-skill.sh](file:///home/kevin/Documents/RCodes/tao-of-coding/skills/tao-of-opencode/scripts/orchestrate-skill.sh)）。
3. **`git` (Git CLI)**: 用於 `sync-superpowers.sh` 從 upstream 同步 superpowers 技能庫。
4. **`npx` / `Node.js`**: 用於執行交互式連結工具 `skill-linker`。

---

## 3. 潛在風險評估 (Risk Assessment)

經靜態掃描與分析，本專案存在以下潛在技術風險：

1. **命令注入與任意命令執行風險 (Shell Injection Risk)**
   - **涉及檔案**: 
     - [skills/tao-of-opencode/scripts/skill-dispatch.sh](file:///home/kevin/Documents/RCodes/tao-of-coding/skills/tao-of-opencode/scripts/skill-dispatch.sh#L393-L395)
   - **風險說明**: 在 `skill-dispatch.sh` 中，`--runner-cmd` 參數所傳入的命令字串會直接透過 `bash -lc "$RUNNER_CMD"` 進行執行。若此參數來源未受充分過濾或由外部不可信的使用者輸入構造，將可能引發 Shell 命令注入攻擊，造成任意系統命令執行。

2. **硬編碼路徑依賴與 broken link 風險 (Hardcoded Symlink Path Risk)**
   - **涉及檔案**: 
     - [README.md](file:///home/kevin/Documents/RCodes/tao-of-coding/README.md#L178-L200)
   - **風險說明**: 在安裝指引（Installation）中，手動建立軟連結（symlink）的指令預設專案被 clone 在 `~/Documents/AgentSkills/tao-of-coding`。若使用者將專案 clone 至其他目錄，直接複製並執行 README 中的手動連結指令將導致軟連結失效（broken symlinks）或連結至錯誤的路徑。
