-- 20260922080000_geraete_codes.sql – Die Codes an den Geräten kommen beim
-- Rest der Wehr an (Issue #177).
--
-- ── Warum das überhaupt eine Migration braucht ──────────────────────────────
-- v1.49.0 und v1.50.0 haben das Vergeben, Aufkleben und Abscannen gebaut,
-- aber alles davon endete in der Datenbank DES GERÄTS. Der Gerätewart klebt
-- die Aufkleber, und beim nächsten Inventurtermin steht jemand anderes mit
-- seinem Handy vor dem Fahrzeug — dessen App kennt keinen einzigen Code und
-- scannt ins Leere. Ein Code, den nur ein Gerät kennt, ist kein Code,
-- sondern eine Notiz.
--
-- ── Warum AUSSERHALB des Snapshots ──────────────────────────────────────────
-- ⚠️ Wörtlich dieselbe Falle wie bei den Fahrzeug-Unterlagen
-- (20260827060000): `publish_snapshot` LÖSCHT die Zeilen der Abteilung und
-- fügt die Nutzlast neu ein. Läge diese Tabelle im Snapshot, würde ein
-- Alt-Client — der von ihr nichts weiß und den Schlüssel gar nicht
-- mitschickt — bei seiner nächsten Veröffentlichung sämtliche Codes der
-- Abteilung löschen. Die Aufkleber klebten dann weiter auf den Geräten und
-- zeigten auf nichts. Also eigener Weg, zeilenweise geschrieben.
--
-- Damit bleibt `publish_snapshot` bewusst UNVERÄNDERT.
--
-- ── Warum der Code der Schlüssel ist und nicht eine ID ───────────────────────
-- Der naheliegende Entwurf wäre `(abteilung_id, id)` mit der lokalen
-- Drift-ID, wie bei `vehicle_attachments`. Hier ist das falsch: Zwei
-- Gerätewarte, die am selben Nachmittag in zwei Geräteräumen Codes vergeben,
-- bekommen von ihrer jeweiligen lokalen Datenbank dieselben laufenden
-- Nummern. Beim Hochladen überschriebe der zweite den ersten, und ein
-- fertig aufgeklebter Aufkleber zeigte plötzlich auf ein anderes Gerät.
--
-- Der Code dagegen ist genau das, was in der Wirklichkeit eindeutig ist: Er
-- klebt auf einem Gegenstand. `(abteilung_id, code)` als Primärschlüssel
-- macht die Kollision unmöglich, statt sie unwahrscheinlich zu machen.
--
-- Eindeutig je ABTEILUNG, nicht global: Ein übernommener Hersteller-Barcode
-- ist in jeder Wehr derselbe — die Nummer auf dem Strahlrohr ist eine
-- Produktnummer. Global eindeutig hieße, dass die erste Wehr, die ihn
-- einträgt, ihn allen anderen wegnimmt.

create table if not exists public.equipment_tags (
  abteilung_id uuid not null
    references public.abteilungen (id) on delete cascade,
  -- Normalisiert abgelegt (App: `normalisiereTagCode`) — Leerraum weg,
  -- Großbuchstaben. Sonst liegt derselbe Aufkleber zweimal hier.
  code         text not null,
  -- Lokale Drift-ID der Geräte-Einheit, vergeben vom erfassenden Gerät.
  -- BEWUSST OHNE Fremdschlüssel: `equipment_instances` liegt im Snapshot,
  -- ein Cascade löschte bei jeder Veröffentlichung mit. Dieselbe Begründung
  -- wie bei `vehicle_attachments.vehicle_id` und
  -- `equipment_type_links.local_id`.
  instance_id  bigint not null,
  -- 'qr' | 'barcode' | 'nfc'. NFC ist noch nicht gebaut (#176), steht aber
  -- schon hier: Die Spalte später zu erweitern hieße, jeden Client
  -- anzufassen, der den Check kennt.
  kind         text not null default 'qr',
  -- Hat die App den Code vergeben (zum Ausdrucken) oder kam er von außen?
  -- Nur für die Anzeige — der Ablauf ist derselbe.
  self_issued  boolean not null default false,
  created_at   timestamptz not null default now(),
  -- ⚠️ Soft-Delete, kein `delete`. Ein Zug kann eine harte Löschung nicht
  -- sehen: Das andere Gerät bekäme die Zeile schlicht nicht mehr geliefert
  -- und könnte das nicht von „noch nie gesehen" unterscheiden — der Code
  -- käme beim nächsten Schieben wieder hoch. Dieselbe Lösung wie bei
  -- `quiz_questions` (#174).
  deleted_at   timestamptz,
  updated_at   timestamptz not null default now(),
  updated_by   uuid references auth.users (id) on delete set null,
  primary key (abteilung_id, code)
);

comment on table public.equipment_tags is
  'Codes an Geraete-Einheiten (Issue #177). Bewusst AUSSERHALB des '
  'Snapshots: publish_snapshot ersetzt die Zeilen der Abteilung, ein '
  'Alt-Client wuerde damit alle Codes loeschen. Schluessel ist der CODE, '
  'nicht die lokale ID — zwei Geraetewarte vergeben sonst dieselbe laufende '
  'Nummer. instance_id ist die LOKALE Drift-ID ohne Fremdschluessel.';

alter table public.equipment_tags
  drop constraint if exists equipment_tags_kind_check;
alter table public.equipment_tags
  add constraint equipment_tags_kind_check
  check (kind in ('qr', 'barcode', 'nfc'));

-- Leerer Code: Der ließe sich nie wieder abscannen und passte beim Suchen
-- auf alles. Die App fängt das ab (`normalisiereTagCode` gibt null zurück);
-- hier steht es noch einmal, weil eine Zusicherung in zwei Programmen
-- billiger ist als eine Zeile, die niemand mehr los wird.
alter table public.equipment_tags
  drop constraint if exists equipment_tags_code_check;
alter table public.equipment_tags
  add constraint equipment_tags_code_check
  check (length(btrim(code)) > 0);

-- Der Zug holt die Codes einer Abteilung; das Nachschlagen beim Scannen
-- passiert lokal. Deshalb genügt dieser eine Index.
create index if not exists equipment_tags_einheit_idx
  on public.equipment_tags (abteilung_id, instance_id);

alter table public.equipment_tags enable row level security;

-- Lesen: wer die Abteilung lesen darf. Das schließt die Quer-Sicht auf
-- Schwester-Abteilungen ein — dieselbe Regel wie beim Bestand.
create policy "read own abteilung" on public.equipment_tags
  for select to authenticated
  using (public.can_read_abteilung(abteilung_id));

-- Schreiben: wer für DIESE Abteilung veröffentlichen darf. Nicht
-- `is_editor` allein — das wäre „Gerätewart irgendwo" und ließe ihn Codes in
-- fremde Abteilungen kleben.
create policy "editor writes own abteilung" on public.equipment_tags
  for insert to authenticated
  with check (public.can_publish_abteilung(abteilung_id));

create policy "editor updates own abteilung" on public.equipment_tags
  for update to authenticated
  using (public.can_publish_abteilung(abteilung_id))
  with check (public.can_publish_abteilung(abteilung_id));

-- ── Rechte: erst entziehen, dann gezielt vergeben ───────────────────────────
--
-- ⚠️ **Eine frisch angelegte Tabelle erbt die Default-Privilegien des
-- Stacks.** 20260910120000 hat sie dem damaligen Bestand entzogen, aber ein
-- `revoke … on all tables` wirkt nur auf das, was zu seiner Zeit existierte.
-- Ohne die folgenden zwei Zeilen stehen hier `TRUNCATE`, `REFERENCES` und
-- `TRIGGER` für `anon` UND `authenticated` — nachgemessen am 2026-09-22 auf
-- CLI 2.109.1, gemeldet von tool/check_schema_grants.sql. Das ist genau die
-- Abhängigkeit vom Stack, die #185 aufgedeckt hat: Der Rechtestand gehört in
-- diese Datei, nicht in die Voreinstellung einer CLI-Version.
revoke insert, update, delete, truncate, references, trigger
  on public.equipment_tags from anon, authenticated, public;

-- `anon` liest hier nichts: Vor dem Login spricht die App keine Tabelle an,
-- und keine Policy nennt die Rolle.
revoke select on public.equipment_tags from anon, public;

-- ⚠️ KEINE Delete-Policy und kein Delete-Grant. Das Entfernen eines Codes
-- ist das Setzen von `deleted_at` — siehe oben. Wer hier `delete` vergibt,
-- öffnet genau den Weg, auf dem ein Code bei anderen Geräten wieder
-- auftaucht. Aufräumen alter Grabsteine ist Sache von service_role.
grant select, insert, update on public.equipment_tags to authenticated;
grant all on public.equipment_tags to service_role;
