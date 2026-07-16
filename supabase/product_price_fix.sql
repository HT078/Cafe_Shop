-- ============================================================
-- SUA GIA SAN PHAM - CA PHE HAI TIN
-- Chay mot lan trong Supabase Dashboard > SQL Editor.
-- Dong bo schema gia moi va schema cu theo 250g/500g/1kg.
-- ============================================================

alter table public.products
  add column if not exists price integer default 0,
  add column if not exists price_250g integer default 0,
  add column if not exists price_500g integer default 0,
  add column if not exists price_1kg integer default 0,
  add column if not exists prices_by_weight jsonb default '{}'::jsonb;

update public.products
set price = case
  when coalesce(price, 0) > 0 then price
  when coalesce(price_500g, 0) > 0 then price_500g
  when coalesce(price_250g, 0) > 0 then price_250g
  else coalesce(price_1kg, 0)
end;

update public.products
set prices_by_weight = jsonb_build_object(
  '250g', coalesce(price_250g, 0),
  '500g', coalesce(price_500g, price, 0),
  '1kg', coalesce(price_1kg, 0)
)
where prices_by_weight is null
   or prices_by_weight = '{}'::jsonb;

select id, name, price, price_250g, price_500g, price_1kg, prices_by_weight
from public.products
order by name;
