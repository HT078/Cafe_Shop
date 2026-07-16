-- ============================================================
-- CAU HINH THANH TOAN - CA PHE HAI TIN
-- Chay toan bo file nay trong Supabase Dashboard > SQL Editor.
-- App Flutter doc bang public.payment_info.
-- ============================================================

create extension if not exists pgcrypto;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and lower(coalesce(to_jsonb(profiles) ->> 'role', '')) = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create table if not exists public.payment_info (
  id uuid primary key default gen_random_uuid(),
  method text not null unique check (method in ('vietqr', 'momo', 'zalopay')),
  account_name text not null,
  account_number text not null,
  bank_name text,
  bank_code text,
  qr_image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payment_info enable row level security;

drop policy if exists "Payment info public read" on public.payment_info;
create policy "Payment info public read"
on public.payment_info
for select
to anon, authenticated
using (is_active = true);

drop policy if exists "Payment info admin insert" on public.payment_info;
create policy "Payment info admin insert"
on public.payment_info
for insert
to authenticated
with check (public.is_admin());

drop policy if exists "Payment info admin update" on public.payment_info;
create policy "Payment info admin update"
on public.payment_info
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Payment info admin delete" on public.payment_info;
create policy "Payment info admin delete"
on public.payment_info
for delete
to authenticated
using (public.is_admin());

insert into public.payment_info
  (method, account_name, account_number, bank_name, bank_code, is_active)
values
  ('vietqr', 'HOANG NGHIA TIN', '96247HAITIN', 'BIDV', 'BIDV', true),
  ('momo', 'Hai Tin Ca Phe', '0909000000', null, null, true),
  ('zalopay', 'Hai Tin Ca Phe', '0909000000', null, null, true)
on conflict (method) do update set
  account_name = excluded.account_name,
  account_number = excluded.account_number,
  bank_name = excluded.bank_name,
  bank_code = excluded.bank_code,
  is_active = excluded.is_active,
  updated_at = now();

select method, account_name, account_number, bank_name, bank_code, is_active
from public.payment_info
order by method;
