-- lerngruppen.sql – Lerngruppen auf Zeit (Issue #136), erster Teil.
--
-- Marcus' Idee: Ein paar Leute einer Gesamtwehr tun sich für ein paar
-- Wochen zusammen, laden sich über einen sechsstelligen Code ein und sehen
-- hinterher ein Ranking.
--
-- ⚠️ WARUM DAS MEHR IST ALS EIN BILDSCHIRM
-- Lernergebnisse verlassen das Gerät bisher NIE. `kSyncedTables` umfasst den
-- Bestand und sonst nichts; `quiz_results` und `learning_progress` sind rein
-- lokale Drift-Tabellen. Ein Ranking ist damit der erste Weg, auf dem
-- Lerndaten überhaupt zum Server gehen — und in einer Freiwilligen Feuerwehr
-- sitzt der Kommandant in der Gruppe mit.
--
-- Deshalb legt DIESE Migration ausdrücklich noch KEINE Punkte an. Sie legt
-- nur die Gruppe und ihre Mitgliedschaft an. Was am Ende wirklich hochgeht
-- (je Person, je Modus: eine Zahl und ein Zeitstempel — nie, welche Frage
-- jemand falsch hatte), kommt im zweiten Teil und wird dort einzeln
-- begründet. Ein Ranking, das nachträglich mehr mitnimmt als angekündigt,
-- ist der Unterschied zwischen Spaß und Prüfung.
--
-- ⚠️ ROLLOUT-REIHENFOLGE (docs/NUTZERKONZEPT.md §7, wie bei den
-- Einladungen): 1. Migration einspielen, 2. App-Version ausrollen,
-- 3. Mindestversion heben. Diese Migration allein ändert für niemanden
-- etwas — ohne App-Teil gibt es keinen Bildschirm, der eine Gruppe anlegt.
-- Das ist Absicht und der Grund, warum sie allein kommen darf.

-- ── 1) Die Gruppe ────────────────────────────────────────────────────────

create table public.lerngruppen (
  id             uuid primary key default gen_random_uuid(),
  gesamtwehr_id  uuid not null references public.gesamtwehren (id) on delete cascade,
  name           text not null check (length(btrim(name)) between 1 and 60),
  -- Sechsstellig und ziffernrein: Der Code wird vorgelesen und abgetippt,
  -- nicht angeklickt. Buchstaben brächten die Frage nach Groß- und
  -- Kleinschreibung und die Verwechslung von O und 0 mit.
  code           text not null unique check (code ~ '^[0-9]{6}$'),
  laeuft_bis     date not null,
  erstellt_von   uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now()
);

create index lerngruppen_gesamtwehr_idx
  on public.lerngruppen (gesamtwehr_id);

-- ⚠️ Der Code ist GLOBAL eindeutig, nicht nur unter den laufenden Gruppen.
-- Ein Teilindex `where laeuft_bis >= current_date` wäre das Naheliegende und
-- geht nicht: `current_date` ist STABLE, nicht IMMUTABLE, und Postgres lässt
-- es in einem Indexprädikat nicht zu. Global eindeutig ist ohnehin die
-- ehrlichere Zusicherung — sonst könnte ein Code, den jemand noch im Chat
-- stehen hat, später eine fremde Gruppe treffen.
comment on table public.lerngruppen is
  'Lerngruppe auf Zeit innerhalb einer Gesamtwehr (Issue #136). '
  'Beitritt ueber den sechsstelligen Code per RPC; bewusst keine '
  'Insert/Update/Delete-Policies.';

-- ── 2) Wer ist drin ──────────────────────────────────────────────────────

create table public.lerngruppen_mitglieder (
  gruppe_id      uuid not null references public.lerngruppen (id) on delete cascade,
  user_id        uuid not null references public.profiles (id) on delete cascade,
  beigetreten_am timestamptz not null default now(),
  primary key (gruppe_id, user_id)
);

create index lerngruppen_mitglieder_user_idx
  on public.lerngruppen_mitglieder (user_id);

comment on table public.lerngruppen_mitglieder is
  'Mitgliedschaft in einer Lerngruppe (Issue #136). Beitritt und Austritt '
  'ausschliesslich ueber die RPCs.';

-- ── 3) Der Policy-Helfer ─────────────────────────────────────────────────
--
-- ⚠️ OHNE DIESE FUNKTION DREHT SICH DIE POLICY IM KREIS.
-- „Sieh die Mitglieder einer Gruppe, in der du Mitglied bist" ist eine
-- Bedingung auf `lerngruppen_mitglieder`, die `lerngruppen_mitglieder`
-- abfragt. Postgres wertet dabei die Policy erneut aus und bricht mit
-- „infinite recursion detected in policy" ab — erst beim ersten echten
-- SELECT, nie beim Anlegen. `security definer` umgeht RLS und beendet die
-- Schleife.
--
-- ⚠️ Hier wird EXECUTE NICHT entzogen: Policies werten mit den Rechten der
-- anfragenden Rolle aus, ein Revoke bräche jedes `select` auf beiden
-- Tabellen. Das ist der Unterschied zu einem App-RPC und der Grund, warum
-- die drei Funktionen weiter unten anders behandelt werden.
create function public.ist_lerngruppen_mitglied(p_gruppe uuid)
returns boolean
language sql
security definer set search_path = ''
stable
as $$
  select exists (
    select 1 from public.lerngruppen_mitglieder m
     where m.gruppe_id = p_gruppe and m.user_id = auth.uid()
  );
$$;

comment on function public.ist_lerngruppen_mitglied(uuid) is
  'Policy-Helfer (Issue #136). security definer, weil die Policy auf '
  'lerngruppen_mitglieder sonst rekursiv waere. EXECUTE bewusst NICHT '
  'entzogen — Policies werten mit den Rechten des Aufrufers aus.';

-- ── 4) RLS ───────────────────────────────────────────────────────────────

alter table public.lerngruppen enable row level security;
alter table public.lerngruppen_mitglieder enable row level security;

-- Eine Gruppe sieht, wer drin ist. Nicht die ganze Gesamtwehr: Wer nicht
-- mitspielt, geht das Ergebnis nichts an — und der Beitritt läuft ohnehin
-- über den Code, nicht über eine Liste zum Durchstöbern.
create policy "Mitglieder lesen ihre Gruppe"
  on public.lerngruppen for select
  to authenticated
  using (public.ist_lerngruppen_mitglied(id));

create policy "Mitglieder lesen die Mitgliederliste"
  on public.lerngruppen_mitglieder for select
  to authenticated
  using (public.ist_lerngruppen_mitglied(gruppe_id));

-- ── 5) Rechte ────────────────────────────────────────────────────────────
--
-- Die API-Oberfläche ist opt-out (tool/check_schema_grants.sql). Ohne die
-- Revokes verteilt der Stack seine Default-Privileges an anon UND
-- authenticated, und der Guard macht die CI rot.

grant select on public.lerngruppen to authenticated;
grant select on public.lerngruppen_mitglieder to authenticated;
grant all    on public.lerngruppen to service_role;
grant all    on public.lerngruppen_mitglieder to service_role;

revoke insert, update, delete, truncate, references, trigger
  on public.lerngruppen from anon, authenticated, public;
revoke insert, update, delete, truncate, references, trigger
  on public.lerngruppen_mitglieder from anon, authenticated, public;
revoke select on public.lerngruppen from anon, public;
revoke select on public.lerngruppen_mitglieder from anon, public;

-- ── 6) Gruppe anlegen ────────────────────────────────────────────────────

create function public.erstelle_lerngruppe(
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
begin
  -- Wer die Gesamtwehr lesen darf, darf darin eine Gruppe aufmachen. Das
  -- ist bewusst kein Recht für Gerätewarte: Lernen ist nicht Bestand, und
  -- eine Lerngruppe zu gründen ist keine Verwaltungshandlung.
  if not public.can_read_gesamtwehr(p_gesamtwehr) then
    raise exception 'Keine Berechtigung fuer diese Gesamtwehr'
      using errcode = '42501';
  end if;
  if p_wochen < 1 or p_wochen > 26 then
    raise exception 'Laufzeit muss zwischen 1 und 26 Wochen liegen'
      using errcode = '22023';
  end if;

  -- Sechs Ziffern aus einer Million: Eine Kollision ist selten, aber nicht
  -- unmöglich, und „unique constraint violated" wäre für den Nutzer kein
  -- Satz. Also ein paar Versuche, dann ein verständlicher Fehler.
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
        (current_date + (p_wochen * 7))::date,
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

comment on function public.erstelle_lerngruppe(uuid, text, int) is
  'Legt eine Lerngruppe an und macht den Aufrufer zum ersten Mitglied '
  '(Issue #136). Nur fuer Mitglieder der Gesamtwehr.';

revoke execute on function public.erstelle_lerngruppe(uuid, text, int)
  from public, anon;
grant execute on function public.erstelle_lerngruppe(uuid, text, int)
  to authenticated;
grant execute on function public.erstelle_lerngruppe(uuid, text, int)
  to service_role;

-- ── 7) Beitreten ─────────────────────────────────────────────────────────

create function public.tritt_lerngruppe_bei(p_code text)
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

  -- ⚠️ Dieselbe Meldung für „gibt es nicht" und „ist abgelaufen" wäre
  -- bequem, aber falsch: Wer den Code richtig abgetippt hat und nur zu spät
  -- kommt, sucht sonst den Tippfehler. Ein Orakel ist das nicht — den Code
  -- muss man ohnehin schon haben.
  if v_gruppe.id is null then
    raise exception 'Diesen Beitrittscode gibt es nicht'
      using errcode = 'P0002';
  end if;
  if v_gruppe.laeuft_bis < current_date then
    raise exception 'Diese Lerngruppe ist abgelaufen'
      using errcode = 'P0002';
  end if;
  -- Die Gruppe lebt in EINER Gesamtwehr. Gruppen darüber hinaus sind
  -- Stufe-4-Gebiet (#101) und hier ausdrücklich nicht gemeint.
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

comment on function public.tritt_lerngruppe_bei(text) is
  'Tritt ueber den sechsstelligen Code bei (Issue #136). Nur innerhalb der '
  'eigenen Gesamtwehr und nur solange die Gruppe laeuft.';

revoke execute on function public.tritt_lerngruppe_bei(text)
  from public, anon;
grant execute on function public.tritt_lerngruppe_bei(text)
  to authenticated;
grant execute on function public.tritt_lerngruppe_bei(text)
  to service_role;

-- ── 8) Verlassen ─────────────────────────────────────────────────────────

create function public.verlasse_lerngruppe(p_gruppe uuid)
returns void
language sql
security definer set search_path = ''
as $$
  delete from public.lerngruppen_mitglieder
   where gruppe_id = p_gruppe and user_id = auth.uid();
$$;

comment on function public.verlasse_lerngruppe(uuid) is
  'Austritt aus einer Lerngruppe (Issue #136). Wirkt nur auf die eigene '
  'Mitgliedschaft — die Zeile des Aufrufers ist fest verdrahtet.';

revoke execute on function public.verlasse_lerngruppe(uuid)
  from public, anon;
grant execute on function public.verlasse_lerngruppe(uuid)
  to authenticated;
grant execute on function public.verlasse_lerngruppe(uuid)
  to service_role;
