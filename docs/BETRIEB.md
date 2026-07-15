# FWApp – Betriebshandbuch

Stand: 2026-07-16. Zielgruppe: die Wehr, die die App produktiv nutzt —
Onboarding neuer Mitglieder, tägliche Admin-Arbeit, Troubleshooting,
Datenschutz. Technisches Server-Setup: [SERVER-SETUP.md](SERVER-SETUP.md).

> Instanzspezifische Werte (Serveradresse, Zugangsdaten) stehen nicht hier,
> sondern auf dem Zugangszettel im Gerätehaus bzw. in den privaten Notizen
> des Admins (`docs/private/`, gitignored).

---

## Onboarding-Zettel (Vorlage zum Aushängen)

> ### FWApp installieren – so geht's
>
> 1. **App laden (Android):** Aktuelles Release öffnen:
>    `https://github.com/MacBuchi/FWApp/releases/latest`
>    (QR-Code hängt daneben) → `fwapp-vX.Y.Z.apk` herunterladen und
>    installieren. Beim ersten Mal fragt Android nach der Erlaubnis,
>    Apps aus dieser Quelle zu installieren – zulassen.
> 2. **Sync aktivieren:** App öffnen → **Mehr → Einstellungen → Sync**
>    einschalten. Server ist bereits voreingestellt.
> 3. **Einloggen** mit dem Mitglieder-Konto der Abteilung
>    (E-Mail + Passwort: siehe Zugangszettel im Gerätehaus).
> 4. Die App lädt den aktuellen Datenbestand und alle Gerätefotos –
>    danach funktioniert **alles auch offline** (Einsatz, Funkloch, Keller).
> 5. **Von außerhalb des Gerätehaus-/Heim-WLANs:** Für Updates der Daten
>    ist die WireGuard-Verbindung nötig (nur für Admins relevant –
>    Lernen geht immer, auch ohne Netz).
>
> **iPhone:** aktuell nur über den Admin (Entwickler-Build), TestFlight ist
> geplant.

Updates: Neue App-Version installieren = einfach das neue APK vom Release
laden und „drüberinstallieren“ – Lernstand und Daten bleiben erhalten
(die Releases sind mit einem festen Schlüssel signiert).

---

## Admin-Handbuch

Alle folgenden Funktionen sind nur mit einem **Admin-Konto** sichtbar.
Grundprinzip: **Lokal bearbeiten → prüfen → „Veröffentlichen“.** Erst das
Veröffentlichen macht Änderungen für die Mitglieder sichtbar (kompletter
Snapshot mit Versionszähler); die Geräte der Mitglieder holen sich den
neuen Stand beim nächsten App-Start bzw. manuellem Pull.

### Beladeliste importieren (Import-Wizard)

1. **Mehr → Import** → Excel-/CSV-Datei wählen (Spalten: Fahrzeug, Fach,
   Gerät, Menge – die Zuordnung passiert im nächsten Schritt).
2. **Spalten-Mapping** prüfen/zuordnen.
3. **Abgleich:** Der Wizard matcht Gerätenamen gegen den Katalog
   (exakt → Aliasse → gelernte Aliasse → unscharf). Vorschläge prüfen –
   bestätigte Zuordnungen merkt sich die App für den nächsten Import.
4. **Anwenden** (läuft als eine Transaktion) → danach Raster der Fächer in
   der Fahrzeug-Detailansicht anordnen → **Veröffentlichen**.

Wichtig: Ein Re-Import ersetzt Zuordnungen (Gerät↔Fach), aber niemals
Prüfhistorie oder Instanzen – die hängen an den physischen Geräten.

### Prüftermine pflegen (Gerätewart)

- Gerät öffnen → Instanz anlegen (Seriennummer etc.) → Prüfung mit Intervall
  erfassen. Fälligkeiten erscheinen im Dashboard und als Badges.
- „Erledigt“ setzen springt die Fälligkeit aufs nächste Intervall.
- Nach der Pflege: **Veröffentlichen** nicht vergessen.

### Gerätebilder: Symbolbilder & Fotos

- Jedes Normgerät startet mit einem **Symbolbild** aus der Bildbibliothek
  (gezeichnetes Piktogramm). In der App sind Symbolbilder als
  „Symbolbild – kein verifiziertes Foto“ gekennzeichnet — beim Import
  zugeordnete Bilder sind also automatisch, nicht geprüft.
- **Echtes Foto:** Gerät öffnen → **Foto aufnehmen** → die App verkleinert
  automatisch (≤ 1024 px, ≤ 300 KB) und lädt zentral hoch →
  **Veröffentlichen**. Das Foto ersetzt das Symbolbild dauerhaft.
- **Bild manuell wählen:** derselbe Button bietet auch „Symbolbild aus
  Bildbibliothek“ — durchsuchbar nach Namen, Kurzformen und gängigen
  Aliassen („Pylone“, „TS“, „HSR“ …). Zum Stöbern: **Mehr → Bildbibliothek**.
- Mitglieder-Geräte laden alle Fotos nach dem nächsten Pull automatisch in
  den Offline-Cache (Fortschritt: Einstellungen → „Gerätefotos offline“).
- Ideal als Gerätehaus-Rundgang: Fach für Fach fotografieren.

### Inventur

- **Mehr → Inventur** → Fahrzeug wählen → Fach für Fach Soll/Ist abhaken,
  Mängel mit Notiz erfassen. Sessions sind unterbrechbar.
- Abschluss-Report exportieren (Dokumentationspflicht) und ablegen.

### Veröffentlichen & Versionen

- **Einstellungen → Sync → Veröffentlichen** schiebt den kompletten lokalen
  Stand als neue Version auf den Server.
- Meldet die App einen **Versionskonflikt**, hat ein anderer Admin
  zwischenzeitlich veröffentlicht: erst **Pull** ausführen, eigene Änderungen
  prüfen/nachziehen, dann erneut veröffentlichen. (Regel im Verein: parallel
  arbeitende Admins sprechen sich kurz ab – die App ist bewusst
  Single-Writer.)

### Server & Backups (Kurzfassung)

- Tägliche Datenbank-Dumps laufen automatisch in der Server-VM
  (Rotation 14 Tage); Restore-Prozedur ist geprobt und in
  [SERVER-SETUP.md](SERVER-SETUP.md) dokumentiert.
- Nach Server-Neustart kommt der Stack selbstständig hoch; prüfen mit
  `docker compose ps` in der VM.

---

## Troubleshooting

| Symptom | Ursache / Lösung |
| --- | --- |
| „Server nicht erreichbar“ zu Hause/im Gerätehaus | Handy hängt im **Gast-WLAN** (vom Heimnetz isoliert) → ins normale WLAN wechseln. |
| „Server nicht erreichbar“ unterwegs | WireGuard-Verbindung aktivieren (nur nötig für Pull/Veröffentlichen – Lernen geht offline). |
| Login schlägt fehl | Zugangsdaten vom Zugangszettel exakt übernehmen; Groß-/Kleinschreibung des Passworts beachten. |
| Veröffentlichen: Versionskonflikt | Anderer Admin war schneller → Pull, prüfen, erneut veröffentlichen (siehe oben). |
| Fotos fehlen auf einem Mitglieder-Gerät | Einstellungen → „Gerätefotos offline“ prüfen, ggf. erneut anstoßen; einmal WLAN mit Serverzugang nötig. |
| App-Update lässt sich nicht installieren | Altbestand mit anders signierter Version (z. B. Entwickler-Build) → einmalig deinstallieren, Release-APK installieren. Danach nie wieder nötig. |
| Import erkennt Geräte nicht | Im Abgleich-Schritt manuell zuordnen – die App lernt den Alias für das nächste Mal. |
| Daten „weg“ nach Neuinstallation | Sync aktivieren + einloggen + Pull: der zentrale Stand kommt zurück. Nur der persönliche **Lernfortschritt** ist gerätelokal und geht bei Deinstallation verloren (bewusst, keine Personendaten auf dem Server). |
| Serverausfall | Alle Geräte arbeiten mit dem letzten Stand normal weiter. Wiederherstellung: [SERVER-SETUP.md](SERVER-SETUP.md) → Backup & Wiederherstellung. |

---

## Datenschutz

Die App ist bewusst datensparsam aufgebaut:

- **Auf dem zentralen Server** liegen nur Sachdaten (Fahrzeuge, Fächer,
  Geräte, Prüftermine, Inventur-Reports, Gerätefotos) sowie die Konten:
  wenige **persönliche Admin-E-Mail-Adressen** und **ein geteiltes
  Mitglieder-Konto** pro Abteilung (keine persönlichen Mitgliederkonten,
  keine Namen, keine Nutzungsstatistiken).
- **Lernfortschritt** (Streak, XP, Quiz-Ergebnisse) bleibt ausschließlich
  lokal auf dem jeweiligen Gerät und wird nie übertragen.
- **Einsatz-Log** (virtuelles Ausladen) bleibt ebenfalls lokal; die App ist
  ausdrücklich **kein** Einsatzdokumentationssystem.
- Freitextfelder mit Personenbezug: „Erledigt von“ bei Prüfungen und
  „erfasst von“ bei Inventuren. Empfehlung im Verein abstimmen: Kürzel
  statt Klarnamen verwenden. *(Abstimmung + kurzer Hinweistext in der App:
  offen, siehe ROADMAP M5.)*
- Der Server ist nur im LAN/per WireGuard erreichbar (keine Portfreigabe),
  Zugriff nur mit Login; tägliche Backups verbleiben auf dem Server.
- Betroffenenrechte (Auskunft/Löschung) sind bei diesem Datenbestand
  trivial erfüllbar: Admin-Konto löschen bzw. Freitexteinträge per SQL
  bereinigen – Ansprechpartner ist der Admin.
