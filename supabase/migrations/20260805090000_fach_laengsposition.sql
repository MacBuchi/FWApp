-- 20260805090000_fach_laengsposition.sql – Fächer bekommen eine Position
-- entlang der Fahrzeuglängsachse (Issue #141, Design „Geräteräume verorten").
--
-- Ziel: Nummer für die Kameraden, Seite und Position für den Kopf. Die Seite
-- (#126) sagt, an welcher Wand des Fahrzeugs ein Fach liegt — vorne/Mitte/
-- hinten sagt, wohin man an dieser Wand läuft. Zusammen ergibt das die
-- Draufsicht, auf der Übersicht, Anlegen und Lernmodus dasselbe Bild zeigen.
--
-- DIESELBEN FESTLEGUNGEN WIE BEI DER SEITE (20260804180000_fach_seiten.sql):
--
-- 1. NULLABLE, KEIN BACKFILL. „G3 liegt in der Mitte" ist dieselbe
--    Konvention wie „ungerade = Fahrerseite" — ein Vorschlag, den ein Mensch
--    bestätigt, keine Tatsache, die eine Migration setzt.
--
-- 2. NUR DREI WERTE. Die Position ist nur auf den Längsseiten sinnvoll;
--    Heck, Dach und Front tragen ihren Ort schon in der Seite. Die App
--    schlägt für solche Fächer nichts vor, der CHECK bleibt trotzdem eng.
--
-- 3. DIE PUBLISH-FUNKTION BLEIBT UNVERÄNDERT. `jsonb_populate_recordset`
--    zählt keine Spalten auf — die neue Spalte fließt von selbst mit, fehlt
--    sie in der Nutzlast, kommt NULL an.
--
-- ⚠️ ROLLOUT-REIHENFOLGE (wie #126): 1. Migration einspielen, 2. App-Version
--    ausrollen, 3. `minimum_supported_version` heben. Der dritte Schritt ist
--    NICHT kosmetisch: Veröffentlicht ein Alt-Client, schickt er Fächer OHNE
--    `laengsposition` — und weil Veröffentlichen die Tabelle ersetzt, sind
--    danach die Positionen der ganzen Abteilung weg.

alter table public.compartments
  add column if not exists laengsposition text;

alter table public.compartments
  drop constraint if exists compartments_laengsposition_check;
alter table public.compartments
  add constraint compartments_laengsposition_check
  check (laengsposition is null or laengsposition in
    ('vorne', 'mitte', 'hinten'));

comment on column public.compartments.laengsposition is
  'Position entlang der Fahrzeuglängsachse (Issue #141): vorne | mitte | '
  'hinten. NULL = keine gesetzt; nur auf Fahrer-/Beifahrerseite sinnvoll, '
  'die App schlägt sie dort aus dem Namen vor.';
