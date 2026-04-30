-- 6A Demo · Notes user_id 默认值
-- 2026-04-30 · P1-2 架构设计(v0.1)
-- 简化插入:POST /notes 时无需显式传 user_id,由 RLS + DEFAULT 保障

ALTER TABLE public.notes
  ALTER COLUMN user_id SET DEFAULT auth.uid();
