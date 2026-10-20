-- Milky Events V1 core schema.
-- Public users are event-goers or organizers; internal platform controls stay private.
create extension if not exists pgcrypto;

create type public.profile_role as enum ('event_goer', 'organizer');
create type public.organizer_status as enum ('pending', 'approved', 'suspended');
create type public.event_status as enum ('draft', 'pending_approval', 'published', 'rejected', 'cancelled', 'completed');
create type public.payment_method_kind as enum ('airtel_money', 'mtn_momo', 'bank_transfer', 'card', 'other');
create type public.verification_status as enum ('pending', 'verified', 'rejected', 'inactive');
create type public.order_status as enum ('payment_pending', 'paid', 'failed', 'expired', 'cancelled');
create type public.ticket_status as enum ('valid', 'used', 'cancelled');
create type public.transaction_status as enum ('pending', 'verified', 'rejected');
create type public.fee_basis as enum ('per_ticket', 'per_order');
create type public.free_event_policy as enum ('waived', 'fixed');
create type public.fee_payment_status as enum ('pending', 'verified', 'rejected');

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.profile_role not null default 'event_goer',
  display_name text not null default '',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.organizers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 160),
  description text,
  contact_phone text not null,
  status public.organizer_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.venues (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.organizers(id) on delete restrict,
  name text not null,
  address text not null,
  area text not null default 'Mbarara',
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create table public.organizer_payment_methods (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.organizers(id) on delete restrict,
  method public.payment_method_kind not null,
  provider text not null,
  account_identifier text not null,
  account_name text not null,
  verification_status public.verification_status not null default 'pending',
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organizer_id, method, account_identifier)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.organizers(id) on delete restrict,
  category_id uuid not null references public.categories(id) on delete restrict,
  venue_id uuid references public.venues(id) on delete restrict,
  payment_method_id uuid references public.organizer_payment_methods(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 3 and 180),
  description text,
  poster_url text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.event_status not null default 'draft',
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  check (ends_at > starts_at)
);

create table public.ticket_types (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete restrict,
  name text not null,
  description text,
  price_ugx bigint not null check (price_ugx >= 0),
  quantity integer not null check (quantity > 0),
  sold_quantity integer not null default 0 check (sold_quantity >= 0 and sold_quantity <= quantity),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (event_id, name)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  total_amount_ugx bigint not null check (total_amount_ugx >= 0),
  status public.order_status not null default 'payment_pending',
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 128),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  unique (user_id, idempotency_key)
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  ticket_type_id uuid not null references public.ticket_types(id) on delete restrict,
  quantity integer not null check (quantity between 1 and 10),
  unit_price_ugx bigint not null check (unit_price_ugx >= 0),
  subtotal_ugx bigint not null check (subtotal_ugx >= 0),
  created_at timestamptz not null default now(),
  check (subtotal_ugx = quantity * unit_price_ugx)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  provider text not null,
  provider_reference text not null unique,
  amount_ugx bigint not null check (amount_ugx >= 0),
  currency text not null default 'UGX' check (currency = 'UGX'),
  status public.transaction_status not null default 'pending',
  verification_source text not null check (verification_source in ('PROVIDER', 'MANUAL_REFERENCE')),
  created_at timestamptz not null default now(),
  verified_at timestamptz
);

create table public.tickets (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  ticket_type_id uuid not null references public.ticket_types(id) on delete restrict,
  unique_code text not null unique,
  qr_payload text not null unique,
  status public.ticket_status not null default 'valid',
  issued_at timestamptz not null default now(),
  checked_in_at timestamptz
);

create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  checked_by uuid not null references public.profiles(id) on delete restrict,
  checked_at timestamptz not null default now(),
  method text not null check (method in ('qr', 'ticket_code', 'order_reference', 'phone', 'offline_sync')),
  device_id text,
  unique (ticket_id)
);

create table public.platform_fee_rules (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  percentage_bps integer not null default 0 check (percentage_bps between 0 and 10000),
  fixed_amount_ugx bigint not null default 0 check (fixed_amount_ugx >= 0),
  basis public.fee_basis not null,
  free_event_policy public.free_event_policy not null default 'waived',
  refund_policy text not null default 'reverse_on_full_refund',
  payable_rule text not null default 'after_ticket_sale',
  active boolean not null default false,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from)
);

create table public.platform_fees (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.organizers(id) on delete restrict,
  event_id uuid not null references public.events(id) on delete restrict,
  order_id uuid not null references public.orders(id) on delete restrict,
  fee_rule_id uuid not null references public.platform_fee_rules(id) on delete restrict,
  amount_ugx bigint not null check (amount_ugx >= 0),
  status text not null default 'outstanding' check (status in ('outstanding', 'partially_paid', 'paid', 'reversed')),
  created_at timestamptz not null default now(),
  reversed_at timestamptz,
  unique (order_id, fee_rule_id)
);

create table public.platform_fee_payments (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.organizers(id) on delete restrict,
  amount_ugx bigint not null check (amount_ugx > 0),
  payment_method text not null check (payment_method in ('airtel_money', 'bank_transfer', 'other')),
  payment_reference text not null,
  status public.fee_payment_status not null default 'pending',
  submitted_at timestamptz not null default now(),
  verified_at timestamptz,
  verified_by uuid references auth.users(id) on delete set null,
  unique (payment_method, payment_reference)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index events_discovery_idx on public.events (status, starts_at);
create index events_organizer_idx on public.events (organizer_id, created_at desc);
create index ticket_types_event_idx on public.ticket_types (event_id, active);
create index orders_user_idx on public.orders (user_id, created_at desc);
create index orders_event_idx on public.orders (event_id, status);
create index order_items_order_idx on public.order_items (order_id);
create index transactions_order_idx on public.transactions (order_id);
create index tickets_user_idx on public.tickets (user_id, issued_at desc);
create index tickets_event_idx on public.tickets (event_id, status);
create index check_ins_event_idx on public.check_ins (event_id, checked_at desc);
create index platform_fees_organizer_idx on public.platform_fees (organizer_id, status);
create index platform_fee_payments_organizer_idx on public.platform_fee_payments (organizer_id, submitted_at desc);

create or replace function private.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, role, display_name)
  values (new.id, 'event_goer'::public.profile_role,
          coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'Event-goer'));
  return new;
end;
$$;
revoke all on function private.create_profile_for_new_user() from public, anon, authenticated;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.create_profile_for_new_user();

create or replace function private.owns_organizer(organizer_key uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.organizers o
    where o.id = organizer_key and o.user_id = (select auth.uid())
  );
$$;

create or replace function private.owns_event(event_key uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.events e
    join public.organizers o on o.id = e.organizer_id
    where e.id = event_key and o.user_id = (select auth.uid())
      and o.status = 'approved'::public.organizer_status
  );
$$;

revoke all on function private.owns_organizer(uuid) from public, anon;
revoke all on function private.owns_event(uuid) from public, anon;
grant execute on function private.owns_organizer(uuid) to authenticated;
grant execute on function private.owns_event(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.organizers enable row level security;
alter table public.venues enable row level security;
alter table public.organizer_payment_methods enable row level security;
alter table public.events enable row level security;
alter table public.ticket_types enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.transactions enable row level security;
alter table public.tickets enable row level security;
alter table public.check_ins enable row level security;
alter table public.platform_fee_rules enable row level security;
alter table public.platform_fees enable row level security;
alter table public.platform_fee_payments enable row level security;
alter table public.audit_logs enable row level security;

create policy "Users read own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "Users update own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()) and role = 'event_goer'::public.profile_role);

create policy "Active categories are public" on public.categories for select to anon, authenticated using (active);
create policy "Organizers read own profile" on public.organizers for select to authenticated using (user_id = (select auth.uid()));
create policy "Organizers apply for themselves" on public.organizers for insert to authenticated with check (user_id = (select auth.uid()) and status = 'pending'::public.organizer_status);
create policy "Public sees approved organizers" on public.organizers for select to anon, authenticated using (status = 'approved'::public.organizer_status);
create policy "Owners read venues" on public.venues for select to authenticated using (private.owns_organizer(organizer_id));
create policy "Approved organizers manage venues" on public.venues for all to authenticated using (private.owns_organizer(organizer_id)) with check (private.owns_organizer(organizer_id));

create policy "Owners read payment methods" on public.organizer_payment_methods for select to authenticated using (private.owns_organizer(organizer_id));
create policy "Owners add payment methods" on public.organizer_payment_methods for insert to authenticated with check (private.owns_organizer(organizer_id) and verification_status = 'pending'::public.verification_status and active = false);
create policy "Owners update payment methods" on public.organizer_payment_methods for update to authenticated using (private.owns_organizer(organizer_id)) with check (private.owns_organizer(organizer_id) and verification_status in ('pending'::public.verification_status, 'inactive'::public.verification_status) and active = false);
create policy "Published event payment details are public" on public.organizer_payment_methods for select to anon, authenticated using (verification_status = 'verified'::public.verification_status and active and exists (select 1 from public.events e where e.payment_method_id = id and e.status = 'published'::public.event_status));

create policy "Published events and owner events are readable" on public.events for select to anon, authenticated using (status = 'published'::public.event_status or exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid())));
create policy "Approved organizers submit events" on public.events for insert to authenticated with check (status = 'pending_approval'::public.event_status and exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid()) and o.status = 'approved'::public.organizer_status));
create policy "Owners edit unapproved events" on public.events for update to authenticated using (exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid())) and status in ('draft'::public.event_status, 'pending_approval'::public.event_status)) with check (exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid())) and status in ('draft'::public.event_status, 'pending_approval'::public.event_status));

create policy "Published ticket types are public" on public.ticket_types for select to anon, authenticated using (active and exists (select 1 from public.events e where e.id = event_id and e.status = 'published'::public.event_status));
create policy "Event owners manage ticket types" on public.ticket_types for all to authenticated using (exists (select 1 from public.events e where e.id = event_id and private.owns_event(e.id))) with check (exists (select 1 from public.events e where e.id = event_id and private.owns_event(e.id)));

create policy "Users read own orders" on public.orders for select to authenticated using (user_id = (select auth.uid()));
create policy "Users read own order items" on public.order_items for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = (select auth.uid())));
create policy "Users read own transactions" on public.transactions for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = (select auth.uid())));
create policy "Users read own tickets and event owners read attendees" on public.tickets for select to authenticated using (user_id = (select auth.uid()) or private.owns_event(event_id));
create policy "Event owners read check-ins" on public.check_ins for select to authenticated using (private.owns_event(event_id));
create policy "Organizers read own platform fees" on public.platform_fees for select to authenticated using (private.owns_organizer(organizer_id));
create policy "Organizers submit own fee payments" on public.platform_fee_payments for insert to authenticated with check (private.owns_organizer(organizer_id) and status = 'pending'::public.fee_payment_status and verified_at is null and verified_by is null);
create policy "Organizers read own fee payments" on public.platform_fee_payments for select to authenticated using (private.owns_organizer(organizer_id));

grant usage on schema public to anon, authenticated;
grant select on public.categories, public.events, public.ticket_types, public.organizers, public.organizer_payment_methods to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert on public.organizers to authenticated;
grant select, insert, update, delete on public.venues, public.organizer_payment_methods, public.events, public.ticket_types to authenticated;
grant select on public.orders, public.order_items, public.transactions, public.tickets, public.check_ins, public.platform_fees, public.platform_fee_payments to authenticated;
grant insert on public.platform_fee_payments to authenticated;

insert into public.categories (slug, name, description) values
('music-nightlife','Music & Nightlife','Live music, DJs, concerts and nightlife'),
('business-networking','Business & Networking','Business meetups, founders and professional networking'),
('arts-culture','Arts & Culture','Art, theatre, exhibitions and cultural experiences'),
('food-drink','Food & Drink','Food festivals, tastings and culinary events'),
('sports-fitness','Sports & Fitness','Sports, tournaments, fitness and active living'),
('education','Education','Workshops, seminars and learning'),
('family-kids','Family & Kids','Family-friendly and children’s activities'),
('faith-community','Faith & Community','Faith gatherings and community events'),
('health-wellness','Health & Wellness','Health awareness and wellbeing'),
('technology','Technology','Technology, innovation and digital skills'),
('markets-shopping','Markets & Shopping','Markets, pop-ups and shopping experiences'),
('charity-causes','Charity & Causes','Fundraisers, volunteering and causes')
on conflict (slug) do update set name = excluded.name, description = excluded.description, active = true;
