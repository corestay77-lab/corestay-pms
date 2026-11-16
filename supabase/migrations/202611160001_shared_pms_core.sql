-- CoreStay PMS shared database foundation
-- Supabase/PostgreSQL migration. Additive only: does not read, alter, or delete browser localStorage.
-- Apply only to a NEW/approved Supabase project after reviewing the migration plan.

create extension if not exists pgcrypto;

create table if not exists public.hotels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'Asia/Makassar',
  business_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.hotel_memberships (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','front_office','housekeeping','outlet','inventory','purchasing','accounting','auditor')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (hotel_id, user_id)
);

create or replace function public.is_hotel_member(target_hotel uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.hotel_memberships m
    where m.hotel_id = target_hotel and m.user_id = auth.uid() and m.active
  );
$$;

create or replace function public.has_hotel_role(target_hotel uuid, allowed_roles text[])
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.hotel_memberships m
    where m.hotel_id = target_hotel and m.user_id = auth.uid()
      and m.active and m.role = any(allowed_roles)
  );
$$;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  room_no text not null,
  room_type text not null,
  floor text,
  bed text,
  status text not null default 'VC' check (status in ('VC','VD','OC','OO')),
  notes text,
  active boolean not null default true,
  unique (hotel_id, room_no)
);

create table if not exists public.rate_codes (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  code text not null,
  room_type text not null,
  name text,
  room_rate numeric(18,2) not null default 0,
  breakfast_rate numeric(18,2) not null default 0,
  service_rate numeric(8,4) not null default 0.10,
  tax_rate numeric(8,4) not null default 0.10,
  active boolean not null default true,
  unique (hotel_id, code, room_type)
);

create table if not exists public.guests (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  guest_code text,
  full_name text not null,
  id_type text,
  id_number text,
  nationality text,
  city text,
  phone text,
  email text,
  address text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  customer_code text not null,
  name text not null,
  segment text,
  address text,
  city text,
  phone text,
  email text,
  credit_limit numeric(18,2) not null default 0,
  active boolean not null default true,
  unique (hotel_id, customer_code)
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  supplier_code text not null,
  name text not null,
  address text,
  city text,
  phone text,
  email text,
  active boolean not null default true,
  unique (hotel_id, supplier_code)
);

-- Reservation header and room-level detail follow R_RESV / R_RESVD.
create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  reservation_no text not null,
  guest_id uuid references public.guests(id),
  guest_name text not null,
  booking_source text,
  status text not null default 'RS' check (status in ('RS','CI','CX','NS')),
  arrival_date date not null,
  departure_date date not null,
  persons integer not null default 1 check (persons > 0),
  customer_id uuid references public.customers(id),
  remarks text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (hotel_id, reservation_no),
  check (departure_date > arrival_date)
);

create table if not exists public.reservation_rooms (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  room_id uuid references public.rooms(id),
  room_no_snapshot text not null,
  room_type_snapshot text not null,
  rate_code text,
  room_rate numeric(18,2) not null default 0,
  breakfast_rate numeric(18,2) not null default 0,
  service_amount numeric(18,2) not null default 0,
  tax_amount numeric(18,2) not null default 0,
  total_amount numeric(18,2) not null default 0,
  status text not null default 'RS' check (status in ('RS','CI','CX','NS'))
);

create table if not exists public.stays (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  registration_no text not null,
  reservation_id uuid references public.reservations(id),
  reservation_room_id uuid references public.reservation_rooms(id),
  guest_id uuid references public.guests(id),
  guest_name text not null,
  room_id uuid references public.rooms(id),
  room_no_snapshot text not null,
  checkin_at timestamptz not null default now(),
  planned_checkout date not null,
  actual_checkout_at timestamptz,
  status text not null default 'IN_HOUSE' check (status in ('IN_HOUSE','CHECKED_OUT','VOID')),
  created_by uuid references auth.users(id),
  unique (hotel_id, registration_no)
);

create table if not exists public.folios (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  folio_no text not null,
  stay_id uuid references public.stays(id),
  customer_id uuid references public.customers(id),
  status text not null default 'OPEN' check (status in ('OPEN','CLOSED','TRANSFERRED')),
  currency text not null default 'IDR',
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  unique (hotel_id, folio_no)
);

-- Source transaction codes retain HOTELINDO terminology: RM, BF, D, E, R, K, KH.
create table if not exists public.folio_lines (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  folio_id uuid not null references public.folios(id) on delete restrict,
  business_date date not null,
  line_type text not null check (line_type in ('RM','BF','D','E','R','K','KH','ADJ')),
  department_code text,
  description text not null,
  debit numeric(18,2) not null default 0,
  credit numeric(18,2) not null default 0,
  payment_method text,
  source_module text,
  source_record_id uuid,
  posting_status text not null default 'UNPOSTED' check (posting_status in ('UNPOSTED','POSTED','VOID')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (debit >= 0 and credit >= 0 and not (debit > 0 and credit > 0))
);

create table if not exists public.deposits (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  folio_id uuid not null references public.folios(id) on delete restrict,
  deposit_no text not null,
  business_date date not null,
  amount_in numeric(18,2) not null default 0,
  amount_out numeric(18,2) not null default 0,
  payment_method text,
  description text,
  status text not null default 'OPEN' check (status in ('OPEN','ALLOCATED','REFUNDED','VOID')),
  created_at timestamptz not null default now(),
  unique (hotel_id, deposit_no),
  check (amount_in >= 0 and amount_out >= 0)
);

create table if not exists public.pos_checks (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  check_no text not null,
  outlet_code text not null,
  business_date date not null,
  stay_id uuid references public.stays(id),
  folio_id uuid references public.folios(id),
  table_no text,
  waiter text,
  subtotal numeric(18,2) not null default 0,
  service_amount numeric(18,2) not null default 0,
  tax_amount numeric(18,2) not null default 0,
  discount_amount numeric(18,2) not null default 0,
  total_amount numeric(18,2) not null default 0,
  payment_status text not null default 'UNPAID' check (payment_status in ('UNPAID','PAID','ROOM_CHARGE','VOID')),
  posting_status text not null default 'UNPOSTED' check (posting_status in ('UNPOSTED','POSTED','VOID')),
  created_at timestamptz not null default now(),
  unique (hotel_id, check_no)
);

create table if not exists public.pos_check_lines (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  pos_check_id uuid not null references public.pos_checks(id) on delete cascade,
  item_code text,
  item_name text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(18,2) not null default 0,
  line_total numeric(18,2) not null default 0,
  department_code text
);

create table if not exists public.banquet_bookings (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  booking_no text not null,
  group_name text not null,
  venue text not null,
  layout text,
  event_name text,
  start_at timestamptz not null,
  end_at timestamptz not null,
  persons integer not null default 1,
  customer_id uuid references public.customers(id),
  total_amount numeric(18,2) not null default 0,
  status text not null default 'RS' check (status in ('RS','CONFIRMED','CANCELLED','CLOSED')),
  unique (hotel_id, booking_no),
  check (end_at > start_at)
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  item_code text not null,
  item_name text not null,
  department_code text,
  unit text,
  average_cost numeric(18,4) not null default 0,
  sale_price numeric(18,2) not null default 0,
  reorder_level numeric(14,3) not null default 0,
  active boolean not null default true,
  unique (hotel_id, item_code)
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  item_id uuid not null references public.inventory_items(id) on delete restrict,
  business_date date not null,
  movement_type text not null check (movement_type in ('OPENING','PURCHASE','TRANSFER_IN','TRANSFER_OUT','CONSUMPTION','SALE','ADJUSTMENT','RETURN')),
  quantity_in numeric(14,3) not null default 0,
  quantity_out numeric(14,3) not null default 0,
  unit_cost numeric(18,4) not null default 0,
  reference_type text,
  reference_id uuid,
  notes text,
  posting_status text not null default 'UNPOSTED' check (posting_status in ('UNPOSTED','POSTED','VOID')),
  created_at timestamptz not null default now(),
  check (quantity_in >= 0 and quantity_out >= 0 and not (quantity_in > 0 and quantity_out > 0))
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  po_no text not null,
  supplier_id uuid references public.suppliers(id),
  order_date date not null,
  expected_date date,
  status text not null default 'DRAFT' check (status in ('DRAFT','APPROVED','RECEIVED','CANCELLED')),
  total_amount numeric(18,2) not null default 0,
  remarks text,
  unique (hotel_id, po_no)
);

create table if not exists public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  item_id uuid references public.inventory_items(id),
  item_code_snapshot text not null,
  item_name_snapshot text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_cost numeric(18,4) not null default 0,
  line_total numeric(18,2) not null default 0
);

create table if not exists public.ap_invoices (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  invoice_no text not null,
  supplier_id uuid references public.suppliers(id),
  purchase_order_id uuid references public.purchase_orders(id),
  invoice_date date not null,
  due_date date,
  total_amount numeric(18,2) not null default 0,
  paid_amount numeric(18,2) not null default 0,
  status text not null default 'OPEN' check (status in ('OPEN','PARTIAL','PAID','VOID')),
  unique (hotel_id, invoice_no),
  check (paid_amount <= total_amount)
);

create table if not exists public.ap_payments (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  payment_no text not null,
  ap_invoice_id uuid not null references public.ap_invoices(id) on delete restrict,
  payment_date date not null,
  amount numeric(18,2) not null check (amount > 0),
  cash_bank_account text,
  reference_no text,
  unique (hotel_id, payment_no)
);

create table if not exists public.ar_invoices (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  invoice_no text not null,
  customer_id uuid references public.customers(id),
  source_folio_id uuid references public.folios(id),
  invoice_date date not null,
  due_date date,
  total_amount numeric(18,2) not null default 0,
  received_amount numeric(18,2) not null default 0,
  status text not null default 'OPEN' check (status in ('OPEN','PARTIAL','PAID','VOID')),
  unique (hotel_id, invoice_no),
  check (received_amount <= total_amount)
);

create table if not exists public.ar_receipts (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  receipt_no text not null,
  ar_invoice_id uuid not null references public.ar_invoices(id) on delete restrict,
  receipt_date date not null,
  amount numeric(18,2) not null check (amount > 0),
  cash_bank_account text,
  reference_no text,
  unique (hotel_id, receipt_no)
);

create table if not exists public.cash_accounts (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  account_code text not null,
  account_name text not null,
  account_type text not null check (account_type in ('CASH','BANK','CLEARING')),
  active boolean not null default true,
  unique (hotel_id, account_code)
);

create table if not exists public.cash_transactions (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  transaction_no text not null,
  transaction_date date not null,
  direction text not null check (direction in ('IN','OUT','TRANSFER')),
  cash_account_id uuid references public.cash_accounts(id),
  amount numeric(18,2) not null check (amount > 0),
  source_module text,
  source_record_id uuid,
  description text,
  posting_status text not null default 'UNPOSTED' check (posting_status in ('UNPOSTED','POSTED','VOID')),
  unique (hotel_id, transaction_no)
);

create table if not exists public.gl_accounts (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  account_code text not null,
  account_name text not null,
  parent_account_id uuid references public.gl_accounts(id),
  account_type text not null check (account_type in ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE')),
  active boolean not null default true,
  unique (hotel_id, account_code)
);

create table if not exists public.gl_journals (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  journal_no text not null,
  journal_date date not null,
  source_module text not null,
  source_record_id uuid,
  description text,
  status text not null default 'DRAFT' check (status in ('DRAFT','POSTED','REVERSED')),
  posted_at timestamptz,
  posted_by uuid references auth.users(id),
  unique (hotel_id, journal_no)
);

create table if not exists public.gl_journal_lines (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  journal_id uuid not null references public.gl_journals(id) on delete cascade,
  account_id uuid not null references public.gl_accounts(id),
  description text,
  debit numeric(18,2) not null default 0,
  credit numeric(18,2) not null default 0,
  check (debit >= 0 and credit >= 0 and not (debit > 0 and credit > 0))
);

create table if not exists public.daily_audits (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  business_date date not null,
  status text not null default 'OPEN' check (status in ('OPEN','RUNNING','POSTED','FAILED','REVERSED')),
  started_at timestamptz,
  completed_at timestamptz,
  summary jsonb not null default '{}'::jsonb,
  started_by uuid references auth.users(id),
  unique (hotel_id, business_date)
);

-- Preserve the existing browser database byte-for-byte as a JSON snapshot before normalization.
-- Import is an explicit, auditable action and never overwrites an existing snapshot.
create table if not exists public.legacy_data_snapshots (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  source_app_key text not null,
  source_device_label text,
  checksum_sha256 text not null,
  payload jsonb not null,
  imported_by uuid references auth.users(id),
  imported_at timestamptz not null default now(),
  migration_status text not null default 'ARCHIVED' check (migration_status in ('ARCHIVED','MAPPED','RECONCILED','REJECTED')),
  unique (hotel_id, source_app_key, checksum_sha256)
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  occurred_at timestamptz not null default now(),
  actor_id uuid references auth.users(id),
  module text not null,
  action text not null,
  entity_type text,
  entity_id uuid,
  reference_no text,
  before_data jsonb,
  after_data jsonb
);

create index if not exists idx_reservations_hotel_dates on public.reservations(hotel_id, arrival_date, departure_date);
create index if not exists idx_stays_hotel_room_status on public.stays(hotel_id, room_id, status);
create index if not exists idx_folio_lines_hotel_date on public.folio_lines(hotel_id, business_date);
create index if not exists idx_stock_movements_hotel_item_date on public.stock_movements(hotel_id, item_id, business_date);
create index if not exists idx_gl_journals_hotel_date on public.gl_journals(hotel_id, journal_date);
create index if not exists idx_audit_events_hotel_time on public.audit_events(hotel_id, occurred_at desc);

-- Enable row-level security and module-specific write permissions.
do $$
declare
  t text;
  write_roles text[];
begin
  foreach t in array array[
    'hotels','hotel_memberships','rooms','rate_codes','guests','customers','suppliers',
    'reservations','reservation_rooms','stays','folios','folio_lines','deposits',
    'pos_checks','pos_check_lines','banquet_bookings','inventory_items','stock_movements',
    'purchase_orders','purchase_order_lines','ap_invoices','ap_payments','ar_invoices',
    'ar_receipts','cash_accounts','cash_transactions','gl_accounts','gl_journals',
    'gl_journal_lines','daily_audits','legacy_data_snapshots','audit_events'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    if t = 'hotels' then
      execute 'drop policy if exists hotel_member_select on public.hotels';
      execute 'create policy hotel_member_select on public.hotels for select using (public.is_hotel_member(id))';
      execute 'drop policy if exists hotel_admin_update on public.hotels';
      execute 'create policy hotel_admin_update on public.hotels for update using (public.has_hotel_role(id, array[''owner'',''admin''])) with check (public.has_hotel_role(id, array[''owner'',''admin'']))';
    elsif t = 'hotel_memberships' then
      execute 'drop policy if exists membership_self_select on public.hotel_memberships';
      execute 'create policy membership_self_select on public.hotel_memberships for select using (user_id = auth.uid() or public.has_hotel_role(hotel_id, array[''owner'',''admin'']))';
      execute 'drop policy if exists membership_admin_manage on public.hotel_memberships';
      execute 'create policy membership_admin_manage on public.hotel_memberships for all using (public.has_hotel_role(hotel_id, array[''owner'',''admin''])) with check (public.has_hotel_role(hotel_id, array[''owner'',''admin'']))';
    else
      if t in ('rooms','rate_codes','guests','customers','suppliers') then
        write_roles := array['owner','admin','front_office','accounting'];
      elsif t in ('reservations','reservation_rooms','stays','folios','folio_lines','deposits','daily_audits') then
        write_roles := array['owner','admin','front_office','accounting'];
      elsif t in ('pos_checks','pos_check_lines','banquet_bookings') then
        write_roles := array['owner','admin','front_office','outlet'];
      elsif t in ('inventory_items','stock_movements') then
        write_roles := array['owner','admin','inventory','purchasing','accounting'];
      elsif t in ('purchase_orders','purchase_order_lines') then
        write_roles := array['owner','admin','purchasing','inventory','accounting'];
      elsif t in ('ap_invoices','ap_payments','ar_invoices','ar_receipts','cash_accounts','cash_transactions','gl_accounts','gl_journals','gl_journal_lines') then
        write_roles := array['owner','admin','accounting'];
      elsif t = 'legacy_data_snapshots' then
        write_roles := array['owner','admin'];
      elsif t = 'audit_events' then
        write_roles := array['owner','admin'];
      else
        write_roles := array['owner','admin'];
      end if;
      execute format('drop policy if exists tenant_member_read on public.%I', t);
      execute format('create policy tenant_member_read on public.%I for select using (public.is_hotel_member(hotel_id))', t);
      execute format('drop policy if exists tenant_role_write on public.%I', t);
      execute format('create policy tenant_role_write on public.%I for all using (public.has_hotel_role(hotel_id, %L::text[])) with check (public.has_hotel_role(hotel_id, %L::text[]))', t, write_roles, write_roles);
    end if;
  end loop;
end $$;

grant usage on schema public to authenticated;
