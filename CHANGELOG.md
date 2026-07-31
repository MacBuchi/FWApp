# Änderungen

Alle nennenswerten Änderungen an FWApp, neueste zuerst.

Die Einträge sind bewusst so formuliert, dass sie auch in der App unter
**Einstellungen → Was ist neu?** verständlich sind — also aus Sicht der
Anwenderin, nicht aus Sicht des Codes. Das Format orientiert sich an
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die Versionen an
[Semantic Versioning](https://semver.org/lang/de/).

Diese Datei wird als Asset mitgeliefert und in der App gerendert. Wer sie
ändert, ändert damit auch den Text auf den Geräten — siehe AGENTS.md § 5.

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
