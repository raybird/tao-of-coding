# Skill Routing Config Format

`orchestrate-skill.sh` 目前使用純 Bash 解析 `skills/tao-of-coding/references/skill-routing.conf`。

## 格式

- 檔案為 INI 風格
- 必填 `[default]` 區塊
- 每條路由使用 `[route.<id>]`
- `pattern=` 可重複多次（依序比對，先中先贏）

```ini
[default]
role=oracle
skill=brainstorming
reason=fallback

[route.debugging]
role=fixer
skill=systematic-debugging
reason=debugging
pattern=根因
pattern=除錯
pattern=debug
```

## 欄位

- `role`: `explorer|oracle|librarian|fixer|designer`
- `skill`: 對應 skill 名稱
- `reason`: 路由原因（dry-run 顯示）
- `pattern`: Bash regex 模式（大小寫不敏感）

## 規則

1. 先依檔案順序比對所有 `[route.*]` 的 `pattern`
2. 命中後即回傳該 route（不再往下）
3. 若無命中，落到 `[default]`

## 注意

- 不再支援 YAML 路由檔
- 若傳入 `.yaml/.yml`，會回 `E_UNSUPPORTED_ROUTE_FORMAT`
