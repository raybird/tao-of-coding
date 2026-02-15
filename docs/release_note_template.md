# Release Note Template

本模板用於每次發版前快速產出 release note，依 SemVer 分成 `major / minor / patch` 三種。

## 使用方式

1. 先判斷版本類型（參考 `docs/semver_decision_tree.md`）
2. 複製對應模板
3. 填入實際內容後再建立 tag

---

## MAJOR（破壞性變更）模板

```markdown
# Release vX.0.0

## Highlights
- <一句話說明這次 major 的核心價值>

## Breaking Changes
- <破壞性變更 1：舊行為 -> 新行為>
- <破壞性變更 2：遷移必要動作>

## Migration Guide
1. <步驟 1>
2. <步驟 2>
3. <步驟 3>

## Added
- <新增功能>

## Changed
- <重要調整>

## Fixed
- <重要修正>

## Verification
- <驗證指令與結果摘要>

## Links
- Protocol: `skills/tao-of-coding/SKILL.md`
- Dispatcher Contract: `docs/skill_dispatcher_contract.md`
```

---

## MINOR（向下相容新功能）模板

```markdown
# Release vX.Y.0

## Highlights
- <本次新增的主要能力>

## Added
- <新增功能 1>
- <新增功能 2>

## Changed
- <相容性內的調整>

## Fixed
- <修正項目>

## Compatibility
- Backward compatible: Yes
- Migration required: No

## Verification
- <驗證指令與結果摘要>
```

---

## PATCH（相容修補）模板

```markdown
# Release vX.Y.Z

## Fixed
- <bug 修正>
- <文件或腳本修正>

## Changed
- <小幅行為調整，若有>

## Compatibility
- Backward compatible: Yes
- Migration required: No

## Verification
- <驗證指令與結果摘要>
```

---

## 建議發布流程（簡版）

```bash
# 1) 確認工作樹
git status

# 2) 建立版本 commit（如有）
git add <files>
git commit -m "chore: release vX.Y.Z"

# 3) 建立 annotated tag
git tag -a "vX.Y.Z" -m "Release vX.Y.Z"

# 4) 推送 branch + tag
git push origin main
git push origin "vX.Y.Z"
```
