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
create policy "Approved organizers manage venues" on public.venues for all to authenticated
using (exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid()) and o.status = 'approved'::public.organizer_status))
with check (exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid()) and o.status = 'approved'::public.organizer_status));

create policy "Owners read payment methods" on public.organizer_payment_methods for select to authenticated using (private.owns_organizer(organizer_id));
create policy "Owners add payment methods" on public.organizer_payment_methods for insert to authenticated with check (private.owns_organizer(organizer_id) and verification_status = 'pending'::public.verification_status and active = false);
create policy "Owners update payment methods" on public.organizer_payment_methods for update to authenticated using (private.owns_organizer(organizer_id)) with check (private.owns_organizer(organizer_id) and verification_status in ('pending'::public.verification_status, 'inactive'::public.verification_status) and active = false);
create policy "Published event payment details are public" on public.organizer_payment_methods for select to anon, authenticated using (verification_status = 'verified'::public.verification_status and active and exists (select 1 from public.events e where e.payment_method_id = id and e.status = 'published'::public.event_status));

create policy "Published events and owner events are readable" on public.events for select to anon, authenticated using (status = 'published'::public.event_status or exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid())));
create policy "Approved organizers submit events" on public.events for insert to authenticated with check (status = 'pending_approval'::public.event_status and exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid()) and o.status = 'approved'::public.organizer_status));
create policy "Owners edit unapproved events" on public.events for update to authenticated
using (
  exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid()))
  and status in ('draft'::public.event_status, 'pending_approval'::public.event_status)
)
with check (
  exists (select 1 from public.organizers o where o.id = organizer_id and o.user_id = (select auth.uid()))
  and status in ('draft'::public.event_status, 'pending_approval'::public.event_status)
  and (
    payment_method_id is null
    or exists (
      select 1 from public.organizer_payment_methods pm
      where pm.id = payment_method_id and pm.organizer_id = organizer_id
        and pm.active and pm.verification_status = 'verified'::public.verification_status
    )
  )
  and (
    not exists (select 1 from public.ticket_types tt where tt.event_id = events.id and tt.active and tt.price_ugx > 0)
    or exists (
      select 1 from public.organizer_payment_methods pm
      where pm.id = payment_method_id and pm.organizer_id = organizer_id
        and pm.active and pm.verification_status = 'verified'::public.verification_status
    )
  )
);

create policy "Published ticket types are public" on public.ticket_types for select to anon, authenticated using (active and exists (select 1 from public.events e where e.id = event_id and e.status = 'published'::public.event_status));
create policy "Owners manage unapproved ticket types" on public.ticket_types for all to authenticated
using (exists (select 1 from public.events e where e.id = event_id and private.owns_event(e.id) and e.status in ('draft'::public.event_status, 'pending_approval'::public.event_status)))
with check (exists (select 1 from public.events e where e.id = event_id and private.owns_event(e.id) and e.status in ('draft'::public.event_status, 'pending_approval'::public.event_status)));

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
grant select, insert, update, delete on public.venues to authenticated;
grant select, insert, update on public.organizer_payment_methods to authenticated;
grant update (title, description, poster_url, category_id, venue_id, payment_method_id, starts_at, ends_at) on public.events to authenticated;
grant update (name, description, price_ugx, quantity, active) on public.ticket_types to authenticated;
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


-- Reserve inventory atomically; a repeated idempotency key returns the original order.
create or replace function public.create_ticket_order(
  p_ticket_type_id uuid,
  p_quantity integer,
  p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  buyer_id uuid := auth.uid();
  ticket_row public.ticket_types%rowtype;
  event_row public.events%rowtype;
  organizer_row public.organizers%rowtype;
  method_row public.organizer_payment_methods%rowtype;
  rule_row public.platform_fee_rules%rowtype;
  v_order_id uuid;
  item_id uuid;
  total_ugx bigint;
  fee_ugx bigint := 0;
begin
  if buyer_id is null then raise exception 'Authentication required'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 10 then
    raise exception 'Quantity must be between 1 and 10';
  end if;
  if p_idempotency_key is null or char_length(p_idempotency_key) < 8 or char_length(p_idempotency_key) > 128 then
    raise exception 'Invalid idempotency key';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(buyer_id::text || ':' || p_idempotency_key, 0));

  select o.id into v_order_id
  from public.orders o
  where o.user_id = buyer_id and o.idempotency_key = p_idempotency_key;
  if v_order_id is not null then
    if exists (
      select 1 from public.order_items oi
      where oi.order_id = v_order_id and oi.ticket_type_id = p_ticket_type_id and oi.quantity = p_quantity
    ) then return v_order_id; end if;
    raise exception 'Idempotency key was reused with different order details';
  end if;

  select * into ticket_row
  from public.ticket_types tt
  where tt.id = p_ticket_type_id and tt.active
  for update;
  if not found then raise exception 'Ticket type not found or inactive'; end if;

  -- Re-check after locking inventory so concurrent retries with the same key
  -- return the first order instead of reserving inventory twice.
  select o.id into v_order_id
  from public.orders o
  where o.user_id = buyer_id and o.idempotency_key = p_idempotency_key;
  if v_order_id is not null then
    if exists (
      select 1 from public.order_items oi
      where oi.order_id = v_order_id and oi.ticket_type_id = p_ticket_type_id and oi.quantity = p_quantity
    ) then return v_order_id; end if;
    raise exception 'Idempotency key was reused with different order details';
  end if;

  select * into event_row from public.events e where e.id = ticket_row.event_id;
  if not found or event_row.status <> 'published'::public.event_status or event_row.ends_at <= now() then
    raise exception 'Event is not available for booking';
  end if;
  select * into organizer_row from public.organizers o
  where o.id = event_row.organizer_id for share;
  if not found or organizer_row.status <> 'approved'::public.organizer_status then
    raise exception 'Organizer is not approved for ticket sales';
  end if;

  if event_row.payment_method_id is not null then
    select * into method_row
    from public.organizer_payment_methods pm
    where pm.id = event_row.payment_method_id
      and pm.organizer_id = event_row.organizer_id
      and pm.active
      and pm.verification_status = 'verified'::public.verification_status
    for share;
  end if;

  total_ugx := ticket_row.price_ugx * p_quantity;
  if total_ugx > 0 and method_row.id is null then
    raise exception 'Event has no verified active payment method';
  end if;
  if ticket_row.sold_quantity + p_quantity > ticket_row.quantity then
    raise exception 'Insufficient ticket inventory';
  end if;

  update public.ticket_types
  set sold_quantity = sold_quantity + p_quantity
  where id = ticket_row.id;

  insert into public.orders (user_id, event_id, total_amount_ugx, status, idempotency_key, paid_at)
  values (buyer_id, event_row.id, total_ugx,
    case when total_ugx = 0 then 'paid'::public.order_status else 'payment_pending'::public.order_status end,
    p_idempotency_key, case when total_ugx = 0 then now() else null end)
  returning id into v_order_id;

  insert into public.order_items (order_id, ticket_type_id, quantity, unit_price_ugx, subtotal_ugx)
  values (v_order_id, ticket_row.id, p_quantity, ticket_row.price_ugx, total_ugx)
  returning id into item_id;

  if total_ugx = 0 then
    insert into public.tickets (order_item_id, event_id, user_id, ticket_type_id, unique_code, qr_payload)
    select item_id, event_row.id, buyer_id, ticket_row.id, code.value, code.value
    from generate_series(1, p_quantity) as ticket_number(n)
    cross join lateral (
      select upper(encode(public.gen_random_bytes(8), 'hex')) as value
      where ticket_number.n > 0
    ) code;

    select * into rule_row from public.platform_fee_rules r
    where r.active and r.effective_from <= now() and (r.effective_to is null or r.effective_to > now())
    order by r.effective_from desc limit 1;
    if found and rule_row.free_event_policy = 'fixed'::public.free_event_policy then
      if rule_row.basis = 'per_order'::public.fee_basis then
        fee_ugx := rule_row.fixed_amount_ugx;
      else
        fee_ugx := p_quantity * rule_row.fixed_amount_ugx;
      end if;
      if fee_ugx > 0 then
        insert into public.platform_fees (organizer_id, event_id, order_id, fee_rule_id, amount_ugx)
        values (event_row.organizer_id, event_row.id, v_order_id, rule_row.id, fee_ugx)
        on conflict (order_id, fee_rule_id) do nothing;
      end if;
    end if;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (buyer_id, 'ticket_order_created', 'order', v_order_id::text,
    jsonb_build_object('event_id', event_row.id, 'ticket_type_id', ticket_row.id, 'quantity', p_quantity, 'total_ugx', total_ugx));

  return v_order_id;
end;
$$;

create or replace function public.cancel_ticket_order(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  buyer_id uuid := auth.uid();
  order_row public.orders%rowtype;
begin
  if buyer_id is null then raise exception 'Authentication required'; end if;
  select * into order_row from public.orders o
  where o.id = p_order_id and o.user_id = buyer_id
  for update;
  if not found then raise exception 'Order not found'; end if;
  if order_row.status = 'cancelled'::public.order_status then return order_row.id; end if;
  if order_row.status <> 'payment_pending'::public.order_status then
    raise exception 'Only pending orders can be cancelled';
  end if;

  update public.ticket_types tt
  set sold_quantity = tt.sold_quantity - oi.quantity
  from public.order_items oi
  where oi.order_id = order_row.id and tt.id = oi.ticket_type_id;

  update public.orders set status = 'cancelled'::public.order_status where id = order_row.id;
  return order_row.id;
end;
$$;

-- Customers submit references as pending. This never issues a ticket.
create or replace function public.submit_payment_reference(
  p_order_id uuid,
  p_provider text,
  p_provider_reference text,
  p_amount_ugx bigint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  buyer_id uuid := auth.uid();
  order_row public.orders%rowtype;
  transaction_id uuid;
begin
  if buyer_id is null then raise exception 'Authentication required'; end if;
  if p_provider is null or char_length(trim(p_provider)) not between 2 and 80 then
    raise exception 'Invalid payment provider';
  end if;
  if p_provider_reference is null or char_length(trim(p_provider_reference)) not between 4 and 160 then
    raise exception 'Invalid payment reference';
  end if;
  if p_amount_ugx is null or p_amount_ugx < 0 then raise exception 'Invalid payment amount'; end if;

  select * into order_row from public.orders o
  where o.id = p_order_id and o.user_id = buyer_id
  for update;
  if not found or order_row.status <> 'payment_pending'::public.order_status or order_row.expires_at <= now() then
    raise exception 'Order is not awaiting payment';
  end if;

  insert into public.transactions (order_id, provider, provider_reference, amount_ugx, status, verification_source)
  values (order_row.id, trim(p_provider), trim(p_provider_reference), p_amount_ugx,
          'pending'::public.transaction_status, 'MANUAL_REFERENCE')
  returning id into transaction_id;
  return transaction_id;
end;
$$;

-- Only the trusted server-side service role can verify payments and issue tickets.
create or replace function public.verify_ticket_order_payment(
  p_order_id uuid,
  p_provider text,
  p_provider_reference text,
  p_amount_ugx bigint,
  p_verification_source text default 'MANUAL_REFERENCE'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  order_row public.orders%rowtype;
  transaction_row public.transactions%rowtype;
  rule_row public.platform_fee_rules%rowtype;
  fee_ugx bigint := 0;
  item_row record;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Trusted payment verification is restricted';
  end if;
  if p_verification_source not in ('PROVIDER', 'MANUAL_REFERENCE') then
    raise exception 'Invalid verification source';
  end if;

  select * into order_row from public.orders o where o.id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;

  if order_row.status = 'paid'::public.order_status then
    if exists (select 1 from public.transactions t where t.order_id = order_row.id
      and t.provider_reference = p_provider_reference and t.status = 'verified'::public.transaction_status) then
      return order_row.id;
    end if;
    raise exception 'Order already paid';
  end if;
  if order_row.status <> 'payment_pending'::public.order_status or order_row.expires_at <= now() then
    raise exception 'Order is not awaiting payment';
  end if;
  if p_amount_ugx <> order_row.total_amount_ugx then raise exception 'Payment amount does not match order total'; end if;
  if p_provider_reference is null or char_length(trim(p_provider_reference)) < 4 then
    raise exception 'Invalid provider reference';
  end if;

  select * into transaction_row from public.transactions t
  where t.order_id = order_row.id and t.provider_reference = trim(p_provider_reference)
  for update;
  if found then
    if transaction_row.status <> 'pending'::public.transaction_status or transaction_row.amount_ugx <> p_amount_ugx then
      raise exception 'Submitted transaction cannot be verified';
    end if;
    update public.transactions
    set provider = trim(p_provider),
        status = 'verified'::public.transaction_status,
        verified_at = now(),
        verification_source = p_verification_source
    where id = transaction_row.id;
  else
    insert into public.transactions (order_id, provider, provider_reference, amount_ugx, status, verification_source, verified_at)
    values (order_row.id, trim(p_provider), trim(p_provider_reference), p_amount_ugx,
      'verified'::public.transaction_status, p_verification_source, now());
  end if;

  update public.orders set status = 'paid'::public.order_status, paid_at = now()
  where id = order_row.id;

  for item_row in
    select oi.id, oi.ticket_type_id, oi.quantity
    from public.order_items oi where oi.order_id = order_row.id
  loop
    insert into public.tickets (order_item_id, event_id, user_id, ticket_type_id, unique_code, qr_payload)
    select item_row.id, order_row.event_id, order_row.user_id, item_row.ticket_type_id, code.value, code.value
    from generate_series(1, item_row.quantity) as ticket_number(n)
    cross join lateral (
      select upper(encode(public.gen_random_bytes(8), 'hex')) as value
      where ticket_number.n > 0
    ) code;
  end loop;

  select * into rule_row from public.platform_fee_rules r
  where r.active and r.effective_from <= now() and (r.effective_to is null or r.effective_to > now())
  order by r.effective_from desc limit 1;

  if found then
    if order_row.total_amount_ugx = 0 and rule_row.free_event_policy = 'waived'::public.free_event_policy then
      fee_ugx := 0;
    elsif rule_row.basis = 'per_order'::public.fee_basis then
      fee_ugx := round(order_row.total_amount_ugx::numeric * rule_row.percentage_bps / 10000)::bigint + rule_row.fixed_amount_ugx;
    else
      select coalesce(sum(oi.quantity * (round(oi.unit_price_ugx::numeric * rule_row.percentage_bps / 10000)::bigint + rule_row.fixed_amount_ugx)), 0)
      into fee_ugx
      from public.order_items oi where oi.order_id = order_row.id;
    end if;

    if fee_ugx > 0 then
      insert into public.platform_fees (organizer_id, event_id, order_id, fee_rule_id, amount_ugx)
      select e.organizer_id, order_row.event_id, order_row.id, rule_row.id, fee_ugx
      from public.events e where e.id = order_row.event_id
      on conflict (order_id, fee_rule_id) do nothing;
    end if;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, 'ticket_order_payment_verified', 'order', order_row.id::text,
    jsonb_build_object('provider', p_provider, 'reference', p_provider_reference, 'amount_ugx', p_amount_ugx));

  return order_row.id;
end;
$$;

create or replace function public.check_in_ticket(
  p_unique_code text,
  p_event_id uuid,
  p_method text default 'qr'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  operator_id uuid := auth.uid();
  ticket_row public.tickets%rowtype;
begin
  if operator_id is null then raise exception 'Authentication required'; end if;
  if p_method not in ('qr', 'ticket_code', 'order_reference', 'phone', 'offline_sync') then
    raise exception 'Invalid check-in method';
  end if;
  if not exists (
    select 1 from public.events e
    join public.organizers o on o.id = e.organizer_id
    where e.id = p_event_id and o.user_id = operator_id
      and o.status = 'approved'::public.organizer_status
  ) then raise exception 'Not authorized for this event'; end if;

  select * into ticket_row from public.tickets t
  where t.unique_code = p_unique_code and t.event_id = p_event_id
  for update;
  if not found then raise exception 'Ticket not found for this event'; end if;
  if ticket_row.status <> 'valid'::public.ticket_status then raise exception 'Ticket is already used or cancelled'; end if;
  if not exists (
    select 1 from public.order_items oi
    join public.orders o on o.id = oi.order_id
    where oi.id = ticket_row.order_item_id
      and o.status = 'paid'::public.order_status
  ) then raise exception 'Ticket order is not paid'; end if;

  update public.tickets set status = 'used'::public.ticket_status, checked_in_at = now() where id = ticket_row.id;
  insert into public.check_ins (ticket_id, event_id, checked_by, method)
  values (ticket_row.id, p_event_id, operator_id, p_method);
  return ticket_row.id;
end;
$$;

revoke all on function public.create_ticket_order(uuid, integer, text) from public, anon;
revoke all on function public.cancel_ticket_order(uuid) from public, anon;
revoke all on function public.submit_payment_reference(uuid, text, text, bigint) from public, anon;
revoke all on function public.verify_ticket_order_payment(uuid, text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.check_in_ticket(text, uuid, text) from public, anon;
grant execute on function public.create_ticket_order(uuid, integer, text) to authenticated;
grant execute on function public.cancel_ticket_order(uuid) to authenticated;
grant execute on function public.submit_payment_reference(uuid, text, text, bigint) to authenticated;
grant execute on function public.verify_ticket_order_payment(uuid, text, text, bigint, text) to service_role;
grant execute on function public.check_in_ticket(text, uuid, text) to authenticated;


-- Event submission is transactional: no orphan event if ticket setup fails.
create or replace function public.submit_event_with_ticket(
  p_category_id uuid,
  p_title text,
  p_description text,
  p_venue_id uuid,
  p_payment_method_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_ticket_name text,
  p_price_ugx bigint,
  p_quantity integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  organizer_row public.organizers%rowtype;
  event_id uuid;
begin
  if actor_id is null then raise exception 'Authentication required'; end if;
  select * into organizer_row from public.organizers o
  where o.user_id = actor_id for update;
  if not found or organizer_row.status <> 'approved'::public.organizer_status then
    raise exception 'Approved organizer account required';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 180 then raise exception 'Invalid event title'; end if;
  if p_ticket_name is null or char_length(trim(p_ticket_name)) not between 1 and 100 then raise exception 'Invalid ticket name'; end if;
  if p_starts_at is null or p_ends_at is null or p_starts_at <= now() or p_ends_at <= p_starts_at then
    raise exception 'Event dates are invalid';
  end if;
  if p_price_ugx is null or p_price_ugx < 0 or p_quantity is null or p_quantity < 1 or p_quantity > 100000 then
    raise exception 'Invalid ticket price or inventory';
  end if;
  if not exists (select 1 from public.categories c where c.id = p_category_id and c.active) then
    raise exception 'Category is unavailable';
  end if;
  if p_venue_id is not null and not exists (
    select 1 from public.venues v where v.id = p_venue_id and v.organizer_id = organizer_row.id
  ) then raise exception 'Venue does not belong to this organizer'; end if;
  if p_price_ugx > 0 and not exists (
    select 1 from public.organizer_payment_methods pm
    where pm.id = p_payment_method_id and pm.organizer_id = organizer_row.id
      and pm.active and pm.verification_status = 'verified'::public.verification_status
  ) then raise exception 'Paid events require a verified active payment method'; end if;

  insert into public.events (
    organizer_id, category_id, venue_id, payment_method_id, title, description,
    starts_at, ends_at, status
  ) values (
    organizer_row.id, p_category_id, p_venue_id,
    case when p_price_ugx > 0 then p_payment_method_id else null end,
    trim(p_title), nullif(trim(coalesce(p_description, '')), ''),
    p_starts_at, p_ends_at, 'pending_approval'::public.event_status
  ) returning id into event_id;

  insert into public.ticket_types (event_id, name, price_ugx, quantity)
  values (event_id, trim(p_ticket_name), p_price_ugx, p_quantity);

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (actor_id, 'event_submitted', 'event', event_id::text,
    jsonb_build_object('title', trim(p_title), 'ticket_price_ugx', p_price_ugx, 'quantity', p_quantity));
  return event_id;
end;
$$;

create or replace function public.review_organizer_application(
  p_organizer_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  organizer_row public.organizers%rowtype;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'Internal review is restricted'; end if;
  select * into organizer_row from public.organizers o where o.id = p_organizer_id for update;
  if not found then raise exception 'Organizer application not found'; end if;
  update public.organizers
  set status = case when p_approve then 'approved'::public.organizer_status else 'suspended'::public.organizer_status end,
      updated_at = now()
  where id = p_organizer_id;
  if not p_approve then
    update public.organizer_payment_methods set active = false, updated_at = now()
    where organizer_id = p_organizer_id;
    update public.events set status = 'cancelled'::public.event_status, updated_at = now()
    where organizer_id = p_organizer_id and status in ('published'::public.event_status, 'pending_approval'::public.event_status);
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, case when p_approve then 'organizer_approved' else 'organizer_suspended' end,
    'organizer', p_organizer_id::text, jsonb_build_object('reason', p_reason));
  return p_organizer_id;
end;
$$;

create or replace function public.review_event_submission(
  p_event_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_row public.events%rowtype;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'Internal review is restricted'; end if;
  select * into event_row from public.events e where e.id = p_event_id for update;
  if not found or event_row.status <> 'pending_approval'::public.event_status then
    raise exception 'Event is not awaiting review';
  end if;
  if p_approve and event_row.ends_at <= now() then raise exception 'Past events cannot be published'; end if;
  if p_approve and not exists (
    select 1 from public.organizers o where o.id = event_row.organizer_id
      and o.status = 'approved'::public.organizer_status
  ) then raise exception 'Organizer must be approved before publication'; end if;
  if p_approve and exists (
    select 1 from public.ticket_types tt where tt.event_id = event_row.id and tt.active and tt.price_ugx > 0
  ) and not exists (
    select 1 from public.organizer_payment_methods pm
    where pm.id = event_row.payment_method_id and pm.organizer_id = event_row.organizer_id
      and pm.active and pm.verification_status = 'verified'::public.verification_status
  ) then raise exception 'Paid events require a verified active payment method'; end if;
  update public.events
  set status = case when p_approve then 'published'::public.event_status else 'rejected'::public.event_status end,
      rejection_reason = case when p_approve then null else nullif(trim(coalesce(p_reason, '')), '') end,
      published_at = case when p_approve then now() else null end,
      updated_at = now()
  where id = p_event_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, case when p_approve then 'event_published' else 'event_rejected' end,
    'event', p_event_id::text, jsonb_build_object('reason', p_reason));
  return p_event_id;
end;
$$;

create or replace function public.review_organizer_payment_method(
  p_method_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  method_row public.organizer_payment_methods%rowtype;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'Internal review is restricted'; end if;
  select * into method_row from public.organizer_payment_methods pm where pm.id = p_method_id for update;
  if not found then raise exception 'Payment method not found'; end if;
  if p_approve and not exists (
    select 1 from public.organizers o where o.id = method_row.organizer_id
      and o.status = 'approved'::public.organizer_status
  ) then raise exception 'Organizer must be approved before payment verification'; end if;
  update public.organizer_payment_methods
  set verification_status = case when p_approve then 'verified'::public.verification_status else 'rejected'::public.verification_status end,
      active = p_approve,
      updated_at = now()
  where id = p_method_id;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, case when p_approve then 'payment_method_verified' else 'payment_method_rejected' end,
    'organizer_payment_method', p_method_id::text, jsonb_build_object('reason', p_reason));
  return p_method_id;
end;
$$;

create or replace function public.review_platform_fee_payment(
  p_payment_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment_row public.platform_fee_payments%rowtype;
  total_fees bigint;
  total_verified bigint;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'Internal review is restricted'; end if;
  select * into payment_row from public.platform_fee_payments p where p.id = p_payment_id for update;
  if not found or payment_row.status <> 'pending'::public.fee_payment_status then
    raise exception 'Platform fee payment is not pending';
  end if;
  update public.platform_fee_payments
  set status = case when p_approve then 'verified'::public.fee_payment_status else 'rejected'::public.fee_payment_status end,
      verified_at = case when p_approve then now() else null end
  where id = p_payment_id;

  if p_approve then
    select coalesce(sum(f.amount_ugx), 0) into total_fees
    from public.platform_fees f where f.organizer_id = payment_row.organizer_id and f.status <> 'reversed';
    select coalesce(sum(p.amount_ugx), 0) into total_verified
    from public.platform_fee_payments p where p.organizer_id = payment_row.organizer_id and p.status = 'verified';
    if total_verified > total_fees then raise exception 'Verified fee payments exceed assessed fees'; end if;
    update public.platform_fees
    set status = case
      when total_verified >= total_fees then 'paid'
      when total_verified > 0 then 'partially_paid'
      else 'outstanding'
    end
    where organizer_id = payment_row.organizer_id and status <> 'reversed';
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, case when p_approve then 'platform_fee_payment_verified' else 'platform_fee_payment_rejected' end,
    'platform_fee_payment', p_payment_id::text, jsonb_build_object('reason', p_reason));
  return p_payment_id;
end;
$$;

revoke all on function public.submit_event_with_ticket(uuid, text, text, uuid, uuid, timestamptz, timestamptz, text, bigint, integer) from public, anon;
revoke all on function public.review_organizer_application(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.review_event_submission(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.review_organizer_payment_method(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.review_platform_fee_payment(uuid, boolean, text) from public, anon, authenticated;
grant execute on function public.submit_event_with_ticket(uuid, text, text, uuid, uuid, timestamptz, timestamptz, text, bigint, integer) to authenticated;
grant execute on function public.review_organizer_application(uuid, boolean, text) to service_role;
grant execute on function public.review_event_submission(uuid, boolean, text) to service_role;
grant execute on function public.review_organizer_payment_method(uuid, boolean, text) to service_role;
grant execute on function public.review_platform_fee_payment(uuid, boolean, text) to service_role;


-- Expire abandoned pending orders and release inventory reservations atomically.
create or replace function public.expire_ticket_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  order_row public.orders%rowtype;
  expired_count integer := 0;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'Order expiry is restricted';
  end if;

  for order_row in
    select * from public.orders o
    where o.status = 'payment_pending'::public.order_status and o.expires_at <= now()
    order by o.expires_at
    for update skip locked
  loop
    update public.ticket_types tt
    set sold_quantity = tt.sold_quantity - oi.quantity
    from public.order_items oi
    where oi.order_id = order_row.id and tt.id = oi.ticket_type_id;
    update public.orders set status = 'expired'::public.order_status where id = order_row.id;
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
end;
$$;

revoke all on function public.expire_ticket_orders() from public, anon, authenticated;
grant execute on function public.expire_ticket_orders() to service_role;


-- Only one fee rule can be active at a time; rule changes are explicit and auditable.
create unique index platform_fee_rules_single_active_idx
  on public.platform_fee_rules (active) where active;

create or replace function public.upsert_platform_fee_rule(
  p_rule_id uuid,
  p_name text,
  p_percentage_bps integer,
  p_fixed_amount_ugx bigint,
  p_basis text,
  p_free_event_policy text,
  p_refund_policy text,
  p_payable_rule text,
  p_effective_from timestamptz,
  p_effective_to timestamptz,
  p_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rule_id uuid;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'Fee rule management is restricted'; end if;
  if p_name is null or char_length(trim(p_name)) not between 2 and 120 then raise exception 'Invalid fee rule name'; end if;
  if p_percentage_bps is null or p_percentage_bps not between 0 and 10000 then raise exception 'Invalid percentage basis points'; end if;
  if p_fixed_amount_ugx is null or p_fixed_amount_ugx < 0 then raise exception 'Invalid fixed fee'; end if;
  if p_basis not in ('per_ticket', 'per_order') then raise exception 'Invalid fee basis'; end if;
  if p_free_event_policy not in ('waived', 'fixed') then raise exception 'Invalid free-event policy'; end if;
  if p_refund_policy is null or char_length(trim(p_refund_policy)) not between 2 and 120 then raise exception 'Invalid refund policy';
  end if;
  if p_payable_rule is null or char_length(trim(p_payable_rule)) not between 2 and 120 then raise exception 'Invalid payable rule';
  end if;
  if p_effective_from is null or (p_effective_to is not null and p_effective_to <= p_effective_from) then
    raise exception 'Invalid effective dates';
  end if;

  if p_active then
    update public.platform_fee_rules
    set active = false
    where active and (p_rule_id is null or id <> p_rule_id);
  end if;

  if p_rule_id is null then
    insert into public.platform_fee_rules (
      name, percentage_bps, fixed_amount_ugx, basis, free_event_policy,
      refund_policy, payable_rule, active, effective_from, effective_to
    ) values (
      trim(p_name), p_percentage_bps, p_fixed_amount_ugx, p_basis::public.fee_basis,
      p_free_event_policy::public.free_event_policy, trim(p_refund_policy),
      trim(p_payable_rule), p_active, p_effective_from, p_effective_to
    ) returning id into rule_id;
  else
    update public.platform_fee_rules
    set name = trim(p_name), percentage_bps = p_percentage_bps,
        fixed_amount_ugx = p_fixed_amount_ugx, basis = p_basis::public.fee_basis,
        free_event_policy = p_free_event_policy::public.free_event_policy,
        refund_policy = trim(p_refund_policy), payable_rule = trim(p_payable_rule),
        active = p_active, effective_from = p_effective_from, effective_to = p_effective_to
    where id = p_rule_id
    returning id into rule_id;
    if rule_id is null then raise exception 'Fee rule not found'; end if;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, 'platform_fee_rule_upserted', 'platform_fee_rule', rule_id::text,
    jsonb_build_object('name', trim(p_name), 'active', p_active, 'basis', p_basis,
      'percentage_bps', p_percentage_bps, 'fixed_amount_ugx', p_fixed_amount_ugx));
  return rule_id;
end;
$$;

create or replace function public.set_category_active(p_category_id uuid, p_active boolean)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  category_id uuid;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then raise exception 'Category management is restricted'; end if;
  update public.categories set active = p_active where id = p_category_id returning id into category_id;
  if category_id is null then raise exception 'Category not found'; end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, metadata)
  values (null, case when p_active then 'category_activated' else 'category_deactivated' end,
    'category', category_id::text, jsonb_build_object('active', p_active));
  return category_id;
end;
$$;

revoke all on function public.upsert_platform_fee_rule(uuid, text, integer, bigint, text, text, text, text, timestamptz, timestamptz, boolean) from public, anon, authenticated;
revoke all on function public.set_category_active(uuid, boolean) from public, anon, authenticated;
grant execute on function public.upsert_platform_fee_rule(uuid, text, integer, bigint, text, text, text, text, timestamptz, timestamptz, boolean) to service_role;
grant execute on function public.set_category_active(uuid, boolean) to service_role;
