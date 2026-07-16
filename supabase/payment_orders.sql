-- ============================================================
-- CHAT - CA PHE HAI TIN
-- Muc dich:
--   1. Luu danh sach hoi thoai va tin nhan.
--   2. Khach chi xem va gui tin trong hoi thoai cua minh.
--   3. Admin xem, tra loi va danh dau da doc toan bo hoi thoai.
--   4. Bat Realtime cho conversations va messages.
--
-- Chay toan bo file mot lan trong Supabase Dashboard > SQL Editor.
-- File nay chi chua cau truc, quyen truy cap va Realtime cho chat.
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1. HAM KIEM TRA QUYEN ADMIN
-- ============================================================

create or replace function public.is_chat_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles as profile
    where profile.id = auth.uid()
      and lower(coalesce(to_jsonb(profile) ->> 'role', '')) = 'admin'
  );
$$;

revoke all on function public.is_chat_admin() from public;
grant execute on function public.is_chat_admin() to authenticated;

-- ============================================================
-- 2. BANG HOI THOAI
-- ============================================================

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'open'
    check (status in ('open', 'waiting_admin', 'closed')),
  last_message text not null default '',
  last_message_at timestamptz not null default now(),
  unread_by_user integer not null default 0 check (unread_by_user >= 0),
  unread_by_admin integer not null default 0 check (unread_by_admin >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Bo sung cot neu bang conversations da ton tai tu truoc.
alter table public.conversations
  add column if not exists user_id uuid
    references auth.users(id) on delete cascade,
  add column if not exists status text default 'open',
  add column if not exists last_message text default '',
  add column if not exists last_message_at timestamptz default now(),
  add column if not exists unread_by_user integer default 0,
  add column if not exists unread_by_admin integer default 0,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

-- ============================================================
-- 3. BANG TIN NHAN
-- ============================================================

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.conversations(id) on delete cascade,
  sender_type text not null check (sender_type in ('user', 'admin', 'bot')),
  sender_id uuid references auth.users(id) on delete set null,
  content text not null check (length(trim(content)) > 0),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Bo sung cot neu bang messages da ton tai tu truoc.
alter table public.messages
  add column if not exists conversation_id uuid
    references public.conversations(id) on delete cascade,
  add column if not exists sender_type text,
  add column if not exists sender_id uuid
    references auth.users(id) on delete set null,
  add column if not exists content text,
  add column if not exists is_read boolean default false,
  add column if not exists created_at timestamptz default now();

-- ============================================================
-- 4. CHUAN HOA DU LIEU CU
-- ============================================================

update public.conversations
set
  status = coalesce(nullif(trim(status), ''), 'open'),
  last_message = coalesce(last_message, ''),
  last_message_at = coalesce(last_message_at, created_at, now()),
  unread_by_user = greatest(coalesce(unread_by_user, 0), 0),
  unread_by_admin = greatest(coalesce(unread_by_admin, 0), 0),
  created_at = coalesce(created_at, now()),
  updated_at = coalesce(updated_at, now());

update public.messages
set
  sender_type = coalesce(nullif(trim(sender_type), ''), 'user'),
  content = coalesce(content, ''),
  is_read = coalesce(is_read, false),
  created_at = coalesce(created_at, now());

-- ============================================================
-- 5. INDEX SAP XEP VA TIM KIEM
-- ============================================================

-- Moi tai khoan nen chi co mot hoi thoai.
-- Neu du lieu cu dang bi trung user_id, script bo qua unique index de khong loi.
do $$
begin
  if not exists (
    select 1
    from public.conversations
    where user_id is not null
    group by user_id
    having count(*) > 1
  ) then
    execute '
      create unique index if not exists conversations_one_per_user_idx
      on public.conversations(user_id)
    ';
  else
    raise notice
      'Khong tao unique index: conversations dang co user_id bi trung';
  end if;
end;
$$;

create index if not exists conversations_admin_list_idx
on public.conversations(last_message_at desc, id);

create index if not exists messages_conversation_order_idx
on public.messages(conversation_id, created_at, id);

-- ============================================================
-- 6. TU DONG CAP NHAT updated_at
-- ============================================================

create or replace function public.set_chat_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists conversations_set_updated_at
on public.conversations;

create trigger conversations_set_updated_at
before update on public.conversations
for each row
execute function public.set_chat_updated_at();

-- ============================================================
-- 7. RPC CAP NHAT TIN CUOI VA SO TIN CHUA DOC
-- Flutter dang goi ham: bump_chat_conversation
-- ============================================================

create or replace function public.bump_chat_conversation(
  p_conversation_id uuid,
  p_last_message text,
  p_unread_for text default null,
  p_status text default null,
  p_reset_admin_unread boolean default false
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_unread_for is not null
     and p_unread_for not in ('unread_by_user', 'unread_by_admin') then
    raise exception 'Invalid unread target';
  end if;

  update public.conversations
  set
    last_message = trim(coalesce(p_last_message, '')),
    last_message_at = now(),
    status = case
      when public.is_chat_admin() then coalesce(p_status, status)
      else status
    end,
    unread_by_user = case
      when p_unread_for = 'unread_by_user'
        then coalesce(unread_by_user, 0) + 1
      else coalesce(unread_by_user, 0)
    end,
    unread_by_admin = case
      when p_reset_admin_unread and public.is_chat_admin() then 0
      when p_unread_for = 'unread_by_admin'
        then coalesce(unread_by_admin, 0) + 1
      else coalesce(unread_by_admin, 0)
    end
  where id = p_conversation_id
    and (user_id = auth.uid() or public.is_chat_admin());

  if not found then
    raise exception 'Conversation not found or access denied';
  end if;
end;
$$;

revoke all on function public.bump_chat_conversation(
  uuid,
  text,
  text,
  text,
  boolean
) from public;

grant execute on function public.bump_chat_conversation(
  uuid,
  text,
  text,
  text,
  boolean
) to authenticated;

-- ============================================================
-- 8. RLS CHO PROFILES
-- Admin can doc ten, email va so dien thoai cua khach dang chat.
-- ============================================================

drop policy if exists "chat_admins_read_profiles" on public.profiles;
drop policy if exists "Chat - admin xem thong tin khach" on public.profiles;

create policy "Chat - admin xem thong tin khach"
on public.profiles
for select
to authenticated
using (id = auth.uid() or public.is_chat_admin());

-- ============================================================
-- 9. RLS CHO CONVERSATIONS
-- ============================================================

alter table public.conversations enable row level security;

drop policy if exists "chat_customers_read_conversations"
on public.conversations;
drop policy if exists "chat_customers_create_conversations"
on public.conversations;
drop policy if exists "chat_customers_update_conversations"
on public.conversations;
drop policy if exists "chat_admins_manage_conversations"
on public.conversations;
drop policy if exists "Chat - khach xem hoi thoai cua minh"
on public.conversations;
drop policy if exists "Chat - khach tao hoi thoai"
on public.conversations;
drop policy if exists "Chat - khach cap nhat hoi thoai"
on public.conversations;
drop policy if exists "Chat - admin quan ly hoi thoai"
on public.conversations;

create policy "Chat - khach xem hoi thoai cua minh"
on public.conversations
for select
to authenticated
using (user_id = auth.uid());

create policy "Chat - khach tao hoi thoai"
on public.conversations
for insert
to authenticated
with check (user_id = auth.uid());

create policy "Chat - khach cap nhat hoi thoai"
on public.conversations
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "Chat - admin quan ly hoi thoai"
on public.conversations
for all
to authenticated
using (public.is_chat_admin())
with check (public.is_chat_admin());

-- ============================================================
-- 10. RLS CHO MESSAGES
-- ============================================================

alter table public.messages enable row level security;

drop policy if exists "chat_members_read_messages" on public.messages;
drop policy if exists "chat_customers_create_messages" on public.messages;
drop policy if exists "chat_customers_mark_messages_read" on public.messages;
drop policy if exists "chat_admins_manage_messages" on public.messages;
drop policy if exists "Chat - thanh vien xem tin nhan" on public.messages;
drop policy if exists "Chat - khach gui tin nhan" on public.messages;
drop policy if exists "Chat - khach danh dau da doc" on public.messages;
drop policy if exists "Chat - admin quan ly tin nhan" on public.messages;

create policy "Chat - thanh vien xem tin nhan"
on public.messages
for select
to authenticated
using (
  public.is_chat_admin()
  or exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and conversations.user_id = auth.uid()
  )
);

create policy "Chat - khach gui tin nhan"
on public.messages
for insert
to authenticated
with check (
  exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and conversations.user_id = auth.uid()
  )
  and (
    (sender_type = 'user' and sender_id = auth.uid())
    or (sender_type = 'bot' and sender_id is null)
  )
);

create policy "Chat - khach danh dau da doc"
on public.messages
for update
to authenticated
using (
  sender_type in ('admin', 'bot')
  and exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and conversations.user_id = auth.uid()
  )
)
with check (
  sender_type in ('admin', 'bot')
  and exists (
    select 1
    from public.conversations
    where conversations.id = messages.conversation_id
      and conversations.user_id = auth.uid()
  )
);

create policy "Chat - admin quan ly tin nhan"
on public.messages
for all
to authenticated
using (public.is_chat_admin())
with check (
  public.is_chat_admin()
  and sender_type in ('user', 'admin', 'bot')
);

-- ============================================================
-- 11. BAT SUPABASE REALTIME
-- ============================================================

do $$
declare
  chat_table text;
begin
  foreach chat_table in array array['conversations', 'messages']
  loop
    if not exists (
      select 1
      from pg_publication as publication
      join pg_publication_rel as publication_relation
        on publication_relation.prpubid = publication.oid
      join pg_class as table_class
        on table_class.oid = publication_relation.prrelid
      join pg_namespace as table_schema
        on table_schema.oid = table_class.relnamespace
      where publication.pubname = 'supabase_realtime'
        and table_schema.nspname = 'public'
        and table_class.relname = chat_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        chat_table
      );
    end if;
  end loop;
end;
$$;

-- ============================================================
-- 12. CAC LENH KIEM TRA SAU KHI RUN
-- Bo dau -- tung dong neu muon kiem tra.
-- ============================================================

-- select count(*) as so_hoi_thoai from public.conversations;
-- select count(*) as so_tin_nhan from public.messages;
-- select * from public.conversations order by last_message_at desc limit 20;
-- select * from public.messages order by created_at desc limit 50;
