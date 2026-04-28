-- 6A Demo · seed 数据
-- 仅本地开发用,生产 DB 不执行
-- 创建一个测试用户 + 几条示例笔记

-- 注意:真正的 auth.users 记录需要 Supabase auth 创建,这里只是 schema 演示占位。
-- 本地 `supabase db reset` 后,可以用 Studio UI 手动造一个 test user,再用这里的 UUID 插笔记。

-- 示例占位(本地执行会失败,因为 auth.users 还没对应行,正常):
-- insert into public.notes (user_id, title, content) values
--   ('00000000-0000-0000-0000-000000000001', '首条笔记', '6A Demo 压测期的示例内容');
