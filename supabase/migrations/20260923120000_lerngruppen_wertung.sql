-- lerngruppen_wertung.sql – Wochenaufgabe und Wertung der Lerngruppen
-- (Issue #136), zweiter Teil.
--
-- ⚠️ DAS IST DER ERSTE WEG, AUF DEM LERNDATEN DAS GERÄT VERLASSEN.
-- Bis hierher liegen `quiz_results` und `learning_progress` ausschließlich
-- lokal. Was ab jetzt zum Server geht, ist mit Marcus am 2026-09-23 genau
-- so festgelegt — und diese Migration lässt technisch nichts anderes zu:
--
--   * JE PERSON, GRUPPE UND KALENDERWOCHE EINE ZAHL: die Trefferquote in
--     Prozent (0–100) im Modus der Wochenaufgabe, gemittelt über die letzten
--     zwei Runden der Woche. Dazu der Zeitpunkt der Meldung.
--   * NICHT: welche Frage jemand falsch hatte, welches Gerät er nicht kennt,
--     wie oft er gespielt hat, die anderen Modi. Die Tabelle hat für nichts
--     davon eine Spalte. Das ist der Unterschied zwischen Spaß und Prüfung —
--     und in einer Freiwilligen Feuerwehr sitzt der Kommandant mit in der
--     Gruppe.
--
-- ⚠️ KEIN UPLOAD-PUFFER. Die App rechnet ihren Wert aus den lokalen
-- Ergebnissen jedes Mal neu und meldet ihn per Upsert, sobald Netz da ist.
-- Ein Wert, der doppelt ankommt, ist derselbe Wert; einer, der nie ankommt,
-- wird beim nächsten Mal neu gerechnet. Das hält die Single-Writer-Regel
-- (AGENTS.md: keine Offline-Write-Queues) — jede Zeile hat genau EINEN
-- Schreiber, ihre Person.
--
-- Die Kehrseite, bewusst hingenommen: Gemeldet wird nur die LAUFENDE Woche.
-- Wer Sonntagabend im Funkloch spielt und erst Montag wieder Netz hat, dem
-- fehlt die Runde in der alten Woche. Eine Meldung für vergangene Wochen
-- hieße dagegen, dass man die Rangliste sieht und danach nachbessert.
--
-- Rollout wie bei den ersten beiden Teilen (docs/NUTZERKONZEPT.md §7): Diese
-- Migration ändert für niemanden etwas, solange keine App meldet.

-- ── 1) Das Datum der Wehr ────────────────────────────────────────────────
--
-- ⚠️ `current_date` ist auf dem Server UTC. Zwischen 0 und 2 Uhr MESZ ist das
-- noch GESTERN — beim Durchklick von #231 endete eine um 1 Uhr gegründete
-- Gruppe deshalb einen Tag früher, als der Kalender sagt. Bei einer
-- Kalenderwoche wird das zum echten Fehler: Sonntag 23:30 UTC ist Montag
-- 01:30 in Deutschland, und die Meldung landete in der falschen Woche.
-- Die App ist einsprachig und die Wehren sind deutsch — also gilt die
-- Uhr der Wehr, fest verdrahtet an EINER Stelle.
create function public.lerngruppen_heute()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Europe/Berlin')::date;
$$;

comment on function public.lerngruppen_heute() is
  'Heutiges Datum in der Zeitzone der Wehr (Europe/Berlin), nicht UTC '
  '(Issue #136). Einzige Stelle, an der Lerngruppen das Datum bestimmen.';

-- Nur die Funktionen unten brauchen sie, und die laufen als Eigentümer.
revoke execute on function public.lerngruppen_heute() from public, anon;
grant execute on function public.lerngruppen_heute()
  to authenticated, service_role;

-- ── 2) Die Wochenaufgabe ─────────────────────────────────────────────────
--
-- ABGELEITET, nicht gespeichert (Issue #136: „derived, not stored per
-- member"). Die vier Modi laufen reihum, damit in vier Wochen jeder einmal
-- dran war; wo eine Gruppe in der Runde einsteigt, hängt an ihrer Kennung,
-- damit nicht jede Gruppe der Wehr in derselben Woche dasselbe spielt.
--
-- ⚠️ Karteikarten (`flashcards`) sind absichtlich NICHT dabei (Marcus,
-- 2026-09-23): Dort sagt man selbst, ob man es wusste. In einer Rangliste
-- lädt das zum Schummeln ein, und wer ehrlich ist, stünde hinten.
--
-- ⚠️ md5 statt `hashtext`: `hashtext` ist eine interne Funktion ohne
-- Stabilitätszusage über Postgres-Versionen. Wechselte sie mit einem
-- Upgrade, bekäme jede laufende Gruppe mitten in der Woche eine andere
-- Aufgabe — und die schon gemeldeten Werte gehörten zu einem Modus, der
-- nicht mehr gefragt ist.
create function public.lerngruppe_wochenaufgabe(
  p_gruppe uuid,
  p_tag date default null
)
returns table (woche date, modus text)
language sql
security definer set search_path = ''
stable
as $$
  with g as (
    select l.id,
           date_trunc('week',
             (l.created_at at time zone 'Europe/Berlin')::date)::date
             as startwoche,
           date_trunc('week',
             coalesce(p_tag, public.lerngruppen_heute()))::date as woche
      from public.lerngruppen l
     where l.id = p_gruppe
       -- Wer nicht drin ist, bekommt nichts — auch nicht „diese Gruppe gibt
       -- es", wie bei den Mitgliedernamen.
       and public.ist_lerngruppen_mitglied(p_gruppe)
  )
  select g.woche,
         -- ⚠️ `%` behält in Postgres das Vorzeichen; für einen Tag vor der
         -- Gründungswoche käme sonst Index 0 oder kleiner heraus — und das
         -- ist in einem SQL-Array still NULL, kein Fehler. Daher mod(mod+4).
         (array['compartment', 'image_recognition', 'cutaway', 'dragdrop'])[
           1 + mod(
             mod(
               ('x' || substr(md5(g.id::text), 1, 7))::bit(28)::int
               + (g.woche - g.startwoche) / 7,
               4
             ) + 4,
             4
           )
         ]
    from g;
$$;

comment on function public.lerngruppe_wochenaufgabe(uuid, date) is
  'Wochenaufgabe einer Lerngruppe: Montag der Kalenderwoche und Lernmodus '
  '(Issue #136). Abgeleitet, reihum ueber vier Modi, ohne Karteikarten. '
  'Nur fuer Mitglieder.';

revoke execute on function public.lerngruppe_wochenaufgabe(uuid, date)
  from public, anon;
grant execute on function public.lerngruppe_wochenaufgabe(uuid, date)
  to authenticated, service_role;

-- ── 3) Die Wertung ───────────────────────────────────────────────────────

create table public.lerngruppen_wertungen (
  gruppe_id    uuid not null,
  user_id      uuid not null,
  -- Montag der Kalenderwoche.
  woche        date not null check (extract(isodow from woche) = 1),
  modus        text not null check (
    modus in ('compartment', 'image_recognition', 'cutaway', 'dragdrop')
  ),
  -- Trefferquote in Prozent. Mehr steht hier nie.
  wert         smallint not null check (wert between 0 and 100),
  gemeldet_am  timestamptz not null default now(),
  primary key (gruppe_id, user_id, woche),
  -- ⚠️ Der Fremdschlüssel zeigt auf die MITGLIEDSCHAFT, nicht auf Gruppe
  -- und Person einzeln: Wer die Gruppe verlässt, nimmt seine Werte mit.
  -- Eine Rangliste, in der jemand steht, der gar nicht mehr dabei ist, wäre
  -- genau die Art Datenrest, die niemand erwartet.
  foreign key (gruppe_id, user_id)
    references public.lerngruppen_mitglieder (gruppe_id, user_id)
    on delete cascade
);

comment on table public.lerngruppen_wertungen is
  'Wertung je Person, Lerngruppe und Kalenderwoche: Trefferquote im Modus '
  'der Wochenaufgabe (Issue #136). Bewusst nur eine Zahl; geschrieben '
  'ausschliesslich ueber melde_lerngruppen_wert.';

alter table public.lerngruppen_wertungen enable row level security;

-- Dieselbe Grenze wie bei der Mitgliederliste: Die Gruppe sieht die Werte
-- ihrer Mitglieder, sonst niemand. Auch nicht der Kommandant der Wehr,
-- solange er nicht selbst mitspielt.
create policy "Mitglieder lesen die Wertung ihrer Gruppe"
  on public.lerngruppen_wertungen for select
  to authenticated
  using (public.ist_lerngruppen_mitglied(gruppe_id));

grant select on public.lerngruppen_wertungen to authenticated;
grant all    on public.lerngruppen_wertungen to service_role;

revoke insert, update, delete, truncate, references, trigger
  on public.lerngruppen_wertungen from anon, authenticated, public;
revoke select on public.lerngruppen_wertungen from anon, public;

-- ── 4) Melden ────────────────────────────────────────────────────────────
--
-- Der Aufrufer schickt Gruppe, Modus und Wert. Woche und Person setzt der
-- Server — beides aus der Hand zu geben hieße, dass man für andere oder
-- für vergangene Wochen melden kann.
--
-- Der Modus kommt trotzdem mit, als Gegenprobe: Die App fragt die Aufgabe
-- ab, rechnet und meldet — fällt dazwischen der Wochenwechsel (Sonntag,
-- 23:59:59), gehörte der Wert zur alten Aufgabe. Dann lieber ablehnen, die
-- App rechnet beim nächsten Mal für die neue Woche.
create function public.melde_lerngruppen_wert(
  p_gruppe uuid,
  p_modus text,
  p_wert int
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_heute date := public.lerngruppen_heute();
  v_gruppe public.lerngruppen;
  v_aufgabe record;
begin
  if not public.ist_lerngruppen_mitglied(p_gruppe) then
    raise exception 'Kein Mitglied dieser Lerngruppe'
      using errcode = '42501';
  end if;

  select * into v_gruppe from public.lerngruppen g where g.id = p_gruppe;
  if v_gruppe.laeuft_bis < v_heute then
    raise exception 'Diese Lerngruppe ist abgelaufen'
      using errcode = 'P0002';
  end if;

  if p_wert is null or p_wert < 0 or p_wert > 100 then
    raise exception 'Wert muss zwischen 0 und 100 liegen'
      using errcode = '22023';
  end if;

  select * into v_aufgabe
    from public.lerngruppe_wochenaufgabe(p_gruppe, v_heute);
  if v_aufgabe.modus is distinct from p_modus then
    raise exception 'Die Wochenaufgabe hat gewechselt'
      using errcode = '22023';
  end if;

  insert into public.lerngruppen_wertungen (
    gruppe_id, user_id, woche, modus, wert, gemeldet_am
  )
  values (p_gruppe, auth.uid(), v_aufgabe.woche, p_modus, p_wert, now())
  on conflict (gruppe_id, user_id, woche) do update
    set wert = excluded.wert,
        modus = excluded.modus,
        gemeldet_am = excluded.gemeldet_am;
end;
$$;

comment on function public.melde_lerngruppen_wert(uuid, text, int) is
  'Meldet die eigene Trefferquote der laufenden Woche (Upsert, Issue #136). '
  'Woche und Person setzt der Server; der Modus muss die Wochenaufgabe sein.';

revoke execute on function public.melde_lerngruppen_wert(uuid, text, int)
  from public, anon;
grant execute on function public.melde_lerngruppen_wert(uuid, text, int)
  to authenticated, service_role;

-- ── 5) Gründen und Beitreten auf die Uhr der Wehr ────────────────────────
--
-- Zwei Änderungen an den Funktionen aus 20260922190000, beide Folge der
-- Kalenderwoche:
--
--   * `lerngruppen_heute()` statt `current_date` (siehe 1).
--   * Eine Gruppe endet an einem SONNTAG. Mit Kalenderwochen hätte eine
--     Gruppe, die am Mittwoch endet, eine abgeschnittene letzte Woche, in
--     der die Rangliste nichts bedeutet. „8 Wochen" heißt jetzt: acht
--     Kalenderwochen, die angebrochene Gründungswoche mitgezählt. Wer am
--     Montag gründet, bekommt volle acht; wer am Samstag gründet, eine
--     Woche, die fast nur Anlauf ist — das ist ehrlicher als eine Woche,
--     die mitten im Dienstabend-Rhythmus aufhört.
--
-- `create or replace` mit gleicher Signatur: Kommentar und Rechte bleiben.

create or replace function public.erstelle_lerngruppe(
  p_gesamtwehr uuid,
  p_name text,
  p_wochen int default 8
)
returns public.lerngruppen
language plpgsql
security definer set search_path = ''
as $$
declare
  v_gruppe public.lerngruppen;
  v_code text;
  v_versuch int := 0;
  v_heute date := public.lerngruppen_heute();
begin
  if not public.can_read_gesamtwehr(p_gesamtwehr) then
    raise exception 'Keine Berechtigung fuer diese Gesamtwehr'
      using errcode = '42501';
  end if;
  if p_wochen < 1 or p_wochen > 26 then
    raise exception 'Laufzeit muss zwischen 1 und 26 Wochen liegen'
      using errcode = '22023';
  end if;

  loop
    v_versuch := v_versuch + 1;
    v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
    begin
      insert into public.lerngruppen (
        gesamtwehr_id, name, code, laeuft_bis, erstellt_von
      )
      values (
        p_gesamtwehr,
        btrim(p_name),
        v_code,
        -- Sonntag der letzten der p_wochen Kalenderwochen.
        (date_trunc('week', v_heute + 7 * (p_wochen - 1))::date + 6),
        auth.uid()
      )
      returning * into v_gruppe;
      exit;
    exception when unique_violation then
      if v_versuch >= 10 then
        raise exception 'Kein freier Beitrittscode gefunden'
          using errcode = '55000';
      end if;
    end;
  end loop;

  insert into public.lerngruppen_mitglieder (gruppe_id, user_id)
  values (v_gruppe.id, auth.uid());

  return v_gruppe;
end;
$$;

create or replace function public.tritt_lerngruppe_bei(p_code text)
returns public.lerngruppen
language plpgsql
security definer set search_path = ''
as $$
declare
  v_gruppe public.lerngruppen;
begin
  select * into v_gruppe
    from public.lerngruppen g
   where g.code = btrim(p_code);

  if v_gruppe.id is null then
    raise exception 'Diesen Beitrittscode gibt es nicht'
      using errcode = 'P0002';
  end if;
  if v_gruppe.laeuft_bis < public.lerngruppen_heute() then
    raise exception 'Diese Lerngruppe ist abgelaufen'
      using errcode = 'P0002';
  end if;
  if not public.can_read_gesamtwehr(v_gruppe.gesamtwehr_id) then
    raise exception 'Diese Lerngruppe gehoert zu einer anderen Feuerwehr'
      using errcode = '42501';
  end if;

  insert into public.lerngruppen_mitglieder (gruppe_id, user_id)
  values (v_gruppe.id, auth.uid())
  on conflict do nothing;

  return v_gruppe;
end;
$$;
