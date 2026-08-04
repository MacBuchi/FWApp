-- 20260804180000_fach_seiten.sql – Fächer bekommen eine Fahrzeugseite
-- (Issue #126, Feld-Rückmeldung von der Wehr).
--
-- Ziel: Der Beladeplan soll aussehen wie das Fahrzeug. Bisher lagen die
-- Fächer auf einem freien Raster (grid_row/grid_col) ohne jeden Bezug zur
-- Wirklichkeit — G1 konnte neben GR stehen. Mit der Seite lässt sich das
-- Fahrzeug flach aufklappen: Dach, Front, Fahrerseite, Heck,
-- Beifahrerseite.
--
-- DREI FESTLEGUNGEN:
--
-- 1. NULLABLE, KEIN BACKFILL. Welche Seite ein bestehendes Fach hat, weiß
--    diese Migration nicht — sie kennt nur seinen Namen. Aus „G3" auf
--    „Fahrerseite" zu schließen ist eine Konvention, keine Tatsache, und
--    eine still gesetzte falsche Seite ist schlimmer als gar keine. Die App
--    bietet den Vorschlag stattdessen sichtbar an; bestätigen tut ein
--    Mensch.
--
-- 2. FÜNF WERTE, NICHT VIER. `front` gibt es, weil manche Fahrzeuge ein
--    Frontgerätefach haben. Der Wert jetzt mitzunehmen kostet nichts; ihn
--    später nachzuziehen kostet eine Migration samt Alt-Client-Choreografie.
--
-- 3. DIE PUBLISH-FUNKTION BLEIBT UNVERÄNDERT. Sie füllt über
--    `jsonb_populate_recordset(null::public.compartments, …)` und zählt
--    keine Spalten auf — eine neue Spalte fließt von selbst mit, fehlt sie
--    in der Nutzlast, kommt NULL an.
--
-- ⚠️ ROLLOUT-REIHENFOLGE (wie #57 Phase 1): 1. Migration einspielen,
--    2. App-Version ausrollen, 3. `minimum_supported_version` heben.
--    Der dritte Schritt ist hier NICHT kosmetisch: Veröffentlicht ein
--    Alt-Client, schickt er Fächer OHNE `seite` — und weil Veröffentlichen
--    die Tabelle ersetzt, sind danach die Seiten der ganzen Abteilung weg.

alter table public.compartments add column if not exists seite text;

alter table public.compartments
  drop constraint if exists compartments_seite_check;
alter table public.compartments
  add constraint compartments_seite_check
  check (seite is null or seite in
    ('fahrerseite', 'beifahrerseite', 'heck', 'dach', 'front'));

comment on column public.compartments.seite is
  'Fahrzeugseite für das Aufklappbild (Issue #126): fahrerseite | '
  'beifahrerseite | heck | dach | front. NULL = noch nicht zugeordnet; die '
  'App zeigt solche Fächer in einem eigenen Bereich.';
