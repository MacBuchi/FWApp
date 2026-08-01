#!/usr/bin/env bash
### migration_rehearsal.sh – Generalprobe von SQL-Migrationen gegen den
### letzten nächtlichen Dump, in einer Wegwerf-Datenbank IM LAUFENDEN
### Postgres-Container der Sync-VM (Issue #57-Anmerkung: Test- vor
### Produktionslauf, siehe docs/STAGING.md, Ebene 2).
###
### Läuft AUF DER VM (als fwapp), nicht auf dem Mac:
###   scp tool/migration_rehearsal.sh supabase/migrations/2026*.sql fwapp@192.168.178.201:
###   ssh fwapp@192.168.178.201 bash migration_rehearsal.sh \
###     20260731000000_minimum_supported_version.sql \
###     20260801000000_abteilungen_mandanten.sql
###
### Warum das sicher ist: Die Probe-DB liegt im selben Cluster (alle
### Supabase-Rollen und -Extensions existieren dort bereits), hat aber einen
### Wegwerf-Namen und wird am Ende — auch im Fehlerfall — gelöscht. Die
### Produktions-DB `postgres` wird zu keinem Zeitpunkt berührt, ein
### NOTIFY pgrst ist nicht nötig (keine API auf der Probe-DB).
###
### Grenzen: prüft NUR die SQL-Ebene (Syntax, Backfill, Constraints gegen
### echte Daten). Kong/GoTrue/PostgREST-Verhalten prüft erst die
### Staging-VM (docs/STAGING.md, Ebene 3).
set -euo pipefail

DB_CONTAINER=${DB_CONTAINER:-supabase-db}
BACKUP_DIR=${BACKUP_DIR:-$HOME/backups}
REHEARSAL_DB="rehearsal_$(date +%Y%m%d_%H%M%S)"

if [ $# -lt 1 ]; then
  echo "Aufruf: $0 <migration1.sql> [migration2.sql ...]   (Reihenfolge = Einspiel-Reihenfolge)" >&2
  exit 2
fi
for f in "$@"; do
  [ -r "$f" ] || { echo "FEHLER: Migration nicht lesbar: $f" >&2; exit 2; }
done

# Neuester Dump aus der nächtlichen Sicherung (fwapp_backup.sh, pg_dump -Fc).
DUMP=${DUMP:-$(ls -t "$BACKUP_DIR"/*.dump 2>/dev/null | head -1)}
if [ -z "${DUMP:-}" ] || [ ! -r "$DUMP" ]; then
  echo "FEHLER: Kein Dump unter $BACKUP_DIR/*.dump gefunden." >&2
  echo "        Anderes Muster? Mit DUMP=/pfad/zur/datei überschreiben." >&2
  exit 2
fi

echo "Dump:     $DUMP ($(date -r "$DUMP" '+%Y-%m-%d %H:%M'))"
echo "Probe-DB: $REHEARSAL_DB"
echo

psql_db() { # psql_db <datenbank>  — liest SQL von stdin, bricht bei Fehler ab
  sudo docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d "$1" \
    -v ON_ERROR_STOP=1 --quiet
}

echo "== 1/5 Wegwerf-DB anlegen"
echo "create database $REHEARSAL_DB;" | psql_db postgres

cleanup() {
  echo "== 5/5 Aufräumen: drop database $REHEARSAL_DB"
  echo "drop database if exists $REHEARSAL_DB with (force);" \
    | psql_db postgres || true
}
trap cleanup EXIT

echo "== 2/5 Restore des Dumps"
# Erkenntnis der Restore-Probe vom 2026-07-16: auth/extensions vorher anlegen.
printf 'create schema if not exists auth;\ncreate schema if not exists extensions;\ncreate schema if not exists storage;\n' \
  | psql_db "$REHEARSAL_DB"
# Einzelne Meldungen zu Ownership/Event-Triggern sind beim Restore in eine
# Nicht-Standard-DB normal — deshalb kein ON_ERROR_STOP, dafür Fehlerzähler.
restore_log=$(mktemp)
if ! sudo docker exec -i "$DB_CONTAINER" pg_restore -U supabase_admin \
    -d "$REHEARSAL_DB" --no-owner < "$DUMP" 2> "$restore_log"; then
  echo "   (pg_restore meldete $(grep -c '^pg_restore' "$restore_log" || true) Einträge — bei Ownership/Triggern normal, Log: $restore_log)"
fi

echo "== 3/5 Zeilenstand VOR den Migrationen"
tables_sql="select relname, n_live_tup from pg_stat_user_tables
            where schemaname='public' order by relname;"
echo "$tables_sql" | psql_db "$REHEARSAL_DB"

echo "== 4/5 Migrationen einspielen (bricht beim ersten Fehler ab)"
for f in "$@"; do
  echo "   -> $f"
  psql_db "$REHEARSAL_DB" < "$f"
done

echo
echo "== Zeilenstand NACH den Migrationen"
echo "$tables_sql" | psql_db "$REHEARSAL_DB"

echo
echo "ERGEBNIS: Alle Migrationen liefen gegen den echten Datenbestand durch."
echo "Zeilenstände oben gegenprüfen (Backfill!), dann dieselben Dateien in"
echo "derselben Reihenfolge auf 'postgres' einspielen + NOTIFY pgrst, 'reload schema'."
