-- check_schema_grants.sql – Wer darf was? Am laufenden Stack nachgesehen.
--
-- Warum es diese Datei gibt: Zwei RLS-Zusicherungen kippten allein dadurch,
-- dass CI eine neuere Supabase-CLI zog (#185). Der Grund war nicht ein Loch,
-- sondern dass die Zusicherung auf einer Abwesenheit ruhte — stand auf einer
-- Tabelle kein Grant, entschied der Stack, was `authenticated` darf. Wie weit
-- die Stacks auseinanderliegen, zeigt derselbe Bericht auf zwei Versionen:
-- CLI 2.116.0 gibt jeder Tabelle `DELETE, INSERT, TRUNCATE, UPDATE` für
-- BEIDE Rollen, CLI 2.109.1 nur `TRUNCATE`. Seit 20260907120000 (#185) und
-- 20260910120000 (#198) steht der Entzug im Schema; hier wird festgehalten,
-- dass er dort auch ankommt, egal welche CLI den Stack hochgezogen hat.
--
-- Geprüft wird das GANZE `public`-Schema, nicht eine Liste bewachter
-- Tabellen. Eine neue Tabelle fällt damit automatisch unter die Regel, statt
-- eine stille Ausnahme zu werden — wer eine echte Ausnahme braucht, trägt sie
-- unten namentlich ein und begründet sie dort.
--
-- Aufruf (lokal wie in CI, nach `supabase start`):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f tool/check_schema_grants.sql
--
-- Ein Verstoß ist ein Fehler, kein Hinweis: Die Abfrage bricht ab.

\pset pager off

-- ── Die Ausnahmeliste ───────────────────────────────────────────────────────
-- Drei Tabellen beschreibt der Client direkt, an keiner RPC vorbei. Sie stehen
-- hier mit ihren erlaubten Befehlen NAMENTLICH, und sie werden in BEIDE
-- Richtungen geprüft: Ein überzähliges Recht ist ein Fehler, ein fehlendes
-- erlaubtes ebenso.
--
-- Die zweite Richtung ist hier die wichtigere. Kein Integrationstest deckt
-- diese drei Schreibpfade ab (#198, Punkt 5) — ein zu weit gefasster `revoke`
-- fiele also nicht in CI auf, sondern erst auf der VM: Der Gerätewart könnte
-- kein Fahrzeugfoto mehr anhängen, keine Frage mehr einreichen, und das
-- App-Feedback käme nicht mehr an. Diese Liste ist der Rückfallschutz an
-- Stelle der fehlenden Tests.
--
-- `anon` steht bewusst in keiner Zeile: Keine der Policies dieses Schemas
-- nennt die Rolle, sie braucht weder Schreib- noch Leserecht.
create temporary table erlaubte_schreibrechte (
  tabelle text not null,
  rolle   text not null,
  recht   text not null,
  grund   text not null
);

insert into erlaubte_schreibrechte values
  ('feedback',            'authenticated', 'INSERT',
   'feedback_repository.dart – die App legt Feedback an; ausgewertet und '
   'geloescht wird ueber service_role (tool/feedback_bot.py)'),
  ('quiz_questions',      'authenticated', 'INSERT',
   'wissen_sync.dart – eine Frage einreichen (#174)'),
  ('quiz_questions',      'authenticated', 'UPDATE',
   'wissen_sync.dart – eine Frage pflegen und freigeben (#174)'),
  ('quiz_questions',      'authenticated', 'DELETE',
   'wissen_sync.dart – Soft-Delete einer Frage (#174)'),
  ('vehicle_attachments', 'authenticated', 'INSERT',
   'anhang_speicher.dart – einen Anhang anlegen'),
  ('vehicle_attachments', 'authenticated', 'UPDATE',
   'anhang_speicher.dart – einen Anhang ersetzen'),
  ('vehicle_attachments', 'authenticated', 'DELETE',
   'anhang_speicher.dart – einen Anhang entfernen');

-- ── 1. Bestandsaufnahme ─────────────────────────────────────────────────────
-- Läuft auch bei Erfolg und landet im CI-Log. Wer beim nächsten CLI-Sprung
-- wissen will, was sich unter uns verschoben hat, liest hier nach, statt die
-- Release Notes zu deuten.

\echo ''
\echo '── Schreibrechte von anon/authenticated/PUBLIC im Schema public ──'
select g.table_name as tabelle, g.grantee as rolle,
       string_agg(g.privilege_type, ', ' order by g.privilege_type) as rechte
  from information_schema.role_table_grants g
 where g.table_schema = 'public'
   and g.grantee in ('anon', 'authenticated', 'PUBLIC')
   and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
                            'REFERENCES', 'TRIGGER')
 group by g.table_name, g.grantee
 order by g.table_name, g.grantee;
\echo '(Erwartet: genau die sieben Zeilen der Ausnahmeliste, als drei Gruppen.)'

\echo ''
\echo '── Eigentuemer und RLS-Zustand aller Tabellen ──'
select c.relname                 as tabelle,
       c.relowner::regrole::text as eigentuemer,
       c.relrowsecurity          as rls_an,
       c.relforcerowsecurity     as rls_erzwungen,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = c.relname) as policies
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r'
 order by c.relname;

-- Berichten statt prüfen: In `storage` hängen die Policies unter Supabase'
-- eigenem Rechteregime, und der Storage-Dienst verbindet sich mit eigener
-- Rolle. Ein Entzug dort riskiert Ausfälle, die kein Test hier abdeckt
-- (#198, Punkt 4). Sichtbar soll die Verschiebung trotzdem sein.
\echo ''
\echo '── Zur Kenntnis, nicht geprueft: storage.objects ──'
select g.grantee as rolle,
       string_agg(g.privilege_type, ', ' order by g.privilege_type) as rechte
  from information_schema.role_table_grants g
 where g.table_schema = 'storage' and g.table_name = 'objects'
   and g.grantee in ('anon', 'authenticated', 'PUBLIC')
 group by g.grantee
 order by g.grantee;

-- ── 2. Zusicherung: kein Schreibrecht ausserhalb der Ausnahmeliste ──────────

do $$
declare
  verstoss text;
begin
  select string_agg(format('%s: %s darf %s', g.table_name, g.grantee, g.privilege_type),
                    E'\n  ' order by g.table_name, g.grantee, g.privilege_type)
    into verstoss
    from information_schema.role_table_grants g
   where g.table_schema = 'public'
     and g.grantee in ('anon', 'authenticated', 'PUBLIC')
     and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
                              'REFERENCES', 'TRIGGER')
     and not exists (
       select 1 from erlaubte_schreibrechte e
        where e.tabelle = g.table_name
          and e.rolle   = g.grantee
          and e.recht   = g.privilege_type);

  if verstoss is not null then
    raise exception E'Schreibrecht ausserhalb der Ausnahmeliste (#198):\n  %\n'
      'Geschrieben wird im Schema public ueber gepruefte Funktionen; die drei '
      'Ausnahmen stehen in tool/check_schema_grants.sql namentlich. Kommt ein '
      'Recht zurueck, hat der Stack Default-Privileges gesetzt — dann fehlt '
      'der Entzug in einer neuen Migration. Ist das Recht gewollt, gehoert es '
      'mit Begruendung in die Ausnahmeliste.', verstoss;
  end if;
end $$;

-- ── 3. Die Gegenrichtung: die Ausnahmen muessen ihr Recht auch HABEN ────────
-- Ohne diese Prüfung wäre ein zu weit geratener Entzug eine stille Änderung,
-- die kein Test bemerkt und die erst auf der VM auffällt.

do $$
declare
  fehlend text;
begin
  select string_agg(format('%s: %s braucht %s (%s)', e.tabelle, e.rolle, e.recht, e.grund),
                    E'\n  ' order by e.tabelle, e.recht)
    into fehlend
    from erlaubte_schreibrechte e
   where not exists (
     select 1 from information_schema.role_table_grants g
      where g.table_schema = 'public'
        and g.table_name = e.tabelle
        and g.grantee    = e.rolle
        and g.privilege_type = e.recht);

  if fehlend is not null then
    raise exception E'Ein Schreibpfad hat sein Recht verloren (#198):\n  %\n'
      'Diese drei Pfade deckt kein Integrationstest ab — faellt das Recht weg, '
      'merkt es zuerst der Geraetewart.', fehlend;
  end if;
end $$;

-- ── 4. Lesen: authenticated ueberall, anon nirgends ─────────────────────────
-- Der Entzug ersetzt RLS nicht, er ergaenzt sie. Ein Entzug, der die App
-- blind macht, waere aber kein Fix.

do $$
declare
  blind text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into blind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and not exists (
       select 1 from information_schema.role_table_grants g
        where g.table_schema = 'public'
          and g.table_name = c.relname
          and g.grantee = 'authenticated'
          and g.privilege_type = 'SELECT');

  if blind is not null then
    raise exception 'Lese-Grant fuer authenticated fehlt auf: %', blind;
  end if;
end $$;

do $$
declare
  sichtbar text;
begin
  select string_agg(format('%s: %s', g.table_name, g.grantee),
                    E'\n  ' order by g.table_name, g.grantee)
    into sichtbar
    from information_schema.role_table_grants g
   where g.table_schema = 'public'
     and g.grantee in ('anon', 'PUBLIC')
     and g.privilege_type = 'SELECT';

  if sichtbar is not null then
    raise exception E'Leserecht fuer anon/PUBLIC im Schema public (#198):\n  %\n'
      'Keine Policy dieses Schemas nennt anon — die Rolle liest nichts. Ein '
      'Grant ohne begleitende Policy ist entweder ueberfluessig oder ein Loch.',
      sichtbar;
  end if;
end $$;

-- ── 5. RLS muss ueberall an sein ────────────────────────────────────────────
-- Faellt eines von beiden weg, traegt das andere — aber nur, wenn beides da
-- ist. Eine Tabelle ohne RLS und ohne Grant ist heute dicht und morgen offen,
-- sobald ein Stack Default-Privileges verteilt.

do $$
declare
  ohne_rls text;
  ohne_policy text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into ohne_rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

  if ohne_rls is not null then
    raise exception 'Row Level Security ist aus auf: %', ohne_rls;
  end if;

  select string_agg(c.relname, ', ' order by c.relname)
    into ohne_policy
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and not exists (select 1 from pg_policies p
                      where p.schemaname = 'public' and p.tablename = c.relname);

  if ohne_policy is not null then
    raise exception E'RLS ist an, aber ohne jede Policy auf: %\n'
      'Das ist dicht bis zur Blindheit — authenticated sieht dort keine Zeile. '
      'Gewollt ist das fast nie; gemeint war vermutlich eine Lese-Policy.',
      ohne_policy;
  end if;
end $$;

\echo ''
\echo '✅ Schreibrechte, Lese-Grants, RLS und Policies sind wie zugesichert.'
