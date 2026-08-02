-- mandantenscharfe_ids.sql – Primärschlüssel je Abteilung statt global.
--
-- **Der Fehler.** Die gespiegelten Tabellen tragen seit dem Ur-Schema die
-- LOKALEN Drift-IDs als alleinigen Primärschlüssel (`id bigint primary key`).
-- Die Mandanten-Migration hat `abteilung_id` ergänzt, die Schlüssel aber nicht
-- angefasst. `publish_snapshot` löscht die Zeilen der eigenen Abteilung und
-- fügt die Payload mit genau diesen IDs wieder ein — und jede lokale Datenbank
-- zählt bei 1 los. Daraus folgen zwei Fehler:
--
--   1. Die ZWEITE Abteilung kann nicht veröffentlichen: Ihre Fahrzeug-ID 1
--      kollidiert mit der ersten → Duplicate-Key, Publish bricht ab.
--   2. Schlimmer: Veröffentlichen löscht fremde Daten. Die Fremdschlüssel
--      zeigen auf `equipment_items (id)` OHNE Abteilung und stehen auf
--      `on delete cascade` — `delete from equipment_items where
--      abteilung_id = A` reißt jede Zuordnung JEDER Abteilung mit, die
--      dieselbe Zahl als `equipment_id` benutzt.
--
-- Beides ist nie aufgefallen, weil in allen E2E-Läufen (und bislang auch auf
-- dem Server) die zweite Abteilung leer war.
--
-- **Die Behebung.** Der Schlüssel wird `(abteilung_id, id)`, und jeder
-- Fremdschlüssel führt `abteilung_id` als erste Spalte mit. Damit kann ein
-- Verweis die Abteilungsgrenze technisch nicht mehr überschreiten — die
-- Isolation steht in den Constraints, nicht nur in der Sorgfalt von
-- `publish_snapshot`.
--
-- Rein serverseitig: Der Client schickt unverändert dieselbe Payload, sie
-- kollidiert nur nicht mehr. Deshalb keine Alt-Client-Choreografie.

-- ── 1. Abhängige Fremdschlüssel lösen ────────────────────────────────────
alter table public.inspection_log
  drop constraint if exists inspection_log_schedule_id_fkey;
alter table public.inspection_schedules
  drop constraint if exists inspection_schedules_instance_id_fkey;
alter table public.equipment_instances
  drop constraint if exists equipment_instances_equipment_id_fkey,
  drop constraint if exists equipment_instances_vehicle_id_fkey,
  drop constraint if exists equipment_instances_compartment_id_fkey;
alter table public.equipment_assignments
  drop constraint if exists equipment_assignments_compartment_id_fkey,
  drop constraint if exists equipment_assignments_equipment_id_fkey;
alter table public.compartments
  drop constraint if exists compartments_vehicle_id_fkey;

-- ── 2. Primärschlüssel mandantenscharf ───────────────────────────────────
-- `abteilung_id` ist auf allen sieben Tabellen bereits `not null` (siehe
-- 20260801000000_abteilungen_mandanten.sql), die Umstellung braucht also
-- keine Datenkorrektur.
alter table public.vehicles
  drop constraint vehicles_pkey,
  add primary key (abteilung_id, id);
alter table public.compartments
  drop constraint compartments_pkey,
  add primary key (abteilung_id, id);
alter table public.equipment_items
  drop constraint equipment_items_pkey,
  add primary key (abteilung_id, id);
alter table public.equipment_assignments
  drop constraint equipment_assignments_pkey,
  add primary key (abteilung_id, id);
alter table public.equipment_instances
  drop constraint equipment_instances_pkey,
  add primary key (abteilung_id, id);
alter table public.inspection_schedules
  drop constraint inspection_schedules_pkey,
  add primary key (abteilung_id, id);
alter table public.inspection_log
  drop constraint inspection_log_pkey,
  add primary key (abteilung_id, id);

-- ── 3. Fremdschlüssel zusammengesetzt neu anlegen ────────────────────────
alter table public.compartments
  add constraint compartments_vehicle_fkey
  foreign key (abteilung_id, vehicle_id)
  references public.vehicles (abteilung_id, id) on delete cascade;

alter table public.equipment_assignments
  add constraint equipment_assignments_compartment_fkey
  foreign key (abteilung_id, compartment_id)
  references public.compartments (abteilung_id, id) on delete cascade,
  add constraint equipment_assignments_equipment_fkey
  foreign key (abteilung_id, equipment_id)
  references public.equipment_items (abteilung_id, id) on delete cascade;

-- Die beiden nullbaren Verweise brauchen zweierlei Sonderbehandlung:
--   • `match simple` (der Standard) lässt die Prüfung entfallen, sobald EINE
--     Spalte NULL ist — genau richtig für „Exemplar ohne Fahrzeug".
--   • `on delete set null` muss die Spalte NENNEN. Ohne die Liste nullt
--     Postgres alle Spalten des Fremdschlüssels, also auch `abteilung_id`,
--     und scheitert an dessen `not null`. Spaltenweises SET NULL gibt es
--     seit PG 15; hier laufen 17.
alter table public.equipment_instances
  add constraint equipment_instances_equipment_fkey
  foreign key (abteilung_id, equipment_id)
  references public.equipment_items (abteilung_id, id) on delete cascade,
  add constraint equipment_instances_vehicle_fkey
  foreign key (abteilung_id, vehicle_id)
  references public.vehicles (abteilung_id, id) on delete set null (vehicle_id),
  add constraint equipment_instances_compartment_fkey
  foreign key (abteilung_id, compartment_id)
  references public.compartments (abteilung_id, id)
  on delete set null (compartment_id);

alter table public.inspection_schedules
  add constraint inspection_schedules_instance_fkey
  foreign key (abteilung_id, instance_id)
  references public.equipment_instances (abteilung_id, id) on delete cascade;

alter table public.inspection_log
  add constraint inspection_log_schedule_fkey
  foreign key (abteilung_id, schedule_id)
  references public.inspection_schedules (abteilung_id, id) on delete cascade;

-- ── 4. Überflüssig gewordene Indizes ─────────────────────────────────────
-- Der neue Primärschlüssel beginnt mit `abteilung_id`; ein eigener Index nur
-- auf dieser Spalte trägt nichts mehr bei und kostet bei jedem Publish.
drop index if exists public.vehicles_abteilung_idx;
drop index if exists public.compartments_abteilung_idx;
drop index if exists public.equipment_items_abteilung_idx;
drop index if exists public.equipment_assignments_abteilung_idx;
drop index if exists public.equipment_instances_abteilung_idx;
drop index if exists public.inspection_schedules_abteilung_idx;
drop index if exists public.inspection_log_abteilung_idx;
