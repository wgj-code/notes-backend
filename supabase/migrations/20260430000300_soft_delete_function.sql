-- 6A Demo · soft_delete_note 函数 (绕过 PostgREST RLS UPDATE 403 bug)
-- PostgREST 在 UPDATE SET deleted_at=NULL→non-NULL 时误触 WITH CHECK
-- SECURITY DEFINER 让函数以 owner 身份执行,绕过 RLS,但仍验证 user_id 归属

create or replace function public.soft_delete_note(p_note_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notes
  set deleted_at = now()
  where id = p_note_id
    and user_id = auth.uid();
end;
$$;

comment on function public.soft_delete_note(uuid) is '软删除笔记:设置 deleted_at,绕过 PostgREST RLS UPDATE bug';
