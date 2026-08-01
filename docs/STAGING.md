# Staging: Testen, bevor es die Produktion trifft

> Antwort auf die Frage vom 2026-08-01: „Es wäre sinnvoll, wenn es einen
> Test-/Preview-Stack und einen Produktionsstack gibt — bekommen wir das im
> selbst gehosteten System hin?" Ja — mit drei Ebenen statt einer großen.
> Zum Vergleich: Die Supabase-Bezahlversion nennt das „Preview Branches";
> unser Gegenstück zur „direkten SQL-Push-Connection" der Gratisversion ist
> das `docker exec psql` auf der VM. Genau davor schieben wir die Proben.

Ergänzt [SERVER-SETUP.md](SERVER-SETUP.md) (Aufbau der Produktions-VM) und
[BETRIEB.md](BETRIEB.md) (Alltag).

---

## Die drei Ebenen im Überblick

| Ebene | Prüft | Wann | Aufwand |
|---|---|---|---|
| **1 · Lokaler CLI-Stack + CI** | Schema & Logik, App-gegen-Server (E2E) | automatisch bei jedem PR | läuft bereits |
| **2 · Probelauf-DB auf der VM** | die Migration gegen den **echten Datenbestand** von gestern Nacht | vor jedem Einspielen auf die Produktion | Minuten |
| **3 · Staging-VM aus dem vzdump** | die komplette Kette: Kong, GoTrue, PostgREST, Storage, App-Zugriff | vor großen Schnitten (Mandanten-Migration, Stack-Updates, .env-Umbauten) | ~30 min, VM nur bei Bedarf an |

Faustregel: **Ebene 2 ist Pflicht vor jedem `docker exec psql` auf die
Produktion.** Ebene 3 ist die Generalprobe, wenn mehr als reines SQL im
Spiel ist — sie validiert nebenbei jedes Mal, dass die vzdump-Backups
wirklich restorebar sind.

---

## Ebene 1 · Lokaler CLI-Stack + CI (vorhanden)

`supabase start` / `supabase db reset` spielt alle Migrationen aus
`supabase/migrations/` auf einen frischen lokalen Stack; die CI tut dasselbe
und lässt die E2E-Suite (`test/integration/sync_e2e_test.dart`) dagegen
laufen. Das ist unser Gegenstück zu den Preview-Branches: Jede
Schema-Änderung wird schon im PR gegen einen echten Supabase-Stack geprüft.

Dazu kommt seit 2026-08-01 der Workflow **Supabase Preview**
(`.github/workflows/supabase-preview.yml`): Bei jedem PR, der
`supabase/migrations/` anfasst, bootet er den Stack auf dem
Migrationsstand des **Basis-Branches**, zieht **nur die neuen** Migrationen
inkrementell darüber — exakt der Upgrade-Pfad, den später die Produktion
nimmt — und postet den Schema-Diff als PR-Kommentar. Außerdem erzwingt er
Migrations-Unveränderlichkeit: Wer eine bestehende Migrationsdatei ändert,
löscht oder umbenennt, bekommt einen roten Check (sie könnte in der
Produktion schon eingespielt sein).

Was diese Ebene *nicht* sieht: den echten Datenbestand (Backfills gegen
reale Daten!), die Produktions-`.env`, Kong-/nginx-/Tunnel-Konfiguration.

## Ebene 2 · Probelauf-DB auf der VM (`tool/migration_rehearsal.sh`)

Die nächtliche Sicherung (`~/bin/fwapp_backup.sh`, `pg_dump -Fc` nach
`~/backups/`) ist bereits die perfekte Datenquelle. Das Skript spielt den
neuesten Dump in eine **Wegwerf-Datenbank im laufenden Postgres-Container**,
zieht die Migrationen darüber und zeigt die Zeilenstände vorher/nachher —
Backfill-Fehler, Constraint-Verletzungen und Syntaxprobleme fallen hier auf,
nicht in der Produktion.

```bash
# Vom Mac aus: Skript + Migrationen auf die VM bringen und laufen lassen
scp tool/migration_rehearsal.sh supabase/migrations/2026*.sql fwapp@192.168.178.201:
ssh fwapp@192.168.178.201 bash migration_rehearsal.sh \
  20260731000000_minimum_supported_version.sql \
  20260801000000_abteilungen_mandanten.sql
```

Sicherheitseigenschaften: Probe-DB im selben Cluster (alle Rollen/Extensions
vorhanden), Wegwerf-Name mit Zeitstempel, `drop database … with (force)` im
`trap` — auch bei Abbruch bleibt nichts liegen. Die Produktions-DB
`postgres` wird nie berührt.

✅ **Auf der VM verifiziert (2026-08-01):** Erster Probelauf mit den zwei
Migrationen Gate + Abteilungen gegen den Nacht-Dump `fwapp_pg_*.dump` —
beide liefen sauber durch, Backfill im Zeilenstand bestätigt. Das
Dump-Namensmuster `*.dump` passt.

⚠️ **Vor der Probe frisch dumpen, nicht den neuesten nehmen:** Der neueste
Dump im Ordner kann von VOR der letzten Migration stammen (passiert am
2026-08-01: Rückfallpunkt-Dump vom Morgen, Gesamtwehr-Migration fand
`gesamtwehren` nicht). Ein frischer `pg_dump` ist zugleich Rückfallpunkt
und korrekte Probe-Basis.

**Seit Route A (#74) läuft Ebene 2 automatisch:** `tool/vm/fwapp_autodeploy.sh`
zieht vor jedem Einspielen einen frischen Dump und fährt die Generalprobe
selbst — das Skript hier bleibt für Hand-Proben einzelner Migrationen und
für die Staging-VM (Ebene 3).

## Ebene 3 · Staging-VM 105 aus dem vzdump

Der wöchentliche vzdump von VM 104 wird zu einer **byte-identischen
Staging-VM** restauriert. Dort laufen exakt die Befehle, die danach auf die
Produktion gehen — gleiche Docker-Images, gleiche `.env`, gleicher
Datenstand.

### Einrichtung (einmal pro Probe, auf dem Proxmox-Host)

```bash
# 1. Neuestes Backup finden
ls -t /mnt/pve/vm-backups/dump/vzdump-qemu-104-*.vma.zst | head -1

# 2. Als VM 105 restaurieren — --unique erzeugt eine NEUE MAC-Adresse
qmrestore <backup-datei> 105 --unique 1 --storage local-lvm

# 3. VOR dem ersten Start: Netz kappen und RAM begrenzen
#    (Host hat nur 15 GB — Staging bekommt 4 GB und läuft nur auf Zeit)
qm set 105 --name fwapp-staging --memory 4096 --balloon 2048
qm set 105 --net0 virtio,bridge=vmbr0,link_down=1
qm start 105
```

### In der VM entschärfen (per `qm terminal 105`, VOR dem Netz-Anschalten)

Reihenfolge ist Sicherheitsrelevant — erst entschärfen, dann Netz:

```bash
# 1. ⚠️ TUNNEL ZUERST: Der Klon trägt denselben Cloudflare-Token wie die
#    Produktion. Startet cloudflared, KAPERT STAGING DEN PROD-TRAFFIC.
docker rm -f fwapp-tunnel
docker update --restart=no fwapp-tunnel 2>/dev/null || true

# 2. Nächtliche Sicherung stilllegen (sonst schreibt Staging Backups)
crontab -l | grep -v fwapp_backup | crontab -

# 3. Eigene Identität: IP .202 statt .201, Hostname
sed -i 's/192.168.178.201/192.168.178.202/' /etc/network/interfaces \
  /etc/netplan/*.yaml 2>/dev/null || true
hostnamectl set-hostname fwapp-staging

# 4. .env: externe URLs auf die LAN-Adresse zurückdrehen
#    (API_EXTERNAL_URL/SITE_URL zeigen im Klon noch auf die öffentliche Domain)
cd ~/supabase && sed -i 's#https://fwapp[^ ]*#http://192.168.178.202:8000#g' .env
docker compose up -d
```

Dann auf dem Host `qm set 105 --net0 virtio,bridge=vmbr0` (Link an).

### Prüfen und benutzen

- API vom Mac: `curl http://192.168.178.202:8000/auth/v1/health`
- App dagegen testen: In den **Einstellungen → Cloud-Synchronisation** URL
  `http://192.168.178.202:8000` + Anon-Key eintragen (Debug-Build/Emulator) —
  genau dafür sind die Felder da.
- Migrationen proben: wie in Ebene 2, nur gegen die Staging-VM, diesmal
  **inklusive** `NOTIFY pgrst, 'reload schema'` und App-Test hinterher.

### Danach

```bash
qm stop 105            # Staging läuft nur auf Zeit (RAM ist knapp)
# Für die nächste Probe frisch restaurieren statt weiterbenutzen:
qm destroy 105 --purge # optional; frisch = validiert erneut das Backup
```

### Bekannte Eigenheiten

- **Fritz!Box-Neugeräte-Sperre:** Die neue MAC des Klons hat vermutlich wie
  die Produktions-MAC kein IPv4-Internet. Egal — Staging braucht nur LAN
  (Mac ↔ VM). Nicht als Fehler fehldeuten.
- **Kein `--unique` vergessen:** Ohne neue MAC stehen zwei Geräte mit
  derselben MAC im Netz — beide unerreichbar.
- Der Restore validiert das Backup gleich mit: Schlägt `qmrestore` fehl,
  ist das ein Backup-Problem, das man GENAU JETZT wissen will.

---

## Was bewusst nicht gebaut wird

- **Dauerhaft laufende Staging-VM** — der Host hat 15 GB RAM für alle
  Gäste; Staging auf Zeit reicht und validiert nebenbei die Backups.
- **Zweiter Supabase-Stack auf VM 104** — Speicherdruck auf derselben VM
  gefährdet genau die Produktion, die er schützen soll.
- **Automatischer Sync Produktion → Staging** — der vzdump *ist* der Sync.
