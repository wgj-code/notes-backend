# notes-backend

6A Demo 项目 · 个人笔记 App 后端(Supabase Edge Functions + PostgreSQL migrations)。

## 环境要求

- Node.js >= 20(仅用于 npm scripts 便利,Supabase CLI 本身独立)
- Supabase CLI(本地开发时安装:`brew install supabase/tap/supabase` 或 `npm i -g supabase`)
- Docker Desktop(Supabase local 需要)

## 本地启动

```bash
supabase start                 # 启动本地 PostgreSQL + Studio + Auth 等
supabase db reset              # 重置 DB 并应用 supabase/migrations/
supabase functions serve hello --no-verify-jwt
```

- Studio:http://localhost:54323
- API:http://localhost:54321
- Postgres:`postgres://postgres:postgres@localhost:54322/postgres`

## 目录结构

```
supabase/
├── config.toml              # 本地 Supabase 配置
├── migrations/
│   ├── 20260428000000_init_notes.sql   # 笔记表结构
│   └── 20260428000100_rls_notes.sql    # Row Level Security
├── functions/
│   └── hello/index.ts       # 示例 Edge Function
└── seed.sql                 # 本地 seed 数据(可选)
```

## CI / CD

- **CI**(`.github/workflows/ci.yml`):每次 PR / push 跑 migration dry-run,验证 SQL 可执行
- **Deploy**(`.github/workflows/deploy.yml`):push main 时自动 `supabase db push` + 部署 Edge Functions(需 Repo Variable `ENABLE_DB_PUSH=true` 开关,避免首次配置前误跑)

## 必需 GitHub Secrets

| Secret | 用途 | 如何获取 |
|---|---|---|
| `SUPABASE_PROJECT_REF` | 项目 slug | Supabase Dashboard → Settings → General → Reference ID |
| `SUPABASE_DB_PASSWORD` | 数据库密码 | 创建 Project 时自己设置 |
| `SUPABASE_ACCESS_TOKEN` | CLI 认证 | Dashboard → Account → Access Tokens |

## 项目归属

组B(Backend 线)主力仓。

## 关联文档

- [A1 基础设施实例化 Checklist](https://www.feishu.cn/wiki/ZHlhwUPK7i8oDBkCem4cvb4FnUc)
- [6A 压测报告 v0.1](https://www.feishu.cn/wiki/ZBptwnRdfiVDdzk3164ckmyHn3o)
- [M1 · Demo 启动方案](https://www.feishu.cn/wiki/QjTVwR7OOi8WZakBRqTcgbGenAb)
