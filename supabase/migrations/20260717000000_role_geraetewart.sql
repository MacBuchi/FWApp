-- role_geraetewart.sql – Rollenmodell-Ausbau (M7 Etappe 2):
-- admin | geraetewart | member.
--   member      – liest den publizierten Stand (unverändert)
--   geraetewart – darf den Datenbestand bearbeiten & veröffentlichen und
--                 Gerätefotos hochladen/ersetzen/löschen
--   admin       – wie geraetewart, zusätzlich künftig Nutzerverwaltung/Reset
--                 (Etappe 3; is_admin() bleibt dafür bestehen)
-- Einspielen wie gehabt per docker exec psql als supabase_admin, danach
-- NOTIFY pgrst, 'reload schema'.

-- 1) Rolle 'geraetewart' zulassen.
alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('admin', 'geraetewart', 'member'));

-- 2) is_editor(): bearbeiten dürfen Admin UND Gerätewart.
create function public.is_editor()
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'geraetewart')
  );
$$;

-- 3) Veröffentlichen: Editor-Recht statt Admin-Recht.
--    (Nur der Guard ändert sich; Rumpf identisch zur Init-Migration.)
create or replace function public.publish_snapshot(expected_version bigint, payload jsonb)
returns bigint
language plpgsql
security definer set search_path = ''
as $$
declare
  current_version bigint;
  new_version bigint;
begin
  if not public.is_editor() then
    raise exception 'permission denied: editor role (admin/geraetewart) required';
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

-- 4) Gerätefoto-Bucket: Schreibrechte für Editoren statt nur Admin.
drop policy "equipment-images admin insert" on storage.objects;
drop policy "equipment-images admin update" on storage.objects;
drop policy "equipment-images admin delete" on storage.objects;

create policy "equipment-images editor insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'equipment-images' and public.is_editor());

create policy "equipment-images editor update" on storage.objects
  for update to authenticated
  using (bucket_id = 'equipment-images' and public.is_editor())
  with check (bucket_id = 'equipment-images' and public.is_editor());

create policy "equipment-images editor delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'equipment-images' and public.is_editor());
