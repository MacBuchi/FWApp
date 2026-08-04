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

> ⚠️ **Seit 2026-08-01 gilt: Vor jedem Einspielen auf die Produktion erst der
> Probelauf gegen den letzten Nacht-Dump** — `tool/migration_rehearsal.sh`,
> beschrieben in [STAGING.md](STAGING.md) (Ebene 2; für große Schnitte die
> Staging-VM, Ebene 3).

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
`set_abteilung/disable/enable/delete`). Sie prüft das mitgeschickte
Nutzer-JWT gegen PostgREST (nur `role = 'admin'` darf) und nutzt für die
eigentlichen Operationen den `SUPABASE_SERVICE_ROLE_KEY` aus der
Container-Umgebung — der mächtige Key verlässt den Server nie.

⚠️ **Mandanten-Schutz beim Zuordnen (seit #57 Phase 3):** `set_abteilung`
und `create` akzeptieren nur Abteilungen aus der **eigenen Gesamtwehr** des
Aufrufers. Das muss die Function selbst prüfen — sie arbeitet mit dem
Service-Role-Key, der RLS vollständig umgeht; die Policies auf
`abteilungen` greifen hier also nicht.

Deploy in der VM (edge-functions-Container läuft im Standard-Stack mit):

```bash
# Function-Ordner in den Stack kopieren, dann Runtime neu starten
cp -r supabase/functions/admin-users ~/supabase/volumes/functions/
cd ~/supabase && docker compose restart functions
```

#### `BREVO_EVENTS_URL` — Zustellauskunft einschalten (Issue #121)

Die Aktion `invite_status` sagt der Nutzerverwaltung, ob eine Einladung
zugestellt oder verworfen wurde. Sie fragt **nicht** Brevo direkt (das ginge
aus dem Container nicht, siehe Mail-Brücke), sondern die Brücke auf dem Host:

```yaml
# ~/supabase/docker-compose.override.yml
services:
  functions:
    environment:
      BREVO_EVENTS_URL: http://172.18.0.1:2501/events
```

```bash
cd ~/supabase && docker compose up -d functions
```

**Ohne diese Zeile funktioniert alles weiter** — die Liste zeigt dann bei
jeder Einladung „Zustellung nicht prüfbar" statt einer Auskunft. Das ist
Absicht: eine Nutzerverwaltung, die wegen einer fehlenden Auskunft scheitert,
hilft niemandem.

⚠️ **Diese Variable fällt nicht unter den Abgleich aus Issue #118.** Der
vergleicht `auth_env` gegen den `auth`-Container; hier geht es um den
`functions`-Container. Fällt sie weg, merkt es niemand außer an der Anzeige.

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

### Wenn die öffentliche Domain wechselt

Die API-URL steckt zur **Build-Zeit** im APK (`--dart-define`). Ein Gerät im
Feld erfährt nie, dass es eine neue Domain gibt — es fragt bis zum nächsten
Update die alte. Deshalb gilt beim Domainwechsel:

1. **Neue Hostnames zusätzlich anlegen**, die alten unverändert lassen (vier
   Routen auf dasselbe `localhost:8080` sind der Normalzustand, kein Fehler).
2. Auf der VM `SITE_URL` und `API_EXTERNAL_URL` auf die neue Domain setzen,
   die alte aber in `ADDITIONAL_REDIRECT_URLS` **behalten**.
3. `config/fwapp.local.json`, das Repo-Secret `FWAPP_SUPABASE_URL` und
   `feedback.yml` nachziehen; wirksam wird das erst im nächsten Release.
4. Alte Hostnames erst abschalten, wenn das Mindestversions-Gate
   (→ [BETRIEB.md](BETRIEB.md)) über dem ersten Release mit der neuen URL
   steht — dann kann kein Gerät mehr auf der alten Domain hängen.

Neue Cloudflare-Zone: Universal SSL wird erst **nach** der Zonen-Aktivierung
ausgestellt (Validierungs-TXT legt Cloudflare selbst an) und kann eine Weile
dauern. Prüfen, ohne auf DNS-Caches hereinzufallen:

```bash
echo | openssl s_client -connect <edge-ip>:443 -servername app.<domain> \
  2>/dev/null | openssl x509 -noout -subject
```

Solange kein Zertifikat da ist, antwortet Port 80 bereits korrekt — daran
erkennt man, dass Tunnel und Ingress stehen und wirklich nur TLS fehlt.

Bausteine in der VM:

- Container `fwapp-tunnel` (`cloudflare/cloudflared`, `--network host`,
  Restart-Policy `unless-stopped`), gestartet mit dem Tunnel-Token aus dem
  Cloudflare-Dashboard.
- `~/fwapp-web/nginx.conf`: die Vorlage liegt im Repo unter
  [tool/vm/fwapp-web-nginx.conf](../tool/vm/fwapp-web-nginx.conf).
  ⚠️ **Alles steht auf `no-cache`** — kein Dateiname eines
  Flutter-Web-Builds trägt einen Inhalts-Hash, langes Cachen friert also die
  ganze App ein (das hat fünf Veröffentlichungen unsichtbar gemacht). Nach
  einer Änderung an der Datei einmal „Purge Everything" im
  Cloudflare-Dashboard, sonst liefert der Rand weiter den alten Stand bis
  zum Ablauf seiner TTL.
  ⚠️ **Der nginx allein genügt nicht.** Gemessen am 2026-08-05 mit bereits
  laufender Änderung: Der Ursprung antwortet auf der VM mit `no-cache`,
  `index.html` und `version.json` kommen auch am Rand so heraus
  (`cf-cache-status: DYNAMIC`) — **`.js` aber mit `max-age=14400`** und wird
  am Rand gespeichert. Cloudflare setzt die Browser-Cache-TTL der Zone über
  die Kopfzeile des Ursprungs, sobald die Endung als statisch gilt. Nötig
  sind daher zusätzlich, einmalig im Dashboard: **Browser Cache TTL auf
  „Respect Existing Headers"** (oder eine Cache-Regel für diesen Hostnamen)
  und ein **„Purge Everything"**. Prüfen, ohne auf das abgelegte Objekt
  hereinzufallen:

  ```bash
  curl -sI "https://fwapp.mcbuchi.de/main.dart.js?p=$(date +%s)" \
    | grep -i cache-control       # muss no-cache sagen, nicht max-age=…
  ```

  Zusätzlicher `location`-Block
  `^/(auth|rest|storage|functions)/`, der an `http://supabase-kong:8000`
  durchreicht; `client_max_body_size 25m` (Foto-Uploads). Wichtig:
  `resolver 127.0.0.11 valid=30s ipv6=off;` und `proxy_pass` über eine
  Variable (`set $kong_upstream …`), damit nginx die Kong-IP **dynamisch**
  auflöst — sonst zeigt er nach einer Neuerstellung des Kong-Containers
  (z. B. `docker compose pull && up -d`) auf die alte IP und liefert 502,
  bis jemand `fwapp-web` neu startet.
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
```

### Auto-Deploy: Migrationen, Functions & Web-App von main (Issue #74, Route A)

Seit dem 2026-08-01 spielt die VM Schema-Änderungen **selbst** ein — von
Hand ist nur noch der Notfall. Ein systemd-Timer (`fwapp-autodeploy.timer`,
alle 10 Minuten) startet [tool/vm/fwapp_autodeploy.sh](../tool/vm/fwapp_autodeploy.sh):

1. holt [deploy/manifest.json](../deploy/manifest.json) über
   `raw.githubusercontent.com` (der einzige GitHub-Weg dieser IPv6-only-VM;
   raw kennt kein Verzeichnis-Listing, **deshalb** gibt es das Manifest —
   ein CI-Guard hält es aktuell),
2. vergleicht mit der Buchführung `deploy.applied_migrations` **in der
   Datenbank** (rollt bei einem Restore mit zurück),
3. für Neues: frischer `pg_dump` (= Rückfallpunkt), **Generalprobe in einer
   Wegwerf-DB gegen genau diesen Dump**, erst bei Erfolg Einspielen auf
   `postgres` + `NOTIFY pgrst`,
4. gleicht die Edge-Function-Dateien per SHA-256 ab und startet bei
   Änderungen den functions-Container neu (Sicherung als `.bak-autodeploy`),
5. hält die **Server-Einstellungen** aus `auth_env` im Manifest gegen
   `docker exec supabase-auth env` — und **meldet** Abweichungen, statt sie
   anzuwenden (siehe unten),
6. gleicht die **Web-App** mit dem `web-dist`-Branch ab (den befüllt der
   Release-Lauf mit einem Tarball des fertigen Prod-Builds — Release-Assets
   wären von der IPv6-only-VM aus unerreichbar, `raw` ist der einzige Weg).
   Bei neuer Version: SHA-256 prüfen, entpacktes `version.json` gegen die
   `VERSION`-Datei halten (raw cached beide getrennt), dann per
   `rsync --delete` **in** `~/fwapp-web/html/` rollen — kein
   Verzeichnis-Tausch, der Bind-Mount des nginx-Containers hängt am Inode.
   Sicherung eine Generation tief unter `html.vorher`.
   `tool/deploy_web.sh` bleibt der Hand-Weg für Sonderfälle.

Der Freigabe-Moment ist der **Merge auf main durch einen Menschen** — der
Timer ist Zustellung, keine Entscheidung.

### Server-Einstellungen, die Features tragen (Issue #118)

Drei Funktionen hingen an GoTrue-Variablen, die **ausschließlich** in
`~/supabase/docker-compose.override.yml` standen — und **zwei davon
scheitern lautlos**: GoTrue verschickt dann seine englische Standardmail
*mit Link*, ohne dass am Aufruf etwas fehlschlägt. Dokumentation ist eine
Erinnerung, keine Prüfung.

Der Soll-Zustand steht deshalb in [deploy/auth_env.json](../deploy/auth_env.json)
und wandert von dort ins Manifest. Jeder Autodeploy-Lauf vergleicht ihn mit
dem laufenden Container:

- **Alles gleich** → eine Zeile im Log, sonst nichts.
- **Abweichung** → die Einzelheiten stehen im Log *und* in
  `~/autodeploy.auth-drift` (Schlüssel, Ist, Soll und der Befehl zum
  Beheben). Sobald es wieder stimmt, verschwindet die Datei von selbst.

⚠️ **Es wird gemeldet, nicht angewendet.** Der Autodeploy schreibt die
compose-Datei nicht: Eine fehlende Mail-Betreffzeile darf nicht dazu führen,
dass Migrationen und Web-Rollout stehen bleiben. Melden hätte alle drei
Fälle gefangen und kann nichts kaputtmachen; automatisch schreiben und
`auth` neu starten ist der viel größere Hammer und kann folgen, wenn sich
das Melden bewährt hat.

⚠️ **Nur Nicht-Geheimes.** `deploy/auth_env.json` liegt öffentlich im Repo.
Der Generator bricht bei Schlüsseln ab, die nach Geheimnis aussehen
(`…KEY`, `…SECRET`, `…PASSWORD`, `…TOKEN`); Brevo-Schlüssel, SMTP-Zugang und
der Service-Role-Key bleiben auf der VM.

Nach einer Änderung an den Variablen:

```bash
cd ~/supabase && sudo docker compose up -d auth
```

**Wenn etwas schiefgeht:** Der erste Fehler erzeugt `~/autodeploy.blocked`
(mit Begründung) und alle weiteren Läufe tun nichts mehr — lieber stehen
bleiben, als dieselbe kaputte Migration alle 10 Minuten gegen die Produktion
zu werfen. Klären, beheben (Migration ist append-only: Korrektur = neue
Migration), dann `rm ~/autodeploy.blocked`. Log: `~/autodeploy.log` und
`journalctl -u fwapp-autodeploy`.

Installation/Neuaufbau:

```bash
scp tool/vm/fwapp_autodeploy.sh fwapp@<vm>:bin/
scp tool/vm/fwapp-autodeploy.{service,timer} fwapp@<vm>:/tmp/
ssh fwapp@<vm> 'chmod +x bin/fwapp_autodeploy.sh \
  && sudo mv /tmp/fwapp-autodeploy.* /etc/systemd/system/ \
  && sudo systemctl daemon-reload \
  && sudo systemctl enable --now fwapp-autodeploy.timer'
# Erster Lauf sät das Ledger: alle Manifest-Migrationen gelten als
# eingespielt (source='seed') — der Server läuft ja auf dem Stand von main.
```

### Mail-Brücke: SMTP → Brevo-HTTP-API (Issue #57 Phase 4, seit 2026-08-01)

Die VM hat kein IPv4 und `smtp-relay.brevo.com` kein IPv6 — klassisches SMTP
nach draußen ist unmöglich. `api.brevo.com` hat dagegen IPv6, aber
Docker-**Bridge**-Netze auf der VM haben keinen IPv6-Ausgang (gemessen:
Bridge-Netz 000, Host-Netz 401). Deshalb läuft
[tool/vm/fwapp_mailbridge.py](../tool/vm/fwapp_mailbridge.py) als
systemd-Dienst **direkt auf dem Host**: GoTrue spricht lokal SMTP, die Brücke
übersetzt zur Brevo-HTTP-API.

- **Bind-Adresse `172.18.0.1:2500`** — das Gateway des
  `supabase_default`-Netzes. Container erreichen es über ihre Default-Route,
  das LAN hat keine Route dorthin (kein offenes Relay im Heimnetz).
- **Zustellauskunft `GET /events?email=…&days=…`** auf `172.18.0.1:2501`
  (Issue #121). Liefert Brevos Ereignisse zu einer Adresse, damit die
  Nutzerverwaltung eine verworfene Einladung von einer offenen unterscheiden
  kann. Sie sitzt aus demselben Grund hier wie der Versand: Der
  edge-functions-Container erreicht `api.brevo.com` nicht (Bridge-Netz ohne
  IPv6-Ausgang). Nebeneffekt: Der Schlüssel bleibt auf dem Host.
  ⚠️ **Kein allgemeiner Weiterleiter** — die Ziel-URL ist fest verdrahtet,
  es gibt genau einen Pfad, und von den Parametern kommen nur `email`
  (Adressform geprüft) und `days` (auf 30 gedeckelt) durch. Abgesichert in
  [test/config/mailbridge_events_test.dart](../test/config/mailbridge_events_test.dart),
  das gegen die ausgelieferte Datei läuft.
- **API-Key** liegt nur auf der VM: `~/brevo-api-key.txt` (chmod 600). Er wird
  pro Versand frisch gelesen — **Key-Tausch = Datei ersetzen, kein Neustart.**
  Achtung Brevo-Falle: Der Key muss mit `xkeysib-` beginnen (HTTP-API); der
  SMTP-Schlüssel (`xsmtpsib-`) wird mit 401 abgelehnt.
- **Absender**: `noreply-fwapp@mcbuchi.de` — die Domain ist in Brevo
  authentifiziert (SPF/DKIM), damit ist jede Adresse darunter erlaubt.
- In `~/supabase/.env`: `SMTP_HOST=172.18.0.1`, `SMTP_PORT=2500`,
  `SMTP_USER=`/`SMTP_PASS=` **leer** (Brücke verlangt kein AUTH),
  `SMTP_ADMIN_EMAIL=noreply-fwapp@mcbuchi.de`, `SMTP_SENDER_NAME=FWApp`.
  Danach `docker compose up -d auth`.

Installation/Neuaufbau:

```bash
ssh fwapp@<vm> 'sudo apt-get install -y python3.11-venv \
  && python3 -m venv ~/mailbridge/venv \
  && ~/mailbridge/venv/bin/pip install aiosmtpd'
scp tool/vm/fwapp_mailbridge.py fwapp@<vm>:bin/
scp tool/vm/fwapp-mailbridge.service fwapp@<vm>:/tmp/
ssh fwapp@<vm> 'sudo mv /tmp/fwapp-mailbridge.service /etc/systemd/system/ \
  && sudo systemctl daemon-reload \
  && sudo systemctl enable --now fwapp-mailbridge.service'
# Log: journalctl -u fwapp-mailbridge  („Angenommen: … Brevo-Message-Id …")
```

**Deutsche Mailvorlage (seit v1.8.0):** Die Passwort-vergessen-Mail zeigt
einen sechsstelligen Code und bewusst **keinen** Link — ein Link stirbt
still, wenn die Mail auf einem anderen Gerät geöffnet wird als dem, das sie
angefordert hat (die PKCE-Prüfsumme liegt nur dort). Vorlage:
`web/mail/recovery.html`, wird mit dem Web-Build ausgeliefert. Auf dem
Server im auth-Container gesetzt:

```yaml
GOTRUE_MAILER_TEMPLATES_RECOVERY: http://fwapp-web/mail/recovery.html
GOTRUE_MAILER_SUBJECTS_RECOVERY: "FWApp: Passwort zurücksetzen"
```

**Einladungsmail (seit v1.17.0):** Gleiches Muster, gleiche Begründung —
Code statt Link. Beim Einladen kommt der Grund noch dazu, dass ein
Einladungslink ein **GET** ist, das den Token verbraucht: Mail-Scanner und
Link-Vorschauen lösen ihn ein, bevor ein Mensch die Mail öffnet. Vorlage:
`web/mail/invite.html`.

```yaml
GOTRUE_MAILER_TEMPLATES_INVITE: http://fwapp-web/mail/invite.html
GOTRUE_MAILER_SUBJECTS_INVITE: "{{ .Data.titel }}: Einladung"
```

⚠️ **Der Betreff ist seit v1.23.0 selbst eine Vorlage.** Dass GoTrue ihn
durch dieselbe Go-Template-Maschine schickt wie den Rumpf, steht in keiner
Dokumentation — es ist am lokalen Stack gemessen (Platzhalter eingesetzt,
Mail in Mailpit angesehen). `{{ .Data.titel }}` ist der Name der Gesamtwehr,
den `admin-users` fertig mitschickt; ohne Gesamtwehr steht dort „FWApp".

**Wer die Variable NICHT umstellt, bekommt weiterhin Mails** — dann nur mit
dem alten, allgemeinen Betreff. Die Überschrift im Rumpf trägt den Wehrnamen
so oder so, weil sie in der Vorlage steht und nicht in der Serverumgebung.

⚠️ **Zwei Fallen, beide beim Bau der Vorlage zugeschnappt:**

1. **GoTrue parst auch HTML-Kommentare.** Ein Go-Platzhalter darin, der
   nicht aufgeht, lässt die ganze Vorlage scheitern — und GoTrue verschickt
   danach **still** seine englische Standardmail *mit Link*, ohne dass am
   Aufruf etwas fehlschlägt. Der einzige Hinweis steht im Log:
   `docker logs supabase-auth | grep template` →
   `templatemailer_template_body_parse_error`.
2. **Das automatische Nachladen erholt sich nicht von einem gescheiterten
   Parse.** Der Fehler bleibt hängen, auch wenn die Datei längst wieder in
   Ordnung ist. Nach jeder Änderung an einer Mailvorlage deshalb
   `docker compose up -d auth` (lokal: `docker restart supabase_auth_FWApp`).

**Reihenfolge beim Ausrollen** wie bei der Recovery-Vorlage: erst
`tool/deploy_web.sh`, dann die Variablen setzen, dann den auth-Container
neu starten. Danach eine Probe-Einladung an die eigene Adresse schicken und
nachsehen, dass Betreff **deutsch** ist und die Mail **keinen** Link auf
`/auth/v1/verify` enthält — genau das prüft auch
`test/integration/einladungen_e2e_test.dart` lokal.

Der Weg geht über den nginx-Container im selben Docker-Netz, braucht also
kein Internet. **Reihenfolge beim Ausrollen:** erst `tool/deploy_web.sh`
(sonst zeigt die URL ins Leere und GoTrue fällt auf die englische
Standardvorlage zurück), dann die beiden Variablen setzen und
`docker compose up -d auth`. Derselbe Text läuft im lokalen Teststack über
`[auth.email.template.recovery]` in `supabase/config.toml` — der E2E-Test
prüft damit genau das, was draußen verschickt wird.

Ende-zu-Ende getestet am 2026-08-01: Direkt-SMTP an die Brücke **und** eine
echte GoTrue-Invite-Mail kamen beim Empfänger an; Fehlversand meldet die
Brücke als SMTP 451 an GoTrue zurück (kein stilles Schlucken).

### Zwei-Faktor-Anmeldung (TOTP, seit v1.9.0)

⚠️ **GoTrue hat TOTP standardmäßig ausgeschaltet.** Ohne die beiden Schalter
antwortet der Server auf jeden Einrichtungsversuch mit „MFA enroll is
disabled for TOTP" (422) — die App zeigt dann eine Fehlermeldung und sonst
nichts. Im auth-Service setzen (`~/supabase/docker-compose.override.yml`):

```yaml
GOTRUE_MFA_TOTP_ENROLL_ENABLED: "true"
GOTRUE_MFA_TOTP_VERIFY_ENABLED: "true"
```

Danach `docker compose up -d auth`. Derselbe Schalter steht im lokalen
Teststack unter `[auth.mfa.totp]` in `supabase/config.toml`, damit der
E2E-Test dieselbe Wahrheit prüft.

**Notausgang, wenn der letzte Admin sein Telefon verliert.** Normalerweise
setzt ein anderer Admin den Faktor in der Nutzerverwaltung zurück. Gibt es
keinen zweiten, geht es direkt am Server — die Faktoren hängen an der
Auth-API:

```bash
# ID des Kontos holen, dann alle Faktoren auflisten und löschen
key=$(grep '^SERVICE_ROLE_KEY=' ~/supabase/.env | cut -d= -f2)
kong=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' supabase-kong)
curl -s "http://$kong:8000/auth/v1/admin/users/<user-id>/factors" \
  -H "apikey: $key" -H "Authorization: Bearer $key"
curl -s -X DELETE \
  "http://$kong:8000/auth/v1/admin/users/<user-id>/factors/<factor-id>" \
  -H "apikey: $key" -H "Authorization: Bearer $key"
```

Die Nutzerverwaltung selbst verlangt von jedem Admin, der einen Faktor
eingerichtet hat, auch die Anmeldung damit (Stufe `aal2`) — bewusst nur
dann: Eine harte Pflicht würde jeden aussperren, der noch nicht
eingerichtet hat, und die Nutzerverwaltung ist genau der Ort, an dem man
sich dabei gegenseitig hilft.

### Feedback-Tabelle & Issue-Bot (seit 2026-07-19)

Die App schreibt In-App-Feedback (Feature/Bug) in die Tabelle `feedback`
(Migration `20260719000000_feedback.sql`; RLS: jeder nur eigene Zeilen).
Der GitHub-Actions-Workflow `feedback.yml` (Cron alle 6 Std.) ruft
`tool/feedback_bot.py` auf: liest unverarbeitete Zeilen über das
öffentliche API-Gateway mit dem Repo-Secret `SUPABASE_SERVICE_ROLE_KEY`,
erzeugt daraus öffentliche Issues (Label `enhancement`/`bug`) und stempelt
`processed_at`. Manuell anstoßen: `gh workflow run feedback.yml`.

### Healthcheck-Intervalle (Idle-CPU, seit 2026-07-19)

Die Standard-Compose-Datei prüft 11 Container **alle 5 Sekunden** — auf einer
kleinen VM kostet allein dieses Dauerfeuer ~15–20 % CPU im Leerlauf (~130
Prozessstarts pro Minute, darunter zwei komplette Node-Interpreter; in
`docker stats` unsichtbar, weil die Prozesse zu kurz leben — messbar nur per
`vmstat` bzw. in der Proxmox-Host-Sicht). Deshalb streckt
`~/supabase/docker-compose.override.yml` alle Healthchecks auf
`interval: 1h` mit `start_period: 10m` und `start_interval: 5s`, sodass die
Startreihenfolge beim Boot schnell bleibt (braucht Docker ≥ 25). Ergebnis:
Leerlauf bei ~2–5 % statt ~19 %. Zwei Stolperfallen:

- Die `.env` setzt `COMPOSE_FILE` — dadurch lädt Compose die Override-Datei
  **nicht** automatisch. Sie muss dort explizit angehängt sein:
  `COMPOSE_FILE=docker-compose.yml:docker-compose.override.yml`.
- Der Health-Status wird von nichts automatisch ausgewertet (Docker startet
  unhealthy Container nicht neu); er dient nur der Anzeige in `docker ps`
  und der Startreihenfolge (`depends_on: service_healthy`). Ein langes
  Intervall verliert also keine Funktionalität.

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
