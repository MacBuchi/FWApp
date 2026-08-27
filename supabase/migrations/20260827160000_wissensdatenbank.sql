-- 20260827160000_wissensdatenbank.sql – Die Wissensdatenbank (Issue #174).
--
-- ═══ Warum eine geteilte Tabelle der GESAMTWEHR ═══════════════════════════
--
-- Feuerwehrwissen ist nicht abteilungsspezifisch: Ein B-Schlauch hat in
-- jeder Abteilung denselben Nenndurchmesser. Die Fragen gehören deshalb der
-- Gesamtwehr, genau wie die Gerätetypen (Stufe ②, Issue #99) — und aus
-- demselben Grund liegen sie NICHT im Snapshot: `publish_snapshot` ist
-- Einzelschreiber, zwei Gerätewarte würden sich beim Veröffentlichen
-- gegenseitig überschreiben. Abgeglichen wird zeilenweise über `updated_at`.
--
-- ═══ Wer was darf ═════════════════════════════════════════════════════════
--
-- Marcus' Vorgabe: **einreichen darf jeder mit Konto**, freigeben nur der
-- Gerätewart — „Filterung, damit kein blöder Unsinn in die Datenbank kommt".
-- Das steht hier als Policy und nicht nur in der App: Ausgeblendete
-- Oberfläche ist Komfort, die Schutzschicht ist RLS.
--
-- Die Insert-Policy erzwingt beides, was ein Einreichender nicht selbst
-- bestimmen darf:
--   * `stand = 'eingereicht'` — niemand gibt seine eigene Frage frei,
--   * `created_by = auth.uid()` — niemand reicht in fremdem Namen ein.
-- Ohne diese beiden Bedingungen wäre „einreichen" in Wahrheit „einstellen",
-- und die Freigabe eine Zierde.
--
-- ⚠️ `deleted_at` statt hartem Löschen — dieselbe Begründung wie bei
-- `equipment_types`: Ein inkrementeller Pull (`updated_at > zuletzt`) sieht
-- harte Löschungen prinzipiell nicht. Eine gelöschte Frage käme auf jedem
-- Gerät, das gerade offline war, nie wieder weg.

create table if not exists public.quiz_questions (
  id            uuid primary key default gen_random_uuid(),
  gesamtwehr_id uuid not null
    references public.gesamtwehren (id) on delete cascade,
  gebiet        text not null,
  frage         text not null,
  antworten_json text not null default '[]',
  richtig       integer not null default 0,
  erklaerung    text,
  -- 'mitgeliefert' | 'eigen'. Mitgeliefertes wird nie hochgeladen; es kommt
  -- auf jedem Gerät aus dem Asset und braucht die Leitung nicht.
  herkunft      text not null default 'eigen',
  stand         text not null default 'eingereicht',
  eingereicht_von text,
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users (id) on delete set null,
  deleted_at    timestamptz
);

comment on table public.quiz_questions is
  'Wissensdatenbank der Gesamtwehr (Issue #174). Ausserhalb des Snapshots, '
  'zeilenweise abgeglichen wie equipment_types. Einreichen darf jedes '
  'Mitglied der Wehr, freigeben nur der Geraetewart.';

alter table public.quiz_questions
  drop constraint if exists quiz_questions_stand_check;
alter table public.quiz_questions
  add constraint quiz_questions_stand_check
  check (stand in ('eingereicht', 'freigegeben', 'abgelehnt'));

alter table public.quiz_questions
  drop constraint if exists quiz_questions_richtig_check;
alter table public.quiz_questions
  add constraint quiz_questions_richtig_check
  check (richtig >= 0);

-- Die Frage muss eine sein. Dieselbe Mindestprüfung wie in der App
-- (`pruefeFrage`) — der Server verlaesst sich nicht darauf, dass ein Client
-- geprueft hat.
alter table public.quiz_questions
  drop constraint if exists quiz_questions_frage_check;
alter table public.quiz_questions
  add constraint quiz_questions_frage_check
  check (char_length(frage) between 8 and 500);

create index if not exists quiz_questions_wehr_idx
  on public.quiz_questions (gesamtwehr_id, updated_at);

alter table public.quiz_questions enable row level security;

create policy "read own gesamtwehr" on public.quiz_questions
  for select to authenticated
  using (public.can_read_gesamtwehr(gesamtwehr_id));

-- Einreichen: jedes Mitglied der Wehr, aber nur als Vorschlag im eigenen
-- Namen. Die beiden Bedingungen sind das ganze Gate.
create policy "jedes mitglied reicht ein" on public.quiz_questions
  for insert to authenticated
  with check (
    public.can_read_gesamtwehr(gesamtwehr_id)
    and stand = 'eingereicht'
    and created_by = auth.uid()
  );

-- Freigeben, ändern, archivieren: Gerätewart der Wehr und darüber.
create policy "geraetewart pflegt" on public.quiz_questions
  for update to authenticated
  using (public.can_write_gesamtwehr_types(gesamtwehr_id))
  with check (public.can_write_gesamtwehr_types(gesamtwehr_id));

-- Hartes Löschen bleibt dem Gerätewart vorbehalten und ist der Ausnahmeweg;
-- der Normalfall ist `deleted_at`.
create policy "geraetewart loescht" on public.quiz_questions
  for delete to authenticated
  using (public.can_write_gesamtwehr_types(gesamtwehr_id));

-- ⚠️ Ein frischer Stack gibt weder DML noch EXECUTE ohne expliziten Grant.
grant select, insert, update, delete on public.quiz_questions to authenticated;
grant all on public.quiz_questions to service_role;

-- `updated_at` fortschreiben, damit der inkrementelle Pull greift. Von Hand
-- gesetzte Werte wären der sichere Weg, sie irgendwann zu vergessen.
create or replace function public.quiz_questions_stempel()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

-- Trigger-Funktion: alle API-Grants entziehen. Der Trigger feuert weiter,
-- EXECUTE zählt beim Anlegen und nicht beim Feuern.
revoke all on function public.quiz_questions_stempel() from public, anon, authenticated;

drop trigger if exists quiz_questions_stempel_trg on public.quiz_questions;
create trigger quiz_questions_stempel_trg
  before update on public.quiz_questions
  for each row execute function public.quiz_questions_stempel();
