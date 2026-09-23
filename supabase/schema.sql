-- Violet Bloom / Supabase schema
-- Run this script in Supabase SQL Editor before using the real account and order flows.

create extension if not exists pgcrypto;

do $$ begin
  create type public.order_status as enum ('new', 'processing', 'delivering', 'delivered', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.user_role as enum ('customer', 'admin');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  city text,
  address text,
  avatar_url text,
  role public.user_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  subtitle text not null default '',
  description text not null default '',
  price integer not null check (price >= 0),
  category text not null default 'Авторские',
  image_url text,
  tag text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null default ('VB-' || floor(extract(epoch from now()))::bigint),
  user_id uuid not null references public.profiles(id) on delete restrict,
  status public.order_status not null default 'new',
  customer_name text not null,
  phone text not null,
  city text not null,
  address text not null,
  comment text,
  total integer not null check (total >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price integer not null check (unit_price >= 0),
  quantity integer not null check (quantity > 0),
  line_total integer not null check (line_total >= 0)
);

create index if not exists orders_user_id_idx on public.orders(user_id);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists order_items_order_id_idx on public.order_items(order_id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
drop trigger if exists products_updated_at on public.products;
create trigger products_updated_at before update on public.products for each row execute procedure public.set_updated_at();
drop trigger if exists orders_updated_at on public.orders;
create trigger orders_updated_at before update on public.orders for each row execute procedure public.set_updated_at();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles for select using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles for update using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select using (is_active = true or public.is_admin());
drop policy if exists products_admin_write on public.products;
create policy products_admin_write on public.products for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists orders_customer_insert on public.orders;
create policy orders_customer_insert on public.orders for insert with check (user_id = auth.uid());
drop policy if exists orders_customer_read on public.orders;
create policy orders_customer_read on public.orders for select using (user_id = auth.uid() or public.is_admin());
drop policy if exists orders_admin_update on public.orders;
create policy orders_admin_update on public.orders for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists order_items_customer_read on public.order_items;
create policy order_items_customer_read on public.order_items for select using (exists (select 1 from public.orders o where o.id = order_id and (o.user_id = auth.uid() or public.is_admin())));
drop policy if exists order_items_customer_insert on public.order_items;
create policy order_items_customer_insert on public.order_items for insert with check (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));
drop policy if exists order_items_admin_all on public.order_items;
create policy order_items_admin_all on public.order_items for all using (public.is_admin()) with check (public.is_admin());

-- Seed catalog. Image URLs can be replaced with Supabase Storage URLs after uploading generated assets.
insert into public.products (slug, name, subtitle, description, price, category, tag, sort_order)
values
 ('quiet-garden','Тихий сад','Пионы · эвкалипт · лен','Авторская композиция с мягкой сиреневой нотой.',6900,'Авторские','Хит',1),
 ('white-line','Белая линия','Ранункулюсы · маттиола','Чистая минималистичная форма и светлая фактура.',5400,'Минимализм',null,2),
 ('after-rain','После дождя','Ирисы · розы · мох','Глубокий букет с прохладным послевкусием.',8200,'Авторские','Новинка',3),
 ('little-gesture','Маленький жест','Лимониум · ромашка','Компактный букет для важного сообщения.',3200,'Компактные',null,4),
 ('midnight-bouquet','Полуночный букет','Каллы · анемоны · рускус','Контрастная премиальная композиция.',9700,'Премиум',null,5),
 ('light-in-window','Свет в окне','Тюльпаны · мимоза · фрезия','Сезонное настроение с солнечным характером.',6100,'Сезонные',null,6),
 ('violet-signal','Violet Signal','Аллиумы · сирень · эвкалипт','Графичный букет с фиолетовым акцентом.',7600,'Авторские',null,7),
 ('soft-focus','Soft Focus','Розы · лизиантус · сухоцветы','Мягкая романтичная композиция.',7300,'Авторские',null,8),
 ('green-room','Green Room','Папоротник · астрация · фиалки','Свежая зелёная композиция с лесным ритмом.',6800,'Сезонные',null,9),
 ('last-light','Last Light','Далии · ирисы · сухие травы','Выразительный букет в оттенках сумерек.',8900,'Премиум',null,10)
on conflict (slug) do update set name = excluded.name, subtitle = excluded.subtitle, price = excluded.price, category = excluded.category, tag = excluded.tag, sort_order = excluded.sort_order;

-- After creating your admin account in Supabase Auth, run this one-time statement with its UUID:
-- update public.profiles set role = 'admin' where id = 'YOUR_AUTH_USER_UUID';

-- Optional Storage bucket for generated bouquet images:
-- insert into storage.buckets (id, name, public) values ('bouquets', 'bouquets', true) on conflict do nothing;
-- create policy "Public bouquet images" on storage.objects for select using (bucket_id = 'bouquets');
-- create policy "Admins upload bouquet images" on storage.objects for insert with check (bucket_id = 'bouquets' and public.is_admin());

-- Admin credentials are intentionally not embedded in SQL. Create the account in Supabase Auth,
-- then promote it with the profile update above.
