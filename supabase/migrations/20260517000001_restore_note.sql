-- Fix: restore_note function to bypass RLS
-- The notes_update_own RLS policy has WITH CHECK (auth.uid() = user_id)
-- but restoring sets deleted_at from non-null to null, which may trigger issues

CREATE OR REPLACE FUNCTION public.restore_note(p_note_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
begin
  update public.notes
  set deleted_at = NULL
  where id = p_note_id
    and user_id = auth.uid()
    and deleted_at IS NOT NULL;
end;
$$;

COMMENT ON FUNCTION public.restore_note(uuid) is '恢复已删除的笔记:设置 deleted_at 为 NULL,绕过 RLS';
