# FWApp Sync-Server – Setup-Dokumentation

Stand: 2026-07-18. Beschreibt den selbst gehosteten Supabase-Sync-Server für die
FWApp auf dem heimischen Proxmox-Host, inklusive öffentlicher Erreichbarkeit
(Cloudflare Tunnel), Betrieb, Backup und Wiederherstellung.

> Platzhalter wie `<server-ip>`, `<proxmox-ip>`, `<vm-id>` oder
> `<backup-job-id>` stehen für instanzspezifische Werte. Unsere konkreten
> Werte liegen **nicht im Repo**, sondern lokal in `docs/private/`
> (gitignored, Datei `SETUP-PRIVAT.md`).

---

## Überblick

Die FWApp nutzt ein **Single-Writer-Modell**: Nur Editoren (Admin/Gerätewart)
publizieren den kompletten Datensatz (Fahrzeuge, Fächer, Geräte, Prüfungen) als
Snapshot über die RPC-Funktion `publish_snapshot()`; Mitglieder lesen den
publizierten Stand. Seit M7 Etappe 1 (2026-07-18) ist der Server **öffentlich
per HTTPS über einen Cloudflare Tunnel** erreichbar — weiterhin **ohne
Portfreigabe** (der Tunnel baut nur ausgehende Verbindungen auf, die Heim-IP
bleibt verborgen). LAN-Zugriff funktioniert parallel weiter.

```text
Handy/Web (überall) ── HTTPS ──► Cloudflare Edge
                                   │ (Tunnel, nur ausgehend)
                                   ▼
LAN/WireGuard ─────────────► VM „fwapp-sync“ (<server-ip>)
                               ├── cloudflared (Host-Netz)
                               ├── nginx „fwapp-web“ :8080
                               │     ├── /            → Web-App (Flutter)
                               │     └── /auth|/rest|/storage → Kong :8000
                               └── Docker: Supabase (Kong :8000)
                                    ├── Auth (GoTrue)   ├── PostgREST
                                    ├── PostgreSQL      └── Studio (nur intern!)
```

---

## Infrastruktur

### Proxmox-Host

| Eigenschaft | Wert |
| --- | --- |
| Adresse | `root@<proxmox-ip>` |
| Version | Proxmox VE 9.1.1 |
| Hardware | 8 Kerne, 15 GB RAM (knapp – neue Gäste sparsam dimensionieren) |
| Storage | `local-lvm` (Thin-LVM, VM-Disks), `vm-backups` (vzdump) |
| Bestehende Gäste | mehrere VMs/LXCs (Liste: private Notizen) — werden NICHT angefasst |

### VM „fwapp-sync“ (VM-ID: siehe private Notizen)

| Eigenschaft | Wert |
| --- | --- |
| Basis | Debian 12 genericcloud (Cloud-Init), Image unter `/var/lib/vz/template/` |
| Ressourcen | 2 vCPU (host), 6 GB RAM mit Ballooning (min. 3 GB), 40 GB Disk (local-lvm) |
| Netzwerk | Statisch **`<server-ip>/24`**, GW/DNS = Router, Bridge `vmbr0` |
| | (IP liegt bewusst außerhalb des DHCP-Pools des Routers) |
| Benutzer | `fwapp` (sudo NOPASSWD), SSH-Key `~/.ssh/fwapp_proxmox_ed25519` |
| Extras | qemu-guest-agent, serielle Konsole (`qm terminal <vm-id>`), Docker + Compose |

Zugriff:

```bash
ssh -i ~/.ssh/fwapp_proxmox_ed25519 fwapp@<server-ip>   # VM
ssh -i ~/.ssh/fwapp_proxmox_ed25519 root@<proxmox-ip>     # Proxmox-Host
```

> **Eigenheit (Ursache 2026-07-18 gefunden):** Die VM hat **kein
> funktionierendes IPv4-Internet** — die Fritz!Box beantwortet ARP-Anfragen
> der VM-MAC nicht (Geräte-/Neugeräte-Sperre in der Box; andere VMs desselben
> Hosts bekommen Antworten). **IPv6 funktioniert**, daher gehen Dienste mit
> IPv6 (Cloudflare, Debian-Mirror, Docker Hub) — rein IPv4-basierte Ziele wie
> `github.com` oder `smtp-relay.brevo.com` (SMTP) scheitern. Fix: Gerät
> (`<server-ip>` / VM-MAC) in der Fritz!Box-Oberfläche freigeben. Bis dahin:
> GitHub-Downloads auf dem Mac ziehen und per `scp` in die VM kopieren.

---

## Supabase (self-hosted)

Installiert nach dem offiziellen Docker-Setup (`supabase/supabase` → Ordner
`docker/`, Stand master Juli 2026) unter **`/home/fwapp/supabase`** in der VM.

| Eigenschaft | Wert |
| --- | --- |
| API-URL (Kong) | `http://<server-ip>:8000` |
| Studio/Dashboard | gleiche URL, Login: siehe Secrets |
| Container | 11 Stück (db, kong, auth, rest, realtime, storage, imgproxy, meta, studio, pooler, edge-functions) |
| Konfiguration | `~/supabase/.env` (chmod 600) |

### Secrets

Alle Zugangsdaten wurden bei der Installation **frisch generiert** (offizielle
Skripte `utils/generate-keys.sh` und `utils/add-new-auth-keys.sh`) und stehen
**nicht** im Repo. Ablage:

- In der VM: `/home/fwapp/fwapp-secrets.txt` (chmod 600) und `~/supabase/.env`
- Lokale Kopie: `docs/private/fwapp-secrets.txt` (gitignored; besser
  zusätzlich in den Passwortmanager übernehmen)

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

- Migration [supabase/migrations/20260717000000_role_geraetewart.sql](../supabase/migrations/20260717000000_role_geraetewart.sql)
  (M7 Etappe 2, eingespielt + verifiziert 2026-07-17): Rollenmodell
  `admin | geraetewart | member` — `is_editor()` erlaubt Admin UND Gerätewart
  das Veröffentlichen und die Foto-Verwaltung; `is_admin()` bleibt für
  Admin-only-Funktionen (Nutzerverwaltung, Etappe 3) bestehen.

- Migration [supabase/migrations/20260718000000_username_login_admin.sql](../supabase/migrations/20260718000000_username_login_admin.sql)
  (M7 Etappe 3, eingespielt + E2E-verifiziert 2026-07-18):
  `profiles.must_change_password` + RPC `clear_must_change_password()` —
  Grundlage für Initialpasswörter mit Pflichtwechsel beim ersten Login.

- Konten (seit M7 Etappe 3 **individuell**, Konvention `<nutzername>@fw.local`):
  - `admin@fw.local` – Rolle `admin` (verwaltet, publiziert, Nutzerverwaltung)
  - Alle weiteren Konten legt der Admin in der App an
    (**Mehr → Nutzerverwaltung**): Nutzername + Rolle + Initialpasswort,
    das beim ersten Login zwingend geändert wird.
  - Das frühere Sammelkonto `member@fw.local` ist seit 2026-07-18 **gesperrt**
    (Entscheidung: individuelle Konten statt geteiltem Login).

### Edge Function `admin-users` (M7 Etappe 3)

Die Nutzerverwaltung der App läuft über die Edge Function
[supabase/functions/admin-users/index.ts](../supabase/functions/admin-users/index.ts)
(`POST /functions/v1/admin-users`, Aktionen `list/create/reset/set_role/`
`disable/enable/delete`). Sie prüft das mitgeschickte Nutzer-JWT gegen
PostgREST (nur `role = 'admin'` darf) und nutzt für die eigentlichen
Operationen den `SUPABASE_SERVICE_ROLE_KEY` aus der Container-Umgebung —
der mächtige Key verlässt den Server nie.

Deploy in der VM (edge-functions-Container läuft im Standard-Stack mit):

```bash
# Function-Ordner in den Stack kopieren, dann Runtime neu starten
cp -r supabase/functions/admin-users ~/supabase/volumes/functions/
cd ~/supabase && docker compose restart functions
```

**Eigenheit dieses Servers:** Der mitgelieferte `main`-Router des Stacks
importiert `jsr:@panva/jose` — ohne IPv4-Internet scheitert der
Modul-Download beim Kaltstart (502 für alle Functions). Er ist deshalb durch
den abhängigkeitsfreien Dispatcher
[supabase/functions/main/index.ts](../supabase/functions/main/index.ts)
ersetzt (Original als `main/index.ts.orig` gesichert); JWT-/Rollenprüfung
machen die Functions selbst.

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
und eingeloggt werden. Ohne Build-Flags (z. B. CI-PR-Builds) bleiben die Felder
leer und werden unter **Settings → Sync** von Hand eingetragen.
Über die öffentliche HTTPS-Adresse funktioniert der Sync von überall;
WireGuard ist nur noch für SSH/Verwaltung nötig.

**Release-APKs von GitHub** (seit 2026-07-16): Die Release-Pipeline
(`.github/workflows/release.yml`) baut bei jedem Version-Bump in
`pubspec.yaml` ein **signiertes** APK (fester Release-Keystore, Updates ohne
Deinstallation) und bekommt URL + `ANON_KEY` über Actions-Secrets
(`FWAPP_SUPABASE_URL`, `FWAPP_SUPABASE_ANON_KEY`) bereits eingebacken —
Mitglieder laden das APK vom GitHub-Release und müssen nur noch einloggen.
Seit M7 Etappe 1 zeigt `FWAPP_SUPABASE_URL` auf die öffentliche
HTTPS-API-Adresse (`https://api.<domain>`) — die App synct damit von überall,
ohne WireGuard. Der Anon-Key ist clientseitig-öffentlich (RLS schützt);
eine Selbst-Registrierung ist serverseitig deaktiviert (`DISABLE_SIGNUP`).

Hinweis: REST-Aufrufe ohne `Authorization`-Header beantwortet Kong mit 403 –
das ist normal, der Supabase-Client sendet den Header immer mit.

**Gerätefotos (M2):** Fotografiert der Admin ein Gerät, skaliert die App das
Bild auf ≤ 1024 px / ≤ 300 KB JPEG und lädt es in den Bucket
`equipment-images`; nach jedem Pull lädt die App alle zentralen Fotos in den
lokalen Offline-Cache (Fortschritt unter Einstellungen → „Gerätefotos
offline“).

**Hinweis Gastnetz:** Die alte Falle „Gast-WLAN (`192.168.179.x`) ist vom
Heimnetz isoliert“ betrifft seit der öffentlichen HTTPS-Adresse nur noch den
direkten LAN-Zugriff (`http://<server-ip>:8000/8080`) — über die
`https://…`-Adressen funktioniert die App auch im Gastnetz.

---

## Öffentliche Erreichbarkeit: Cloudflare Tunnel (M7 Etappe 1, seit 2026-07-18)

Zwei öffentliche Hostnames (DNS als CNAME auf `<tunnel-id>.cfargotunnel.com`,
angelegt über Cloudflare Zero Trust → Networks → Tunnels → „Published
application“; konkrete Namen siehe private Notizen):

| Hostname | Ziel im Tunnel | Zweck |
| --- | --- | --- |
| `https://app.<domain>` | `http://localhost:8080` (nginx) | Web-App (volle PWA) |
| `https://api.<domain>` | `http://localhost:8080` (nginx) | Supabase-API für App-Sync |

Beide zeigen auf **nginx**, der als kleines Gateway arbeitet: `/auth/`,
`/rest/`, `/storage/` und `/functions/` werden an Kong
(`supabase-kong:8000`) durchgereicht, alles andere liefert die Web-App aus. Dadurch sind **nur die App-Pfade**
öffentlich — Studio/Dashboard und alle übrigen Kong-Routen bleiben intern.
TLS terminiert an der Cloudflare-Edge; der Tunnel selbst baut ausschließlich
ausgehende Verbindungen auf (keine Portfreigabe, Heim-IP unsichtbar).

Bausteine in der VM:

- Container `fwapp-tunnel` (`cloudflare/cloudflared`, `--network host`,
  Restart-Policy `unless-stopped`), gestartet mit dem Tunnel-Token aus dem
  Cloudflare-Dashboard.
- `~/fwapp-web/nginx.conf`: zusätzlicher `location`-Block
  `^/(auth|rest|storage)/` mit `proxy_pass http://supabase-kong:8000`,
  `client_max_body_size 25m` (Foto-Uploads).
- `~/fwapp-web/docker-compose.yml`: Container hängt zusätzlich im externen
  Netz `supabase_default`, damit er `supabase-kong` per Namen erreicht.
- `~/supabase/.env`: `API_EXTERNAL_URL=https://api.<domain>`,
  `SITE_URL=https://app.<domain>`, `ADDITIONAL_REDIRECT_URLS`,
  **`DISABLE_SIGNUP=true`** (Konten entstehen nur über die Admin-API) sowie
  Brevo-SMTP (`SMTP_HOST=smtp-relay.brevo.com`, Port 587, Login/Key siehe
  private Notizen). Danach `docker compose up -d`.

Verifiziert am 2026-07-18 (öffentlich, durch den Tunnel): `/auth/v1/health`
200, REST mit apikey 200, Storage antwortet, `/auth/v1/signup` →
`signup_disabled`, Web-App liefert `version.json`.

> **Offen: E-Mail-Versand.** Ausgehendes SMTP scheitert derzeit an der
> IPv4-Sperre der VM in der Fritz!Box (siehe „Eigenheit“ oben — Brevo hat
> kein IPv6). Nach Freigabe des Geräts in der Fritz!Box den Testversand
> wiederholen; die GoTrue-Konfiguration ist bereits vollständig.

---

## Web-App (seit 2026-07-17, öffentlich seit 2026-07-18)

Ohne Apple-Developer-Account läuft die App auf iPhones als **Web-App** aus
dem Browser — gehostet als nginx-Container **in derselben VM** neben dem
Supabase-Stack: öffentlich unter `https://app.<domain>`, im LAN weiterhin
unter `http://<server-ip>:8080`.

Dank HTTPS ist sie eine **volle PWA**: Safari installiert einen Service
Worker, „Zum Home-Bildschirm“ ergibt eine App, die nach dem ersten Laden
auch **offline startet**. Datenbestand/Lernstand liegen im Browser-Speicher
(IndexedDB/OPFS).

Setup in der VM (`~/fwapp-web/`): `docker-compose.yml` mit `nginx:alpine`,
Port `8080:80`, Volumes `./html` (Webroot, read-only) und `./nginx.conf`
(gzip an; `Cache-Control: no-cache` für `index.html`/`flutter_bootstrap.js`,
lange Cache-Zeiten für gehashte Assets; API-Gateway-Block siehe oben).
`docker compose up -d` — Restart-Policy bringt den Container nach Reboots
selbst hoch. `rsync` muss in der VM installiert sein
(`apt-get install rsync`).

**Deploy** (vom Admin-Rechner, LAN nötig):

```bash
FWAPP_WEB_SSH_OPTS="-i ~/.ssh/<key>" bash tool/deploy_web.sh "fwapp@<server-ip>"
```

Das Skript baut `flutter build web --release` mit der Vorbelegung aus
`config/fwapp.local.json` und synct nach `~/fwapp-web/html/`. Durch die
No-Cache-Header greifen Updates beim nächsten Seiten-Reload.

---

## Backup & Wiederherstellung

### Automatisch (in der VM)

Cronjob des Users `fwapp`, täglich **03:15 Uhr** (`crontab -l`):

- Skript `~/bin/fwapp_backup.sh`:
  `pg_dump -Fc` der Datenbank + `pg_dumpall --globals-only` (Rollen)
- Ablage `~/backups/`, Rotation nach **14 Tagen**, Log `~/backups/backup.log`

### Zusätzlich: vzdump auf dem Host (eingerichtet 2026-07-16)

Die Sync-VM hat einen **eigenen** vzdump-Job (wöchentlich So 03:45, Storage
`vm-backups`, zstd/snapshot, Aufbewahrung 4 Wochen) — bewusst getrennt vom
bestehenden Job der übrigen Gäste. Neu anlegen ginge mit:

```bash
pvesh create /cluster/backup --vmid <vm-id> --schedule "sun 03:45" \
  --storage vm-backups --mode snapshot --compress zstd \
  --prune-backups keep-weekly=4
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
`qm set <vm-id> --onboot 1` setzen. Docker-Container haben Restart-Policys aus dem
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
