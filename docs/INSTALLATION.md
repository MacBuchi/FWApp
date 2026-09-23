# Installation einer eigenen FWApp-Instanz (Zielbild)

> Konzept aus Issue #234, Stand 2026-09-23. Wird mit jedem Baustein
> fortgeschrieben; wenn ein Teil gebaut ist, steht es hier. Die
> Einrichtung **unserer** Instanz beschreibt [SERVER-SETUP.md](SERVER-SETUP.md).

## Ziel

Eine Feuerwehr soll ohne Entwickler zu einem eigenen Server kommen — ein
Raspberry Pi oder eine kleine VM im Gerätehaus. Ein Installer, eine
Konfigurationsdatei, Prüfungen **vor** dem Einrichten, und Handys, die den
Server ohne eigene App finden. Das Wort dafür war „Plug and Play".

## Entscheidungen (Marcus, 2026-09-23)

| Frage | Entscheidung |
|---|---|
| Wer betreibt? | **Beides**: eine Wehr mit eigenem Server, oder mehrere Wehren auf einem gemeinsamen Server (KreisDatenMeister-Konsole, #101). Ein Installer für beide Fälle. |
| Wie findet die App ihren Server? | **QR-Code und Domain** (`/.well-known/fwapp.json`). **Kein öffentliches Verzeichnis.** — umgesetzt in v1.63.0 (#238) |
| Mail | **Pflicht**, vor dem Weitermachen mit einem Test-Code geprüft (#240). |
| Hardware | **Raspberry Pi 5 mit 8 GB oder VM mit 4 GB** — nach Messung, siehe unten (#239). |

Bausteine: #238 Kopplung (fertig), #239 Messung (fertig), #240
Vorab-Prüfung (fertig), #241 Installer-Bündel.

## Messung: was der Stack wirklich braucht (#239)

Gemessen am 2026-09-23 am lokalen Supabase-Stack auf **arm64** (Apple
Silicon, dieselbe Architektur wie ein Raspberry Pi 5), mit der Demo-Wehr
aus `tool/seed_demo_wehr.py`. Last: alle 191 E2E-Tests
(`test/integration/`) nacheinander — sie legen Wehren an, veröffentlichen,
ziehen, laden hoch, laden ein.

⚠️ Die Produktions-VM war zum Zeitpunkt der Messung nicht erreichbar. Ihre
Zahlen (echte Datenmenge, Laufzeit über Wochen) fehlen noch und gehören
hier ergänzt.

### Welche Dienste die App braucht

Die App nutzt **kein Realtime** (kein `.stream()`, kein `channel()`) und
**keine Bildumwandlung** (keine `transform:`-Aufrufe). Das ist nicht nur
gelesen, sondern bewiesen: **Alle 191 E2E-Tests laufen grün mit
ausschließlich diesen sechs Diensten.**

| Dienst | Wofür | Leerlauf | Spitze unter Last |
|---|---|---:|---:|
| `db` (Postgres 17) | Daten, RLS, RPCs | 138 MB | 183 MB |
| `storage` | Fotos, Anhänge | 242 MB | 242 MB |
| `rest` (PostgREST) | Tabellen und RPCs | 122 MB | 140 MB |
| `kong` | API-Einstieg | 94 MB | 108 MB |
| `edge_runtime` | Edge Function `admin-users` (Nutzerverwaltung, Einladungen) | 24 MB | 47 MB |
| `auth` (GoTrue) | Anmeldung, Einladungs- und Reset-Mails | 14 MB | 19 MB |
| **Summe** | | **≈ 630 MB** | **≈ 740 MB** |

**Weglassen kann der Installer** (zusammen ≈ 1,5 GB im Leerlauf):

| Dienst | Leerlauf | Warum verzichtbar |
|---|---:|---|
| `analytics` (Logflare) | 570–650 MB | Log-Sammlung; Fehler findet man über `docker logs` |
| `studio` | 264 MB | Admin-Oberfläche; das Nötige macht die KreisDatenMeister-Konsole |
| `vector` | 241 MB | Log-Transport für analytics |
| `realtime` | 236 MB | von der App nicht genutzt |
| `pg_meta` | 131 MB | nur für Studio |
| `imgproxy` | — | Bildumwandlung, nicht genutzt |

Voller Stack im Leerlauf zum Vergleich: **≈ 2,4 GB**.

### Was dazukommt

- **nginx** für Web-App und API-Einstieg: wenige MB.
- **Mail-Brücke** (Python auf dem Host): wenige zehn MB.
- **Autodeploy**: Er spielt jede Migration zuerst in eine Probe-Datenbank
  ein (Dump + Restore). Das kostet kurzzeitig Plattenplatz in der Größe der
  Datenbank und etwas Arbeitsspeicher — **nicht gemessen**, bei einer
  Wehr-Datenbank aber klein.
- **Betriebssystem und Docker** selbst: auf einem Pi mit Raspberry Pi OS
  Lite um 300–500 MB.
- **Postgres-Cache**: wächst mit der Datenmenge; bei einer Wehr (einige
  tausend Zeilen, Fotos liegen im Storage) unkritisch.

### Plattenplatz — der eigentliche Engpass auf dem Pi

Die Images des schlanken Sets sind groß (arm64, entpackt): Postgres
1,76 GB, Storage 1,36 GB, Edge Runtime 1,08 GB, PostgREST 0,66 GB, Kong
0,21 GB, GoTrue 0,09 GB — **zusammen ≈ 5,2 GB**, dazu bei jedem Update
kurzzeitig die neue Fassung daneben. Plus Datenbank, Fotos, Backups.

⚠️ **Eine SD-Karte ist für Postgres die falsche Wahl** — ständige kleine
Schreibzugriffe verschleißen sie, und ein Stromausfall im Gerätehaus
beschädigt sie schneller als eine SSD. Auf dem Pi 5 gehört die Installation
auf eine **SSD (NVMe-HAT oder USB)**.

### Empfehlung

| | Minimum | Empfohlen |
|---|---|---|
| Arbeitsspeicher | 4 GB (schlankes Set) | Pi 5 mit **8 GB** / VM mit **4 GB** |
| Speicher | 32 GB | **64 GB SSD** |
| Architektur | amd64 oder arm64 | |

Das bestätigt die Entscheidung „Pi 5 / 8 GB oder VM / 4 GB" mit viel Luft:
Das schlanke Set braucht unter Last unter 1 GB, das ganze System etwa
1,5 GB. **Ein Pi 4 mit 4 GB dürfte ebenfalls reichen** — gemessen ist das
nicht, und versprochen wird es deshalb nicht.

## Vorab-Prüfung (#240)

`tool/installer/fwapp_check.py` — nur Python-Standardbibliothek, läuft auf
einem frischen Pi oder einer frischen VM. Konfiguration aus
`fwapp.conf` (Vorlage: `tool/installer/fwapp.conf.example`); das
SMTP-Passwort darf als Umgebungsvariable kommen statt in die Datei.

```bash
./fwapp_check.py --conf fwapp.conf --vorher   # vor der Installation
./fwapp_check.py --conf fwapp.conf            # laufende Installation, jederzeit
```

| Bereich | Geprüft | Blockiert (❌) wenn |
|---|---|---|
| Rechner | Architektur, Arbeitsspeicher, freier Platz unter `DATA_DIR`, SD-Karte, Zeitsynchronisation | 32-Bit-System, < 3,5 GB RAM, < 16 GB frei |
| Domain | DNS; nach der Installation auch HTTPS mit gültigem Zertifikat, `/.well-known/fwapp.json` und ob der Server hinter der Adresse antwortet | Domain löst nicht auf, HTTPS/Zertifikat kaputt, Server antwortet nicht |
| Mail | Anmeldung am SMTP-Server, **Testmail mit Code, den man zurücktippt**, SPF, DMARC, DKIM (mit Selector) | Anmeldung scheitert, Code nicht bestätigt |

⚠️ **Warum der Code:** „Der Server hat die Mail angenommen" beweist nichts —
genau so sah es aus, als Brevo eine Einladung wegen DKIM verwarf (#121).
Erst der zurückgetippte Code zeigt, dass eine Einladung ankommt.

Unverschlüsseltes SMTP ist nur für `localhost` erlaubt (etwa die
Mail-Brücke auf demselben Rechner); über das Netz wäre das Passwort im
Klartext unterwegs.

Nachgewiesen am 2026-09-23: echte Läufe gegen DNS, HTTPS und
DNS-over-HTTPS, und der ganze Mailweg gegen Mailpit — richtiger Code ✅
(Exit 0), dreimal falsch ❌ (Exit 1). Die Regeln prüft
`tool/installer/test_fwapp_check.py` in CI.

## Installer (#241)

`tool/installer/fwapp_install.py` — Python-Standardbibliothek plus Docker
mit Compose-Plugin. Konfiguration in derselben `fwapp.conf` wie die
Vorab-Prüfung.

Ab dem ersten Release nach #241 hängen an jedem Release zwei Bündel. So
richtet eine Wehr ihren Server ein (`<tag>` z. B. `v1.64.0`):

```bash
mkdir -p ~/fwapp/server ~/fwapp/web && cd ~/fwapp
# fwapp-server-<tag>.tar.gz, fwapp-web-<tag>.tar.gz und SHA256SUMS
# von der Release-Seite laden, dann:
sha256sum -c --ignore-missing SHA256SUMS
tar -xzf fwapp-server-<tag>.tar.gz -C server
tar -xzf fwapp-web-<tag>.tar.gz -C web
cp server/tool/installer/fwapp.conf.example fwapp.conf   # ausfüllen
sudo python3 server/tool/installer/fwapp_install.py --conf fwapp.conf --web web
```

Mit `sudo`, damit der Installer den Timer für das nächtliche Update
einrichten kann. Das Web-Bündel ist **neutral** gebaut — ohne unsere
Server-Adresse; es findet seinen Server über `/.well-known/fwapp.json`
(#238).

Ablauf: Vorab-Prüfung → Dateien → Schlüssel → Dienste starten →
Migrationen → Einrichtungs-Datei (`/.well-known/fwapp.json`) →
KreisDatenMeister-Konto (Startpasswort, beim ersten Anmelden zu ändern).
Danach legt der KreisDatenMeister in der App die erste Wehr an und lädt
ihren Kommandanten ein (#101).

**Auf dem Rechner** liegt alles unter `DATA_DIR`: `server/` (Compose-Dateien,
`.env` mit den Schlüsseln und `fwapp.conf`, beide chmod 600, dazu
`installation.json` mit dem eingerichteten Stand), `db/`, `storage/`,
`web/`, `functions/`, `kopplung/`, `backups/`, `releases/`.

**Dienste**: genau die sechs aus der Messung plus nginx
(`tool/installer/docker-compose.yml`). Die Container heißen wie auf unserer
VM, damit `tool/vm/fwapp-web-nginx.conf` und die Mailvorlagen-URLs ohne
Kopie passen. Kong 2.8 mit einer gekürzten `kong.yml` (vier Routen,
Schlüsselprüfung per `key-auth`/`acl`).

**Erreichbarkeit** über eine Zusatzdatei je Art (`compose/lan.yml`,
`caddy.yml`, `tunnel.yml`), in `.env` als `COMPOSE_FILE` festgehalten — ein
späteres `docker compose up -d` startet dieselbe Zusammenstellung.

**Idempotent**: Ein zweiter Lauf behält Schlüssel und Daten, spielt nur
neue Migrationen ein (dieselbe Buchführung wie der Autodeploy,
`deploy.applied_migrations`) und ersetzt Web-App, Functions und
Konfiguration. Genau das ist der Kern des Updates.

⚠️ **Die Schlüssel werden nie neu erzeugt**, wenn es sie schon gibt: Das
Postgres-Passwort steckt in der Datenbank, der Anon-Key in jeder App und im
Einrichtungs-QR. `test_fwapp_install.py` hält das fest.

**Server-Images sind gepinnt** (kein `latest`, Postgres bleibt bei 17) —
auch das prüft ein Test.

**Nachgewiesen am 2026-09-23:** Installer im Testmodus (`--testmodus`
legt den Server auf die Ports des lokalen Stacks und nimmt dessen
Demo-Schlüssel), gleich danach ein zweiter Lauf als Update, dann
`tool/setup_local_supabase.sh` und **alle 191 E2E-Tests grün** gegen
diesen Server. Der zweite Lauf spielte 0 Migrationen ein, ließ die `.env`
unverändert und legte kein zweites KreisDatenMeister-Konto an.

```bash
python3 tool/installer/fwapp_install.py --conf <test.conf> --web build/web \
  --ohne-pruefung --testmodus      # test.conf: ERREICHBARKEIT=lan, LAN_PORT frei
bash tool/setup_local_supabase.sh
flutter test test/integration --concurrency=1
```

Was der Nachweis gefunden hat, steht als ⚠️ an der jeweiligen Stelle:
`db/roles.sql` (eine fehlende Rolle bricht die Einrichtung des Images ab),
`kong.yml` (keine doppelten Anführungszeichen), `Server._ersetze` (Inhalt
ersetzen, nie das Verzeichnis — sonst sieht ein laufender Container nach
dem Update ein leeres) und `compose/test.yml` (Storage braucht am Mac ein
Docker-Volume).

### Update-Pfad (entschieden 2026-09-23)

| | Fremde Installationen | Unser Server |
|---|---|---|
| Folgt | jedem **freigegebenen** Release (`UPDATE_KANAL=stabil`); Option `vorab`, oder `aus` | `main` (Testfeld) |
| Wann | automatisch nachts (systemd-Timer, gegen 3 Uhr, holt verpasste Läufe nach) | bei jedem Merge (Autodeploy) |
| Wie | `tool/installer/fwapp_update.py` | `tool/vm/fwapp_autodeploy.sh` |
| Bei Fehler | **vollständige Sicherung wird automatisch eingespielt**, Mail an den KreisDatenMeister, Updates angehalten | Autodeploy blockiert |

**Release-Seite** (`release.yml`, Job *Build installer bundles*): Jedes
Release trägt `fwapp-server-<tag>.tar.gz` (aus
`tool/installer/fwapp_buendel.py`: Installer, Compose-Dateien,
Migrationen, Functions — im Aufbau des Repos), `fwapp-web-<tag>.tar.gz`
(neutral gebaut) und `SHA256SUMS`. Ein Release ohne diese drei Anhänge
kommt für den Updater nicht in Frage — so sieht jedes Release vor #241 aus.
`test/release_workflow_test.dart` hält fest, dass das neutrale Bündel keine
Server-Adresse bekommt.

**Ein Lauf des Updaters:**

| Schritt | Scheitert es … |
|---|---|
| 1. Release wählen (GitHub-API) | Netz weg → nächste Nacht |
| 2. Bündel laden, Prüfsummen | Netz weg / Summe falsch → nächste Nacht |
| 3. Images des Release ziehen | Netz weg → nächste Nacht |
| 4. Dump der Datenbank (`backups/`, die letzten 7; Grundlage des Probelaufs) | blockieren + Mail |
| 5. Probelauf der neuen Migrationen in einer Wegwerf-Datenbank | blockieren + Mail — **nichts eingespielt** |
| 6. **Vollständige Sicherung** bei angehaltenem Stack (siehe unten) | alter Stand startet wieder, blockieren + Mail — **kein Update ohne Sicherung** |
| 7. Installer des neuen Bündels, dann Gesundheitsprüfung | **Sicherung aus 6 automatisch einspielen**, erneut prüfen, blockieren + Mail |

Bis Schritt 5 ist am laufenden Server nichts verändert. Blockiert heißt:
`DATA_DIR/update.blocked` liegt da, jeder weitere Lauf tut nichts, bis sie
gelöscht ist — dasselbe Muster wie im Autodeploy. Die Mail sagt, was zu tun
ist. Nach Erfolg räumt der Updater die Images weg, die nur der alte Stand
brauchte (die Platte ist auf dem Pi der Engpass).

```bash
U="sudo python3 /srv/fwapp/server/fwapp_update.py --conf /srv/fwapp/server/fwapp.conf"
$U --pruefen                  # nur nachsehen
$U                            # jetzt aktualisieren
$U --sichern                  # vollständige Sicherung jetzt
$U --sicherungen              # vorhandene Sicherungen
$U --zuruecksetzen <name>     # diesen Stand zurückholen (hält danach die Updates an)
```

### Vollständige Sicherung vor jedem Update (Marcus, 2026-09-23)

> „Bei jedem Update sollte ein vollständiges Backup erstellt werden. Falls
> irgendwas schief geht, kann das automatisch eingespielt werden."

**Wie andere es machen** (recherchiert am 2026-09-23):

| Ansatz | Wer | Passt hier? |
|---|---|---|
| Vollständige Sicherung der Container-Daten vor dem Update, Container dafür angehalten, Wiederherstellung in einem Schritt | [Nextcloud AIO](https://github.com/nextcloud/all-in-one) (BorgBackup, täglich + vor Container-Updates), [Home Assistant](https://www.home-assistant.io/faq/do-updates-break-things/) (Sicherung vor jedem Update) | **Ja — das ist der Weg hier.** |
| A/B-Partitionen: neues System in die zweite Partition, bei Fehlstart zurück | RAUC, Mender, Rugix ([Bootlin zum Pi 5](https://bootlin.com/blog/safe-updates-using-rauc-on-raspberry-pi-5/), [Vergleich](https://rugix.org/blog/2026-02-28-ota-update-engines-compared/)) | Nein: tauscht das **Betriebssystem**; unsere Updates fassen nur den Stack an. Setzte ein eigenes OS-Abbild voraus. |
| Dateisystem-Schnappschuss (btrfs, ZFS, LVM) | Snapper, [buttervolume](https://github.com/ccomb/buttervolume) | Nein: Pi OS ist ext4, und [Postgres auf Copy-on-Write](https://helmundwalter.de/en/blog/next-gen-backup-with-btrfs-snapshots-for-root-fs-and-databases) gilt als Fehlerquelle. |

**Was gesichert wird** (`tool/installer/fwapp_sicherung.py`): alles, was ein
Container beschreiben kann — die Liste kommt aus `docker inspect`, nicht
aus einer Aufzählung, ein neuer Dienst mit Volume ist also automatisch
dabei. Heute: Postgres-Dateien, `db-config` (pgsodium-Schlüssel!), Fotos,
Functions, bei Caddy die Zertifikate. Dazu `server/` (Schlüssel,
Compose-Dateien), `web/`, `kopplung/` und die Images samt Digest.
Aufbewahrt werden die letzten **zwei** Sicherungen; ihre Images löscht der
Updater nicht, sonst ließe sich eine Sicherung nicht mehr starten.

- **Bei angehaltenem Stack:** eine Datei-Kopie einer laufenden Datenbank
  ist keine. Gemessen: ≈ 6 Sekunden Stillstand für die Sicherung, das ganze
  Update ≈ 20 Sekunden.
- ⚠️ **Mit erweiterten Dateiattributen:** Storage legt den Inhaltstyp jedes
  Fotos als xattr an der Datei ab, nicht in der Datenbank (so auch die
  [Anleitung für selbst gehostetes Supabase](https://simplebackups.com/blog/backup-self-hosted-supabase)).
  Das busybox-tar der meisten Images verliert ihn; GNU tar steckt im
  edge-runtime-Image, das ohnehin auf jedem Server liegt.
- ⚠️ **Über `--volumes-from`, nie über den Pfad aus `docker inspect`:**
  Docker Desktop meldet dort `/host_mnt/…`. Die erste Fassung übersprang
  deshalb die Datenbank STILL — gefunden hat es erst das Zurückspielen im
  Nachweis. Seitdem gilt eine Pflichtliste: ohne Datenbank und Fotos keine
  Sicherung.
- **Integrität:** Jede Datei der Sicherung hat eine Prüfsumme im Manifest;
  vor dem Einspielen wird geprüft — eine halbe Sicherung über die Daten zu
  legen wäre schlimmer als keine.
- **Gesundheitsprüfung** nach dem Update, von innen über das Docker-Netz:
  Datenbank/Anmeldung/Storage gesund, Kong → Anmeldung, Kong → PostgREST →
  Datenbank mit einem echten RPC, Edge Functions nicht 502/503, Web-App und
  Einrichtungs-Datei. „Container läuft" allein beweist nichts.

**Nachgewiesen am 2026-09-23:** `v0.0.1` installiert, eine Kontaktzeile in
die Datenbank und ein PNG in Storage gelegt. Update auf `v0.0.2`, dessen
Migration im Probelauf UND echt durchläuft, aber den RPC der
Gesundheitsprüfung löscht und die Kontaktzeile überschreibt. Ergebnis:
Gesundheitsprüfung schlägt an, Sicherung automatisch eingespielt — RPC
wieder da, Kontaktzeile wieder „vor dem Update", die Migration auch aus der
Buchführung verschwunden, das Foto byte-gleich und weiter `image/png`,
Mail in Mailpit. Danach Update auf `v0.0.3` erfolgreich, von Hand auf die
Sicherung davor zurückgesetzt, von Hand gesichert, und **alle 191
E2E-Tests grün** gegen diesen Server.

⚠️ **Die Sicherung liegt auf demselben Datenträger wie die Daten.** Sie
schützt vor einem missglückten Update, nicht vor einer toten SSD, Diebstahl
oder Brand im Gerätehaus. Dafür braucht es eine Kopie außer Haus (siehe
„Offen").

⚠️ Der Updater braucht **IPv4 zu GitHub** (api.github.com und die
Download-Server sind IPv4-only). Ein Anschluss im Gerätehaus hat das in der
Regel; unsere VM hat es nicht — ein Grund mehr, warum sie beim Autodeploy
bleibt.

**Updater nachgewiesen am 2026-09-23** (vor der vollständigen Sicherung)
mit echten Bündeln aus
`fwapp_buendel.py` und einer nachgebauten Release-API (`UPDATE_API` in der
Konfiguration zeigt auf einen lokalen Webserver):

1. `v0.0.1` aus dem ausgepackten Bündel installiert (`--testmodus`).
2. Update auf `v0.0.2` mit einer neuen Migration: Dump, Probelauf,
   eingespielt, Probe-Datenbank wieder weg.
3. `v0.0.3` mit kaputter Migration: im Probelauf abgefangen, **nicht**
   eingespielt, Server weiter auf `v0.0.2`, Mail in Mailpit, der nächste
   Lauf übersprungen.
4. `v0.0.4` mit kaputter Compose-Datei: Installer scheitert, `v0.0.2`
   zurückgeholt, alle Container laufen, Mail in Mailpit. (Damals über das
   alte Bündel; heute über die vollständige Sicherung, siehe oben.)
5. Danach **alle 191 E2E-Tests grün** gegen den so behandelten Server.

## Offen

- Zahlen von der Produktions-VM nachtragen (echte Daten, Laufzeit).
- Speicherbedarf des Autodeploy-Probelaufs messen.
- **Kopie außer Haus** (3-2-1-Regel): Die Sicherung liegt heute auf
  demselben Datenträger. Denkbar: USB-Platte, zweiter Rechner, oder ein
  verschlüsseltes Borg-Repository wie bei Nextcloud AIO. Braucht eine
  Entscheidung (wohin, wer hält den Schlüssel).
- **Tägliche Sicherung** unabhängig vom Update (Nextcloud AIO macht beides):
  Heute entsteht eine vollständige Sicherung nur vor einem Update oder von
  Hand.
- Das erste echte Release mit Bündeln (nächster Merge mit Versions-Bump)
  einmal von Hand herunterladen und prüfen.
