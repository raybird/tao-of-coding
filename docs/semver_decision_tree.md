# SemVer Decision Tree (tao-of-coding)

本文件用於快速判斷下一版應升 `major.minor.patch` 的哪一位。

## 1) 30 秒決策樹

```text
Start
  |
  |-- Q1: 這次變更是否會讓舊版使用方式失效（breaking change）？
  |       例：CLI 參數不相容、必填欄位改變、核心契約改變
  |       |
  |       |-- Yes -> MAJOR
  |       |          例如: 2.1.1 -> 3.0.0
  |       |
  |       '-- No
  |            |
  |            |-- Q2: 是否新增了向下相容的新功能？
  |            |       例：新增可選參數、增加新腳本、新 skill 路由能力
  |            |       |
  |            |       |-- Yes -> MINOR
  |            |       |          例如: 3.0.0 -> 3.1.0
  |            |       |
  |            |       '-- No -> PATCH
  |            |                  例如: 3.1.0 -> 3.1.1
  |
  End
```

## 2) 專案對照表

- **MAJOR**
  - 改動 runtime contract，舊 orchestrator 無法直接沿用
  - 修改 `skill-dispatch.sh` 的不相容參數語意
  - 改動路由/技能結構導致舊配置無法解析

- **MINOR**
  - 新增可選能力（例如新路由規則、可選參數）
  - 新增文件規範與操作路徑，且不破壞既有流程

- **PATCH**
  - 錯字修正、說明補強、範例修正
  - bug 修復但外部介面不變

## 3) 發版前檢查

1. 舊版流程是否不用改就能跑？
2. 是否有新增功能但保持相容？
3. 是否僅修補而無新功能？
4. 版本號與 release note 是否一致？

## 4) 範例

- 調整 `FORBID_ROOT_RELOAD` 的預設行為且影響舊流程 -> **MAJOR**
- 新增 `--route-config`（舊流程可不使用）-> **MINOR**
- 修正 README 指令 typo -> **PATCH**
