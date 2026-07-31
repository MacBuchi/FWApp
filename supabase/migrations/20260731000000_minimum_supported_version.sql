-- minimum_supported_version.sql – Mindestversions-Gate fürs Veröffentlichen
-- (Issue #35).
--
-- Das Problem, gegen das das hier schützt: Nicht der Pull ist gefährlich,
-- sondern `publish_snapshot`. Ein Gerätewart auf altem Stand baut den Snapshot
-- aus seiner lokalen DB; `jsonb_populate_recordset` setzt Keys, die er nicht
-- kennt, kommentarlos auf NULL. Eine neu hinzugekommene Sync-Spalte wäre
-- danach für die ganze Wehr leer — ohne Fehlermeldung. `expected_version`
-- fängt das nicht ab, das schützt nur gegen parallele Publishes.
--
-- ── Aussperr-Schutz (bewusste Entwurfsentscheidungen) ─────────────────────
--
-- 1. `minimum_supported_version` ist NULL by default. Diese Migration allein
--    ändert also GAR NICHTS am Verhalten. Erst wenn jemand bewusst einen Wert
--    setzt, greift das Gate.
-- 2. Das Gate sperrt nur `publish_snapshot`. Lesen (Pull) und die App selbst
--    bleiben unangetastet — local-first bleibt local-first. Ein zu alter
--    Client kann weiterhin alles ausser veröffentlichen.
-- 3. Bei jeder Unklarheit wird DURCHGELASSEN, nicht gesperrt (fail-open).
--    Begründung: Ohne Gate ist der Zustand exakt der heutige; mit einem
--    fail-closed-Gate könnte ein Tippfehler die ganze Wehr vom
--    Veröffentlichen abschneiden, und das liesse sich nur noch mit
--    DB-Zugriff reparieren.
-- 4. Der CHECK auf der Spalte lässt Unsinn erst gar nicht hinein, damit
--    Punkt 3 der Notnagel bleibt und nicht der Normalfall.
--
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

-- ── 1) Die Spalte ────────────────────────────────────────────────────────

alter table public.dataset_meta
  add column if not exists minimum_supported_version text
    check (
      minimum_supported_version is null
      or minimum_supported_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'
    );

comment on column public.dataset_meta.minimum_supported_version is
  'Kleinste App-Version, die veroeffentlichen darf (MAJOR.MINOR.PATCH). '
  'NULL = kein Gate. Nur publish_snapshot wird geprueft, nie der Pull.';

-- ── 2) Versionsvergleich ─────────────────────────────────────────────────

-- Vergleicht zwei MAJOR.MINOR.PATCH-Strings numerisch (damit 1.10.0 > 1.9.2
-- gilt, was ein reiner Textvergleich falsch machen würde).
-- Liefert NULL, wenn eine Seite nicht dem Muster entspricht — der Aufrufer
-- deutet das als "nicht entscheidbar" und lässt durch.
create or replace function public.compare_app_versions(a text, b text)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  pa integer[];
  pb integer[];
  i integer;
begin
  if a is null or b is null then return null; end if;
  if a !~ '^[0-9]+\.[0-9]+\.[0-9]+$' or b !~ '^[0-9]+\.[0-9]+\.[0-9]+$' then
    return null;
  end if;

  pa := string_to_array(a, '.')::integer[];
  pb := string_to_array(b, '.')::integer[];

  for i in 1..3 loop
    if pa[i] > pb[i] then return 1; end if;
    if pa[i] < pb[i] then return -1; end if;
  end loop;
  return 0;
end;
$$;

-- ── 3) publish_snapshot mit Gate ─────────────────────────────────────────

-- Die alte 2-argumentige Fassung muss weg, sonst wäre der Aufruf mit zwei
-- Argumenten zwischen ihr und der neuen Fassung mit Default mehrdeutig
-- ("function is not unique"). Nach dem Drop landen Alt-Clients, die nur
-- expected_version und payload schicken, automatisch in der neuen Fassung
-- mit client_version = NULL — genau der Fall, den das Gate abfangen soll.
drop function if exists public.publish_snapshot(bigint, jsonb);

create or replace function public.publish_snapshot(
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
begin
  if not public.is_editor() then
    raise exception 'permission denied: editor role (admin/geraetewart) required';
  end if;

  select version, minimum_supported_version
    into current_version, min_version
    from public.dataset_meta where id = 1 for update;

  -- Mindestversions-Gate. Kein Wert gesetzt = kein Gate (Aussperr-Schutz 1).
  if min_version is not null and min_version <> '' then
    if client_version is null then
      -- Alt-Client ohne Versionsangabe: Er kann per Definition nicht wissen,
      -- welche Spalten es inzwischen gibt.
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

-- ── 4) Rechte ────────────────────────────────────────────────────────────

-- WICHTIG: `create function` vergibt EXECUTE per Default an PUBLIC. Die
-- Init-Migration hatte das für publish_snapshot bewusst wieder entzogen
-- (20260713000000, Zeile 209) — durch das Drop/Recreate oben wäre der
-- Default sonst still zurück. Die Funktion prüft zwar selbst `is_editor()`,
-- ein anonymer Aufruf käme also nicht durch; das hier ist die zweite Schicht.
revoke execute on function public.publish_snapshot(bigint, jsonb, text)
  from public, anon;
grant execute on function public.publish_snapshot(bigint, jsonb, text)
  to authenticated;

revoke execute on function public.compare_app_versions(text, text)
  from public, anon;
grant execute on function public.compare_app_versions(text, text)
  to authenticated;
