-- schreibrechte_alle_tabellen.sql – Der Entzug für den Rest des Schemas (#198).
--
-- ── Was gemessen wurde ──────────────────────────────────────────────────────
-- 20260907120000 hat den Entzug für `profiles` und `gesamtwehr_branding` ins
-- Schema geholt (#185); für die übrigen zwanzig Tabellen stand er aus. Der
-- Bericht aus tool/check_schema_grants.sql zeigt am CI-Stack (Supabase CLI
-- 2.116.0, Lauf 34089559951) für JEDE dieser Tabellen dieselbe Zeile:
--
--   <tabelle> | anon          | DELETE, INSERT, TRUNCATE, UPDATE
--   <tabelle> | authenticated | DELETE, INSERT, TRUNCATE, UPDATE
--
-- Am 2026-09-10 lokal auf CLI 2.109.1 nachgemessen steht dort nur `TRUNCATE`
-- (plus `REFERENCES`/`TRIGGER`), und INSERT/UPDATE/DELETE nur da, wo eine
-- Migration sie ausdrücklich vergeben hat. Zwei Stacks, dasselbe Schema,
-- verschiedene Rechte — genau die Abhängigkeit, die #185 aufgedeckt hat.
-- Solange der Rechtestand vom Stack kommt und nicht aus einer Migration, ist
-- er keine Zusicherung, sondern eine Beobachtung.
--
-- ── Kein Loch, trotzdem ein Entzug ──────────────────────────────────────────
-- Durchgegangen ist nichts: Alle 29 Policies dieses Schemas lauten
-- `to authenticated`, keine einzige nennt `anon` oder `public`, und alle 22
-- Tabellen haben RLS an. Ohne Schreib-Policy lehnt RLS jeden direkten
-- Schreibversuch ab. Der Entzug ersetzt RLS also nicht, er ergänzt sie —
-- fällt eines von beiden weg, trägt das andere.
--
-- ── Bewusst NICHT angefasst ─────────────────────────────────────────────────
-- * `service_role`: Autodeploy, Edge Functions und tool/setup_local_supabase.sh
--   schreiben darüber (Letzteres setzt die Rolle der Testnutzer per PATCH auf
--   `profiles`); ein Entzug legte die CI lahm.
-- * `storage.objects`: Dort hängen Policies unter Supabase' eigenem
--   Rechteregime, und der Storage-Dienst verbindet sich mit eigener Rolle. Der
--   Guard berichtet den Stand, prüft ihn aber nicht (#198, Punkt 4).
-- * `alter default privileges`: wirkt nur auf neu angelegte Objekte und hängt
--   an der anlegenden Rolle. Der Guard deckt denselben Fall ab und schlägt
--   LAUT fehl, statt still zu wirken oder still nicht zu wirken (#198, Punkt 3).

-- ── 1. Der Entzug, über das ganze Schema ────────────────────────────────────
-- `on all tables in schema public` trifft genau die 22 Basistabellen — im
-- Schema liegen keine Views, keine Fremdtabellen, keine partitionierten
-- Tabellen (nachgesehen am 2026-09-10). Auch die drei Ausnahmen unten sind
-- hier eingeschlossen; sie bekommen in Schritt 2 zurück, was sie brauchen,
-- und nichts darüber hinaus. Der Weg über Entzug-dann-Vergabe ist der
-- Punkt: Danach steht der Rechtestand vollständig in dieser Datei, statt
-- teils hier und teils in den Default-Privileges des Stacks.
revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public
  from anon, authenticated, public;

-- `anon` liest nirgends: Keine der 29 Policies nennt die Rolle, die App
-- spricht vor dem Login keine Tabelle an. Ein Leserecht, das keine Policy
-- begleitet, ist damit so überflüssig wie die Schreibrechte darüber.
--
-- `public` geht mit, weil jede Rolle davon erbt — auch `anon` und
-- `authenticated`, denen wir es gerade entzogen haben. Für `authenticated`
-- ist das gefahrlos: Alle 22 Tabellen tragen einen eigenen `grant select on
-- … to authenticated` aus ihrer jeweiligen Migration, geerbt wird dort
-- nichts.
revoke select on all tables in schema public from anon, public;

-- ── 2. Die drei Ausnahmen, namentlich ───────────────────────────────────────
-- Diese drei Tabellen beschreibt der Client wirklich direkt, an keiner RPC
-- vorbei. Was sie zurückbekommen, ist auf den tatsächlichen Schreibpfad
-- zugeschnitten: kein `truncate`, kein `references`, kein `trigger`, und für
-- `feedback` auch kein `update`/`delete` — die App legt dort nur an.
--
-- ⚠️ Kein Test deckt diese drei Pfade ab (#198, Punkt 5). Ein zu weit
-- gefasster Entzug fiele deshalb nicht in CI auf, sondern erst auf der VM:
-- kein Fahrzeugfoto mehr anhängbar, keine Frage mehr einreichbar, kein
-- Feedback mehr zustellbar. Diesen Rückfallschutz leistet stattdessen
-- tool/check_schema_grants.sql, das die drei Zeilen hier in BEIDE Richtungen
-- prüft: ein überzähliges Recht ist ein Fehler, ein fehlendes erlaubtes auch.

-- lib/features/feedback/data/feedback_repository.dart – nur anlegen.
grant insert on public.feedback to authenticated;

-- lib/features/knowledge/data/wissen_sync.dart – einreichen, pflegen,
-- Soft-Delete (#174).
grant insert, update, delete on public.quiz_questions to authenticated;

-- lib/features/vehicle/data/anhang_speicher.dart – Anhang anlegen,
-- ersetzen, entfernen.
grant insert, update, delete on public.vehicle_attachments to authenticated;

-- ── 3. Die Migration prüft ihre eigene Wirkung ──────────────────────────────
-- Ein `revoke` durch eine Rolle, die weder Eigentümerin noch Superuser ist,
-- ist kein Fehler: Postgres gibt eine WARNUNG aus und lässt das Recht stehen.
-- Bleibt hier etwas stehen, schlägt die Migration fehl und der Autodeploy
-- hält an (fwapp_autodeploy.sh setzt ~/autodeploy.blocked) — besser als eine
-- Zusicherung zu melden, die es nicht gibt.
do $$
declare
  rest text;
begin
  select string_agg(format('%s: %s darf %s', g.table_name, g.grantee, g.privilege_type),
                    E'\n  ' order by g.table_name, g.grantee, g.privilege_type)
    into rest
    from information_schema.role_table_grants g
   where g.table_schema = 'public'
     and g.grantee in ('anon', 'authenticated', 'PUBLIC')
     and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
                              'REFERENCES', 'TRIGGER')
     and not exists (
       select 1
         from (values ('feedback', 'INSERT'),
                      ('quiz_questions', 'INSERT'),
                      ('quiz_questions', 'UPDATE'),
                      ('quiz_questions', 'DELETE'),
                      ('vehicle_attachments', 'INSERT'),
                      ('vehicle_attachments', 'UPDATE'),
                      ('vehicle_attachments', 'DELETE')) as e(tabelle, recht)
        where e.tabelle = g.table_name
          and e.recht = g.privilege_type
          and g.grantee = 'authenticated');

  if rest is not null then
    raise exception E'Der Entzug ist wirkungslos geblieben (#198):\n  %\n'
      'Vermutlich ist die einspielende Rolle weder Eigentuemerin der Tabellen '
      'noch Superuser — dann ist REVOKE nur eine Warnung.', rest;
  end if;
end $$;

-- Und die Gegenrichtung: Was die drei Ausnahmen brauchen, muss auch da sein.
-- Ohne diese Prüfung wäre ein zu weit geratener Entzug oben eine stille
-- Änderung, die erst dem Gerätewart auffällt.
do $$
declare
  fehlend text;
begin
  select string_agg(format('%s: authenticated braucht %s', e.tabelle, e.recht),
                    E'\n  ' order by e.tabelle, e.recht)
    into fehlend
    from (values ('feedback', 'INSERT'),
                 ('quiz_questions', 'INSERT'),
                 ('quiz_questions', 'UPDATE'),
                 ('quiz_questions', 'DELETE'),
                 ('vehicle_attachments', 'INSERT'),
                 ('vehicle_attachments', 'UPDATE'),
                 ('vehicle_attachments', 'DELETE')) as e(tabelle, recht)
   where not exists (
     select 1 from information_schema.role_table_grants g
      where g.table_schema = 'public'
        and g.table_name = e.tabelle
        and g.grantee = 'authenticated'
        and g.privilege_type = e.recht);

  if fehlend is not null then
    raise exception E'Ein Schreibpfad hat sein Recht verloren (#198):\n  %', fehlend;
  end if;
end $$;

-- Lesen muss bleiben — ein Entzug, der die App blind macht, wäre kein Fix.
do $$
declare
  blind text;
begin
  select string_agg(c.relname, ', ' order by c.relname)
    into blind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relkind = 'r'
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

comment on table public.quiz_questions is
  'Wissensfragen. Direkt beschreibbar durch authenticated (Einreichen, '
  'Pflegen, Soft-Delete), gefiltert durch die Policies; alle uebrigen '
  'Schreibrechte sind entzogen (#198).';

comment on table public.vehicle_attachments is
  'Fahrzeug-Anhaenge. Direkt beschreibbar durch authenticated, gefiltert '
  'durch die Policies; alle uebrigen Schreibrechte sind entzogen (#198).';

comment on table public.feedback is
  'App-Feedback. authenticated darf ausschliesslich anlegen; Auswertung und '
  'Loeschen laufen ueber service_role (tool/feedback_bot.py) (#198).';
