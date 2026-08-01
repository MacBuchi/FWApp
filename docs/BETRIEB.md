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
>    einschalten. Server ist bereits voreingestellt. Danach die App einmal
>    schließen und neu öffnen.
> 3. **Anmelden** mit deinem **persönlichen Nutzernamen** und dem
>    Initialpasswort von deinem Zugangszettel (gibt es beim
>    Gerätewart/Admin — eine Registrierung gibt es nicht). Seit v1.7.0
>    begrüßt dich die App direkt mit dem Anmeldebildschirm. Beim ersten
>    Anmelden verlangt sie einmalig ein **eigenes neues Passwort**.
>    Ob die Verbindung steht, zeigt der grüne Haken „Server erreichbar“
>    über den Eingabefeldern.
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

### Fahrzeug erfassen: Fach für Fach (seit v1.10.0)

Der Weg für den Gerätehaus-Rundgang — Geräteraum öffnen, alles darin
erfassen, weiter zum nächsten:

1. **Fahrzeuge → Fahrzeug → Beladefach aufklappen** (oder im Schnittbild
   auf ein Fach tippen) → **„Gerät zuweisen“**.
2. **Schon erfasst?** Suchen und antippen — das Gerät liegt sofort im Fach.
   Bereits zugewiesene Geräte sind ausgegraut.
3. **Noch nicht erfasst?** Namen eintippen → **„… neu anlegen“**. Das
   Geräte-Formular öffnet sich mit dem Namen schon eingetragen; nach dem
   Speichern liegt das neue Gerät im offenen Fach.
4. **Foto:** im Formular auf das Bild tippen → *Foto aufnehmen*. Passt der
   Name zu einem Normgerät (auch über Zweitnamen wie „Pylone“ oder
   „B-Schlauch“), steht bis dahin automatisch dessen Symbolbild da —
   gekennzeichnet als „Symbolbild – kein verifiziertes Foto“. Ein eigenes
   Foto ersetzt es und wird nie automatisch überschrieben.
5. **Menge und Korrekturen:** über das ⋯-Menü an jeder Zeile („Menge
   ändern“, „Aus dem Fach entfernen“).
6. Am Ende **Veröffentlichen** nicht vergessen — sonst bleibt der Rundgang
   auf dem eigenen Gerät.

Für eine bestehende Liste in Excel/CSV ist der Import-Wizard schneller.

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
- Beim ersten Anmelden muss die Person das Initialpasswort durch ein eigenes
  ersetzen (die App erzwingt das mit einer eigenen Seite, die sich nicht
  wegtippen lässt); der Zettel ist danach wertlos.
- **Passwort vergessen?** Zwei Wege, je nach Konto:
  - *Mit hinterlegter E-Mail-Adresse* (Admins, Gerätewarte): Die Person hilft
    sich selbst — „Passwort vergessen?“ auf dem Anmeldebildschirm, Code aus
    der Mail eintippen, neues Passwort setzen. Alternativ schickt der Admin
    die Mail über das Kontomenü („Passwort-Mail senden“).
  - *Mit Zugangszettel*: Konto in der Liste → „Passwort zurücksetzen“ → neues
    Initialpasswort aushändigen (derselbe Pflichtwechsel greift wieder).
- **E-Mail-Adresse hinterlegen** (seit v1.8.0): Kontomenü →
  „E-Mail-Adresse hinterlegen“. Sinnvoll für alle, die verwalten oder
  bearbeiten. ⚠️ **Die Person meldet sich danach mit der Adresse an, nicht
  mehr mit dem Nutzernamen** — vorher Bescheid geben. Der Nutzername bleibt
  als Anzeigename in der Liste. Ob die Adresse stimmt, zeigt sich sofort:
  „Passwort-Mail senden“ drücken und fragen, ob sie ankam.
- **Zwei-Faktor-Anmeldung** (seit v1.9.0): Einstellungen →
  „Zwei-Faktor-Anmeldung“ → Einrichtung starten → in der Authenticator-App
  öffnen (oder Schlüssel abtippen) → ersten Code bestätigen. **Freiwillig,
  für Admin-Konten empfohlen** (seit v1.9.1 — die ursprünglich für den
  1. September 2026 angekündigte Pflicht ist gestrichen). Wer einen Faktor
  eingerichtet hat, meldet sich damit auch an — halbe Sicherheit gibt es
  nicht.
- **Telefon verloren / neues Handy?** Ein *anderer* Admin setzt den Faktor
  zurück: Kontomenü → „Zwei-Faktor zurücksetzen“. Danach reicht wieder das
  Passwort allein, und die Person richtet neu ein. Gibt es keinen zweiten
  Admin, hilft nur der Weg über den Server ([SERVER-SETUP.md](SERVER-SETUP.md)).
- **Austritt/Gerätewechsel:** Konto **sperren** (umkehrbar) statt löschen;
  Löschen nur für endgültige Aufräumarbeiten.
- Das frühere Sammelkonto `member@fw.local` ist gesperrt — alte
  Zugangszettel damit sind ungültig.

### Abteilung & Gesamtwehr (seit v1.6.0)

**Mehr → Abteilung & Gesamtwehr.** Hier steht, zu welcher Abteilung das
eigene Konto gehört und ob sie einer Gesamtwehr angeschlossen ist.

Die Gesamtwehr ist die Klammer über mehreren Abteilungen. Verbundene
Abteilungen sehen den Bestand der jeweils anderen — **lesend**, zum Lernen
und Nachschlagen. Bearbeiten und Veröffentlichen darf jede nur bei sich;
einzige Ausnahme ist der Admin der Gesamtwehr, der überall arbeiten darf.

Eine zweite Abteilung einrichten (als Admin):

1. **Gesamtwehr gründen** — Name eingeben, fertig. Die eigene Abteilung
   wird automatisch das erste Mitglied. Das geht nur einmal: Wer schon zu
   einer Gesamtwehr gehört, kann keine zweite gründen.
2. **Weitere Abteilung anlegen** — Name eingeben. Sie gehört sofort zur
   eigenen Gesamtwehr und darf sofort veröffentlichen; der anlegende Admin
   bürgt dafür.
3. Für die neue Abteilung in der **Nutzerverwaltung** einen Gerätewart
   anlegen — im Anlege-Dialog steht jetzt ein Feld **Abteilung**. Bestehende
   Konten lassen sich über das Menü der Kontozeile → **Abteilung ändern**
   umhängen. Wählbar sind nur Abteilungen der eigenen Gesamtwehr.

Anschluss einer bestehenden, eigenständigen Abteilung:

- Deren Gerätewart oder Admin wählt **Anschluss beantragen** und die
  Ziel-Gesamtwehr aus.
- Der **Admin der Gesamtwehr** sieht den Antrag unter „Offene Anfragen" und
  gibt ihn frei oder lehnt ab. **Wer fragt, gibt sich nicht selbst frei** —
  das lässt der Server nicht zu.
- Mit der Freigabe ist eine noch nicht freigegebene Abteilung zugleich
  **freigeschaltet** und darf veröffentlichen. Vorher arbeitet sie ganz
  normal lokal weiter; nur das Veröffentlichen wartet.

**Wenn ein Konto die Abteilung wechselt:** Das Gerät merkt das nicht von
allein. Die App holt neue Stände nur, wenn der Server **neuer** ist als der
lokale Stand — eine frische Abteilung steht aber bei Version 0. Wer schon
mit dem Konto gearbeitet hat, löst deshalb einmal Einstellungen → Sync →
**Pull** aus; das erzwingt den Abgleich und räumt den alten Bestand weg.
Konten, die noch nie auf einem Gerät angemeldet waren, brauchen nichts.

**Bekannte Lücken (Stand v1.6.3):** Eine Abteilung, die gar keiner
Gesamtwehr beitreten will, kann niemand in der App freigeben — das bleibt
Sache des Betreibers. Branding der Gesamtwehr (eigener Header, Bild) und
eigene Konten mit Mail-Bestätigung/2FA sind die nächsten Schritte von
Issue #57.

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
- Der Server kann seit dem 2026-08-01 E-Mails senden (Absender
  `noreply-fwapp@mcbuchi.de` über Brevo). Kontrolle:
  `journalctl -u fwapp-mailbridge` auf der VM; Key-Tausch = Datei
  `~/brevo-api-key.txt` ersetzen, kein Neustart nötig. Details in
  [SERVER-SETUP.md](SERVER-SETUP.md) (Abschnitt Mail-Brücke).

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
- Kleine Eigenheit beim allerersten Update: Wer für die einmalige
  Erlaubnis in die Android-Einstellungen springt, kehrt danach in die App
  zurück, aber der Installer erscheint nicht von allein — einfach noch
  einmal „Jetzt aktualisieren" tippen, der zweite Anlauf läuft ohne Umweg
  durch. (Beobachtet beim verifizierten Testlauf, s. u.)

### Mindestversion scharf schalten (Checkliste)

Das Mindestversions-Gate (seit v1.5.2) weist zu alte Apps **nur beim
Veröffentlichen** ab — Lesen und der lokale Betrieb laufen immer weiter.
Trotzdem gilt vor jedem Setzen von `minimum_supported_version` diese
Reihenfolge, damit niemand in einer Sackgasse landet:

1. **Ziel-Release ist draußen** und wurde auf mindestens einem echten
   Gerät **über den In-App-Update-Weg** installiert — also über genau den
   Weg, den alle Betroffenen nehmen müssen.
2. **Minimum nie über das neueste Release setzen.** Empfehlung: eine
   Version unter dem aktuellsten Release lassen (Puffer für Geräte, die
   das Banner noch nicht gesehen haben).
3. Setzen per `psql` auf der VM (bewusst KEIN Teil des Auto-Deploys aus
   #74 — das Gate ist Betriebszustand, keine Schema-Änderung, und bleibt
   eine bewusste Einzelentscheidung):
   `update public.dataset_meta set minimum_supported_version = 'X.Y.Z';`
   Kein `NOTIFY` nötig — die Funktion liest den Wert bei jedem Aufruf.
4. **Rückweg:** Wert auf `NULL` setzen = Gate aus (fail-open, sofort).

> **Aktueller Stand:** Das Gate ist seit dem 2026-08-01 auf **1.5.5**
> scharf geschaltet (Freigabe Marcus, nachdem das In-App-Update auf einem
> echten Gerät durchlief). Aktuellstes Release ist 1.5.6 — der Puffer aus
> Punkt 2 ist damit eingehalten. Geprüft direkt nach dem Setzen: 1.5.3 und
> 1.5.4 werden abgewiesen, ab 1.5.5 darf veröffentlicht werden.

Beim Setzen per SSH gilt eine Stolperfalle: Kommt das Skript über
`ssh … 'bash -s' < skript.sh` herein, verschluckt ein `docker exec -i psql -c …`
den **Rest des Skripts** als eigenen stdin — die Folgebefehle laufen dann
stillschweigend nie. SQL deshalb immer per Heredoc übergeben.

**Verifiziert am 2026-08-01** (Emulator, echte Release-APKs, kompletter
Kreis v1.5.3 → v1.5.6): Die Gate-Ablehnung ist eine **Snackbar** — kein
Vollbild, nichts wird überdeckt, die App bleibt voll bedienbar und das
Update-Banner erreichbar. OTA-Download, Android-Installer und Neustart
liefen durch; Sitzung, Datenbestand und Lernstand blieben erhalten, und
derselbe vorher abgewiesene Publish ging nach dem Update sofort durch.
Es musste zu keinem Zeitpunkt etwas gelöscht werden.

---

## Troubleshooting

| Symptom | Ursache / Lösung |
| --- | --- |
| „Server nicht erreichbar“ | Internetverbindung des Geräts prüfen (Flugmodus? Gast-WLAN ohne Internet?). Status live prüfen: Einstellungen → Cloud-Synchronisation → Kachel „Server erreichbar“ (tippen = neu prüfen). Bleibt es rot: Server/Tunnel prüfen ([SERVER-SETUP.md](SERVER-SETUP.md)). Lernen geht immer offline weiter. |
| Login schlägt fehl | Nutzername + Passwort vom Zugangszettel exakt übernehmen (Groß-/Kleinschreibung des Passworts!) — das Auge im Passwortfeld zeigt das Getippte. Konto evtl. gesperrt oder noch nicht angelegt → Admin fragt in der Nutzerverwaltung nach. |
| App zeigt nur die Anmeldung, Server antwortet nicht | Seit v1.7.0 führt vom Anmeldebildschirm ein Knopf zu **Servereinstellungen** — dort Adresse prüfen. Hilft das nicht, dort die Cloud-Synchronisation abschalten und die App neu starten: Sie läuft dann wieder ohne Anmeldung im Lokalmodus. |
| Code der Authenticator-App wird nicht akzeptiert | Fast immer die Uhr: TOTP-Codes hängen an der Uhrzeit. Auf beiden Geräten die automatische Zeitsynchronisation einschalten. Sonst: anderer Admin setzt den Faktor zurück. |
| Passwort vergessen | Mit hinterlegter E-Mail: „Passwort vergessen?“ auf dem Anmeldebildschirm, Code aus der Mail eintippen (seit v1.8.0). Sonst Admin: Mehr → Nutzerverwaltung → Konto → „Passwort zurücksetzen“ → neues Initialpasswort aushändigen. |
| Code-Mail kommt nicht an | Hat das Konto überhaupt eine Adresse? In der Nutzerverwaltung steht sie in der Kontozeile; ohne Adresse gibt es keinen Weg über Mail. Sonst Spam-Ordner prüfen und Adresse im Kontomenü korrigieren. Serverseitig: `journalctl -u fwapp-mailbridge` auf der VM zeigt jeden Versand. |
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
