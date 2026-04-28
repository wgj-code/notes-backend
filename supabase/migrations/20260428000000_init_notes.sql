-- 6A Demo · Notes 核心表初始化
-- 2026-04-28 · P0-4 AI 自助产出

create table if not exists public.notes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  title         text not null,
  content       text not null default '',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index if not exists notes_user_id_idx on public.notes(user_id);
create index if not exists notes_updated_at_idx on public.notes(updated_at desc);
create index if not exists notes_deleted_at_idx on public.notes(deleted_at) where deleted_at is null;

comment on table public.notes is '笔记条目,按 user_id 隔离,软删除用 deleted_at';
comment on column public.notes.deleted_at is '非空表示已软删除,RLS 过滤';

-- updated_at 自动刷新
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists notes_touch_updated_at on public.notes;
create trigger notes_touch_updated_at
  before update on public.notes
  for each row
  execute function public.touch_updated_at();
