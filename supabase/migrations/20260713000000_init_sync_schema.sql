-- init_sync_schema.sql – Central FW dataset, mirroring the app's Drift tables 1:1.
-- Single-writer model: members read the published snapshot; only admins write,
-- and all writes go through the publish_snapshot() RPC (no direct table writes).

-- ── Mirrored data tables (integer IDs are the admin's local Drift IDs) ──

create table vehicles (
  id bigint primary key,
  name text not null,
  type text not null,
  license_plate text,
  image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table compartments (
  id bigint primary key,
  vehicle_id bigint not null references vehicles (id) on delete cascade,
  label text not null,
  position integer not null default 0,
  grid_row integer,
  grid_col integer,
  grid_col_span integer not null default 1,
  updated_at timestamptz not null default now()
);

create table equipment_items (
  id bigint primary key,
  name text not null,
  short_name text,
  equipment_functions_json text not null default '[]',
  deployment_scenarios_json text not null default '[]',
  description text not null default '',
  image_path text,
  training_url text,
  library_equipment_id text,
  is_custom boolean not null default false,
  extra_attributes_json text not null default '{}',
  training_questions_json text not null default '[]',
  typical_use_json text not null default '[]',
  updated_at timestamptz not null default now()
);

create table equipment_assignments (
  id bigint primary key,
  compartment_id bigint not null references compartments (id) on delete cascade,
  equipment_id bigint not null references equipment_items (id) on delete cascade,
  quantity integer not null default 1,
  updated_at timestamptz not null default now()
);

create table equipment_instances (
  id bigint primary key,
  equipment_id bigint not null references equipment_items (id) on delete cascade,
  vehicle_id bigint references vehicles (id) on delete set null,
  compartment_id bigint references compartments (id) on delete set null,
  identifier text,
  notes text not null default '',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table inspection_schedules (
  id bigint primary key,
  instance_id bigint not null references equipment_instances (id) on delete cascade,
  kind text not null check (kind in ('recurring', 'expiry')),
  title text not null,
  interval_months integer,
  last_done_at timestamptz,
  due_at timestamptz not null,
  notes text not null default '',
  updated_at timestamptz not null default now()
);

create table inspection_log (
  id bigint primary key,
  schedule_id bigint not null references inspection_schedules (id) on delete cascade,
  done_at timestamptz not null,
  done_by text not null default '',
  note text not null default ''
);

-- ── Sync/auth bookkeeping ──

create table dataset_meta (
  id integer primary key default 1 check (id = 1),
  version bigint not null default 0,
  published_at timestamptz,
  published_by uuid
);
insert into dataset_meta (id, version) values (1, 0);

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  created_at timestamptz not null default now()
);

-- Auto-create a member profile for every new auth user.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.is_admin()
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ── RLS: authenticated users read everything; nobody writes tables directly.
-- All writes go through publish_snapshot() (security definer + admin check). ──

alter table vehicles enable row level security;
alter table compartments enable row level security;
alter table equipment_items enable row level security;
alter table equipment_assignments enable row level security;
alter table equipment_instances enable row level security;
alter table inspection_schedules enable row level security;
alter table inspection_log enable row level security;
alter table dataset_meta enable row level security;
alter table profiles enable row level security;

create policy "authenticated read" on vehicles for select to authenticated using (true);
create policy "authenticated read" on compartments for select to authenticated using (true);
create policy "authenticated read" on equipment_items for select to authenticated using (true);
create policy "authenticated read" on equipment_assignments for select to authenticated using (true);
create policy "authenticated read" on equipment_instances for select to authenticated using (true);
create policy "authenticated read" on inspection_schedules for select to authenticated using (true);
create policy "authenticated read" on inspection_log for select to authenticated using (true);
create policy "authenticated read" on dataset_meta for select to authenticated using (true);
create policy "read own profile" on profiles for select to authenticated using (id = auth.uid());

-- ── publish_snapshot: transactional full-dataset replace with optimistic
-- version check. payload format:
-- { "vehicles": [...], "compartments": [...], "equipment_items": [...],
--   "equipment_assignments": [...], "equipment_instances": [...],
--   "inspection_schedules": [...], "inspection_log": [...] }
-- Row keys use the snake_case column names. Returns the new version. ──

create function public.publish_snapshot(expected_version bigint, payload jsonb)
returns bigint
language plpgsql
security definer set search_path = ''
as $$
declare
  current_version bigint;
  new_version bigint;
begin
  if not public.is_admin() then
    raise exception 'permission denied: admin role required';
  end if;

  select version into current_version from public.dataset_meta where id = 1 for update;
  if current_version <> expected_version then
    raise exception 'version conflict: expected %, got % — pull first, then republish',
      current_version, expected_version;
  end if;

  -- children first ("where true" satisfies pg-safeupdate)
  delete from public.inspection_log where true;
  delete from public.inspection_schedules where true;
  delete from public.equipment_instances where true;
  delete from public.equipment_assignments where true;
  delete from public.compartments where true;
  delete from public.equipment_items where true;
  delete from public.vehicles where true;

  insert into public.vehicles
    select * from jsonb_populate_recordset(null::public.vehicles, payload->'vehicles');
  insert into public.equipment_items
    select * from jsonb_populate_recordset(null::public.equipment_items, payload->'equipment_items');
  insert into public.compartments
    select * from jsonb_populate_recordset(null::public.compartments, payload->'compartments');
  insert into public.equipment_assignments
    select * from jsonb_populate_recordset(null::public.equipment_assignments, payload->'equipment_assignments');
  insert into public.equipment_instances
    select * from jsonb_populate_recordset(null::public.equipment_instances, payload->'equipment_instances');
  insert into public.inspection_schedules
    select * from jsonb_populate_recordset(null::public.inspection_schedules, payload->'inspection_schedules');
  insert into public.inspection_log
    select * from jsonb_populate_recordset(null::public.inspection_log, payload->'inspection_log');

  new_version := current_version + 1;
  update public.dataset_meta
    set version = new_version, published_at = now(), published_by = auth.uid()
    where id = 1;
  return new_version;
end;
$$;

revoke execute on function public.publish_snapshot from public, anon;
grant execute on function public.publish_snapshot to authenticated;

-- ── Table privileges (RLS still applies on top for authenticated) ──

grant select on vehicles, compartments, equipment_items, equipment_assignments,
  equipment_instances, inspection_schedules, inspection_log, dataset_meta,
  profiles to authenticated;
grant all on vehicles, compartments, equipment_items, equipment_assignments,
  equipment_instances, inspection_schedules, inspection_log, dataset_meta,
  profiles to service_role;
