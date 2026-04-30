-- 6A Demo · Notes 正文长度约束
-- 2026-04-30 · P1-2 架构设计(v0.1)
-- 预演决策 D1:content 上限 100KB(102400 bytes)

ALTER TABLE public.notes
  ADD CONSTRAINT notes_content_check
  CHECK (char_length(content) <= 102400);
