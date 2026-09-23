-- roles.sql – Passwörter der internen Rollen setzen (#241). Übernommen aus
-- Supabase self-hosted (docker/volumes/db/roles.sql, Apache-2.0). Läuft
-- einmal beim ersten Start der Datenbank.
--
-- ⚠️ Ohne supabase_functions_admin: Die Rolle legt erst webhooks.sql an,
-- und die App nutzt keine Datenbank-Webhooks. Ein Fehler hier bricht die
-- Einrichtung des Images ab, BEVOR dessen eigene Migrationen laufen — dann
-- gehört auth.uid() noch postgres, und GoTrue startet nie („must be owner
-- of function uid").
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
