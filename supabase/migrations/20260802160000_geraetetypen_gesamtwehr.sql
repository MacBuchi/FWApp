-- geraetetypen_gesamtwehr.sql – Gerätetypen auf Gesamtwehr-Ebene
-- (Nutzerkonzept Stufe ②, Issue #99; docs/NUTZERKONZEPT.md §4).
--
-- **Der Schnitt.** Was ein C-Strahlrohr *ist*, teilt die ganze Wehr; das
-- physische Exemplar mit seiner Prüfhistorie gehört einer Abteilung. Deshalb:
--
--   Gesamtwehr  → equipment_types  (Name, Aliasse, Foto, Piktogramm)
--   Abteilung   → equipment_items  (Projektion: lokale ID → Typ)
--               → equipment_instances, equipment_assignments, Prüfungen
--
-- **Warum die Typen NICHT im Snapshot liegen dürfen.** Der Sync ist ein
-- Single-Writer-Snapshot JE ABTEILUNG. Eine über Abteilungen geteilte Tabelle
-- würde beim Veröffentlichen von zwei Gerätewarten wechselseitig
-- überschrieben. `equipment_types` bekommt darum einen eigenen, zeilenweisen
-- Weg: Lesen per RLS mit `updated_at`-Fenster, Schreiben über
-- `push_equipment_types` (letzte Änderung gewinnt, je Zeile).
--
-- **`equipment_items` bleibt.** Die Tabelle behält ihre lokale Int-ID und
-- damit alle Verweise aus Zuordnungen und Exemplaren; neu ist nur `type_id`.
-- Der Snapshot trägt sie unverändert weiter — auch von Clients, die von
-- Typen noch nichts wissen (Alt-Client-Choreografie).
--
-- **Abteilungen ohne Gesamtwehr** haben keinen geteilten Bestand und laufen
-- unverändert auf dem Snapshot-Weg. `gesamtwehr_id` ist deshalb Pflicht am
-- Typ, aber der ganze Mechanismus ist optional.

-- ── Namensnormalisierung ─────────────────────────────────────────────────
-- Wortgleich zu EquipmentMatcher.normalize in
-- lib/features/import/data/equipment_matcher.dart — dieselbe Regel muss auf
-- beiden Seiten gelten, sonst dedupliziert der Server anders als der Import.
create function public.normalize_equipment_name(quelle text)
returns text
language sql
immutable
set search_path = ''
as $$
  select trim(regexp_replace(
    replace(replace(replace(replace(lower(coalesce(quelle, '')),
      'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss'),
    '[^a-z0-9]+', ' ', 'g'));
$$;

-- ── Der geteilte Typ-Bestand ─────────────────────────────────────────────
create table public.equipment_types (
  id uuid primary key default gen_random_uuid(),
  gesamtwehr_id uuid not null
    references public.gesamtwehren (id) on delete cascade,
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  -- Archiviert statt gelöscht. Zwei Gründe: Ein inkrementeller Pull
  -- (`updated_at > zuletzt`) sieht harte Löschungen prinzipiell nicht, und
  -- ein Typ kann in einer anderen Abteilung noch zugeordnet sein.
  deleted_at timestamptz
);

-- Das Pull-Fenster des zeilenweisen Syncs.
create index equipment_types_pull_idx
  on public.equipment_types (gesamtwehr_id, updated_at);

-- Katalog-Typen sind über ihre Katalog-ID eindeutig — hier lohnt die harte
-- Zusage. Über den NAMEN gibt es bewusst KEINEN Unique-Index: Er würde eine
-- Umbenennung auf einen belegten Namen mit einer kryptischen
-- Constraint-Meldung abbrechen. Über Namen wird nur beim Anlegen
-- zusammengeführt (siehe find_or_create_equipment_type).
create unique index equipment_types_katalog_idx
  on public.equipment_types (gesamtwehr_id, library_equipment_id)
  where library_equipment_id is not null and deleted_at is null;

create index equipment_types_name_idx
  on public.equipment_types
     (gesamtwehr_id, public.normalize_equipment_name(name))
  where deleted_at is null;

-- ── Die Abteilungs-Projektion ────────────────────────────────────────────
-- `on delete set null`, nicht `restrict`: Wird eine Gesamtwehr gelöscht,
-- sollen ihre Abteilungen nicht mit einem Constraint-Fehler blockieren. Der
-- Verweis ist dann leer, und der nächste Publish stellt ihn wieder her.
alter table public.equipment_items
  add column type_id uuid references public.equipment_types (id)
    on delete set null;

create index equipment_items_type_idx on public.equipment_items (type_id);

-- ── Das Gedächtnis über den Publish-Zyklus hinweg ────────────────────────
-- `publish_snapshot` LÖSCHT die Zeilen der Abteilung und fügt die Payload neu
-- ein — `equipment_items.type_id` überlebt das nicht. Für einen Client, der
-- `type_id` schon mitschickt, ist das egal; ein Alt-Client schickt aber nur
-- den Namen, und über den findet er einen inzwischen UMBENANNTEN Typ nicht
-- mehr wieder. Ohne dieses Gedächtnis entstünde bei jedem zentralen
-- Umbenennen ein Zwilling.
--
-- Die Tabelle liegt bewusst außerhalb des Snapshots: Sie ist Buchhaltung des
-- Servers, nicht Bestand der Abteilung.
create table public.equipment_type_links (
  abteilung_id uuid not null
    references public.abteilungen (id) on delete cascade,
  local_id bigint not null,
  type_id uuid not null
    references public.equipment_types (id) on delete cascade,
  primary key (abteilung_id, local_id)
);

grant select on public.equipment_type_links to authenticated;
grant all on public.equipment_type_links to service_role;
alter table public.equipment_type_links enable row level security;
create policy "read own abteilung" on public.equipment_type_links
  for select to authenticated
  using (public.can_read_abteilung(abteilung_id));

-- ── Typ finden oder anlegen ──────────────────────────────────────────────
-- Die einzige Stelle, an der ein Typ entsteht. Zusammengeführt wird über die
-- Katalog-ID (eindeutig) und sonst über den normalisierten Namen — dieselbe
-- Reihenfolge wie im Import-Matcher.
--
-- `nur_anlegen` ist der Alt-Client-Schalter: Eine Snapshot-Payload ohne
-- `type_id` stammt aus einer App, die von Typen nichts weiß. Sie darf einen
-- fehlenden Typ ANLEGEN, aber niemals den Inhalt eines bestehenden
-- überschreiben — sonst kippt ein alter Client die Pflege einer anderen
-- Abteilung zurück.
-- `anlegen = false` macht daraus ein reines Suchen — der Trigger braucht
-- beide Hälften getrennt, weil zwischen Suchen und Anlegen noch das
-- Verknüpfungs-Gedächtnis befragt wird.
create function public.find_or_create_equipment_type(
  gw uuid,
  zeile jsonb,
  nur_anlegen boolean default true,
  anlegen boolean default true
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  treffer uuid;
  norm text := public.normalize_equipment_name(zeile ->> 'name');
begin
  if gw is null then
    return null;
  end if;

  if nullif(zeile ->> 'library_equipment_id', '') is not null then
    select id into treffer from public.equipment_types
     where gesamtwehr_id = gw
       and library_equipment_id = zeile ->> 'library_equipment_id'
       and deleted_at is null
     limit 1;
  end if;

  if treffer is null and norm <> '' then
    select id into treffer from public.equipment_types
     where gesamtwehr_id = gw
       and public.normalize_equipment_name(name) = norm
       and deleted_at is null
     limit 1;
  end if;

  if treffer is not null then
    if not nur_anlegen then
      update public.equipment_types set
        name = coalesce(zeile ->> 'name', name),
        short_name = zeile ->> 'short_name',
        equipment_functions_json =
          coalesce(zeile ->> 'equipment_functions_json', equipment_functions_json),
        deployment_scenarios_json =
          coalesce(zeile ->> 'deployment_scenarios_json', deployment_scenarios_json),
        description = coalesce(zeile ->> 'description', description),
        image_path = zeile ->> 'image_path',
        training_url = zeile ->> 'training_url',
        library_equipment_id = zeile ->> 'library_equipment_id',
        is_custom = coalesce((zeile ->> 'is_custom')::boolean, is_custom),
        extra_attributes_json =
          coalesce(zeile ->> 'extra_attributes_json', extra_attributes_json),
        training_questions_json =
          coalesce(zeile ->> 'training_questions_json', training_questions_json),
        typical_use_json =
          coalesce(zeile ->> 'typical_use_json', typical_use_json),
        updated_at = now(),
        updated_by = auth.uid()
      where id = treffer;
    end if;
    return treffer;
  end if;

  if not anlegen then
    return null;
  end if;

  insert into public.equipment_types (
    gesamtwehr_id, name, short_name, equipment_functions_json,
    deployment_scenarios_json, description, image_path, training_url,
    library_equipment_id, is_custom, extra_attributes_json,
    training_questions_json, typical_use_json, updated_by)
  values (
    gw,
    coalesce(nullif(zeile ->> 'name', ''), 'Unbenannt'),
    zeile ->> 'short_name',
    coalesce(zeile ->> 'equipment_functions_json', '[]'),
    coalesce(zeile ->> 'deployment_scenarios_json', '[]'),
    coalesce(zeile ->> 'description', ''),
    zeile ->> 'image_path',
    zeile ->> 'training_url',
    nullif(zeile ->> 'library_equipment_id', ''),
    coalesce((zeile ->> 'is_custom')::boolean, false),
    coalesce(zeile ->> 'extra_attributes_json', '{}'),
    coalesce(zeile ->> 'training_questions_json', '[]'),
    coalesce(zeile ->> 'typical_use_json', '[]'),
    auth.uid())
  returning id into treffer;
  return treffer;
end;
$$;

-- ── Jede eingehende Zeile bekommt ihren Typ ──────────────────────────────
-- Bewusst ein Trigger und KEINE Erweiterung von `publish_snapshot`: Der
-- Snapshot-Weg ist nicht der einzige (Seeder, Import, künftige Wege), und
-- eine abgeschriebene 90-Zeilen-Funktion driftet mit der Zeit vom Original
-- weg. Der Trigger deckt jeden Schreibweg ab und bleibt an einer Stelle.
--
-- `nur_anlegen = true`: Eine Payload ohne `type_id` stammt aus einer App,
-- die von Gesamtwehr-Typen nichts weiß. Sie darf einen fehlenden Typ
-- anlegen, aber keinen bestehenden überschreiben — sonst kippt ein alter
-- Client die Pflege einer anderen Abteilung zurück.
create function public.equipment_items_typ_zuweisen()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  gw uuid;
  gemerkt uuid;
begin
  select gesamtwehr_id into gw
    from public.abteilungen where id = new.abteilung_id;
  if gw is null then
    -- Abteilung ohne Gesamtwehr: kein geteilter Bestand, kein Typ.
    return new;
  end if;

  if new.type_id is null then
    -- Reihenfolge mit Absicht: Erst über Katalog-ID und Namen suchen, DANN
    -- erst auf das Gedächtnis zurückfallen. Andersherum würde eine
    -- Neuinstallation, die wieder bei ID 1 beginnt, an den Typ des alten
    -- Geräts 1 gekettet. So gewinnt immer die Bedeutung vor der Buchhaltung,
    -- und das Gedächtnis greift genau dann, wenn der Name nichts mehr
    -- trifft — also nach einem zentralen Umbenennen.
    new.type_id :=
      public.find_or_create_equipment_type(gw, to_jsonb(new), true, false);
    if new.type_id is null then
      select l.type_id into gemerkt from public.equipment_type_links l
        join public.equipment_types t on t.id = l.type_id
       where l.abteilung_id = new.abteilung_id
         and l.local_id = new.id
         and t.gesamtwehr_id = gw
         and t.deleted_at is null;
      new.type_id := gemerkt;
    end if;
    if new.type_id is null then
      -- Hier gibt es per Definition keinen Treffer mehr (die Suche oben ist
      -- schon leer ausgegangen), `nur_anlegen` ist an dieser Stelle also
      -- wirkungslos — der wirksame Schalter sitzt im ERSTEN Aufruf.
      new.type_id :=
        public.find_or_create_equipment_type(gw, to_jsonb(new), true, true);
    end if;
  end if;

  insert into public.equipment_type_links (abteilung_id, local_id, type_id)
    values (new.abteilung_id, new.id, new.type_id)
    on conflict (abteilung_id, local_id)
      do update set type_id = excluded.type_id;
  return new;
end;
$$;

create trigger equipment_items_typ_zuweisen
  before insert or update on public.equipment_items
  for each row execute function public.equipment_items_typ_zuweisen();

-- ── Backfill: bestehende Bestände in den geteilten Typ-Bestand heben ─────
-- Reihenfolge ist wichtig: Katalog-Geräte zuerst, damit sie den Typ prägen
-- und selbst angelegte Geräte gleichen Namens sich daran anhängen.
do $$
declare
  z record;
  neu uuid;
begin
  for z in
    select e.abteilung_id, e.id, a.gesamtwehr_id, to_jsonb(e) as zeile
      from public.equipment_items e
      join public.abteilungen a on a.id = e.abteilung_id
     where a.gesamtwehr_id is not null
     order by (e.library_equipment_id is null), e.id
  loop
    neu := public.find_or_create_equipment_type(z.gesamtwehr_id, z.zeile, true);
    update public.equipment_items set type_id = neu
     where abteilung_id = z.abteilung_id and id = z.id;
  end loop;
end;
$$;

-- ── Wer darf den geteilten Bestand lesen und schreiben? ──────────────────
-- Lesen: wer irgendeine Abteilung der Gesamtwehr lesen darf.
create function public.can_read_gesamtwehr(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships m
    join public.abteilungen a on a.id = m.abteilung_id
    where m.user_id = auth.uid() and a.gesamtwehr_id = ziel
  )
  or exists (
    select 1 from public.gesamtwehr_kommandanten k
    where k.user_id = auth.uid() and k.gesamtwehr_id = ziel
  );
$$;

-- Schreiben: Schreibrolle in IRGENDEINER Abteilung der Gesamtwehr oder deren
-- Kommandant. Bewusst weiter als `can_publish_abteilung` — der Typ-Bestand
-- gehört der ganzen Wehr, und genau das war Marcus' Entscheidung: „Ändern
-- darf jeder Gerätewart der Gesamtwehr."
create function public.can_write_gesamtwehr_types(ziel uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships m
    join public.abteilungen a on a.id = m.abteilung_id
    where m.user_id = auth.uid()
      and a.gesamtwehr_id = ziel
      and m.role in ('admin', 'geraetewart')
  )
  or exists (
    select 1 from public.gesamtwehr_kommandanten k
    where k.user_id = auth.uid() and k.gesamtwehr_id = ziel
  );
$$;

alter table public.equipment_types enable row level security;

-- Nur Lesen per Policy. Geschrieben wird ausschließlich über die RPC unten —
-- dieselbe Disziplin wie beim Snapshot (AGENTS.md: Schreibwege gehen über
-- geprüfte Funktionen, nie direkt auf die Tabelle).
create policy "read own gesamtwehr" on public.equipment_types
  for select to authenticated
  using (public.can_read_gesamtwehr(gesamtwehr_id));

grant select on public.equipment_types to authenticated;
grant all on public.equipment_types to service_role;

-- ── Verwendung: löschen oder archivieren? ────────────────────────────────
-- Marcus' Regel: „Gelöscht wird nur, was in KEINER Abteilung zugeordnet ist —
-- sonst archivieren." Die Entscheidung trifft die App, die Zahlen liefert der
-- Server; RLS auf equipment_items zeigt einem Client nur die eigene und die
-- Schwester-Abteilungen, die Frage geht aber über die ganze Gesamtwehr.
create function public.equipment_type_verwendung(ziel uuid)
returns table (abteilung_id uuid, zuordnungen bigint, exemplare bigint)
language sql
security definer set search_path = ''
stable
as $$
  select e.abteilung_id,
         (select count(*) from public.equipment_assignments x
           where x.abteilung_id = e.abteilung_id and x.equipment_id = e.id),
         (select count(*) from public.equipment_instances i
           where i.abteilung_id = e.abteilung_id and i.equipment_id = e.id)
    from public.equipment_items e
    join public.equipment_types t on t.id = ziel
   where e.type_id = ziel
     and public.can_read_gesamtwehr(t.gesamtwehr_id);
$$;

-- ── Der zeilenweise Schreibweg ───────────────────────────────────────────
-- Nimmt geänderte Typen einer Gesamtwehr entgegen und gibt zurück, was
-- danach zentral gilt. Letzte Änderung gewinnt, aber je ZEILE statt je
-- Bestand — das ist der ganze Unterschied zum Snapshot.
--
-- `deleted_at` setzen heißt archivieren. Ob die App das „löschen" oder
-- „archivieren" nennt, entscheidet sie anhand von equipment_type_verwendung;
-- der Server unterscheidet nicht, weil beides derselbe Vorgang ist.
create function public.push_equipment_types(gw uuid, aenderungen jsonb)
returns jsonb
language plpgsql
security definer set search_path = ''
as $$
declare
  zeile jsonb;
  vorhanden public.equipment_types;
  ziel uuid;
  ergebnis jsonb := '[]'::jsonb;
begin
  if not public.can_write_gesamtwehr_types(gw) then
    raise exception 'permission denied: editor role in this gesamtwehr required';
  end if;

  for zeile in select * from jsonb_array_elements(coalesce(aenderungen, '[]'::jsonb))
  loop
    ziel := nullif(zeile ->> 'id', '')::uuid;
    vorhanden := null;
    if ziel is not null then
      select * into vorhanden from public.equipment_types
       where id = ziel and gesamtwehr_id = gw;
    end if;

    if vorhanden.id is null then
      -- Unbekannte oder fehlende ID: zusammenführen statt blind anlegen,
      -- sonst entstehen bei zwei Gerätewarten zwei „Kübelspritzen".
      ziel := public.find_or_create_equipment_type(gw, zeile, false);
    else
      -- Letzte Änderung gewinnt: Ein älterer Stand aus einem Gerät, das
      -- lange offline war, darf die neuere Pflege nicht zurückrollen.
      if vorhanden.updated_at <= coalesce(
           (zeile ->> 'updated_at')::timestamptz, now()) then
        update public.equipment_types set
          name = coalesce(nullif(zeile ->> 'name', ''), name),
          short_name = zeile ->> 'short_name',
          equipment_functions_json = coalesce(
            zeile ->> 'equipment_functions_json', equipment_functions_json),
          deployment_scenarios_json = coalesce(
            zeile ->> 'deployment_scenarios_json', deployment_scenarios_json),
          description = coalesce(zeile ->> 'description', description),
          image_path = zeile ->> 'image_path',
          training_url = zeile ->> 'training_url',
          library_equipment_id = nullif(zeile ->> 'library_equipment_id', ''),
          is_custom = coalesce((zeile ->> 'is_custom')::boolean, is_custom),
          extra_attributes_json = coalesce(
            zeile ->> 'extra_attributes_json', extra_attributes_json),
          training_questions_json = coalesce(
            zeile ->> 'training_questions_json', training_questions_json),
          typical_use_json =
            coalesce(zeile ->> 'typical_use_json', typical_use_json),
          deleted_at = (zeile ->> 'deleted_at')::timestamptz,
          updated_at = now(),
          updated_by = auth.uid()
        where id = ziel;
      end if;
    end if;

    ergebnis := ergebnis || jsonb_build_array(
      (select to_jsonb(t) from public.equipment_types t where t.id = ziel));
  end loop;

  return ergebnis;
end;
$$;

revoke execute on function public.normalize_equipment_name(text),
  public.find_or_create_equipment_type(uuid, jsonb, boolean, boolean),
  public.equipment_items_typ_zuweisen(),
  public.can_read_gesamtwehr(uuid), public.can_write_gesamtwehr_types(uuid),
  public.equipment_type_verwendung(uuid),
  public.push_equipment_types(uuid, jsonb) from public, anon;

-- ⚠️ `revoke ... from public` nimmt auch service_role das Recht — der
-- Autodeploy und die Edge Functions brauchen es danach explizit zurück
-- (Lehre aus Stufe ①, steht im DocuHub unter datenhaltung.md).
grant execute on function public.normalize_equipment_name(text),
  public.can_read_gesamtwehr(uuid), public.can_write_gesamtwehr_types(uuid),
  public.equipment_type_verwendung(uuid),
  public.push_equipment_types(uuid, jsonb) to authenticated;
grant execute on function public.normalize_equipment_name(text),
  public.find_or_create_equipment_type(uuid, jsonb, boolean, boolean),
  public.equipment_items_typ_zuweisen(),
  public.can_read_gesamtwehr(uuid), public.can_write_gesamtwehr_types(uuid),
  public.equipment_type_verwendung(uuid),
  public.push_equipment_types(uuid, jsonb) to service_role;
