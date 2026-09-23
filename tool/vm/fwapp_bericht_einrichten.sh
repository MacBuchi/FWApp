#!/usr/bin/env bash
### fwapp_bericht_einrichten.sh – Wochenbericht und neue Mail-Brücke auf
### UNSERE VM bringen. Läuft auf dem MAC, im Heimnetz oder per WireGuard.
###
###   tool/vm/fwapp_bericht_einrichten.sh <empfaenger@adresse> <öffentliche-domain>
###
### Was passiert:
###   1. fwapp_bericht.py samt fwapp_check.py/fwapp_install.py nach
###      ~/bin/fwapp-bericht/, Konfiguration nach ~/fwapp-bericht.conf
###      (nur beim ersten Mal — eine angepasste Datei bleibt stehen).
###   2. Die Mail-Brücke mit Anhängen (sonst käme der Bericht ohne Logs an)
###      und Neustart des Dienstes.
###   3. systemd-Timer fwapp-bericht (sonntags 5 Uhr) aktivieren.
###   4. Einen Bericht zur Ansicht erzeugen UND einen echten verschicken —
###      der erste Beweis, dass Weg und Anhang ankommen.
set -euo pipefail

AN=${1:?Empfänger fehlt}
DOMAIN=${2:?Domain fehlt}
VM=${VM:-fwapp@192.168.178.201}
KEY=${KEY:-$HOME/.ssh/fwapp_proxmox_ed25519}
REPO=$(cd "$(dirname "$0")/../.." && pwd)
SSH=(ssh -i "$KEY" -o ConnectTimeout=10 "$VM")
SCP=(scp -i "$KEY" -o ConnectTimeout=10)

"${SSH[@]}" 'mkdir -p ~/bin/fwapp-bericht'
"${SCP[@]}" "$REPO"/tool/installer/{fwapp_bericht.py,fwapp_check.py,fwapp_install.py} "$VM:bin/fwapp-bericht/"
"${SCP[@]}" "$REPO"/tool/vm/{fwapp-bericht.service,fwapp-bericht.timer,fwapp_mailbridge.py} "$VM:/tmp/"
sed -e "s|^BERICHT_AN=.*|BERICHT_AN=$AN|" -e "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" \
  "$REPO/tool/vm/fwapp-bericht.conf.example" | "${SSH[@]}" \
  'test -f ~/fwapp-bericht.conf && echo "Konfiguration bleibt wie sie ist" || { cat > ~/fwapp-bericht.conf; chmod 600 ~/fwapp-bericht.conf; }'

"${SSH[@]}" 'bash -s' <<'REMOTE'
set -euo pipefail
# Compose-Projekte der laufenden Container eintragen (nur beim Platzhalter).
projekte=$(sudo docker ps --format '{{.Label "com.docker.compose.project"}}' | grep . | sort -u | paste -sd, -)
sed -i "s|^BERICHT_PROJEKTE=<wird beim Einrichten ermittelt>|BERICHT_PROJEKTE=$projekte|" ~/fwapp-bericht.conf
grep '^BERICHT_PROJEKTE' ~/fwapp-bericht.conf
# Mail-Brücke: den Pfad nimmt der laufende Dienst selbst.
ziel=$(systemctl show -p ExecStart fwapp-mailbridge | grep -o '/[^ ;]*fwapp_mailbridge.py' | head -1)
cp "$ziel" "$ziel.vor-anhaengen"
cp /tmp/fwapp_mailbridge.py "$ziel"
sudo systemctl restart fwapp-mailbridge
sleep 2; systemctl is-active fwapp-mailbridge
sudo cp /tmp/fwapp-bericht.service /tmp/fwapp-bericht.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now fwapp-bericht.timer
systemctl list-timers fwapp-bericht.timer --no-pager | head -3
DOCKER="sudo docker" python3 ~/bin/fwapp-bericht/fwapp_bericht.py --conf ~/fwapp-bericht.conf --ansehen
sudo systemctl start fwapp-bericht.service
journalctl -u fwapp-bericht -n 3 --no-pager
REMOTE
