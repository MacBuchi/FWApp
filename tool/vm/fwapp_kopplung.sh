#!/usr/bin/env bash
### fwapp_kopplung.sh – Die Beschreibung dieser Installation für die App
### schreiben: ~/fwapp-web/kopplung/fwapp.json (Issue #238).
###
### nginx liefert sie unter https://<domain>/.well-known/fwapp.json aus
### (tool/vm/fwapp-web-nginx.conf). Damit findet die Web-App ihren Server
### von selbst, und in der Android-App reicht es, die Domain einzutippen
### oder den Einrichtungs-QR zu scannen.
###
### Aufruf (auf der VM):
###   fwapp_kopplung.sh <öffentliche API-Adresse> ["<Name der Installation>"]
###   z. B. fwapp_kopplung.sh https://app.example.org "Feuerwehr Musterstadt"
###
### Der Anon-Key kommt aus ~/supabase/.env (ANON_KEY) — er ist öffentlich,
### steckt ohnehin in jeder App, und wer ihn hier abtippt, vertippt sich.
### Der Service-Role-Key wird NIE gelesen.
###
### Einmalig nötig: das Verzeichnis im Web-Container einhängen,
###   volumes: - ./kopplung:/etc/fwapp:ro
### in ~/fwapp-web/docker-compose.yml, danach `docker compose up -d`.
set -euo pipefail

ENV_DATEI=${ENV_DATEI:-$HOME/supabase/.env}
ZIEL=${ZIEL:-$HOME/fwapp-web/kopplung/fwapp.json}

if [ $# -lt 1 ]; then
  sed -n 's/^### \{0,1\}//p' "$0" | sed -n '/^Aufruf/,/^$/p'
  exit 2
fi
URL=$1
NAME=${2:-}

ANON=$(grep -E '^ANON_KEY=' "$ENV_DATEI" | head -1 | cut -d= -f2- | tr -d '"'"'")
if [ -z "$ANON" ]; then
  echo "Kein ANON_KEY in $ENV_DATEI gefunden." >&2
  exit 1
fi

mkdir -p "$(dirname "$ZIEL")"
# JSON über python3 statt von Hand zusammengeklebt: Ein Anführungszeichen im
# Namen machte die Datei sonst still ungültig, und die App fände den Server
# nicht, ohne dass hier etwas scheitert.
URL="$URL" NAME="$NAME" ANON="$ANON" python3 - "$ZIEL" <<'PY'
import json, os, sys
url = os.environ["URL"].strip().rstrip("/")
if not url.startswith(("https://", "http://")):
    sys.exit("Die Adresse muss mit https:// (oder im LAN http://) beginnen.")
daten = {"fwapp": 1, "url": url, "anon_key": os.environ["ANON"]}
if os.environ["NAME"].strip():
    daten["name"] = os.environ["NAME"].strip()
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(daten, f, ensure_ascii=False)
    f.write("\n")
print(f"Geschrieben: {sys.argv[1]} ({url})")
PY
