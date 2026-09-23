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

## Offen

- Zahlen von der Produktions-VM nachtragen (echte Daten, Laufzeit).
- Speicherbedarf des Autodeploy-Probelaufs messen.
- Installer (#241).
