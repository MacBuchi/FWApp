# FWApp – Betriebshandbuch

Stand: 2026-07-18. Zielgruppe: die Wehr, die die App produktiv nutzt —
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
> 3. **Einloggen** mit deinem **persönlichen Nutzernamen** und dem
>    Initialpasswort von deinem Zugangszettel (gibt es beim
>    Gerätewart/Admin — eine Registrierung gibt es nicht). Beim ersten
>    Login fragt die App einmalig nach einem **eigenen neuen Passwort**.
>    Ob die Verbindung steht, zeigt der grüne Haken „Server erreichbar“
>    direkt über dem Login.
> 4. Die App lädt den aktuellen Datenbestand und alle Gerätefotos –
>    danach funktioniert **alles auch offline** (Einsatz, Funkloch, Keller).
> 5. Aktualisieren der Daten funktioniert **überall, wo Internet ist**
>    (seit Juli 2026 ist der Server über eine verschlüsselte
>    HTTPS-Adresse erreichbar — kein spezielles WLAN/VPN mehr nötig).
>
> **iPhone:** die App als **Web-App** nutzen — `https://<web-app-adresse>`
> in Safari öffnen (Adresse siehe Zugangszettel), einloggen, dann über das
> Teilen-Menü **„Zum Home-Bildschirm“** — sieht danach aus wie eine App
> und startet dank HTTPS auch offline (nach dem ersten Laden).

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

### Nutzerverwaltung (nur Admin)

- **Mehr → Nutzerverwaltung**: Konto anlegen mit **Nutzername**
  (z. B. `max.m`), Rolle (Mitglied / Gerätewart / Admin) und generiertem
  **Initialpasswort**. Die Zugangsdaten werden genau **einmal** angezeigt —
  direkt auf den Zugangszettel übertragen.
- Beim ersten Login muss die Person das Initialpasswort durch ein eigenes
  ersetzen (die App erzwingt das); der Zettel ist danach wertlos.
- **Passwort vergessen?** Konto in der Liste → „Passwort zurücksetzen“ →
  neues Initialpasswort aushändigen (derselbe Pflichtwechsel greift wieder).
- **Austritt/Gerätewechsel:** Konto **sperren** (umkehrbar) statt löschen;
  Löschen nur für endgültige Aufräumarbeiten.
- Das frühere Sammelkonto `member@fw.local` ist gesperrt — alte
  Zugangszettel damit sind ungültig.

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

## Feedback & App-Updates (seit v1.4.0)

### Wunsch oder Fehler melden

- Auf dem **Start-Dashboard** erscheint (angemeldet) ein Banner „💡 Wunsch
  oder Fehler melden“; dauerhaft gibt es die Kachel **Mehr → Feedback
  senden**. Kategorie wählen (Feature/Bug), kurz beschreiben, senden.
- Die Meldung landet zunächst auf dem eigenen Server und wird dann
  automatisch (alle 6 Std.) als **öffentliches GitHub-Issue** im
  App-Projekt angelegt — inklusive Nutzername. Deshalb zeigt der Dialog
  den Hinweis: **keine persönlichen Daten in den Text schreiben.**

### App-Updates

- Gibt es ein neues Release, zeigt die Android-App auf dem Start-Dashboard
  den Banner „🔄 Update auf v… verfügbar“. Antippen → „Jetzt
  aktualisieren“: Das APK lädt mit Fortschrittsbalken direkt in der App,
  danach fragt der Android-Installer einmalig um Bestätigung.
- Beim allerersten In-App-Update fragt Android zusätzlich nach der
  Erlaubnis „Unbekannte Apps installieren“ für die FWApp — einmal
  erlauben, fertig.
- Klappt der Direkt-Download nicht, bietet der Dialog den Browser-Download
  an. Die **Web-App** aktualisiert sich beim nächsten Öffnen von selbst
  und zeigt daher keinen Banner.

---

## Troubleshooting

| Symptom | Ursache / Lösung |
| --- | --- |
| „Server nicht erreichbar“ | Internetverbindung des Geräts prüfen (Flugmodus? Gast-WLAN ohne Internet?). Status live prüfen: Einstellungen → Cloud-Synchronisation → Kachel „Server erreichbar“ (tippen = neu prüfen). Bleibt es rot: Server/Tunnel prüfen ([SERVER-SETUP.md](SERVER-SETUP.md)). Lernen geht immer offline weiter. |
| Login schlägt fehl | Nutzername + Passwort vom Zugangszettel exakt übernehmen (Groß-/Kleinschreibung des Passworts!). Konto evtl. gesperrt oder noch nicht angelegt → Admin fragt in der Nutzerverwaltung nach. |
| Passwort vergessen | Admin: Mehr → Nutzerverwaltung → Konto → „Passwort zurücksetzen“ → neues Initialpasswort aushändigen. |
| Veröffentlichen: Versionskonflikt | Anderer Admin war schneller → Pull, prüfen, erneut veröffentlichen (siehe oben). |
| Fotos fehlen auf einem Mitglieder-Gerät | Einstellungen → „Gerätefotos offline“ prüfen, ggf. erneut anstoßen; einmal WLAN mit Serverzugang nötig. |
| App-Update lässt sich nicht installieren | Altbestand mit anders signierter Version (z. B. Entwickler-Build) → einmalig deinstallieren, Release-APK installieren. Danach nie wieder nötig. |
| Sync geht nicht, obwohl Internet da ist (App-Version < 1.3.1) | Release-APKs vor 1.3.1 fehlte die Android-Netzwerkberechtigung — einfach das aktuelle APK vom Release drüberinstallieren. |
| Import erkennt Geräte nicht | Im Abgleich-Schritt manuell zuordnen – die App lernt den Alias für das nächste Mal. |
| Daten „weg“ nach Neuinstallation | Sync aktivieren + einloggen + Pull: der zentrale Stand kommt zurück. Nur der persönliche **Lernfortschritt** ist gerätelokal und geht bei Deinstallation verloren (bewusst, keine Personendaten auf dem Server). |
| Serverausfall | Alle Geräte arbeiten mit dem letzten Stand normal weiter. Wiederherstellung: [SERVER-SETUP.md](SERVER-SETUP.md) → Backup & Wiederherstellung. |

---

## Datenschutz

Die App ist bewusst datensparsam aufgebaut:

- **Auf dem zentralen Server** liegen nur Sachdaten (Fahrzeuge, Fächer,
  Geräte, Prüftermine, Inventur-Reports, Gerätefotos) sowie die Konten:
  seit M7 Etappe 3 **individuelle Konten mit selbstgewähltem Nutzernamen**
  (Empfehlung: Kürzel statt Klarnamen, z. B. `max.m`) — gespeichert werden
  nur Nutzername-als-E-Mail-Form, Rolle und Login-Zeitpunkt; keine
  Klarnamen, keine Nutzungsstatistiken. Das frühere geteilte
  Mitglieder-Konto ist gesperrt.
- **Lernfortschritt** (Streak, XP, Quiz-Ergebnisse) bleibt ausschließlich
  lokal auf dem jeweiligen Gerät und wird nie übertragen.
- **In-App-Feedback** wird mit Nutzername als öffentliches GitHub-Issue
  veröffentlicht (der Dialog weist darauf hin) — Meldungen daher ohne
  Personenbezug formulieren.
- **Einsatz-Log** (virtuelles Ausladen) bleibt ebenfalls lokal; die App ist
  ausdrücklich **kein** Einsatzdokumentationssystem.
- Freitextfelder mit Personenbezug: „Erledigt von“ bei Prüfungen und
  „erfasst von“ bei Inventuren. Empfehlung im Verein abstimmen: Kürzel
  statt Klarnamen verwenden. *(Abstimmung + kurzer Hinweistext in der App:
  offen, siehe ROADMAP M5.)*
- Der Server ist über einen **Cloudflare-Tunnel** per HTTPS erreichbar
  (keine Portfreigabe, Heim-IP bleibt verborgen); es sind nur die
  API-Pfade der App exponiert, die Verwaltungsoberfläche bleibt intern.
  Zugriff nur mit Login, eine Selbst-Registrierung ist serverseitig
  deaktiviert; tägliche Backups verbleiben auf dem Server.
- Betroffenenrechte (Auskunft/Löschung) sind bei diesem Datenbestand
  trivial erfüllbar: Admin-Konto löschen bzw. Freitexteinträge per SQL
  bereinigen – Ansprechpartner ist der Admin.
