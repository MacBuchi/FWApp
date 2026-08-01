#!/usr/bin/env bash
### fwapp_autodeploy.sh – Route A aus Issue #74: Die VM holt sich Migrationen
### und Edge Functions nach einem Merge auf main selbst — mit automatischer
### Generalprobe VOR jedem Einspielen und frischem Dump als Rückfallpunkt.
###
### Läuft AUF DER VM als fwapp, alle 10 Minuten per systemd-Timer
### (fwapp-autodeploy.timer). Installation: siehe docs/SERVER-SETUP.md.
###
### Ablauf eines Laufs:
###   1. deploy/manifest.json von raw.githubusercontent.com holen (IPv6 —
###      der einzige GitHub-Weg, den diese VM hat; raw liefert nur einzelne
###      Dateien, deshalb existiert das Manifest überhaupt).
###   2. Migrationen: Manifest gegen deploy.applied_migrations in der DB
###      vergleichen. Neue Dateien laden, SHA-256 prüfen, Generalprobe gegen
###      einen FRISCHEN Dump in einer Wegwerf-DB (Lehre vom 2026-08-01: der
###      neueste Dump im Ordner kann Vor-Migrations-Stand sein), erst dann
###      auf postgres einspielen + NOTIFY pgrst + Ledger fortschreiben.
###   3. Functions: SHA-256 der Manifest-Dateien gegen die ausgerollten
###      vergleichen; bei Abweichung sichern, ersetzen, Container neu starten.
###
### Fehlerverhalten: Beim ersten Fehler entsteht ~/autodeploy.blocked mit
### Begründung; weitere Läufe tun NICHTS mehr, bis jemand die Datei löscht.
### Lieber stehenbleiben als dieselbe kaputte Migration alle 10 Minuten
### gegen die Produktion werfen. Der Freigabe-Moment bleibt der Merge durch
### einen Menschen — dieses Skript führt nur aus, was main sagt.
###
### Die Buchführung liegt IN der Datenbank (Schema deploy): Wird ein Dump
### zurückgespielt, rollt sie mit zurück, und der nächste Lauf spielt genau
### das nach, was der wiederhergestellten DB fehlt.
set -euo pipefail

RAW=${RAW:-https://raw.githubusercontent.com/MacBuchi/FWApp/main}
DB_CONTAINER=${DB_CONTAINER:-supabase-db}
BACKUP_DIR=${BACKUP_DIR:-$HOME/backups}
FUNCTIONS_DIR=${FUNCTIONS_DIR:-$HOME/supabase/volumes/functions}
COMPOSE_DIR=${COMPOSE_DIR:-$HOME/supabase}
BLOCKED=$HOME/autodeploy.blocked
LOCK=$HOME/autodeploy.lock
LOG=$HOME/autodeploy.log
DRY_RUN=${DRY_RUN:-0}

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }

blockiere() {
  printf '%s\n%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" > "$BLOCKED"
  log "BLOCKIERT: $*"
  log "Weiter geht es erst nach Klärung: rm $BLOCKED"
  exit 1
}

# ── Vorbedingungen ─────────────────────────────────────────────────────────
if [ -f "$BLOCKED" ]; then
  # Bewusst leise (Exit 0): Der Timer soll nicht als "failed" rot werden,
  # der Block selbst steht schon im Log und in der Datei.
  echo "autodeploy.blocked existiert — Lauf übersprungen." >&2
  exit 0
fi
exec 9> "$LOCK"
flock -n 9 || { echo "Anderer Lauf aktiv — übersprungen." >&2; exit 0; }

psql_db() { # psql_db <datenbank> — SQL von stdin, bricht bei Fehler ab
  sudo docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d "$1" \
    -v ON_ERROR_STOP=1 --quiet
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ── 1) Manifest holen ─────────────────────────────────────────────────────
if ! curl -fsS --max-time 30 "$RAW/deploy/manifest.json" -o "$WORK/manifest.json"; then
  # Netzfehler blockieren nicht — der nächste Lauf versucht es wieder.
  log "Manifest nicht erreichbar (Netz?) — nächster Lauf versucht es erneut."
  exit 0
fi
python3 - "$WORK/manifest.json" <<'PY' > "$WORK/migrations.txt" || blockiere "Manifest unlesbar"
import json, sys
m = json.load(open(sys.argv[1]))
for e in m["migrations"]:
    print(f'{e["name"]} {e["sha256"]}')
PY
python3 - "$WORK/manifest.json" <<'PY' > "$WORK/functions.txt" || blockiere "Manifest unlesbar (functions)"
import json, sys
m = json.load(open(sys.argv[1]))
for pfad, h in m["functions"].items():
    print(f'{pfad} {h}')
PY

# ── 2) Ledger sicherstellen und Bestand lesen ─────────────────────────────
# Bootstrap auf einem Bestandsserver: existiert das Ledger noch nicht,
# werden ALLE Manifest-Migrationen als bereits eingespielt übernommen —
# dieser Server läuft ja nachweislich auf dem Stand von main. Ab dann
# zählt nur noch das Ledger.
psql_db postgres <<'SQL'
create schema if not exists deploy;
create table if not exists deploy.applied_migrations (
  name       text primary key,
  sha256     text not null,
  applied_at timestamptz not null default now(),
  source     text not null default 'auto'
    check (source in ('seed', 'auto', 'manual'))
);
SQL

anzahl=$(echo "select count(*) from deploy.applied_migrations;" \
  | sudo docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -Atq)
if [ "$anzahl" = "0" ]; then
  log "Bootstrap: Ledger leer — übernehme $(wc -l < "$WORK/migrations.txt" | tr -d ' ') Manifest-Migrationen als 'seed'."
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN: Seeding übersprungen."
  else
    while read -r name hash; do
      printf "insert into deploy.applied_migrations (name, sha256, source) values ('%s', '%s', 'seed') on conflict do nothing;\n" "$name" "$hash"
    done < "$WORK/migrations.txt" | psql_db postgres
  fi
fi

echo "select name from deploy.applied_migrations;" \
  | sudo docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -Atq \
  | sort > "$WORK/applied.txt"

# ── 3) Ausstehende Migrationen bestimmen ──────────────────────────────────
: > "$WORK/pending.txt"
while read -r name hash; do
  grep -qxF "$name" "$WORK/applied.txt" || echo "$name $hash" >> "$WORK/pending.txt"
done < "$WORK/migrations.txt"

if [ -s "$WORK/pending.txt" ]; then
  log "Ausstehend: $(cut -d' ' -f1 "$WORK/pending.txt" | tr '\n' ' ')"

  # Laden + Hash prüfen (raw cached ein paar Minuten; wer zu früh kommt,
  # bekommt evtl. noch den alten Stand — dann passt der Hash nicht und wir
  # warten einfach auf den nächsten Lauf statt zu blockieren).
  mkdir "$WORK/mig"
  while read -r name hash; do
    if ! curl -fsS --max-time 30 "$RAW/supabase/migrations/$name" -o "$WORK/mig/$name"; then
      log "Migration $name noch nicht abrufbar (Cache?) — nächster Lauf."
      exit 0
    fi
    ist=$(sha256sum "$WORK/mig/$name" | cut -d' ' -f1)
    if [ "$ist" != "$hash" ]; then
      log "Hash-Abweichung bei $name (Cache hinkt?) — nächster Lauf."
      exit 0
    fi
  done < "$WORK/pending.txt"

  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN: würde Generalprobe + Einspielen fahren, tue nichts."
  else
    # Frischer Dump: Rückfallpunkt UND Basis der Generalprobe in einem.
    DUMP="$BACKUP_DIR/pre_autodeploy_$(date +%Y%m%d_%H%M%S).dump"
    sudo docker exec "$DB_CONTAINER" pg_dump -U supabase_admin -d postgres -Fc > "$DUMP" \
      || blockiere "pg_dump fehlgeschlagen"
    log "Rückfallpunkt: $DUMP"

    # Generalprobe in einer Wegwerf-DB im selben Cluster (Rollen und
    # Extensions existieren dort schon) — Produktions-DB bleibt unberührt.
    PROBE="autodeploy_probe_$(date +%s)"
    echo "create database $PROBE;" | psql_db postgres || blockiere "Probe-DB nicht anlegbar"
    probe_weg() { echo "drop database if exists $PROBE with (force);" | psql_db postgres || true; }

    printf 'create schema if not exists auth;\ncreate schema if not exists extensions;\ncreate schema if not exists storage;\n' | psql_db "$PROBE"
    if ! sudo docker exec -i "$DB_CONTAINER" pg_restore -U supabase_admin \
        -d "$PROBE" --no-owner < "$DUMP" 2> "$WORK/restore.log"; then
      # Ownership-/Event-Trigger-Meldungen sind beim Restore in eine
      # Nicht-Standard-DB normal (siehe migration_rehearsal.sh).
      log "pg_restore meldete Einträge (bei Ownership/Triggern normal)."
    fi
    while read -r name hash; do
      if ! psql_db "$PROBE" < "$WORK/mig/$name"; then
        probe_weg
        blockiere "Generalprobe von $name fehlgeschlagen — NICHT eingespielt. Log: $LOG"
      fi
      log "Generalprobe ok: $name"
    done < "$WORK/pending.txt"
    probe_weg

    # Ernstfall: exakt dieselben Dateien in derselben Reihenfolge.
    while read -r name hash; do
      if ! psql_db postgres < "$WORK/mig/$name"; then
        blockiere "$name scheiterte auf postgres NACH bestandener Probe — Rückfallpunkt: $DUMP"
      fi
      printf "insert into deploy.applied_migrations (name, sha256, source) values ('%s', '%s', 'auto');\n" "$name" "$hash" | psql_db postgres
      log "Eingespielt: $name"
    done < "$WORK/pending.txt"
    echo "notify pgrst, 'reload schema';" | psql_db postgres
    log "NOTIFY pgrst — Schema-Cache aktualisiert."
  fi
else
  log "Migrationen: nichts ausstehend."
fi

# ── 4) Edge Functions abgleichen ──────────────────────────────────────────
geaendert=0
while read -r pfad hash; do
  ziel="$FUNCTIONS_DIR/$pfad"
  ist=""
  [ -f "$ziel" ] && ist=$(sha256sum "$ziel" | cut -d' ' -f1)
  [ "$ist" = "$hash" ] && continue

  if ! curl -fsS --max-time 30 "$RAW/supabase/functions/$pfad" -o "$WORK/fn"; then
    log "Function $pfad noch nicht abrufbar — nächster Lauf."
    exit 0
  fi
  neu=$(sha256sum "$WORK/fn" | cut -d' ' -f1)
  if [ "$neu" != "$hash" ]; then
    log "Hash-Abweichung bei Function $pfad (Cache hinkt?) — nächster Lauf."
    exit 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN: würde Function $pfad aktualisieren."
  else
    mkdir -p "$(dirname "$ziel")"
    [ -f "$ziel" ] && cp "$ziel" "$ziel.bak-autodeploy"
    cp "$WORK/fn" "$ziel"
    log "Function aktualisiert: $pfad"
  fi
  geaendert=1
done < "$WORK/functions.txt"

if [ "$geaendert" = "1" ] && [ "$DRY_RUN" != "1" ]; then
  (cd "$COMPOSE_DIR" && sudo docker compose restart functions >> "$LOG" 2>&1) \
    || blockiere "functions-Container-Neustart fehlgeschlagen"
  log "functions-Container neu gestartet."
elif [ "$geaendert" = "0" ]; then
  log "Functions: nichts zu tun."
fi

log "Lauf beendet."
