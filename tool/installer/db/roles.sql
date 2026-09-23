-- roles.sql – Passwörter der internen Rollen setzen (#241). Übernommen aus
-- Supabase self-hosted (docker/volumes/db/roles.sql, Apache-2.0). Läuft
-- einmal beim ersten Start der Datenbank.
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_functions_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
