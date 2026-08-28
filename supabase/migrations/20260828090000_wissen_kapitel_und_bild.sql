-- 20260828090000_wissen_kapitel_und_bild.sql
-- Unterkapitel und Bild an der Wissensfrage (Issue #174, ABC-Einsatz).
--
-- ═══ Warum ein Unterkapitel und nicht ein weiteres Sachgebiet ═════════════
--
-- „Gefahrgut" ist EIN Sachgebiet, aber der Stoff dahinter zerfällt in Dinge,
-- die man einzeln übt: die Gefahrzettel und die orangefarbene Warntafel, die
-- Gefahrengruppen, die Dekon-Stufen, den Strahlenschutz. Vierzig Fragen in
-- einem Topf sind eine Liste, in der niemand gezielt das eine wiederholt,
-- was er nicht kann.
--
-- Ein weiteres Sachgebiet wäre der falsche Schnitt: Die Sachgebiete
-- entsprechen den Lehrgängen und sollen es weiter tun. Das Kapitel liegt
-- deshalb DARUNTER.
--
-- ⚠️ Freier Text und bewusst KEINE Aufzählung mit CHECK: Ein neues Kapitel
-- soll eine Zeile im mitgelieferten Asset kosten und keine Migration. Gegen
-- Tippfehler wacht `wissen_asset_test.dart` mit einer namentlichen Liste je
-- Bestandsdatei — ein verrutschter Buchstabe legte sonst still ein zweites,
-- fast gleich heißendes Kapitel an, und beide wären halb gefüllt.
--
-- ═══ Warum das Bild eine eigene Spalte bekommt ════════════════════════════
--
-- Bei manchen Fragen IST das Bild die Frage. Ein Gefahrzettel der Klasse 3
-- lässt sich nicht so umschreiben, dass die Frage noch prüft, was sie prüfen
-- soll — „rote Raute mit weisser Flamme" ist bereits die Antwort. Ohne Bild
-- gäbe es diese Fragen also gar nicht, und ausgerechnet die Kennzeichnung
-- ist das, was am Einsatzort als Erstes gelesen wird.
--
-- Der Inhalt ist heute IMMER ein Asset-Pfad (`assets/knowledge/bilder/…`),
-- weil nur mitgelieferte Fragen Bilder haben und mitgelieferte Fragen nie
-- hochgeladen werden. Die Spalte steht hier trotzdem: Der Abgleich muss
-- jede Spalte hin und zurück tragen können. Eine Spalte, die es lokal gibt
-- und auf dem Server nicht, verliert ihren Inhalt in dem Moment, in dem
-- jemand die Frage bearbeitet — still und ohne Fehlermeldung.
--
-- Wenn später eigene Bilder dazukommen, trägt die Spalte denselben
-- `supabase://bucket/pfad`-Marker wie `equipment_items.image_path`; die
-- Anzeige über `resolveImage` kann beides schon.

alter table public.quiz_questions
  add column if not exists kapitel text;
alter table public.quiz_questions
  add column if not exists bild_pfad text;

comment on column public.quiz_questions.kapitel is
  'Unterkapitel im Klartext („Gefahrzettel und Kennzeichnung"). Bewusst ohne '
  'CHECK: Ein neues Kapitel soll eine Zeile im Asset kosten, keine '
  'Migration. Getippfehlerschutz siehe wissen_asset_test.dart.';
comment on column public.quiz_questions.bild_pfad is
  'Bild zur Frage. Heute immer ein Asset-Pfad (assets/knowledge/bilder/...); '
  'fuer spaeter eigene Bilder derselbe supabase://-Marker wie bei '
  'equipment_items.image_path.';

-- Gefiltert wird nach Gebiet UND Kapitel, sobald der Gerätewart Kapitel
-- abwählen kann. Der Index nimmt das vorweg — er kostet bei wenigen hundert
-- Zeilen nichts und erspart den Nachtrag.
create index if not exists quiz_questions_kapitel_idx
  on public.quiz_questions (gesamtwehr_id, gebiet, kapitel);
