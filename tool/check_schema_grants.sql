-- check_schema_grants.sql – Wer darf schreiben? Am laufenden Stack nachgesehen (#185).
--
-- Warum es diese Datei gibt: Zwei RLS-Zusicherungen kippten allein dadurch,
-- dass CI eine neuere Supabase-CLI zog (#185). Der Grund war nicht ein Loch,
-- sondern dass die Zusicherung auf einer Abwesenheit ruhte — auf `profiles`
-- stand kein einziger Grant, also entschied der Stack, was `authenticated`
-- darf. Seit 20260907120000 steht der Entzug im Schema; diese Prüfung hält
-- fest, dass er dort auch ankommt, egal welche CLI den Stack hochgezogen hat.
--
-- Aufruf (lokal wie in CI, nach `supabase start`):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f tool/check_schema_grants.sql
--
-- Ein Verstoß ist ein Fehler, kein Hinweis: Die Abfrage bricht ab.

\pset pager off

-- ── 1. Bestandsaufnahme: das, was #185 „How to settle it" sehen wollte ──────
-- Läuft auch bei Erfolg und landet im CI-Log. Wer beim nächsten CLI-Sprung
-- wissen will, was sich unter uns verschoben hat, liest hier nach, statt die
-- Release Notes zu deuten.

\echo ''
\echo '── Eigentuemer und RLS-Zustand der bewachten Tabellen ──'
select c.relname                as tabelle,
       c.relowner::regrole::text as eigentuemer,
       c.relrowsecurity          as rls_an,
       c.relforcerowsecurity     as rls_erzwungen
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('profiles', 'gesamtwehr_branding')
 order by c.relname;

\echo ''
\echo '── Rechte von anon/authenticated auf den bewachten Tabellen ──'
select table_name as tabelle, grantee as rolle, privilege_type as recht
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('profiles', 'gesamtwehr_branding')
   and grantee in ('anon', 'authenticated', 'PUBLIC')
 order by table_name, grantee, privilege_type;

\echo ''
\echo '── Policies auf den bewachten Tabellen ──'
select tablename as tabelle, policyname as policy, cmd as befehl, roles::text as rollen
  from pg_policies
 where schemaname = 'public'
   and tablename in ('profiles', 'gesamtwehr_branding')
 order by tablename, policyname;

-- Zur Kenntnis, nicht zur Prüfung: Dieselbe Abwesenheit tragen die
-- Snapshot-Tabellen, die ebenfalls nur über RPCs beschrieben werden. Solange
-- RLS dort keine Schreib-Policy hat, ist das kein Loch — aber es ist derselbe
-- ungeschriebene Verlass. Die Liste steht hier, damit die Entscheidung darüber
-- auf Zahlen fußt und nicht auf Erinnerung.
\echo ''
\echo '── Zur Kenntnis: weitere Tabellen mit Schreibrecht fuer anon/authenticated ──'
select table_name as tabelle, grantee as rolle,
       string_agg(privilege_type, ', ' order by privilege_type) as rechte
  from information_schema.role_table_grants
 where table_schema = 'public'
   and grantee in ('anon', 'authenticated')
   and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
   and table_name not in ('profiles', 'gesamtwehr_branding')
 group by table_name, grantee
 order by table_name, grantee;

-- ── 2. Die eigentliche Zusicherung ──────────────────────────────────────────

do $$
declare
  verstoss text;
begin
  select string_agg(format('%s: %s darf %s', table_name, grantee, privilege_type),
                    E'\n  ' order by table_name, grantee, privilege_type)
    into verstoss
    from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name in ('profiles', 'gesamtwehr_branding')
     and grantee in ('anon', 'authenticated', 'PUBLIC')
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
                            'REFERENCES', 'TRIGGER');

  if verstoss is not null then
    raise exception E'Schreibrecht auf einer RPC-only-Tabelle (#185):\n  %\n'
      'Geschrieben wird dort ausschliesslich ueber die geprueften Funktionen. '
      'Kommt ein Recht zurueck, hat der Stack Default-Privileges gesetzt — '
      'dann fehlt der Entzug in einer neuen Migration.', verstoss;
  end if;
end $$;

-- Der Entzug ersetzt RLS nicht, er ergaenzt sie. Faellt eines von beiden weg,
-- traegt das andere — aber nur, wenn beides da ist.
do $$
declare
  ohne_rls text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into ohne_rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname in ('profiles', 'gesamtwehr_branding')
     and not c.relrowsecurity;

  if ohne_rls is not null then
    raise exception 'Row Level Security ist aus auf: %', ohne_rls;
  end if;
end $$;

-- Lesen muss bleiben — ein Entzug, der die App blind macht, waere kein Fix.
do $$
declare
  fehlend text;
begin
  select string_agg(t.name, ', ' order by t.name)
    into fehlend
    from (values ('profiles'), ('gesamtwehr_branding')) as t(name)
   where not exists (
     select 1 from information_schema.role_table_grants g
      where g.table_schema = 'public'
        and g.table_name = t.name
        and g.grantee = 'authenticated'
        and g.privilege_type = 'SELECT');

  if fehlend is not null then
    raise exception 'Lese-Grant fuer authenticated fehlt auf: %', fehlend;
  end if;
end $$;

\echo ''
\echo '✅ Schreibrechte, RLS und Lese-Grants sind wie zugesichert.'
