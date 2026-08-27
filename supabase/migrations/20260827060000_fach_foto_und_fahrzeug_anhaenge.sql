-- 20260827060000_fach_foto_und_fahrzeug_anhaenge.sql
-- Fotos je Geräteraum (Issue #181) und Unterlagen am Fahrzeug (Issue #182).
--
-- Zwei Wünsche, ein Thema: An Fahrzeug und Fach hängt mehr als Text. Ein
-- Geräteraum ist auf einem Foto in einer Sekunde erfasst, wofür eine
-- Fachliste zehn Zeilen braucht — und die Betriebsanleitung nützt nur, wo
-- das Fahrzeug steht.
--
-- ═══ 1. Foto je Fach: eine Spalte, sonst nichts ═══════════════════════════
--
-- `compartments` liegt im Snapshot. Eine neue Spalte fließt dort von selbst
-- mit: `publish_snapshot` benutzt `jsonb_populate_recordset`, das zählt
-- keine Spalten auf. Fehlt der Schlüssel in der Nutzlast, kommt NULL an.
--
-- ⚠️ ROLLOUT-REIHENFOLGE, wörtlich wie bei Seite (#126) und Längsposition
--    (#141): 1. Migration einspielen, 2. App-Version ausrollen,
--    3. `minimum_supported_version` heben. Schritt 3 ist NICHT kosmetisch —
--    ein Alt-Client schickt Fächer OHNE `image_path`, und weil
--    Veröffentlichen die Tabelle ERSETZT, sind danach die Fotos der ganzen
--    Abteilung weg.
--    ⚠️ Und Schritt 3 darf nie über den FREIGEGEBENEN Stand hinausgehen
--    (`releases/latest`), sonst findet der Gerätewart im Update-Banner
--    nichts, womit er die Sperre auflösen könnte.

alter table public.compartments
  add column if not exists image_path text;

comment on column public.compartments.image_path is
  'Foto des Geraeteraums (Issue #181). Marker der Form '
  'supabase://equipment-images/<objekt>, wie equipment_items.image_path — '
  'derselbe Bucket, weil das Schreibrecht dasselbe ist: der Geraetewart.';

-- ═══ 2. Unterlagen am Fahrzeug: eigene Tabelle, NICHT im Snapshot ═════════
--
-- ⚠️ DER ENTSCHEIDENDE PUNKT. `publish_snapshot` LÖSCHT alle Zeilen der
-- Abteilung und fügt die Nutzlast neu ein. Zwei Folgen, die beide gegen den
-- naheliegenden Entwurf sprechen:
--
--   a) Ein Fremdschlüssel auf `vehicles` mit `on delete cascade` würde bei
--      JEDER Veröffentlichung jeden Anhang mitlöschen. Deshalb trägt
--      `vehicle_id` hier die LOKALE Drift-ID ohne Fremdschlüssel — genau wie
--      `equipment_type_links.local_id` (20260802160000). Die IDs sind
--      mandantenscharf stabil, die Zuordnung überlebt den Publish-Zyklus.
--
--   b) Läge die Tabelle IM Snapshot, würde ein Alt-Client — der von ihr
--      nichts weiß und den Schlüssel gar nicht mitschickt — bei seiner
--      nächsten Veröffentlichung sämtliche Unterlagen der Abteilung
--      löschen. Bei einer neuen Spalte ist das ärgerlich, hier wäre es der
--      Verlust hochgeladener Dokumente. Also eigener Weg, zeilenweise
--      geschrieben, wie bei den Gerätetypen (Issue #99).
--
-- Damit ist `publish_snapshot` bewusst UNVERÄNDERT. Wer die Tabelle später
-- doch in den Snapshot nimmt, muss zuerst (b) lösen.

create table if not exists public.vehicle_attachments (
  abteilung_id uuid not null
    references public.abteilungen (id) on delete cascade,
  -- Lokale Drift-ID des Anhangs, vergeben vom erfassenden Gerät.
  id           bigint not null,
  -- Lokale Drift-ID des Fahrzeugs. BEWUSST OHNE Fremdschlüssel, siehe oben.
  vehicle_id   bigint not null,
  title        text   not null,
  -- 'image' | 'document'. Die App entscheidet daran, ob sie das Ding selbst
  -- anzeigt oder an den Android-Betrachter weitergibt.
  kind         text   not null,
  mime_type    text   not null,
  -- Marker der Form supabase://vehicle-attachments/<abteilung>/<datei>.
  storage_path text   not null,
  size_bytes   bigint not null default 0,
  updated_at   timestamptz not null default now(),
  updated_by   uuid references auth.users (id) on delete set null,
  primary key (abteilung_id, id)
);

comment on table public.vehicle_attachments is
  'Unterlagen und Bilder am Fahrzeug (Issue #182). Bewusst AUSSERHALB des '
  'Snapshots: publish_snapshot ersetzt die Zeilen der Abteilung, ein '
  'Alt-Client wuerde damit alle Anhaenge loeschen. vehicle_id ist die LOKALE '
  'Drift-ID ohne Fremdschluessel, weil ein Cascade bei jeder '
  'Veroeffentlichung mitloeschen wuerde.';

alter table public.vehicle_attachments
  drop constraint if exists vehicle_attachments_kind_check;
alter table public.vehicle_attachments
  add constraint vehicle_attachments_kind_check
  check (kind in ('image', 'document'));

create index if not exists vehicle_attachments_fahrzeug_idx
  on public.vehicle_attachments (abteilung_id, vehicle_id);

alter table public.vehicle_attachments enable row level security;

-- Lesen: wer die Abteilung lesen darf. Das schließt die Quer-Sicht auf
-- Schwester-Abteilungen ein — dieselbe Regel wie beim Bestand.
create policy "read own abteilung" on public.vehicle_attachments
  for select to authenticated
  using (public.can_read_abteilung(abteilung_id));

-- Schreiben: wer für DIESE Abteilung veröffentlichen darf. Nicht `is_editor`
-- allein — das wäre „Gerätewart irgendwo" und ließe ihn in fremde
-- Abteilungen schreiben.
create policy "editor writes own abteilung" on public.vehicle_attachments
  for insert to authenticated
  with check (public.can_publish_abteilung(abteilung_id));

create policy "editor updates own abteilung" on public.vehicle_attachments
  for update to authenticated
  using (public.can_publish_abteilung(abteilung_id))
  with check (public.can_publish_abteilung(abteilung_id));

create policy "editor deletes own abteilung" on public.vehicle_attachments
  for delete to authenticated
  using (public.can_publish_abteilung(abteilung_id));

-- ⚠️ Ein frischer Stack gibt weder DML noch EXECUTE ohne expliziten Grant —
-- die App fände die Tabelle sonst gar nicht. RLS bleibt das Sicherheits-Gate.
grant select, insert, update, delete
  on public.vehicle_attachments to authenticated;
grant all on public.vehicle_attachments to service_role;

-- ═══ 3. Der Bucket für die Dateien ════════════════════════════════════════
--
-- Eigener Bucket statt `equipment-images`, weil hier zum ersten Mal etwas
-- liegt, das KEIN Bild ist: PDFs werden nicht verkleinert, nicht
-- umkomprimiert und brauchen mehr Platz. Ein gemeinsamer Bucket müsste seine
-- MIME-Liste und sein Größenlimit für den größten Fall öffnen — und damit
-- auch für Gerätefotos.
--
-- Der Ordner IST die Abteilung, wie beim Branding die Gesamtwehr: Die
-- Policies lesen sie aus dem ersten Pfadsegment.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'vehicle-attachments',
  'vehicle-attachments',
  false,
  20971520, -- 20 MB: eine gescannte Betriebsanleitung passt, ein Film nicht.
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy "vehicle-attachments read own abteilung" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'vehicle-attachments'
    and public.can_read_abteilung((storage.foldername(name))[1]::uuid)
  );

create policy "vehicle-attachments editor insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'vehicle-attachments'
    and public.can_publish_abteilung((storage.foldername(name))[1]::uuid)
  );

create policy "vehicle-attachments editor update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'vehicle-attachments'
    and public.can_publish_abteilung((storage.foldername(name))[1]::uuid)
  )
  with check (
    bucket_id = 'vehicle-attachments'
    and public.can_publish_abteilung((storage.foldername(name))[1]::uuid)
  );

create policy "vehicle-attachments editor delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'vehicle-attachments'
    and public.can_publish_abteilung((storage.foldername(name))[1]::uuid)
  );
