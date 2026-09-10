-- frage_hinweise.sql – Jede Frage darf hinterfragt werden (Issue #194).
--
-- Marcus in der App (2026-08-28): „Bei Quizfragen (egal ob allgemein oder FW
-- Spezifisch) kann der Nutzer einen Kommentar / Änderungswunsch bzw Hinweis
-- abgeben. Bei globalen Fragen kann das über den Feedback Bot eingesammelt
-- und kategorisiert werden. Bei Eigenen Fragen sollte das beim Gerätewart
-- landen."
--
-- ── Warum das ZWEI Wege sind und nicht einer ───────────────────────────────
-- Weil die beiden Fragensorten an verschiedenen Orten leben. Eine
-- MITGELIEFERTE Frage steht auf jedem Gerät im Asset und wird bewusst nie
-- hochgeladen (siehe wissen_sync.dart) — sie hat auf dem Server gar keine
-- Zeile, auf die ein Hinweis zeigen könnte. Ein Fehler darin ist zudem ein
-- Fehler für ALLE Wehren, nicht für diese eine; er gehört ins Repo. Deshalb
-- geht dieser Weg über `feedback` und den Bot (siehe die Migration daneben,
-- die 'frage' als fünfte Meldungsart zulässt).
--
-- Eine EIGENE Frage dagegen gehört dieser Gesamtwehr allein. Ein Hinweis
-- darauf ist niemandes Sache außer der ihren, und schon gar nicht die eines
-- öffentlichen GitHub-Issues. Er landet hier und damit beim Gerätewart.
--
-- ── Warum sie jeder in der Wehr lesen darf ─────────────────────────────────
-- Damit der Meldende sieht, dass sein Hinweis angekommen ist und was daraus
-- wurde. Ein Briefkasten, in den man nur hineinwerfen kann, wird zweimal
-- benutzt und dann nicht mehr.

create table if not exists public.frage_hinweise (
  id            uuid primary key default gen_random_uuid(),
  gesamtwehr_id uuid not null
    references public.gesamtwehren (id) on delete cascade,
  -- Stirbt die Frage, stirbt der Hinweis mit ihr: Ein Hinweis auf eine Frage,
  -- die es nicht mehr gibt, ist kein Hinweis, sondern Rätselraten.
  frage_id      uuid not null
    references public.quiz_questions (id) on delete cascade,
  hinweis       text not null,
  von           uuid references auth.users (id) on delete set null,
  -- Anzeigename zum Zeitpunkt der Meldung, rein zur Nachvollziehbarkeit —
  -- dieselbe Begruendung wie bei quiz_questions.eingereicht_von.
  von_name      text,
  created_at    timestamptz not null default now(),
  erledigt_am   timestamptz,
  erledigt_von  uuid references auth.users (id) on delete set null,
  -- Dieselbe Grenze wie bei `feedback`: unten genug für einen Satz, oben
  -- knapp genug, dass niemand ein Logbuch hineinkippt.
  constraint frage_hinweise_laenge
    check (char_length(hinweis) between 3 and 2000)
);

comment on table public.frage_hinweise is
  'Hinweise und Aenderungswuensche zu EIGENEN Fragen dieser Gesamtwehr '
  '(#194). Mitgelieferte Fragen gehen stattdessen ueber feedback an den Bot. '
  'Geschrieben ausschliesslich ueber melde_frage_hinweis und '
  'erledige_frage_hinweis.';

-- Der Gerätewart fragt „was liegt offen?" — dafür ist das der Index.
create index if not exists frage_hinweise_offen
  on public.frage_hinweise (gesamtwehr_id, erledigt_am);

alter table public.frage_hinweise enable row level security;

create policy "read own gesamtwehr hinweise" on public.frage_hinweise
  for select to authenticated
  using (public.can_read_gesamtwehr(gesamtwehr_id));

grant select on public.frage_hinweise to authenticated;
grant all    on public.frage_hinweise to service_role;

-- ⚠️ Der Entzug gehört zu JEDER neuen Tabelle (#198). Ohne ihn verteilt der
-- Stack seine Default-Privileges — Supabase CLI 2.116.0 gibt jeder frischen
-- Tabelle `DELETE, INSERT, TRUNCATE, UPDATE` für beide Rollen, 2.109.1
-- immerhin noch `TRUNCATE, REFERENCES, TRIGGER`. Geschrieben wird hier
-- ausschließlich über die geprüfte Funktion, gelesen nur von
-- `authenticated`; alles andere ist ein Recht, das niemand braucht.
-- `tool/check_schema_grants.sql` prüft genau das und war es auch, der diese
-- Zeilen eingefordert hat.
revoke insert, update, delete, truncate, references, trigger
  on public.frage_hinweise from anon, authenticated, public;
revoke select on public.frage_hinweise from anon, public;

-- ── Melden darf jeder in der Wehr ───────────────────────────────────────────
-- Dieselbe Linie wie beim Einreichen einer Frage: beitragen darf jeder mit
-- Konto, entscheiden nur der Gerätewart. Die Funktion prüft zwei Dinge, die
-- der Aufrufer nicht selbst bestimmen darf — dass er die Wehr überhaupt lesen
-- darf, und dass die Frage auch wirklich zu dieser Wehr gehört. Ohne die
-- zweite Prüfung könnte man an eine fremde Frage schreiben, indem man die
-- eigene Wehr-ID mitschickt.
-- ⚠️ Der Parameter heißt `p_frage` und nicht `frage`: `quiz_questions` hat
-- eine Spalte dieses Namens, und in der Prüfung unten wäre `frage` damit
-- mehrdeutig — Postgres bricht mit 42702 ab, und zwar erst zur Laufzeit beim
-- ersten Aufruf. Gefunden hat das lernbereiche_e2e_test.dart; dieselbe
-- Präfix-Regel wie bei `p_gebiet`/`p_kapitel` nebenan.
create or replace function public.melde_frage_hinweis(
  gw uuid,
  p_frage uuid,
  text_hinweis text,
  melder_name text default null
)
returns public.frage_hinweise
language plpgsql
security definer set search_path = ''
as $$
declare
  ergebnis public.frage_hinweise;
begin
  if not public.can_read_gesamtwehr(gw) then
    raise exception 'permission denied: not a member of this gesamtwehr';
  end if;

  if not exists (
    select 1 from public.quiz_questions q
     where q.id = p_frage and q.gesamtwehr_id = gw and q.deleted_at is null
  ) then
    raise exception 'frage gehoert nicht zu dieser gesamtwehr';
  end if;

  insert into public.frage_hinweise
    (gesamtwehr_id, frage_id, hinweis, von, von_name)
  values (gw, p_frage, btrim(text_hinweis), auth.uid(),
          nullif(btrim(melder_name), ''))
  returning * into ergebnis;

  return ergebnis;
end;
$$;

-- ── Abhaken darf nur der Gerätewart ─────────────────────────────────────────
-- `erledigt` ist ein Schalter in beide Richtungen: Wer versehentlich abhakt,
-- soll das zurücknehmen können, ohne dass der Hinweis verloren geht.
create or replace function public.erledige_frage_hinweis(
  hinweis_id uuid,
  erledigt boolean default true
)
returns public.frage_hinweise
language plpgsql
security definer set search_path = ''
as $$
declare
  ergebnis public.frage_hinweise;
  wehr uuid;
begin
  select h.gesamtwehr_id into wehr
    from public.frage_hinweise h where h.id = hinweis_id;
  if wehr is null then
    raise exception 'hinweis nicht gefunden';
  end if;

  if not public.can_write_gesamtwehr_types(wehr) then
    raise exception 'permission denied: geraetewart of this gesamtwehr required';
  end if;

  update public.frage_hinweise
     set erledigt_am  = case when erledigt then now() else null end,
         erledigt_von = case when erledigt then auth.uid() else null end
   where id = hinweis_id
  returning * into ergebnis;

  return ergebnis;
end;
$$;

revoke execute on function
  public.melde_frage_hinweis(uuid, uuid, text, text),
  public.erledige_frage_hinweis(uuid, boolean) from public, anon;
grant execute on function
  public.melde_frage_hinweis(uuid, uuid, text, text),
  public.erledige_frage_hinweis(uuid, boolean) to authenticated;
grant execute on function
  public.melde_frage_hinweis(uuid, uuid, text, text),
  public.erledige_frage_hinweis(uuid, boolean) to service_role;

-- ── Der andere Weg: mitgelieferte Fragen gehen an den Bot ───────────────────
-- Fünfte Meldungsart neben feature/bug/katalog/fahrzeug, nach dem Muster von
-- 20260802180000 und 20260805130000. Ohne diese Zeilen scheitert das Insert
-- am Check-Constraint — und zwar stumm mit „Senden fehlgeschlagen", weil der
-- Client den Constraint-Namen nicht deutet.
alter table public.feedback drop constraint feedback_type_check;
alter table public.feedback add constraint feedback_type_check
  check (type in ('feature', 'bug', 'katalog', 'fahrzeug', 'frage'));
