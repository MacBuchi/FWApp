-- schreibrechte_explizit_entziehen.sql – Die Zusicherung ins Schema holen (#185).
--
-- ── Was passiert ist ────────────────────────────────────────────────────────
-- Am 2026-08-26 erschien Supabase CLI 2.116.0; der nächste CI-Lauf zog sie und
-- zwei Integrationstests kippten auf unverändertem `main`:
--
--   * branding_e2e_test  „an der RPC vorbei geht nichts"
--   * profil_e2e_test    „ein fremdes Profil lässt sich auch nicht direkt
--                         beschreiben"
--
-- Beide erwarteten eine PostgrestException und bekamen keine. Daraus wurde
-- zunächst geschlossen, der Schreibzugriff sei durchgegangen.
--
-- ── Was tatsächlich passiert ist ────────────────────────────────────────────
-- Nachgestellt auf blankem Postgres 16 (drei Lagen, siehe #185): Hat
-- `authenticated` KEIN Schreibrecht, scheitert ein direktes UPDATE mit
-- 42501 `permission denied` — der Fehler, den die Tests erwarten. Bekommt die
-- Rolle das Recht, ändert sich das Ergebnis, aber nicht die Wirkung:
--
--   UPDATE auf fremde Zeile  → RLS filtert sie weg → `UPDATE 0`, KEIN Fehler
--   INSERT ohne INSERT-Policy → „new row violates row-level security policy"
--
-- Die Zeile blieb in jeder Lage unverändert. Es ging nichts durch; RLS hat
-- gehalten. Umgekippt ist nur, WORAN die Tests die Zusicherung erkannt haben —
-- sie prüften die Fehlermeldung fehlender Rechte statt die Unversehrtheit der
-- Daten. Der Unterschied zwischen „abgelehnt" und „erlaubt, aber null Zeilen"
-- ist für die Sicherheit keiner; für ein `expect(throwsA(...))` ist er alles.
--
-- ── Warum diese Migration trotzdem sein muss ────────────────────────────────
-- Weil die Zusicherung bis heute auf einer ABWESENHEIT ruhte: Auf `profiles`
-- steht in keiner Migration ein Grant, auf `gesamtwehr_branding` nur
-- `grant select`. Was `authenticated` darf, entschied damit allein, welche
-- Default-Privileges der Stack beim Anlegen der Tabelle gerade wirken ließ —
-- also eine Version der CLI, nicht unser Schema. Genau das ist die Frage aus
-- #185: Hängt die Garantie am Stack, öffnet ein Upgrade der VM 104 sie
-- irgendwann still.
--
-- Ab hier steht sie geschrieben. `revoke` ist unabhängig davon, was vorher
-- galt, und idempotent — die Migration darf auf jedem Stand laufen.
--
-- ── Grenzen, bewusst gezogen ────────────────────────────────────────────────
-- Nur die zwei Tabellen aus #185. Dieselbe Abwesenheit tragen auch die
-- Snapshot-Tabellen (vehicles, compartments, equipment_items, …), die
-- ebenfalls ausschließlich über `publish_snapshot` beschrieben werden — das
-- ist ein eigener Schnitt und gehört in ein eigenes Issue, nicht in einen
-- unbeaufsichtigten Rundumschlag über zwölf Tabellen.
--
-- NICHT entzogen wird `select`: Beide Tabellen werden von der App gelesen,
-- gefiltert durch ihre Lese-Policies. Und nichts wird `service_role`
-- entzogen — Autodeploy, Edge Functions und tool/setup_local_supabase.sh
-- schreiben darüber (Letzteres setzt die Rolle der Testnutzer per PATCH auf
-- profiles; ein Entzug für service_role legte die CI lahm).

-- `trigger` und `references` gehen mit, obwohl sie keine Zeile schreiben.
-- `trigger` besonders: Wer einen Trigger an `profiles` hängen darf, hängt ihn
-- an eine Tabelle, in die gleich darauf `mein_profil_setzen` schreibt — und
-- die Funktion ist SECURITY DEFINER. Der Trigger liefe dann in deren Kontext,
-- nicht im eigenen. Der Weg dorthin ist eng (DDL kommt über PostgREST nicht
-- herein), aber ein Recht, das niemand braucht, ist auch keines, das man
-- stehen lässt.
revoke insert, update, delete, truncate, references, trigger
  on public.profiles, public.gesamtwehr_branding
  from anon, authenticated;

-- Der Vollständigkeit halber dieselbe Linie für `public`: Ein Recht, das dort
-- hängt, erbt jede Rolle — auch die beiden oben, an denen wir es gerade
-- entzogen haben.
revoke insert, update, delete, truncate, references, trigger
  on public.profiles, public.gesamtwehr_branding
  from public;

-- ── Die Migration prüft ihre eigene Wirkung ────────────────────────────────
-- Ein `revoke` durch eine Rolle, die weder Eigentümerin noch Superuser ist,
-- ist kein Fehler: Postgres gibt eine WARNUNG aus und lässt das Recht stehen.
-- Auf der VM spielt der Autodeploy als `supabase_admin` ein — Superuser,
-- handelt also als Eigentümerin, und dann greift der Entzug. „Sollte passen"
-- ist bei einem Recht aber die falsche Genauigkeit. Bleibt hier etwas stehen,
-- schlägt die Migration fehl, und der Autodeploy hält an
-- (fwapp_autodeploy.sh setzt ~/autodeploy.blocked) — besser als eine
-- Zusicherung zu melden, die es nicht gibt.
do $$
declare
  rest text;
begin
  select string_agg(format('%s: %s darf %s', table_name, grantee, privilege_type),
                    E'\n  ' order by table_name, grantee, privilege_type)
    into rest
    from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name in ('profiles', 'gesamtwehr_branding')
     and grantee in ('anon', 'authenticated', 'PUBLIC')
     and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE',
                            'REFERENCES', 'TRIGGER');

  if rest is not null then
    raise exception E'Der Entzug ist wirkungslos geblieben (#185):\n  %\n'
      'Vermutlich ist die einspielende Rolle weder Eigentuemerin der Tabelle '
      'noch Superuser — dann ist REVOKE nur eine Warnung.', rest;
  end if;
end $$;

comment on table public.profiles is
  'Konto-Stammdaten. Lesen per RLS auf die eigene Zeile, Schreiben '
  'ausschliesslich ueber RPCs (mein_profil_setzen, Admin-Funktionen). '
  'Schreibrechte fuer anon/authenticated sind explizit entzogen (#185).';
