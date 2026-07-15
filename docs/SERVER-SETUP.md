# FWApp Sync-Server – Setup-Dokumentation

Stand: 2026-07-14. Beschreibt den selbst gehosteten Supabase-Sync-Server für die
FWApp auf dem heimischen Proxmox-Host, inklusive Betrieb, Backup und
Wiederherstellung.

---

## Überblick

Die FWApp nutzt ein **Single-Writer-Modell**: Nur Admins publizieren den
kompletten Datensatz (Fahrzeuge, Fächer, Geräte, Prüfungen) als Snapshot über
die RPC-Funktion `publish_snapshot()`; Mitglieder lesen den publizierten Stand.
Der Server ist **nur im LAN bzw. per WireGuard** erreichbar – es gibt bewusst
**keine Portfreigabe** ins Internet.

```text
MacBook (Admin)  ──┐
                   ├── LAN / WireGuard ──► VM 104 „fwapp-sync“ (192.168.178.201)
Handy (Member)   ──┘                        └── Docker: Supabase (Kong :8000)
                                                 ├── Auth (GoTrue)
                                                 ├── PostgREST
                                                 ├── PostgreSQL
                                                 └── Studio, Realtime, Storage …
```

---

## Infrastruktur

### Proxmox-Host

| Eigenschaft | Wert |
| --- | --- |
| Adresse | `root@192.168.178.26` |
| Version | Proxmox VE 9.1.1 |
| Hardware | 8 Kerne, 15 GB RAM (knapp – neue Gäste sparsam dimensionieren) |
| Storage | `local-lvm` (Thin-LVM, VM-Disks), `vm-backups` (vzdump) |
| Bestehende Gäste | VM 100 debian, 101 haos, 110 nextcloud, LXC 102 PiHole, 103 caddy |

### VM 104 „fwapp-sync“

| Eigenschaft | Wert |
| --- | --- |
| Basis | Debian 12 genericcloud (Cloud-Init), Image unter `/var/lib/vz/template/` |
| Ressourcen | 2 vCPU (host), 6 GB RAM mit Ballooning (min. 3 GB), 40 GB Disk (local-lvm) |
| Netzwerk | Statisch **192.168.178.201/24**, GW/DNS 192.168.178.1, Bridge `vmbr0` |
| | (IP liegt bewusst außerhalb des Fritzbox-DHCP-Pools .20–.200) |
| Benutzer | `fwapp` (sudo NOPASSWD), SSH-Key `~/.ssh/fwapp_proxmox_ed25519` |
| Extras | qemu-guest-agent, serielle Konsole (`qm terminal 104`), Docker + Compose |

Zugriff:

```bash
ssh -i ~/.ssh/fwapp_proxmox_ed25519 fwapp@192.168.178.201   # VM
ssh -i ~/.ssh/fwapp_proxmox_ed25519 root@192.168.178.26     # Proxmox-Host
```

> **Eigenheit:** Die VM erreicht `github.com` nicht (Port 443 blockiert, übriges
> Internet funktioniert). Downloads von GitHub daher auf dem Mac ziehen und per
> `scp` in die VM kopieren.

---

## Supabase (self-hosted)

Installiert nach dem offiziellen Docker-Setup (`supabase/supabase` → Ordner
`docker/`, Stand master Juli 2026) unter **`/home/fwapp/supabase`** in der VM.

| Eigenschaft | Wert |
| --- | --- |
| API-URL (Kong) | `http://192.168.178.201:8000` |
| Studio/Dashboard | gleiche URL, Login `fwadmin` (Passwort siehe Secrets) |
| Container | 11 Stück (db, kong, auth, rest, realtime, storage, imgproxy, meta, studio, pooler, edge-functions) |
| Konfiguration | `~/supabase/.env` (chmod 600) |

### Secrets

Alle Zugangsdaten wurden bei der Installation **frisch generiert** (offizielle
Skripte `utils/generate-keys.sh` und `utils/add-new-auth-keys.sh`) und stehen
**nicht** im Repo. Ablage:

- In der VM: `/home/fwapp/fwapp-secrets.txt` (chmod 600) und `~/supabase/.env`
- Kopie: `~/Desktop/fwapp-secrets.txt` auf dem MacBook (besser: in den
  Passwortmanager übernehmen)

Enthalten: `ANON_KEY` (öffentlicher Client-Key für die App), `SERVICE_ROLE_KEY`,
`JWT_SECRET`, Postgres-Passwort, Dashboard-Login sowie die App-Konten.

### Datenbank-Schema & Konten

- Migration [supabase/migrations/20260713000000_init_sync_schema.sql](../supabase/migrations/20260713000000_init_sync_schema.sql)
  ist eingespielt (Tabellen, RLS „authenticated read“, `publish_snapshot()`-RPC,
  Profil-Trigger). Einspielen erfolgt per `docker exec psql` als `supabase_admin`
  – **nicht** mit `supabase db push`.
- Migration [supabase/migrations/20260715000000_equipment_images_storage.sql](../supabase/migrations/20260715000000_equipment_images_storage.sql)
  (M2): Storage-Bucket `equipment-images` für zentrale Gerätefotos — privat,
  authenticated read, Upload/Ersetzen/Löschen nur Admin, max. 1 MB,
  JPEG/PNG/WebP. Die App speichert Marker `supabase://equipment-images/<datei>`
  in `imagePath` und löst sie zur Laufzeit gegen
  `/storage/v1/object/authenticated/...` auf (Header `apikey` + `Bearer`).

  Eingespielt und verifiziert am 2026-07-15: Admin-Upload 200, Member-Upload
  400 (Policy greift), Member-Lesen über `/object/authenticated/` 200,
  anonymer Zugriff 400.

- Konten (Passwörter siehe Secrets-Datei):
  - `admin@fw.local` – Rolle `admin` (darf publizieren)
  - `member@fw.local` – Rolle `member` (liest)

### Verifiziert (Abnahmetests vom 2026-07-14)

- Passwort-Login über GoTrue und RLS-Lesezugriff auf `dataset_meta` (Version 0)
- Erreichbarkeit vom MacBook: `/auth/v1/health` → 200, REST mit
  `apikey` + `Authorization: Bearer` → 200
- Restore-Probe des Backups (siehe unten) erfolgreich

---

## App-Anbindung

URL und `ANON_KEY` des eigenen Servers werden **zur Build-Zeit** vorbelegt
(seit das Repo öffentlich ist, stehen instanzspezifische Werte nicht mehr im
Code): `config/fwapp.local.json.example` nach `config/fwapp.local.json`
kopieren (gitignored), Werte eintragen und bauen mit

```bash
flutter build apk --dart-define-from-file=config/fwapp.local.json   # bzw. run/build macos …
```

Nach einer Neuinstallation eines solchen Builds muss nur noch Sync aktiviert
und eingeloggt werden. Ohne Build-Flags (z. B. CI-Builds) bleiben die Felder
leer und werden unter **Settings → Sync** von Hand eingetragen.
Von unterwegs muss auf dem Gerät die WireGuard-Verbindung ins Heimnetz aktiv sein.

Hinweis: REST-Aufrufe ohne `Authorization`-Header beantwortet Kong mit 403 –
das ist normal, der Supabase-Client sendet den Header immer mit.

**Gerätefotos (M2):** Fotografiert der Admin ein Gerät, skaliert die App das
Bild auf ≤ 1024 px / ≤ 300 KB JPEG und lädt es in den Bucket
`equipment-images`; nach jedem Pull lädt die App alle zentralen Fotos in den
lokalen Offline-Cache (Fortschritt unter Einstellungen → „Gerätefotos
offline“).

**Achtung Gastnetz:** Aus dem Fritzbox-Gast-WLAN (Subnetz `192.168.179.x`)
ist das Heimnetz per Design isoliert — Server dann nicht erreichbar, obwohl
man „zu Hause“ ist. Fürs Publizieren/Synchronisieren ins normale WLAN wechseln.

---

## Backup & Wiederherstellung

### Automatisch (in der VM)

Cronjob des Users `fwapp`, täglich **03:15 Uhr** (`crontab -l`):

- Skript `~/bin/fwapp_backup.sh`:
  `pg_dump -Fc` der Datenbank + `pg_dumpall --globals-only` (Rollen)
- Ablage `~/backups/`, Rotation nach **14 Tagen**, Log `~/backups/backup.log`

### Zusätzlich empfohlen: vzdump auf dem Host

Der nächtliche vzdump-Job (02:30, Storage `vm-backups`) sichert bisher nur die
älteren Gäste. VM 104 aufnehmen mit:

```bash
pvesh set /cluster/backup/backup-eae87c36-99cc --vmid 101,102,103,104,110
```

### Restore (geprobt am 2026-07-14)

```bash
# In der VM; DUMP = gewünschte Datei aus ~/backups/
docker exec supabase-db psql -U supabase_admin -d postgres -c "create database restore_test"
docker exec supabase-db psql -U supabase_admin -d restore_test -c \
  'create schema if not exists auth; create schema if not exists extensions;
   create extension if not exists "uuid-ossp" schema extensions;
   create extension if not exists pgcrypto schema extensions;'
docker exec -i supabase-db pg_restore -U supabase_admin -d restore_test \
  --no-owner --no-acl --schema=public --schema=auth --no-comments < "$DUMP"
```

Die Schemata `auth`/`extensions` müssen vor dem `pg_restore` existieren, da der
Schema-Filter sie nicht selbst anlegt. Für ein echtes Desaster-Recovery:
Stack stoppen, Volume `~/supabase/volumes/db/data` leeren, Stack starten
(frische DB), Migration einspielen, dann Restore in `postgres` statt
`restore_test` – oder einfacher: die ganze VM aus dem vzdump zurückholen.

---

## Betrieb

```bash
# Status / Logs (in der VM, Verzeichnis ~/supabase)
docker compose ps
docker compose logs -f auth        # bzw. rest, db, kong …

# Stack neu starten / stoppen
docker compose restart
docker compose down && docker compose up -d

# Updates (Images aktualisieren)
docker compose pull && docker compose up -d

# Schema-Änderungen: neue Migration per psql einspielen, danach
docker exec supabase-db psql -U supabase_admin -d postgres -c "NOTIFY pgrst, 'reload schema';"
```

Die VM startet automatisch mit dem Host nicht – falls gewünscht, auf dem Host
`qm set 104 --onboot 1` setzen. Docker-Container haben Restart-Policys aus dem
offiziellen Compose-File und kommen nach einem VM-Reboot selbst hoch.

---

## Neuaufbau von Grund auf (Kurzfassung)

1. VM aus Debian-12-genericcloud-Image anlegen (`qm create` + `import-from`,
   Cloud-Init: SSH-Key, statische IP, 2 vCPU / 6 GB / 40 GB).
2. In der VM: qemu-guest-agent, Docker (get.docker.com), User in `docker`-Gruppe.
3. `supabase/docker` (auf dem Mac laden, GitHub-Sperre!) nach `~/supabase`,
   `cp .env.example .env`, `sh utils/generate-keys.sh --update-env`,
   `sh utils/add-new-auth-keys.sh --update-env`, URLs/`DASHBOARD_USERNAME`/
   `POOLER_TENANT_ID` in `.env` anpassen.
4. `docker compose up -d`, Migration einspielen, Konten über die
   Auth-Admin-API anlegen (analog [tool/setup_local_supabase.sh](../tool/setup_local_supabase.sh)),
   `profiles.role` des Admins auf `admin` setzen.
5. Backup-Cron einrichten, Restore proben, App-Settings aktualisieren.
