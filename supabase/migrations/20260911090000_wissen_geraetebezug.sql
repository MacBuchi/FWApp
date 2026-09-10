-- 20260911090000_wissen_geraetebezug.sql
-- Der Gerätebezug an der Wissensfrage — Fragen, die den Fuhrpark kennen.
--
-- ═══ Wozu ═════════════════════════════════════════════════════════════════
--
-- Marcus' Vorschlag: Die App weiß, welche Geräte auf den Fahrzeugen liegen —
-- dann soll sie auch danach fragen. Trägt eine Frage die Katalog-ID ihres
-- Geräts, kann das Spiel die Fragen zum EIGENEN Bestand bevorzugt stellen.
--
-- **Gewichten, nicht filtern** (entschieden): In der Wissensdatenbank bleibt
-- alles sichtbar und wird nur gekennzeichnet; im Spiel kommen die eigenen
-- Geräte bevorzugt dran, fremde gedeckelt (`kFremdeGeraeteAnteil`). Wer
-- filterte, nähme einer Wehr das Gerät der Nachbarwehr weg, das sie bei
-- jeder überörtlichen Hilfe sieht.
--
-- ═══ Warum die KATALOG-ID und nicht die Zeilennummer ══════════════════════
--
-- `std_b_druckschlauch_20m` ist auf jedem Gerät derselbe Schlüssel;
-- `equipment_items.id` ist es nicht — sie entsteht lokal beim Import und
-- stirbt beim nächsten. Verglichen wird deshalb gegen
-- `EquipmentItems.libraryEquipmentId`, denselben Schlüssel, an dem schon die
-- Symbolbilder und der Import-Matcher hängen.
--
-- ═══ Warum die Spalte hier steht, obwohl sie heute nur lokal gefüllt wird ══
--
-- Die erzeugten Gerätefragen sind `mitgeliefert` und werden nie hochgeladen
-- (siehe wissen_sync.dart) — auf dem Server steht also vorerst keine Zeile
-- mit Gerätebezug. Die Spalte gehört trotzdem jetzt hierher, aus genau dem
-- Grund, der schon bei `bild_pfad` galt: **Der Abgleich muss jede Spalte hin
-- und zurück tragen können.** Eine Spalte, die es lokal gibt und auf dem
-- Server nicht, verliert ihren Inhalt in dem Moment, in dem jemand die Frage
-- bearbeitet — still und ohne Fehlermeldung. Und der nächste Schritt sind
-- kuratierte Typ-Fragen, die ein Gerätewart selbst einreicht; die tragen den
-- Bezug dann wirklich.
--
-- ⚠️ Kein Fremdschlüssel und kein CHECK: Der Katalog ist ein App-Asset und
-- wächst mit einer App-Version, nicht mit einer Migration. Eine ID, die der
-- Server nicht kennt, ist kein Fehler — sie gehört zu einer neueren App.

alter table public.quiz_questions
  add column if not exists geraet text;

comment on column public.quiz_questions.geraet is
  'Katalog-ID des Geraets, um das es geht (std_...), derselbe Schluessel wie '
  'equipment_items.library_equipment_id. NULL = die Frage haengt an keinem '
  'bestimmten Geraet (Rechtskunde, ABC, Loeschlehre — der groesste Teil). '
  'Bewusst ohne Fremdschluessel: Der Katalog ist ein App-Asset.';

-- Das Spiel fragt „welche Fragen gehoeren zu diesen Geraeten?". Bei wenigen
-- hundert Zeilen kostet der Index nichts und erspart den Nachtrag.
create index if not exists quiz_questions_geraet_idx
  on public.quiz_questions (gesamtwehr_id, geraet);
