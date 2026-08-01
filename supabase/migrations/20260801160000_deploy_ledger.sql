-- deploy_ledger.sql – Buchführung für den Auto-Deploy (Issue #74, Route A).
--
-- Der Autodeploy auf der VM (tool/vm/fwapp_autodeploy.sh) muss wissen,
-- welche Migrationen die Produktions-DB schon gesehen hat. Diese Buchführung
-- gehört IN die Datenbank, nicht in eine Datei daneben: Wird ein Dump
-- zurückgespielt, rollt der Kontostand mit zurück und der nächste Lauf
-- spielt genau das nach, was wirklich fehlt.
--
-- Eigenes Schema statt public: public wird von PostgREST als API
-- ausgeliefert (die Oberfläche ist opt-out, siehe DocuHub datenhaltung.md) —
-- Betriebs-Buchführung hat dort nichts verloren. Das Schema `deploy` steht
-- nicht in der PostgREST-Schemaliste und ist damit von außen unsichtbar.
--
-- Das Skript legt Schema und Tabelle zur Not selbst an (Bootstrap auf
-- Bestandsservern); diese Migration hält Neuaufbauten (CI, Staging,
-- supabase db reset) deckungsgleich. Beide Wege sind absichtlich idempotent.

create schema if not exists deploy;

create table if not exists deploy.applied_migrations (
  name       text primary key,
  sha256     text not null,
  applied_at timestamptz not null default now(),
  -- 'seed' = beim Bootstrap als bereits-eingespielt übernommen,
  -- 'auto' = vom Autodeploy eingespielt, 'manual' = per Hand nachgetragen.
  source     text not null default 'auto'
    check (source in ('seed', 'auto', 'manual'))
);

comment on schema deploy is
  'Betriebs-Buchführung des Auto-Deploys (Issue #74) — bewusst ohne API-Zugriff.';
comment on table deploy.applied_migrations is
  'Welche Migration hat DIESE Datenbank gesehen? Quelle der Wahrheit für '
  'tool/vm/fwapp_autodeploy.sh; rollt bei einem Restore mit zurück.';

-- Kein Grant an anon/authenticated: nur supabase_admin (Eigentümer) und
-- service_role sollen hier lesen können.
grant usage on schema deploy to service_role;
grant select on deploy.applied_migrations to service_role;
