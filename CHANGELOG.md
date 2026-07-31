# Änderungen

Alle nennenswerten Änderungen an FWApp, neueste zuerst.

Die Einträge sind bewusst so formuliert, dass sie auch in der App unter
**Einstellungen → Was ist neu?** verständlich sind — also aus Sicht der
Anwenderin, nicht aus Sicht des Codes. Das Format orientiert sich an
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen an
[Semantic Versioning](https://semver.org/lang/de/).

Diese Datei wird als Asset mitgeliefert und in der App gerendert. Wer sie
ändert, ändert damit auch den Text auf den Geräten — siehe AGENTS.md,
Abschnitt „Workflow".

## [1.5.4] – 2026-08-01

### Neu

- **Drei wählbare Farbkonzepte** unter Einstellungen → Darstellung
  (Issue #58): **Florian** (Feuerrot auf ruhigem Grund, der Ton des
  App-Icons), **Blaulicht** (Signalblau mit rotem Zweitakzent — die
  Farbpaarung des Einsatzfahrzeugs) und **Glut** (Warnorange wie
  Einsatzjacke und Helm). Dazu **Eigenes Farbthema** mit freier Farbwahl.
  Jedes Konzept unterstützt Hell und Dunkel; welcher Modus gilt, steuert
  wie bisher der Design-Schalter (Standard: folgt dem System).
- Auf einer verbundenen Installation legt die **Verwaltung** das Farbthema
  fest; im reinen Lokalbetrieb wählt ihr frei.

### Verbessert

- **Die Farben sitzen jetzt, wo sie hingehören:** Der Handlungsaufruf auf
  der Startseite, die Navigationsleiste und die Fortschrittsbalken tragen
  die kräftige Konzeptfarbe; Flächen und Karten bleiben ruhig. Vorher
  wirkte die App durch die vielen Pastellflächen blasser als gedacht.
- Mehrere Stellen repariert, an denen Schrift auf getönten Flächen die
  falsche Farbe erbte und je nach Thema schwer lesbar werden konnte
  (Startseiten-Banner, „Weiterlernen", Karteikarten, Fahrzeug-Formular).
  Ein automatischer Test prüft jetzt jede Farbkombination aller Konzepte
  gegen die WCAG-Lesbarkeitsschwelle.

## [1.5.3] – 2026-07-31

### Neu

- **Fahrzeuge lassen sich aus einer Vorlage anlegen.** Beim Anlegen gibt es
  jetzt Vorlagen für LF 10, LF 20, HLF 20, TSF-W, DLK 23/12, RW, GW-L, MTW und
  ELW 1: Die Geräteräume (G1–G6, Heck, Dach) entstehen mit einem Griff statt
  von Hand.
- Für **LF 20 und HLF 20** lässt sich zusätzlich die Normbeladung übernehmen —
  63 bzw. 73 Positionen. ⚠️ Die Liste ist **ungeprüft** und stammt aus einer
  öffentlichen Beladeliste einer Feuerwehrschule; sie gehört durchgegangen.
  Weil die Norm nur vorschreibt, *was* an Bord ist und nicht, in welchem
  Geräteraum es liegt, landen die Positionen gesammelt in einem eigenen Fach.
  Von dort verteilt ihr sie auf eure Räume — genau so, wie sie bei euch
  wirklich liegen.
- Für die übrigen Fahrzeugtypen liegt keine belegbare Liste vor; dort legt die
  Vorlage nur die Geräteräume an. Beladung kommt weiterhin über den
  Import-Assistenten oder von Hand dazu.

## [1.5.2] – 2026-07-31

### Behoben

- **Absturzberichte gingen ausgerechnet bei den schlimmsten Abstürzen
  verloren.** Der Bericht wurde nebenher geschrieben; stürzte die App hart ab,
  war er weg. Jetzt wird er sofort gesichert, bevor irgendetwas anderes
  passiert.

### Geändert

- Ein Absturzbericht enthält jetzt auch Android-Version, Spracheinstellung und
  die letzten Protokollzeilen davor. Ohne diese Vorgeschichte lässt sich ein
  Fehler oft gar nicht nachvollziehen.
- Stürzt dieselbe Sache mehrfach ab, erscheint sie nur noch **einmal** statt
  als lange Liste gleicher Meldungen.
- Der Hinweis im Melde-Dialog sagt jetzt genau, was im Bericht steht — vorher
  stand dort „keine Gerätedaten", obwohl inzwischen die Android-Version
  mitgeschickt wird.

## [1.5.1] – 2026-07-31

### Geändert

- **Bilder auswählen ist deutlich besser geworden.** Beim Fahrzeug- und
  Gerätebild lässt sich jetzt wählen, ob man ein Foto aufnimmt oder eins aus
  der Galerie holt. Danach öffnet sich ein Editor: Der Rahmen steht fest und
  ist der spätere Bildausschnitt, das Bild bewegt man darin — mit zwei Fingern
  zoomen und drehen, mit einem verschieben. Dazu ein Knopf für 90°-Sprünge und
  einer zum Zurücksetzen, mit großen Schaltflächen, die sich auch mit Handschuh
  treffen lassen.
- Bilder werden automatisch auf eine sinnvolle Größe gerechnet. Die vorher
  vorgeschaltete Frage nach der Bildgröße entfällt damit.

## [1.5.0] – 2026-07-31

### Neu

- Stürzt die App ab, bietet sie beim nächsten Start an, das Problem zu melden —
  mit den technischen Angaben, die zur Behebung nötig sind. Vorher blieben
  solche Fehler unbemerkt, wenn niemand von sich aus schrieb. Der Bericht
  enthält keine Gerätedaten und geht nur auf ausdrückliche Bestätigung raus;
  alternativ lässt er sich kopieren.

### Geändert

- Ist eine App-Version zu alt, lehnt der Server das **Veröffentlichen** ab und
  sagt das mit klarem Hinweis. Das schützt den gemeinsamen Datenbestand davor,
  von einem alten Stand unvollständig überschrieben zu werden. Wichtig: Nur das
  Veröffentlichen ist betroffen — die App bleibt vollständig nutzbar, lokale
  Daten bleiben erhalten, und Aktualisieren funktioniert weiter.

## [1.4.9] – 2026-07-31

### Neu

- **Was ist neu?** unter Einstellungen → App-Information: die Änderungen aller
  bisherigen Versionen, die installierte Version ist markiert. Funktioniert
  ohne Netz.

## [1.4.8] – 2026-07-31

### Geändert

- Unterbau auf Flutter 3.44.8 gehoben und alle Bibliotheken nachgezogen. Für
  die Bedienung ändert sich nichts; die App läuft auf aktuellerer Technik und
  bleibt damit sicherheitstechnisch versorgt.

### Behoben

- Beim Sortieren der Geräteräume per Drag & Drop konnte ein Fach eine Position
  zu weit rutschen.

## [1.4.7] – 2026-07-23

### Geändert

- Sammel-Aktualisierung aller verwendeten Bibliotheken.

## [1.4.6] – 2026-07-20

### Behoben

- Geräte einer Serie werden wieder mit ihrem eigenen Symbol angezeigt.
- Ein seltener Absturz direkt beim App-Start ist behoben.

## [1.4.5] – 2026-07-20

### Neu

- Die Lizenzen aller mitgelieferten Fremdbibliotheken sind jetzt in der App
  einsehbar (Einstellungen → Open-Source-Lizenzen).

### Behoben

- Die Anmeldesitzung wandert nicht mehr in das Google-Cloud-Backup. Nach einem
  Gerätewechsel muss man sich einmal neu anmelden — das ist gewollt.

## [1.4.4] – 2026-07-20

### Behoben

- Release-Builds schreiben wieder Protokolleinträge. Ohne sie war jede
  Fehlersuche im Feld blind.

## [1.4.3] – 2026-07-20

### Behoben

- Links öffnen sich unter Android 11 und neuer wieder zuverlässig im Browser.

## [1.4.2] – 2026-07-19

### Geändert

- Aufräumarbeiten unter der Haube: Zugriffsschutz auch für direkt aufgerufene
  Adressen (wichtig in der Web-Version) und ein zentrales Protokoll.

## [1.4.1] – 2026-07-19

### Neu

- Das Design folgt jetzt der Systemeinstellung für Hell/Dunkel und lässt sich
  weiterhin von Hand überschreiben.

## [1.4.0] – 2026-07-19

### Neu

- Rückmeldungen lassen sich direkt aus der App senden.
- Die App meldet neue Versionen selbst und kann sie auf Wunsch gleich
  installieren.

## [1.3.1] – 2026-07-18

### Behoben

- Der Serverabgleich funktioniert wieder auf echten Geräten (der fertigen
  App fehlte die Berechtigung für Internetzugriff).

## [1.3.0] – 2026-07-18

### Neu

- Anmeldung per Benutzername statt E-Mail.
- Ein Initialpasswort muss bei der ersten Anmeldung gewechselt werden.
- Nutzerverwaltung für Administratoren.

## [1.2.1] – 2026-07-18

### Neu

- Der Server ist öffentlich über HTTPS erreichbar, der Abgleich funktioniert
  damit auch außerhalb des Feuerwehr-WLANs.

## [1.2.0] – 2026-07-17

### Neu

- Rollenmodell mit eigener Gerätewart-Rolle.

## [1.1.1] – 2026-07-17

### Neu

- FWApp läuft als Web-App im Browser — die Zwischenlösung für iPhones.
- Der Serverstatus ist schon vor der Anmeldung sichtbar.

## [1.1.0] – 2026-07-16

### Neu

- Symbolbilder für alle Normgeräte samt Bildbrowser und Suche.
- Demo-Datenbestand (HLF 20) und Beispieldateien für den Import.

### Geändert

- Die App steht unter der MIT-Lizenz.

## [1.0.0] – 2026-07-15

### Neu

- Erste Ausgabe: Fahrzeuge, Geräteräume, Beladepläne, Lernspiele und
  Serverabgleich.

[1.5.4]: https://github.com/MacBuchi/FWApp/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/MacBuchi/FWApp/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/MacBuchi/FWApp/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/MacBuchi/FWApp/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/MacBuchi/FWApp/compare/v1.4.9...v1.5.0
[1.4.9]: https://github.com/MacBuchi/FWApp/compare/v1.4.8...v1.4.9
[1.4.8]: https://github.com/MacBuchi/FWApp/compare/v1.4.7...v1.4.8
[1.4.7]: https://github.com/MacBuchi/FWApp/compare/v1.4.6...v1.4.7
[1.4.6]: https://github.com/MacBuchi/FWApp/compare/v1.4.5...v1.4.6
[1.4.5]: https://github.com/MacBuchi/FWApp/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/MacBuchi/FWApp/compare/v1.4.3...v1.4.4
[1.4.3]: https://github.com/MacBuchi/FWApp/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/MacBuchi/FWApp/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/MacBuchi/FWApp/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/MacBuchi/FWApp/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/MacBuchi/FWApp/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/MacBuchi/FWApp/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/MacBuchi/FWApp/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/MacBuchi/FWApp/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/MacBuchi/FWApp/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/MacBuchi/FWApp/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/MacBuchi/FWApp/releases/tag/v1.0.0
