-- DIA CHI GIAO HANG - CA PHE HAI TIN
-- Chay file nay trong Supabase Dashboard > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  province text not null,
  district text not null,
  ward text not null,
  detail_address text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.addresses enable row level security;

drop policy if exists "Dia chi - khach tu quan ly" on public.addresses;
create policy "Dia chi - khach tu quan ly"
on public.addresses
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create index if not exists addresses_user_default_idx
on public.addresses(user_id, is_default desc, created_at desc);

create or replace function public.set_address_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists addresses_set_updated_at on public.addresses;
create trigger addresses_set_updated_at
before update on public.addresses
for each row execute function public.set_address_updated_at();

select id, user_id, full_name, phone, province, district, ward,
       detail_address, is_default, created_at, updated_at
from public.addresses
limit 1;
