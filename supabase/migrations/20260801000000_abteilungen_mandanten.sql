-- abteilungen_mandanten.sql – Phase 1 von Issue #57: Abteilung = Datenbestand.
--
-- Der Single-Writer-Snapshot bleibt wörtlich bestehen; er bekommt nur eine
-- neue Bezugsgröße. Jede Abteilung hat ihren eigenen Versionszähler und ihren
-- eigenen Gerätewart als Schreiber. Die Gesamtwehr ist eine Klammer darüber
-- (Branding, Admin, Verbindungs-Anfragen — kommt in Phase 3, die Tabelle
-- entsteht aber schon jetzt, damit die RLS-Helfer nicht zweimal umgebaut
-- werden müssen).
--
-- ⚠️ ROLLOUT-REIHENFOLGE (Aussperr-Schutz, siehe Konzept zu #57):
--   1. Diese Migration einspielen — es existiert genau EINE Abteilung
--      (Backfill). Alt-Clients (`dataset_meta.select().single()`) sehen
--      weiterhin genau eine Zeile und laufen unverändert.
--   2. App-Version mit Mandanten-Sync ausrollen.
--   3. `dataset_meta.minimum_supported_version` auf diese Version heben.
--   4. ERST DANN eine zweite Abteilung zulassen. Vorher nicht: Alt-Clients
--      würden beim Publish den Bestand fremder Abteilungen nicht anfassen
--      (das Gate schützt), aber ihr Pull bliebe ungefiltert.
--
-- Entscheidungen vom 2026-08-01 (Marcus): Quer-Sicht innerhalb der
-- Gesamtwehr lesend erlaubt; Selbstregistrierung neuer Abteilungen landet
-- als 'pending' (lokal voll arbeitsfähig, Veröffentlichen erst nach
-- Freigabe durch den Host-Betreiber).
--
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

-- ── 1) Gesamtwehren (minimal — Ausbau in Phase 3) ─────────────────────────

create table public.gesamtwehren (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  created_at timestamptz not null default now()
);

comment on table public.gesamtwehren is
  'Klammer über Abteilungen (Issue #57). Branding/Admin-Ausbau folgt in Phase 3.';

-- ── 2) Abteilungen: der Mandant. Übernimmt die dataset_meta-Rolle je
--       Abteilung (version/published_*) gleich mit — eine Tabelle weniger. ──

create table public.abteilungen (
  id uuid primary key default gen_random_uuid(),
  gesamtwehr_id uuid references public.gesamtwehren (id) on delete set null,
  name text not null,
  slug text unique not null,
  -- 'pending' ist der Selbstregistrierungs-Zustand: lokal darf alles,
  -- veröffentlichen erst nach Freigabe (publish_snapshot prüft das).
  status text not null default 'pending'
    check (status in ('pending', 'active', 'rejected')),
  -- Genau eine Abteilung spiegelt ihren Stand nach dataset_meta, damit
  -- Alt-Clients bis zur angehobenen Mindestversion weiterlaufen.
  legacy_mirror boolean not null default false,
  version bigint not null default 0,
  published_at timestamptz,
  published_by uuid,
  created_at timestamptz not null default now()
);

create unique index abteilungen_one_legacy_mirror
  on public.abteilungen (legacy_mirror) where legacy_mirror;

-- Bestands-Abteilung: übernimmt Zähler und Veröffentlichungsstand 1:1.
insert into public.abteilungen
    (name, slug, status, legacy_mirror, version, published_at, published_by)
select 'Feuerwehr', 'hauptwehr', 'active', true,
       version, published_at, published_by
from public.dataset_meta where id = 1;

-- ── 3) Mandanten-Spalte an den 7 Sync-Tabellen und an profiles ───────────

alter table public.vehicles              add column abteilung_id uuid;
alter table public.compartments          add column abteilung_id uuid;
alter table public.equipment_items       add column abteilung_id uuid;
alter table public.equipment_assignments add column abteilung_id uuid;
alter table public.equipment_instances   add column abteilung_id uuid;
alter table public.inspection_schedules  add column abteilung_id uuid;
alter table public.inspection_log        add column abteilung_id uuid;
alter table public.profiles              add column abteilung_id uuid;

update public.vehicles              set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.compartments          set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.equipment_items       set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.equipment_assignments set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.equipment_instances   set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.inspection_schedules  set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.inspection_log        set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;
update public.profiles              set abteilung_id = a.id from public.abteilungen a where a.legacy_mirror;

alter table public.vehicles              alter column abteilung_id set not null;
alter table public.compartments          alter column abteilung_id set not null;
alter table public.equipment_items       alter column abteilung_id set not null;
alter table public.equipment_assignments alter column abteilung_id set not null;
alter table public.equipment_instances   alter column abteilung_id set not null;
alter table public.inspection_schedules  alter column abteilung_id set not null;
alter table public.inspection_log        alter column abteilung_id set not null;
-- profiles bleibt nullable: Ein Profil darf die Löschung seiner Abteilung
-- überleben (dann ohne Datenzugriff, statt den Auth-User zu reißen).

alter table public.vehicles              add constraint vehicles_abteilung_fkey              foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.compartments          add constraint compartments_abteilung_fkey          foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.equipment_items       add constraint equipment_items_abteilung_fkey       foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.equipment_assignments add constraint equipment_assignments_abteilung_fkey foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.equipment_instances   add constraint equipment_instances_abteilung_fkey   foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.inspection_schedules  add constraint inspection_schedules_abteilung_fkey  foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.inspection_log        add constraint inspection_log_abteilung_fkey        foreign key (abteilung_id) references public.abteilungen (id) on delete cascade;
alter table public.profiles              add constraint profiles_abteilung_fkey              foreign key (abteilung_id) references public.abteilungen (id) on delete set null;

create index vehicles_abteilung_idx              on public.vehicles (abteilung_id);
create index compartments_abteilung_idx          on public.compartments (abteilung_id);
create index equipment_items_abteilung_idx       on public.equipment_items (abteilung_id);
create index equipment_assignments_abteilung_idx on public.equipment_assignments (abteilung_id);
create index equipment_instances_abteilung_idx   on public.equipment_instances (abteilung_id);
create index inspection_schedules_abteilung_idx  on public.inspection_schedules (abteilung_id);
create index inspection_log_abteilung_idx        on public.inspection_log (abteilung_id);

-- Neue Auth-User: Abteilung aus den Signup-Metadaten (Selbstregistrierung,
-- Phase 3) oder — solange es die nicht gibt — die Bestands-Abteilung.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, abteilung_id)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'abteilung_id', '')::uuid,
      (select id from public.abteilungen where legacy_mirror)
    )
  )
  on conflict do nothing;
  return new;
end;
$$;

-- ── 4) RLS-Helfer (security definer gegen Policy-Rekursion, wie gehabt) ──

create function public.my_abteilung_id()
returns uuid
language sql
security definer set search_path = ''
stable
as $$
  select abteilung_id from public.profiles where id = auth.uid();
$$;

-- Lesen: eigene Abteilung, oder Schwester-Abteilung derselben Gesamtwehr
-- (Entscheidung A: Quer-Sicht lesend erlaubt).
create function public.can_read_abteilung(target uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.abteilungen mine
    join public.abteilungen t on t.id = target
    where mine.id = public.my_abteilung_id()
      and (t.id = mine.id
           or (mine.gesamtwehr_id is not null
               and t.gesamtwehr_id = mine.gesamtwehr_id))
  );
$$;

-- Schreiben/Veröffentlichen: Gerätewart oder Admin der eigenen Abteilung;
-- der Admin zusätzlich in jeder Abteilung seiner Gesamtwehr (Issue-Text:
-- „Der Admin der Gesamtfeuerwehr kann dabei alles bearbeiten").
create function public.can_publish_abteilung(target uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.profiles p
    join public.abteilungen mine on mine.id = p.abteilung_id
    join public.abteilungen t on t.id = target
    where p.id = auth.uid()
      and (
        (p.role in ('admin', 'geraetewart') and t.id = mine.id)
        or (p.role = 'admin'
            and mine.gesamtwehr_id is not null
            and t.gesamtwehr_id = mine.gesamtwehr_id)
      )
  );
$$;

revoke execute on function public.my_abteilung_id, public.can_read_abteilung,
  public.can_publish_abteilung from public, anon;
grant execute on function public.my_abteilung_id, public.can_read_abteilung,
  public.can_publish_abteilung to authenticated;

-- ── 5) RLS: „authenticated liest alles" → mandantenscharf ────────────────

drop policy "authenticated read" on public.vehicles;
drop policy "authenticated read" on public.compartments;
drop policy "authenticated read" on public.equipment_items;
drop policy "authenticated read" on public.equipment_assignments;
drop policy "authenticated read" on public.equipment_instances;
drop policy "authenticated read" on public.inspection_schedules;
drop policy "authenticated read" on public.inspection_log;

create policy "read own or sister abteilung" on public.vehicles              for select to authenticated using (public.can_read_abteilung(abteilung_id));
create policy "read own or sister abteilung" on public.compartments          for select to authenticated using (public.can_read_abteilung(abteilung_id));
create policy "read own or sister abteilung" on public.equipment_items       for select to authenticated using (public.can_read_abteilung(abteilung_id));
create policy "read own or sister abteilung" on public.equipment_assignments for select to authenticated using (public.can_read_abteilung(abteilung_id));
create policy "read own or sister abteilung" on public.equipment_instances   for select to authenticated using (public.can_read_abteilung(abteilung_id));
create policy "read own or sister abteilung" on public.inspection_schedules  for select to authenticated using (public.can_read_abteilung(abteilung_id));
create policy "read own or sister abteilung" on public.inspection_log        for select to authenticated using (public.can_read_abteilung(abteilung_id));

-- dataset_meta bleibt für alle lesbar (Alt-Clients, Gate-Konfiguration).
alter table public.gesamtwehren enable row level security;
alter table public.abteilungen enable row level security;
create policy "authenticated read" on public.gesamtwehren
  for select to authenticated using (true);
create policy "read own or sister abteilung" on public.abteilungen
  for select to authenticated using (public.can_read_abteilung(id));

grant select on public.gesamtwehren, public.abteilungen to authenticated;
grant all on public.gesamtwehren, public.abteilungen to service_role;

-- ── 6) publish_snapshot v2: mandantenscharf ──────────────────────────────
-- Payload-Zeilen kommen OHNE abteilung_id vom Client (die lokale Drift-DB
-- kennt die Spalte nicht); der Server stempelt sie hier auf. So kann ein
-- Client niemals in eine fremde Abteilung schreiben, egal was er schickt.

create function public.publish_snapshot(
  abteilung uuid,
  expected_version bigint,
  payload jsonb,
  client_version text default null
)
returns bigint
language plpgsql
security definer set search_path = ''
as $$
declare
  current_version bigint;
  new_version bigint;
  min_version text;
  cmp integer;
  ziel record;
  stamped jsonb := '{}'::jsonb;
  t text;
begin
  select a.* into ziel from public.abteilungen a where a.id = abteilung for update;
  if ziel is null then
    raise exception 'unknown abteilung %', abteilung;
  end if;

  if not public.can_publish_abteilung(abteilung) then
    raise exception 'permission denied: editor role for this abteilung required';
  end if;

  -- Selbstregistrierung: pending darf lokal alles, aber nicht veröffentlichen.
  if ziel.status <> 'active' then
    raise exception 'abteilung not approved yet (status %): publishing requires activation',
      ziel.status;
  end if;

  -- Mindestversions-Gate — Block wörtlich aus der Gate-Migration übernommen:
  -- Der Client erkennt die Ablehnung am Marker 'client too old', und die
  -- Fail-open-Semantik (kein Wert / nicht entscheidbar → durchlassen) ist
  -- dort dreifach abgesichert. Konfiguration bleibt global in dataset_meta.
  select minimum_supported_version into min_version
    from public.dataset_meta where id = 1;
  if min_version is not null and min_version <> '' then
    if client_version is null then
      raise exception 'client too old: app version unknown, minimum is %. '
        'Bitte die App aktualisieren und erneut veroeffentlichen.', min_version
        using errcode = 'P0001';
    end if;
    cmp := public.compare_app_versions(client_version, min_version);
    -- cmp is null = nicht entscheidbar -> durchlassen (Aussperr-Schutz 3).
    if cmp is not null and cmp < 0 then
      raise exception 'client too old: app version % is below the minimum %. '
        'Bitte die App aktualisieren und erneut veroeffentlichen.',
        client_version, min_version
        using errcode = 'P0001';
    end if;
  end if;

  current_version := ziel.version;
  if current_version <> expected_version then
    raise exception 'version conflict: expected %, got % — pull first, then republish',
      current_version, expected_version;
  end if;

  -- Jede Payload-Zeile mit der Ziel-Abteilung stempeln.
  foreach t in array array['vehicles','equipment_items','compartments',
    'equipment_assignments','equipment_instances','inspection_schedules',
    'inspection_log']
  loop
    stamped := stamped || jsonb_build_object(t, coalesce(
      (select jsonb_agg(elem || jsonb_build_object('abteilung_id', abteilung))
       from jsonb_array_elements(coalesce(payload -> t, '[]'::jsonb)) elem),
      '[]'::jsonb));
  end loop;

  -- children first, nur die eigene Abteilung
  delete from public.inspection_log        where abteilung_id = abteilung;
  delete from public.inspection_schedules  where abteilung_id = abteilung;
  delete from public.equipment_instances   where abteilung_id = abteilung;
  delete from public.equipment_assignments where abteilung_id = abteilung;
  delete from public.compartments          where abteilung_id = abteilung;
  delete from public.equipment_items       where abteilung_id = abteilung;
  delete from public.vehicles              where abteilung_id = abteilung;

  insert into public.vehicles
    select * from jsonb_populate_recordset(null::public.vehicles, stamped->'vehicles');
  insert into public.equipment_items
    select * from jsonb_populate_recordset(null::public.equipment_items, stamped->'equipment_items');
  insert into public.compartments
    select * from jsonb_populate_recordset(null::public.compartments, stamped->'compartments');
  insert into public.equipment_assignments
    select * from jsonb_populate_recordset(null::public.equipment_assignments, stamped->'equipment_assignments');
  insert into public.equipment_instances
    select * from jsonb_populate_recordset(null::public.equipment_instances, stamped->'equipment_instances');
  insert into public.inspection_schedules
    select * from jsonb_populate_recordset(null::public.inspection_schedules, stamped->'inspection_schedules');
  insert into public.inspection_log
    select * from jsonb_populate_recordset(null::public.inspection_log, stamped->'inspection_log');

  new_version := current_version + 1;
  update public.abteilungen
    set version = new_version, published_at = now(), published_by = auth.uid()
    where id = abteilung;

  -- Alt-Client-Spiegel: die Bestands-Abteilung hält dataset_meta aktuell,
  -- bis die Mindestversion angehoben ist und der Spiegel fallen kann.
  if ziel.legacy_mirror then
    update public.dataset_meta
      set version = new_version, published_at = now(), published_by = auth.uid()
      where id = 1;
  end if;

  return new_version;
end;
$$;

-- Alt-Signatur bleibt als Weiche auf die Spiegel-Abteilung bestehen, damit
-- bereits ausgerollte 1.5.x-Clients bis zur Mindestversions-Anhebung
-- weiter veröffentlichen können. Danach: Wrapper und Spiegel entfernen.
create or replace function public.publish_snapshot(
  expected_version bigint,
  payload jsonb,
  client_version text default null
)
returns bigint
language plpgsql
security definer set search_path = ''
as $$
begin
  return public.publish_snapshot(
    (select id from public.abteilungen where legacy_mirror),
    expected_version, payload, client_version);
end;
$$;

-- ⚠️ CREATE stellt den PUBLIC-EXECUTE-Default wieder her — Revoke-Muster
-- wie in der Gate-Migration, sonst wiederholt sich die dortige Regression.
revoke execute on function
  public.publish_snapshot(uuid, bigint, jsonb, text),
  public.publish_snapshot(bigint, jsonb, text)
  from public, anon;
grant execute on function
  public.publish_snapshot(uuid, bigint, jsonb, text),
  public.publish_snapshot(bigint, jsonb, text)
  to authenticated;

-- Eigene Profilzeile: die App braucht jetzt auch die eigene Abteilung.
-- (Die bestehende Policy "read own profile" deckt das bereits — kein Umbau.)

comment on function public.publish_snapshot(uuid, bigint, jsonb, text) is
  'Mandantenscharfer Voll-Snapshot je Abteilung (Issue #57 Phase 1). '
  'Stempelt abteilung_id serverseitig, prüft Rolle, Freigabe-Status, '
  'Mindestversion und Versionszähler der Abteilung.';
