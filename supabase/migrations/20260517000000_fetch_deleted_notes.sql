-- Fix: fetch_deleted_notes function to bypass RLS
-- The notes_select_own RLS policy only allows viewing deleted_at = NULL
-- But recycle bin needs to view deleted_at IS NOT NULL

CREATE OR REPLACE FUNCTION public.fetch_deleted_notes()
RETURNS SETOF public.notes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.notes
  WHERE user_id = auth.uid()
    AND deleted_at IS NOT NULL
  ORDER BY deleted_at DESC;
END;
$$;

COMMENT ON FUNCTION public.fetch_deleted_notes() IS '获取用户已删除的笔记(回收站),绕过 RLS 的 deleted_at 过滤';
