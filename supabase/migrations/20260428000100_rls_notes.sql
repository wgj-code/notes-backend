-- 6A Demo · Notes 表 Row Level Security
-- 按 auth.uid() 严格过滤,用户只能看到自己的笔记

alter table public.notes enable row level security;

-- SELECT:仅看自己的、未软删除的笔记
create policy "notes_select_own"
  on public.notes for select
  using (auth.uid() = user_id and deleted_at is null);

-- INSERT:user_id 必须等于 auth.uid()
create policy "notes_insert_own"
  on public.notes for insert
  with check (auth.uid() = user_id);

-- UPDATE:仅允许修改自己的笔记,且不能改 user_id
create policy "notes_update_own"
  on public.notes for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- DELETE:仅允许删除自己的(含软删)
create policy "notes_delete_own"
  on public.notes for delete
  using (auth.uid() = user_id);
