-- Fix: permanent_delete_note function to bypass RLS

CREATE OR REPLACE FUNCTION public.permanent_delete_note(p_note_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
begin
  delete from public.notes
  where id = p_note_id
    and user_id = auth.uid();
end;
$$;

COMMENT ON FUNCTION public.permanent_delete_note(uuid) is '永久删除笔记:从数据库中彻底删除,绕过 RLS';
