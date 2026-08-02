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

## [1.13.0] – 2026-08-02

### Neu

- **Gerätetypen gehören jetzt der ganzen Wehr.** Was ein C-Strahlrohr *ist* —
  Name, Kurzform, Foto, Piktogramm — pflegt ihr ab sofort gemeinsam: Legt
  Grombach einen Typ an, steht er auch in Bad Rappenau Stadt zur Verfügung,
  mit demselben Bild. Die Geräte selbst, ihre Seriennummern und die
  Prüfhistorie bleiben unverändert bei eurer Abteilung.
- Damit sich beim Umschalten nichts doppelt: Ein geteilter Typ hängt sich an
  das Gerät an, das ihr schon habt, statt daneben ein zweites anzulegen.

### Hinweis

Die App holt den geteilten Bestand ab dieser Version im Hintergrund mit —
beim Start und bei **Jetzt aktualisieren**. Die Oberfläche dazu (Typen
suchen, ändern, aus dem Bestand nehmen) kommt in der nächsten Version.

## [1.12.0] – 2026-08-02

### Neu

- **Die gewählte Abteilung steht jetzt oben rechts in der Leiste** — auf der
  Startseite, beim Lernen, bei Fahrzeugen und Geräten, unter „Mehr" und in
  den Einstellungen. Sie nennt die Abteilung beim Namen, und ein Tipp darauf
  öffnet die Auswahl: Kein Weg mehr über die Einstellungen, wenn du nur
  kurz in die Nachbar-Abteilung schauen willst.
- **Auf einen Blick, ob du daheim bist.** In deiner eigenen Abteilung bleibt
  die Anzeige zurückhaltend; sobald du eine Schwester-Abteilung ansiehst,
  ist sie farbig abgesetzt und trägt ein Auge statt des Hauses.

### Geändert

- **Die Abteilungswahl sagt jetzt, was du wo darfst.** Bisher stand an jeder
  fremden Abteilung pauschal „nur lesen" — seit den Rollen je Abteilung
  (1.11.0) stimmte das nicht mehr: Wer in einer zweiten Abteilung Gerätewart
  ist oder die Gesamtwehr führt, darf dort sehr wohl arbeiten. Die Auswahl
  nennt deshalb bei jeder Abteilung deine Rolle.
- Die schon angezeigte Abteilung noch einmal auszuwählen lädt den Bestand
  nicht mehr neu.

## [1.11.0] – 2026-08-02

### Neu

- **Rollen heißen jetzt wie bei der Feuerwehr — und gelten je Abteilung.**
  Aus Admin, Gerätewart und Mitglied werden Abteilungskommandant,
  Gerätewart und Truppführer/Truppmann. Dieselbe Person kann in mehreren
  Abteilungen (auch unterschiedliche) Rollen haben — etwa ein Gerätewart,
  der zwei Abteilungen betreut. In der Nutzerverwaltung bündelt der neue
  Dialog **„Rollen & Abteilungen"** alles an einem Ort.
- **Der Feuerwehrkommandant ist eine eigene Stellung.** Wer die Gesamtwehr
  gründet, ist ihr erster Kommandant; weitere lassen sich in der
  Nutzerverwaltung ernennen (und entlassen). Der Kommandant arbeitet in
  allen Abteilungen seiner Gesamtwehr, legt Abteilungen an und entscheidet
  über Anschluss-Anfragen — ein Abteilungskommandant nur in seiner.
- **Schreibrechte folgen der gewählten Abteilung.** Wer in der gerade
  angezeigten Abteilung keine Schreibrolle hat, sieht sie lesend — auch
  als Kommandant einer anderen Gesamtwehr. Die Einstellungen zeigen die
  Rolle jetzt für die aktuelle Sicht an.

Das ist Stufe 1 des Nutzerkonzepts (docs/NUTZERKONZEPT.md); ältere
App-Versionen laufen unverändert weiter, bis die Mindestversion angehoben
wird.

## [1.10.0] – 2026-08-02

### Neu

- **Geräte lassen sich endlich von Hand in ein Fach legen.** Im Fahrzeug
  öffnet jedes Beladefach jetzt „Gerät zuweisen": suchen, antippen, drin —
  das funktioniert in der Fächerliste und in der Schnittdarstellung. Über
  das Menü an jedem Gerät lassen sich Menge ändern und die Zuweisung wieder
  entfernen. Bisher konnten Geräte nur per Import oder Vorlage in ein Fach
  gelangen.
- **Neue Geräte entstehen direkt im Fach.** Ist das Gerät noch gar nicht
  erfasst, führt „… neu anlegen" aus derselben Auswahl ins Geräte-Formular —
  der eingetippte Suchbegriff steht schon als Name drin, und nach dem
  Speichern liegt das Gerät im offenen Fach. So bildet man ein Fahrzeug
  Raum für Raum ab, ohne zwischendurch in die Geräteverwaltung zu wechseln.
- **Das Symbolbild kommt beim Tippen von allein.** Passt der eingegebene
  Name zu einem Normgerät (auch über gängige Zweitnamen wie „Pylone" oder
  „B-Schlauch"), setzt die App dessen Piktogramm automatisch — sichtbar
  gekennzeichnet als *Symbolbild, kein verifiziertes Foto*. Ein eigenes
  Foto ersetzt es jederzeit und wird nie überschrieben.

### Behoben

- **„Mit Normbeladung" legt die Geräte jetzt auch wirklich an.** Auf
  Geräten, die schon einmal den zentralen Datenbestand geladen hatten,
  entstand aus einer Vorlage ein Fahrzeug ganz ohne Geräte — der
  mitgelieferte Katalog fehlte dort still. Die Vorlage legt fehlende
  Katalog-Geräte jetzt selbst nach, und falls doch einmal Positionen
  übersprungen werden, sagt die App das offen dazu.

## [1.9.1] – 2026-08-01

### Geändert

- **Die Zwei-Faktor-Anmeldung bleibt freiwillig — auch für Admins.** Die
  mit v1.9.0 angekündigte Pflicht ab dem 1. September ist gestrichen; die
  Einrichtung wird Admin-Konten weiterhin empfohlen. Wer einen zweiten
  Faktor eingerichtet hat, meldet sich damit unverändert auch an.

### Behoben

- Die Kachel *Einstellungen → Zwei-Faktor-Anmeldung* führt jetzt wirklich
  zur Einrichtung — vorher sprang die App zurück auf die Startseite.

## [1.9.0] – 2026-08-01

### Neu

- **Zwei-Faktor-Anmeldung.** Unter *Einstellungen → Zwei-Faktor-Anmeldung*
  lässt sich das Konto zusätzlich mit einer Authenticator-App absichern:
  Beim Anmelden fragt die App dann nach einem sechsstelligen Code, der alle
  30 Sekunden wechselt. Ein abgeschautes Passwort allein reicht damit nicht
  mehr.
- **Für Admin-Konten wird das ab dem 1. September Pflicht.** Bis dahin ist
  es eine Empfehlung; danach führt der Weg beim Anmelden über die
  Einrichtung. Gerätewarte und Mitglieder sind nicht betroffen.
- Einrichten ohne QR-Code-Scannerei: Ein Knopf öffnet die Authenticator-App
  direkt, und wer sie auf einem anderen Gerät hat, tippt den Schlüssel ab —
  er steht in gut lesbaren Viererblöcken da und lässt sich kopieren.
- **Telefon verloren?** Ein Admin setzt den zweiten Faktor in der
  Nutzerverwaltung zurück (Kontomenü → „Zwei-Faktor zurücksetzen"); danach
  meldet sich die Person wieder allein mit dem Passwort an und richtet ihn
  neu ein.

## [1.8.0] – 2026-08-01

### Neu

- **Passwort vergessen — ohne den Umweg über den Gerätewart.** Auf dem
  Anmeldebildschirm führt „Passwort vergessen?" zu einer E-Mail mit einem
  sechsstelligen Code. Den tippt man in der App ein und vergibt direkt sein
  neues Passwort. Der Code funktioniert auch dann, wenn die Mail am PC
  gelesen und die App am Handy bedient wird — genau daran scheitern die
  üblichen Links.
- Das geht für Konten mit **hinterlegter E-Mail-Adresse**, also für Admins
  und Gerätewarte. Wer sich mit einem Zugangszettel anmeldet, wendet sich
  weiterhin an den Gerätewart — dort ändert sich nichts.
- **E-Mail-Adressen in der Nutzerverwaltung.** Über das Menü einer
  Kontozeile lässt sich eine Adresse hinterlegen oder ändern, und es gibt
  einen Knopf „Passwort-Mail senden". Damit richtet man jemanden ein, ohne
  je ein Passwort auszusprechen: Adresse eintragen, Mail schicken, die
  Person setzt sich selbst eines.
- **Achtung dabei:** Wer eine E-Mail-Adresse bekommt, meldet sich ab dann
  mit dieser Adresse an — nicht mehr mit dem Nutzernamen. Die App weist im
  Dialog darauf hin. Der Nutzername bleibt als Anzeigename in der Liste
  stehen.

## [1.7.0] – 2026-08-01

### Geändert

- **Die App beginnt jetzt mit der Anmeldung.** Wer mit der Abteilung
  verbunden ist, landet beim Start auf einem eigenen Anmeldebildschirm
  statt in der App. Bisher kam man auch ohne Anmeldung überall hin — nur
  eben ohne Daten, weil ohne Anmeldung nichts vom Server geladen wird. Das
  sah aus wie eine leere App und war in Wahrheit eine unangemeldete.
- **Wichtig für den Umstieg:** Wer die Cloud-Synchronisation eingeschaltet,
  sich aber noch nie angemeldet hat, braucht ab jetzt seinen Zugangszettel.
  Frisch installierte Geräte sind nicht betroffen — sie starten ohne
  Synchronisation und bleiben ohne Anmeldung nutzbar.
- Der **Passwortwechsel beim ersten Anmelden** ist kein Dialog mehr,
  sondern eine eigene Seite. Er lässt sich nicht mehr wegtippen; der
  einzige andere Weg ist Abmelden.

### Neu

- **Auge im Passwortfeld:** Das getippte Passwort lässt sich sichtbar
  machen — die zuverlässigere Kontrolle als blindes Tippen.
- **Servereinstellungen ohne Anmeldung erreichbar.** Vom Anmeldebildschirm
  führt ein Knopf zu Adresse und Schlüssel des Servers. Ohne diesen Weg
  säße man mit einer falschen Serveradresse fest: anmelden ginge nicht,
  und die Einstellungen lägen hinter der Anmeldung.
- Der Anmeldebildschirm zeigt **vor** dem Versuch, ob der Server überhaupt
  antwortet — ein Netzproblem sieht damit nicht mehr aus wie ein falsches
  Passwort.

## [1.6.3] – 2026-08-01

### Neu

- **Die Abteilung gehört jetzt zur Nutzerverwaltung.** In der Kontoliste
  steht bei jedem Konto, zu welcher Abteilung es gehört. Über das Menü der
  Kontozeile lässt sich das ändern, und beim Anlegen eines Kontos gibt es
  ein Feld dafür — vorbelegt mit der eigenen Abteilung. Damit ist der
  letzte Handgriff aus dem Abteilungs-Aufbau in der App angekommen; vorher
  musste dafür jemand an den Server.
- Wählbar sind ausschließlich Abteilungen der **eigenen Gesamtwehr**. Der
  Server prüft das noch einmal selbst und lehnt alles andere ab.

## [1.6.2] – 2026-08-01

### Behoben

- **Lange Absturzberichte ließen sich nicht melden.** Der Server nimmt
  Meldungen bis 2000 Zeichen an; Absturzberichte mit Protokoll-Anhang sind
  länger, und das Senden scheiterte mit dem irreführenden Hinweis auf die
  Internetverbindung. Die App kürzt jetzt vor dem Senden sichtbar auf das
  Limit — der wichtige Anfang (Fehler und Absturzstelle) bleibt immer
  erhalten.

## [1.6.1] – 2026-08-01

### Behoben

- **„Gesamtwehr gründen" und „Abteilung anlegen" taten nichts:** Der
  Anlegen-Knopf im Namens-Dialog schloss den Dialog über die falsche
  Navigationsebene — sichtbar passierte gar nichts. Betroffen war auch das
  Bestätigen und Ablehnen von Anschluss-Anfragen. Alle drei Dialoge
  funktionieren jetzt; ein automatischer Test bildet die echte
  Navigationsstruktur der App nach, damit genau das nicht wieder
  unbemerkt durchrutscht.

## [1.6.0] – 2026-08-01

### Neu

- **Gesamtwehr und Verbindungen** (dritter Schritt zu #57): Unter **Mehr →
  Abteilung & Gesamtwehr** siehst du, zu welcher Abteilung du gehörst und ob
  sie einer Gesamtwehr angeschlossen ist. Ein Admin kann die Gesamtwehr
  **gründen** und **weitere Abteilungen anlegen** — beides direkt in der App,
  ohne dass jemand am Server arbeiten muss.
- **Anschluss beantragen und freigeben:** Eine eigenständige Abteilung kann
  um Anschluss an eine bestehende Gesamtwehr bitten; entscheiden tut das der
  Admin dieser Gesamtwehr. Wer fragt, gibt sich nicht selbst frei. Nach der
  Freigabe sehen die verbundenen Abteilungen den Bestand der jeweils anderen
  — **lesend**, bearbeiten darf weiterhin jede nur ihren eigenen.
- Eine neu angeschlossene Abteilung ist mit der Freigabe zugleich
  **freigeschaltet** und darf veröffentlichen. Bis dahin arbeitet sie ganz
  normal lokal weiter; nur das Veröffentlichen wartet.

## [1.5.6] – 2026-08-01

### Neu

- **Abteilungswahl** (zweiter Schritt zu #57): Wer zu einer Gesamtwehr
  gehört, sieht in den Einstellungen seine Abteilung und kann in die
  Schwester-Abteilungen wechseln — **lesend**, zum Lernen an deren
  Fahrzeugen. Bearbeiten und Veröffentlichen gibt es nur in der eigenen.
  Jede Abteilung hat ihren eigenen lokalen Bestand; beim Zurückwechseln
  ist alles unverändert da, auch offline.

## [1.5.5] – 2026-08-01

### Unter der Haube

- **Vorbereitung für Abteilungen** (erster Schritt zu #57): Der Server kennt
  jetzt Abteilungen als eigene Datenbestände, und die App synchronisiert
  gezielt den Bestand ihrer Abteilung. Sichtbar ändert sich noch nichts —
  es existiert weiterhin genau eine Abteilung, und die App arbeitet mit
  älteren Servern unverändert zusammen. Die Abteilungswahl und die
  Gesamtwehr folgen in den nächsten Versionen.

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

- **Modernere Formensprache:** randlose Karten mit großen Radien statt
  umrandeter Kästen, Symbole in getönten Kacheln, ein Handlungsaufruf mit
  Farbverlauf und die aktualisierten Material-Fortschrittsbalken mit
  abgerundeten Enden.
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

[1.5.6]: https://github.com/MacBuchi/FWApp/compare/v1.5.5...v1.5.6
[1.5.5]: https://github.com/MacBuchi/FWApp/compare/v1.5.4...v1.5.5
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
