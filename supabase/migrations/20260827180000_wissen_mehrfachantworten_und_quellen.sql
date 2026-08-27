-- 20260827180000_wissen_mehrfachantworten_und_quellen.sql
-- Mehrfachantworten, Quellenangabe und Geltungsbereich für die
-- Wissensdatenbank (Issue #174, zweite Stufe).
--
-- ═══ Warum die Lösung eine Menge sein muss ════════════════════════════════
--
-- Der Fragenkatalog des Innenministeriums Baden-Württemberg zum
-- Feuerwehr-Leistungsabzeichen wurde ausgezählt: Von 210 Lösungen haben nur
-- 79 genau eine richtige Antwort. 63 % sind Mehrfachantworten, bis zu acht
-- richtige aus zehn Möglichkeiten. Eine Wissensdatenbank mit einem einzelnen
-- `richtig`-Index kann echten Pruefungsstoff also zu gut einem Drittel
-- abbilden — und ausgerechnet die fachlich dichten Fragen fallen heraus.
--
-- ═══ Warum die Quelle vier Spalten bekommt ════════════════════════════════
--
-- Weil man nach ihr filtern will. Wird das Feuerwehrgesetz geändert, muss
-- man alle Fragen mit `quelle_werk = 'FwG BW'` wiederfinden können; in einem
-- Fließtextfeld findet man sie nicht. `quelle_stand` ist die FASSUNG der
-- Quelle, nicht das Abrufdatum — eine Frage nach § 8 FwG haengt an der
-- Gesetzesfassung, nicht daran, wann jemand nachgesehen hat.
--
-- ═══ Warum es einen Geltungsbereich gibt ══════════════════════════════════
--
-- Der Lernzielkatalog der Truppmannausbildung belegt jedes Lernziel im
-- Abschnitt „Rechtsgrundlagen" mit einem Paragraphen des BADEN-
-- WÜRTTEMBERGISCHEN Feuerwehrgesetzes. In Bayern steht dort das BayFwG mit
-- anderen Regeln. Fachliches aus den Feuerwehr-Dienstvorschriften gilt
-- dagegen bundesweit. Also zwei Toepfe: `bund` und `land` + Laenderkuerzel.

alter table public.quiz_questions
  add column if not exists richtige_json text not null default '[0]';

alter table public.quiz_questions
  add column if not exists quelle_werk text;
alter table public.quiz_questions
  add column if not exists quelle_fundstelle text;
alter table public.quiz_questions
  add column if not exists quelle_stand text;
alter table public.quiz_questions
  add column if not exists quelle_url text;

alter table public.quiz_questions
  add column if not exists geltung text not null default 'bund';
alter table public.quiz_questions
  add column if not exists land text;

comment on column public.quiz_questions.richtige_json is
  'Indizes der richtigen Antworten als JSON-Liste, z. B. [0,3,5]. Eine '
  'MENGE, kein einzelner Index: 63 % des amtlichen Pruefungsstoffs sind '
  'Mehrfachantworten (Issue #174).';
comment on column public.quiz_questions.quelle_stand is
  'FASSUNG der Quelle (z. B. 2010-03-02), nicht das Abrufdatum.';
comment on column public.quiz_questions.geltung is
  'bund = gilt ueberall (Dienstvorschriften, Unfallverhuetung); '
  'land = Landesrecht, dann traegt land das Kuerzel.';

-- Der bisherige Einzel-Index wird zur einelementigen Menge.
-- ⚠️ Vor dem Verwerfen der Spalte, sonst ist die Zuordnung weg. Die Tabelle
-- ist erst seit heute in Betrieb; der Schritt ist trotzdem geschrieben, als
-- waere sie voll — eine Migration, die nur auf leeren Tabellen stimmt, ist
-- eine Falle fuer den naechsten Server.
update public.quiz_questions
  set richtige_json = '[' || richtig || ']'
  where richtig is not null;

alter table public.quiz_questions drop column if exists richtig;

-- Zwei Darstellungen derselben Sache laufen auseinander — deshalb faellt
-- `richtig` ganz weg statt danebenzustehen.

alter table public.quiz_questions
  drop constraint if exists quiz_questions_richtig_check;

alter table public.quiz_questions
  drop constraint if exists quiz_questions_geltung_check;
alter table public.quiz_questions
  add constraint quiz_questions_geltung_check
  check (
    (geltung = 'bund' and land is null)
    or (geltung = 'land' and land is not null)
  );

-- Laenderkuerzel wie im Kfz-Kennzeichen-Schema der Laender. Eng gefasst,
-- damit ein Tippfehler beim Import nicht still eine 17. „Region" anlegt.
alter table public.quiz_questions
  drop constraint if exists quiz_questions_land_check;
alter table public.quiz_questions
  add constraint quiz_questions_land_check
  check (land is null or land in (
    'BW','BY','BE','BB','HB','HH','HE','MV',
    'NI','NW','RP','SL','SN','ST','SH','TH'));

create index if not exists quiz_questions_geltung_idx
  on public.quiz_questions (gesamtwehr_id, geltung, land);
