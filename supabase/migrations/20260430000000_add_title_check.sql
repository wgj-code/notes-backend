-- 6A Demo · Notes 标题约束
-- 2026-04-30 · P1-2 架构设计(v0.1)
-- PRD v1.0:标题必填 1-200 字,trim 后非空

-- 先清理可能存在的空格标题(生产环境慎用,内测期可执行)
UPDATE public.notes SET title = trim(title) WHERE title != trim(title);

ALTER TABLE public.notes
  ADD CONSTRAINT notes_title_check
  CHECK (char_length(trim(title)) > 0 AND char_length(title) <= 200);
