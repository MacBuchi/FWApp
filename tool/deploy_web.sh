#!/usr/bin/env bash
# deploy_web.sh – Baut den Flutter-Web-Build (mit Server-Vorbelegung aus
# config/fwapp.local.json) und synct ihn auf den Webserver der eigenen
# Instanz (nginx-Container, siehe docs/SERVER-SETUP.md → "Web-App").
#
# Aufruf:
#   bash tool/deploy_web.sh "<user>@<server-ip>"
# Optional eigener SSH-Key/Optionen:
#   FWAPP_WEB_SSH_OPTS="-i ~/.ssh/<key>" bash tool/deploy_web.sh "<user>@<server-ip>"
#
# Zielpfad auf dem Server: ~/fwapp-web/html/ (vom nginx-Container gemountet).
# Instanz-konkreter Aufruf: siehe docs/private/SETUP-PRIVAT.md (untracked).
set -euo pipefail
cd "$(dirname "$0")/.."

SSH_TARGET="${FWAPP_WEB_SSH:-${1:-}}"
SSH_OPTS="${FWAPP_WEB_SSH_OPTS:-}"
if [ -z "$SSH_TARGET" ]; then
  echo "Fehler: Ziel fehlt. Als Argument übergeben (oder FWAPP_WEB_SSH setzen)," >&2
  echo "z. B.: bash tool/deploy_web.sh 'fwapp@<server-ip>'" >&2
  exit 1
fi

if [ ! -f config/fwapp.local.json ]; then
  echo "Fehler: config/fwapp.local.json fehlt (Vorlage: config/fwapp.local.json.example)." >&2
  exit 1
fi

echo "» Baue Web-Release …"
flutter build web --release --dart-define-from-file=config/fwapp.local.json

echo "» Sync nach $SSH_TARGET:fwapp-web/html/ …"
rsync -az --delete -e "ssh $SSH_OPTS" build/web/ "$SSH_TARGET:fwapp-web/html/"

echo "» Fertig. Test: http://<server-ip>:8080 im Browser öffnen."
