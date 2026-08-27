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

## [1.38.0] – 2026-08-27

### Neu

- **Fotos für einzelne Geräteräume.** Jedes Fach kann jetzt ein Bild
  bekommen — unter *Fächer verwalten* auf das Kästchen neben dem Fach tippen.
  In der Fahrzeugansicht steht das Foto über der Geräteliste des Fachs: Wer
  nachts nachlädt, vergleicht schneller ein Bild, als er eine Liste liest.
  Langes Tippen entfernt das Foto wieder. Das gilt auch für Transportwägen
  und Rollcontainer — die werden als Geräteraum angelegt.
- **Unterlagen am Fahrzeug.** Betriebsanleitung, Fahrzeugschein,
  Prüfbescheinigung: PDF oder Foto, direkt am Fahrzeug, gleich unter dem
  Kopfbereich. Angehängt wird über *Anhängen*, geöffnet mit einem Tipp.
- **Und zwar auch ohne Netz.** Das ist der eigentliche Punkt: Ein Fahrzeug
  steht selten im WLAN. Jede Unterlage sagt deshalb, ob sie **auf diesem
  Gerät** liegt oder nur auf dem Server, und ein Knopf holt alles Fehlende
  auf einmal herunter. Was du einmal geöffnet hast, bleibt da.

### Hinweis für den Gerätewart

Die Fach-Fotos wandern über die normale Veröffentlichung mit. Damit sie auf
den Geräten der Kameraden ankommen, muss dort **mindestens diese Version**
installiert sein — eine ältere App kennt die Fotos nicht und würde sie beim
Veröffentlichen wieder entfernen. Die Unterlagen sind davon nicht betroffen,
die gehen einen eigenen Weg.

## [1.37.0] – 2026-08-27

### Neu

- **Gerätesuche: „Wo liegt das?"** Bisher konnte die App nur den Katalog
  durchsuchen — also welche Geräte es gibt. Wo eines davon verlastet ist,
  stand nirgends; man klickte sich Fahrzeug für Fahrzeug durch die Fächer.
  Jetzt gibt es eine Suche, die **Fahrzeug und Fach** nennt, mit Farbpunkt und
  Ortsangabe wie im Fahrzeugmenü, und mit der Stückzahl, wenn mehrere in einem
  Fach liegen.
- **Zwei Wege hin:** eine Kachel ganz oben auf der Startseite für den
  ganzen Fuhrpark, und die Lupe in einer Fahrzeugansicht für dieses
  Fahrzeug. Die Kachel steht bewusst über Serie und Wochenziel — „Wo
  liegt das?" fragt man unter Zeitdruck.
- **Am Fahrzeug sucht sie im Fahrzeug.** Die Lupe in einer Fahrzeugansicht
  öffnet dieselbe Suche, aber auf dieses Fahrzeug eingegrenzt. Liegt das
  gesuchte Gerät nicht darin, sagt sie nicht „nichts gefunden", sondern
  **wo es stattdessen liegt** — im Einsatz die eigentliche Auskunft.
- **Sie verzeiht beim Tippen.** Umlaute sind egal („schlauche" findet
  „C-Schläuche"), der Kurzname zählt mit („C42"), und mehrere Wörter dürfen in
  beliebiger Reihenfolge stehen („schere akku" findet die
  „Akku-Rettungsschere").
- **Was noch nicht verlastet ist, wird als solches gemeldet.** Steht ein Gerät
  im Katalog, aber in keinem Fahrzeug, sagt die Suche genau das, statt „nichts
  gefunden" zu behaupten.

### Geändert

- Die Lupe in der Fahrzeugliste führt jetzt in die Gerätesuche statt in den
  Gerätekatalog. Der Katalog bleibt unter **Mehr → Geräte** erreichbar.

## [1.36.0] – 2026-08-26

### Behoben

- **Der Feedback-Banner bleibt nach dem Senden stehen.** Wer einen Wunsch
  abgeschickt hatte, verlor damit den Zugang zum Dialog: Das Banner
  verschwand bis zum nächsten App-Start, und die zweite Idee musste warten.
  Es geht jetzt erst weg, wenn du es selbst wegklickst — und auch dann nur
  für diese Sitzung.

## [1.35.0] – 2026-08-26

### Behoben

- **Der Party-Modus nennt jetzt das Fahrzeug.** „In welchem Fach liegt das?"
  war bei mehr als einem Fahrzeug nicht zu beantworten: Zur Wahl standen vier
  Fachnamen, aber von welchem Wagen sie stammen, stand erst in der Auflösung —
  also nach der Antwort. Das Fahrzeug steht jetzt über der Frage.
- **Lange Fahrzeugnamen passen wieder in die Auswahl.** Beim Aufbau einer
  Partie lief ein Name wie „HLF 20/16 Florian Musterstadt 1/44" auf einem
  Handy über den Rand hinaus; zu sehen war statt des Namens eine
  gelb-schwarze Warnfläche. Der Name wird jetzt gekürzt statt überzulaufen.

### Geändert

- **Eine Runde bleibt bei einer Kategorie.** Innerhalb eines Umlaufs bekommen
  alle Spieler dieselbe Art Frage — entweder „Wo liegt was?", „Was ist das?"
  oder Unerwartetes. Vorher wechselte die Art bei fast jeder Frage: Einer
  durfte ein Klischee raten, während der Nächste ein Fach auswendig wissen
  musste. Der Übergabe-Schirm sagt die Kategorie der Runde jetzt mit an.

## [1.34.0] – 2026-08-22

### Neu

- **Party-Modus.** Ein Handy, alle am Tisch: Namen eintragen, und das Gerät
  geht reihum. Wer dran ist, bekommt einen Übergabe-Schirm zu sehen, bevor die
  Frage erscheint — so liest der Vorgänger nicht mit. Die Fragen kommen aus
  drei Töpfen: Wo liegt welches Gerät, was ist auf dem Bild zu sehen, und ein
  neuer Topf mit **unerwarteten Fragen** aus Feuerwehrwissen und Klischees.
  Der Topf funktioniert auch auf einem frisch eingerichteten Gerät, also noch
  bevor ein Fahrzeug angelegt ist.
- **Trinkspiel, ausdrücklich abschaltbar.** Der Schalter ist ab Werk aus. Ist
  er an, schlägt das Spiel bei einer falschen Antwort „einen Schluck — oder"
  eine Aufgabe vor, und zwar gleichwertig: Wer Bereitschaft hat, nimmt die
  Aufgabe. Der Hinweis steht im Aufbau mit dabei.
- Die Antworten des Party-Modus tragen dieselben Seitenfarben und Ortsangaben
  wie das Fahrzeugmenü und das Fach-Quiz.

### Geändert

- Am Ende einer Partie steht bei Gleichstand **„Unentschieden"** statt eines
  Siegers, der nur zufällig zuerst eingetragen wurde. Gleiche Punktzahl heißt
  gleicher Platz.

### Hinweis

Der Party-Modus rührt die persönliche Lernstatistik **nicht** an: Wer an
diesem Abend auf dem Handy mitspielt, verändert weder XP noch Serie noch die
Ergebnisliste des Besitzers.

## [1.33.0] – 2026-08-22

### Neu

- **Vorabversionen erhalten.** In den Einstellungen unter „App-Information"
  gibt es einen neuen Schalter. Ist er an, bietet die App auch Stände an,
  die noch nicht freigegeben sind — gedacht zum Ausprobieren, bevor eine
  Version an die ganze Wehr geht. Der Schalter ist ab Werk aus und **gilt
  nur für das Gerät, auf dem er umgelegt wird**; niemand sonst bekommt
  dadurch Vorabversionen angeboten. In der Web-App gibt es ihn nicht: Dort
  ist beim nächsten Neuladen ohnehin der aktuelle Stand geladen.
- **Das Banner sagt, was es anbietet.** Ein noch nicht freigegebener Stand
  erscheint als „🧪 Vorabversion v… verfügbar", und im Dialog steht vor dem
  Installieren noch einmal, dass es ein Zwischenstand ist.

## [1.32.0] – 2026-08-22

### Geändert

- **Die Farben der Fahrzeugseiten gelten jetzt überall.** Bisher war das
  Fahrzeug nur in der Draufsicht bunt — im aufgeklappten Bild, beim
  Drag & Drop, in der Inventur, in der Einsatzplanung und in der
  Fächerverwaltung blieben dieselben Fächer grau. Jetzt trägt jedes Fach
  seine Seitenfarbe in jeder Ansicht: Fahrerseite blau, Beifahrerseite
  rostrot, Heck grün, Dach ocker, Front violett. Beim Üben stechen Grün und
  Rot die Seitenfarbe weiterhin — die Rückmeldung bleibt eindeutig.
- **Das Fach-Quiz sagt, wo die Fächer liegen.** Die Antworten hießen bisher
  nur „G5" oder „Dach". Jetzt steht der Farbpunkt davor und die Ortsangabe
  darunter („Fahrerseite · hinten") — bei allen vier Antworten, es ist also
  kein Hinweis auf die richtige, sondern die Gelegenheit, die Konvention
  nebenbei zu lernen.

### Neu

- **Das mitgelieferte Demo-Fahrzeug ist verortet.** Direkt nach der
  Installation — also bevor die eigenen Daten da sind — zeigt die App die
  Draufsicht mit farbigen Geräteräumen statt einer grauen Kachelreihe. Auf
  Geräten, die schon vorher installiert waren, wird die Verortung
  nachgetragen; selbst gesetzte Seiten bleiben unangetastet.

## [1.31.0] – 2026-08-21

### Neu

- **Zugangsdaten teilen statt abtippen.** Wer ein Konto mit Zugangszettel
  anlegt, findet im Dialog jetzt neben „Kopieren" auch **„Teilen"** — die
  Zugangsdaten wandern damit als fertige Nachricht in WhatsApp, Signal oder
  SMS. Dass das gefahrlos geht, liegt am Pflichtwechsel: Beim ersten
  Anmelden wählt die Person ein eigenes Passwort, danach ist die
  verschickte Nachricht wertlos.
- **Demo-Zugang zum Weitergeben.** In der Nutzerverwaltung teilt ein Knopf
  einen Blick in die erfundene Wehr „Feuerwehr Freiwilligen" — für alle,
  die erst einmal schauen wollen, ohne einen eigenen Zugang zu brauchen.
  Dahinter liegen erfundene Fahrzeuge und kein einziges echtes Wehrdatum,
  und der Zugang liest nur.

## [1.30.0] – 2026-08-17

### Neu

- **Fahrzeug aus Vorlage: Beladung auf Wunsch gleich in die Geräteräume.**
  Beim LF 20 und HLF 20 lässt sich die Normbeladung jetzt beim Anlegen nach
  der verbreiteten Konvention auf die Fächer verteilen — Atemschutz in den
  Mannschaftsraum, Stromerzeuger in G1, Schläuche in G3, der
  Rettungssatz in G2 … Wer den Schalter nicht setzt, bekommt wie bisher
  alles gesammelt in ein Fach. Die Verteilung ist eine ungeprüfte
  Vorbelegung: bitte am eigenen Fahrzeug prüfen, jede Position bleibt
  einzeln änderbar.
- Die Vorlagen für LF 20 und HLF 20 bringen dafür ein neues Fach
  **„Mannschaftsraum"** mit — dort liegen Pressluftatmer, Masken,
  Feuerwehrleinen und Funkgeräte.

## [1.29.0] – 2026-08-06

### Neu

- **Mehrere Geräte auf einmal einsortieren.** Im Geräte-Wähler hakt ein Tipp
  jetzt an, statt sofort zuzuweisen und zu schließen — angehakt wird, was ins
  Fach gehört, und ein Knopf legt alles gemeinsam hinein. Die Auswahl bleibt
  auch dann bestehen, wenn zwischendurch neu gesucht wird: erst „Schlauch"
  suchen und drei anhaken, dann „Strahlrohr" und zwei.
- **Geräte lassen sich gemeinsam in ein anderes Fach schieben.** Ein langer
  Druck auf ein Gerät im Fach öffnet die Auswahl; danach reicht ein Tipp je
  weiterem Gerät. Über *Verschieben* wandern sie zusammen ins gewählte Fach,
  über das Papierkorb-Symbol gemeinsam heraus.

  Damit lässt sich vor allem das Sammelfach „Normbeladung (ungeprüft) – noch
  zuzuordnen" auflösen, das eine Fahrzeug-Vorlage anlegt: am Fahrzeug stehen,
  die Geräte eines Faches markieren, verschieben, weiter zum nächsten. Vorher
  war das ein Handgriff je Gerät — bei einer vollständigen Beladung mehrere
  hundert.

### Behoben

- Ein Gerät, das in ein Fach verschoben wird, in dem es bereits liegt, taucht
  dort nicht mehr doppelt auf: Die Stückzahlen werden zusammengezählt.

## [1.28.0] – 2026-08-05

### Neu

- **Fahrzeug-Vorlagen kommen fertig verortet.** Wer ein Fahrzeug aus einer
  Vorlage anlegt, bekommt Seiten und Positionen gleich mit — die Draufsicht
  steht ab der ersten Sekunde. Vorbelegt ist die verbreitete Konvention;
  der Hinweis der Vorlage sagt es dazu, und jedes Fach lässt sich einzeln
  ändern.
- **Zwei neue Vorlagen: TLF 3000 und TLF 4000.** Beide mit der üblichen
  Trupp-Aufteilung (G1–G4, Heck, Dach), ohne Beladeliste — für die gibt es
  keine öffentlich belegbare Quelle.
- **Der Feedback-Dialog kennt jetzt vier Arten.** Neben Wunsch und Fehler
  kannst du eine fehlende Fahrzeug-Vorlage 🚒 oder ein fehlendes
  Standard-Gerät 🧰 vorschlagen. Die erste Zeile deiner Nachricht wird
  dabei die Überschrift beim Entwickler — der Hinweis im Dialog erinnert
  daran.

## [1.27.0] – 2026-08-05

### Neu

- **Die Fahrzeugübersicht zeigt jetzt eine Draufsicht.** Fahrtrichtung nach
  oben: Front oben, Fahrerseite links, Dach in der Mitte, Beifahrerseite
  rechts, Heck unten — ein Blick aufs Schema statt einer Liste im Kopf.
  Das Aufklappbild bleibt als zweite Ansicht erreichbar, und ohne
  Seitenangaben sieht alles aus wie bisher.
- **Jede Seite hat ihre feste Farbe.** Beifahrerseite warm, Fahrerseite
  kühl, Heck grün, Dach ocker, Front violett — im Schema, in der
  Fächerliste und im Fach. Die Farben bleiben gleich, egal welche
  Farbpalette du wählst: Sie sind die Merkhilfe, kein Schmuck.
- **Fächer haben jetzt eine Position an der Seite: vorne, Mitte oder
  hinten.** Sie wird wie die Seite aus dem Namen vorgeschlagen (G1/G2
  vorne, G3/G4 Mitte, G5/G6 hinten) und erst übernommen, wenn du
  bestätigst. Der Knopf in der Fächerverwaltung heißt jetzt „Verortung
  aus den Namen vorschlagen" und füllt auch bei schon zugewiesenen Seiten
  die fehlenden Positionen nach.
- **Das Fach beantwortet „wo finde ich das?".** Beim Antippen zeigt sein
  Kopf Seite und Position in der Seitenfarbe, dazu die Leiste
  Front · vorne · Mitte · hinten · Heck und ein Mini-Schema mit dem
  markierten Fach.
- **„Wo liegt's?" fragt auf demselben Bild ab.** Sobald ein Fahrzeug
  verortet ist, tippst du im Quiz auf die Draufsicht — gelernt wird am
  gleichen Schema, das auch die Übersicht zeigt.

### Behoben

- **Das Quiz und Drag & Drop kannten die Seiten nicht.** Beide zeigten das
  Fahrzeug ohne Bereiche, auch wenn Seiten längst zugewiesen waren.

## [1.26.0] – 2026-08-05

### Neu

- **Du siehst jetzt, ob eine Einladung angekommen ist.** Bisher stand an
  jeder offenen Einladung dasselbe — „wartet auf Bestätigung", auch wenn die
  Mail längst verworfen worden war. In der Nutzerverwaltung steht jetzt
  darunter, ob sie zugestellt wurde, noch unterwegs ist oder **unzustellbar**
  war; im letzten Fall mit Grund und Zeitpunkt.
- **Der Ausweg steht direkt an der Einladung.** Über das Menü der Zeile legst
  du stattdessen ein Konto mit Zugangszettel an — Nutzername, Rolle und
  Abteilung sind schon ausgefüllt, und die tote Einladung wird dabei
  zurückgezogen.

### Gut zu wissen

- **„Zustellung nicht prüfbar" heißt genau das.** Kann der Server die
  Auskunft nicht einholen, steht das da — und ausdrücklich nicht „alles in
  Ordnung". Genau diese Verwechslung war das Problem.
- **Ob jemand die Mail geöffnet hat, steht nirgends.** Postfach-Scanner
  melden ein „geöffnet" wenige Sekunden nach dem Versand, ohne dass ein
  Mensch die Mail gesehen hat. Das wäre keine Auskunft, sondern eine falsche.

## [1.25.0] – 2026-08-04

### Neu

- **Leistungsabzeichen fürs Lernen.** Wer übt, steigt im Level — und ab
  Level 3 hängt ein Leistungsabzeichen in **Bronze** am eigenen Avatar, ab
  Level 8 in **Silber**, ab Level 15 in **Gold**. Es steht in „Mein Profil",
  in der Einstellungs-Kachel und auf der Level-Karte der Startseite, jeweils
  mit der Angabe, wie weit es bis zur nächsten Stufe ist.

### Gut zu wissen

- **Einmal verliehen, bleibt verliehen.** Ein Abzeichen verschwindet nicht
  wieder, wenn du zwei Wochen nicht übst.
- **Bewusst kein Dienstgrad.** Schulterklappen mit Sternen und Balken stehen
  für ein Amt mit echter Weisungsbefugnis — die gibt es nicht fürs Quiz. Das
  Leistungsabzeichen wird dagegen für gezeigtes Können verliehen, und genau
  das ist hier gemeint.
- **Die Stufe bleibt auf deinem Gerät.** Sie entsteht aus deinen
  Lernergebnissen, und die verlassen das Handy nicht. Deshalb steht das
  Abzeichen auch nur an deinem eigenen Kopf und nicht in der
  Nutzerverwaltung.

## [1.24.0] – 2026-08-04

### Neu

- **Der Beladeplan sieht jetzt aus wie das Fahrzeug.** Jedes Fach bekommt
  eine Seite — Dach, Front, Fahrerseite, Heck oder Beifahrerseite — und die
  Schnittdarstellung klappt das Fahrzeug entsprechend auf: Dach oben, dann
  einmal herum. Wer davorsteht, findet das Fach an derselben Stelle wieder.
- **Seiten für den Bestand vorschlagen lassen.** In der Fächerverwaltung
  ordnet ein Knopf alle Fächer auf einmal zu, abgeleitet aus ihren Namen
  (ungerade Geräteräume Fahrerseite, gerade Beifahrerseite, GR ans Heck).
  Der Vorschlag wird vorher vollständig angezeigt und erst nach deinem Ja
  übernommen.

### Gut zu wissen

- **Nichts wird still verschoben.** Fächer ohne Seite bleiben sichtbar, in
  einem eigenen Bereich am Ende. Und der Vorschlag rührt kein Fach an, dem
  du selbst schon eine Seite gegeben hast.
- **Fahrerseite statt links** — „links" hängt davon ab, ob man vor oder
  hinter dem Fahrzeug steht.

## [1.23.0] – 2026-08-04

### Geändert

- **Die Einladungsmail kommt mit dem Namen eurer Wehr an.** Betreff und
  Überschrift nennen jetzt die Gesamtfeuerwehr statt „Willkommen bei der
  FWApp" — im Postfach sieht die Einladung damit nach Feuerwehr aus und
  nicht nach Werbung. Abteilung und Rolle stehen wie bisher darunter.

### Behoben

- Stand keine Gesamtwehr dahinter, las sich die Einladung als „Du wurdest
  für deiner Feuerwehr eingeladen". Der Satz ist weg; die Wehr steht in der
  Überschrift.

## [1.22.0] – 2026-08-04

### Neu

- **Die App begrüßt dich beim Start.** Eine kurze Animation: die Flamme geht
  auf, ein Wasserstrahl löscht sie, daraus wird das Logo. Sie läuft in voller
  Länge nur nach der Installation und nach einem Update — sonst siehst du
  bloß kurz das Logo, damit das zweite Öffnen im Gerätehaus nicht wartet.

### Gut zu wissen

- **Sie hält nichts auf.** Die App baut darunter schon auf; wenn die
  Animation endet, ist sie sofort da. Ein Tipp auf den Bildschirm bricht ab.
- **Wer Animationen abgeschaltet hat** (Bedienungshilfen des Geräts), bekommt
  immer die kurze Fassung.

## [1.21.0] – 2026-08-04

### Neu

- **Fahrzeuge lassen sich wieder entfernen.** Auf der Fahrzeugseite steht im
  ⋮-Menü jetzt *Fahrzeug entfernen*. Bisher blieb ein einmal angelegtes
  Fahrzeug für immer stehen — auch ein Vertipper beim Erfassen. Vor dem
  Entfernen steht, was mitgeht: die Fächer und die Beladeliste. Die Geräte
  selbst bleiben im Bestand, nur ihre Zuordnung zu diesem Fahrzeug entfällt;
  prüfpflichtige Exemplare behalten ihre Prüfhistorie und verlieren nur den
  Standort.

### Gut zu wissen

- **Entfernen darf, wer bearbeiten darf.** Wer nur lesen kann, sieht den
  Menüpunkt nicht.
- **Rückgängig machen geht nicht.** Deshalb die Rückfrage mit den Zahlen —
  und deshalb steht die Aktion im Menü statt als eigenes Symbol neben
  „Bearbeiten".

## [1.20.0] – 2026-08-04

### Neu

- **Eigener Anzeigename und eigener Avatar.** Unter *Einstellungen → Mein
  Profil* legst du fest, wie du in der Nutzerverwaltung stehst: mit deinem
  Namen statt mit der Kennung vom Zugangszettel, und mit einem Kopf, den du
  dir aussuchst. 36 fertige Köpfe stehen bereit — vom Atemschutzgeräteträger
  über den Maschinisten bis zum Dalmatiner — und wer mag, stellt sich im
  Baukasten seinen eigenen zusammen: Helm, Augen, Mund, Bart, Hautton,
  Haarfarbe, Hintergrund. „Zufällig würfeln" geht auch.

### Gut zu wissen

- **Der Kopf ist gezeichnet, kein Foto.** Gespeichert werden acht Werte, kein
  Bild. Das lädt nichts hoch, braucht kein Netz zum Anzeigen und legt kein
  Gesicht einer echten Person in der Datenbank ab.
- **Dein Nutzername bleibt, wie er ist.** Er ist die Anmeldung und wird
  weiterhin vom Kommandanten vergeben; in der Nutzerverwaltung steht er
  neben deinem Anzeigenamen, damit beim Passwort-Zurücksetzen klar bleibt,
  wer gemeint ist.
- **Beides gehört dir.** Anzeigename und Avatar kann nur das Konto selbst
  setzen — auch der Kommandant nicht.

## [1.19.0] – 2026-08-04

### Neu

- **Übungsrechte: Gerätewarte können Truppführern befristet Schreibrechte
  geben.** In der Nutzerverwaltung steht beim Konto jetzt *Übungsrechte
  erteilen* — bis Tagesende, zwei oder vier Stunden. Der Betreffende darf
  danach Fahrzeuge, Fächer und Geräte anlegen und ändern, genau wie ein
  Gerätewart, und sieht auf der Startseite bis wann. Gedacht für die Übung:
  Wer mitschreibt, muss dafür nicht dauerhaft Gerätewart werden.

### Gut zu wissen

- **Verwalten bleibt außen vor.** Übungsrechte schalten das Bearbeiten frei,
  niemals die Nutzerverwaltung — und wer sie hat, kann sie nicht selbst
  weitergeben.
- **Erteilen darf, wer selbst schreiben darf**: der Gerätewart, der
  Abteilungskommandant, der Feuerwehrkommandant. Nicht nötig, dafür jemanden
  zu holen.
- **Beenden wirkt sofort**, und jedes Erteilen und Beenden bleibt
  nachvollziehbar: wer wem wann.
- **Nur online.** Rechteänderungen erreichen ein Gerät nur mit Verbindung —
  also vor der Übung erteilen, nicht unten im Keller.

## [1.18.1] – 2026-08-04

### Behoben

- **Passwortmanager erkennen die Passwortfelder wieder.** Beim Zurücksetzen
  des Passworts und beim Einlösen einer Einladung boten Bitwarden & Co.
  nichts an, und „generiertes Passwort einfügen" tat sichtbar nichts. Ursache
  war im Browser messbar: Die App meldete dem Browser weiterhin das
  Anmeldeformular, während längst die Felder für ein neues Passwort auf dem
  Bildschirm standen.

### Gut zu wissen

- Auf dem Bildschirm **„Neues Passwort festlegen"** (Pflichtwechsel nach der
  ersten Anmeldung mit einem Zugangszettel) hilft der Manager erst, nachdem
  man einmal ins Feld getippt hat. Danach füllt er beide Felder normal.

## [1.18.0] – 2026-08-03

### Neu

- **Abteilungen und die Gesamtwehr lassen sich umbenennen.** Unter
  *Mehr → Abteilung & Gesamtwehr* steht neben jedem Namen ein Stift. Der
  Abteilungskommandant ändert den Namen seiner Abteilung, der
  Feuerwehrkommandant jeden Namen seiner Wehr — auch den der Wehr selbst.
  Bisher stand ein Name fest, sobald er einmal vergeben war: Ein Tippfehler
  im Abteilungsnamen war nur noch am Server zu heilen.

### Gut zu wissen

- Beim Umbenennen ändert sich **nur die Beschriftung**. Alles, was an einer
  Abteilung hängt — Fahrzeuge, Geräte, Mitgliedschaften, Prüfungen —, bleibt
  unangetastet, und alle Geräte sehen den neuen Namen beim nächsten Abgleich.

## [1.17.0] – 2026-08-03

### Neu

- **Kommandanten laden neue Leute jetzt per E-Mail ein.** In der
  Nutzerverwaltung steht ganz oben „Einladen": Adresse, Name, Abteilung und
  Rolle eintragen, fertig. Der Eingeladene bekommt eine Mail mit einem
  sechsstelligen Code, tippt in der App auf **„Ich habe eine Einladung"** und
  wählt dabei sein eigenes Passwort. Der große Gewinn: So ein Konto kann
  „Passwort vergessen" benutzen — ein Konto vom Zugangszettel nie, weil an die
  interne Adresse `@fw.local` keine Post zugestellt werden kann. Der
  Zugangszettel bleibt für alle, die keine E-Mail-Adresse angeben wollen.
- **Die Einladung entscheidet nicht über Rechte — die Bestätigung tut es.**
  Solange der Code nicht eingelöst ist, hat das Konto keine Abteilung und
  keine Rolle; es sieht also auch nichts. Erst mit dem Einlösen bekommt es
  genau die Rolle in genau der Abteilung, die in der Einladung steht.
- **Offene Einladungen stehen in der Liste** — mit „Erneut senden", falls die
  Mail nicht ankam, und „Zurückziehen", falls sie an die falsche Adresse ging.
  Zurückziehen gibt die Adresse sofort wieder frei.
- **Der Anzeigename kommt aus der Einladung.** Wer als „Max Muster"
  eingeladen wird, heißt danach in der Nutzerliste auch so — und nicht
  `max.muster` nach dem Anfang seiner E-Mail-Adresse.
- **Wer wen einladen darf, folgt der Feuerwehr-Hierarchie:** Der
  Feuerwehrkommandant lädt in jede Abteilung seiner Gesamtwehr ein und kann
  einen zweiten Feuerwehrkommandanten ernennen (der Schutz davor, dass sich
  die Wehr aussperrt). Ein Abteilungskommandant lädt nur in seine eigene
  Abteilung ein und höchstens als Gerätewart. Ein Gerätewart lädt niemanden
  ein.

## [1.16.1] – 2026-08-03

### Behoben

- **In der Web-App auf dem iPhone sind wieder alle Fotos zu sehen.** Gerätefotos,
  Fahrzeugfotos und der neue Kopfbereich blieben dort leer und zeigten nur eine
  graue Fläche — auf Android war alles in Ordnung. Ursache war die Art, wie die
  Web-App Bilder vom Server holte: Sie schickte dabei die Anmeldung nicht mit,
  und der Server gibt Fotos nur an Angemeldete heraus. Das betraf alle zentral
  gespeicherten Fotos, seit es sie gibt.

## [1.16.0] – 2026-08-03

### Neu

- **Eure Gesamtwehr zeigt sich jetzt auf der Startseite.** Ganz oben steht
  ein eigener Kopfbereich: ein Bild vom Gerätehaus oder vom Fuhrpark, der
  Name der Wehr und ein Begrüßungstext — zum Beispiel der nächste
  Übungstermin. Alle Abteilungen der Gesamtwehr sehen dasselbe. Ist nichts
  eingerichtet, bleibt die Startseite wie bisher; es entsteht kein leerer
  Kasten.
- **Eingerichtet wird das vom Feuerwehrkommandanten** unter *Mehr →
  Abteilung & Gesamtwehr → Kopfbereich der Startseite*. Beim Tippen seht ihr
  sofort, wie es später aussieht. Ein Gerätewart sieht den Kopf, ändern kann
  ihn nur der Kommandant — den Gerätebestand pflegt die ganze Wehr, wie sie
  sich zeigt, entscheidet ihre Führung.
- Einmal geladen, steht der Kopfbereich **auch ohne Netz** — wie die
  Gerätefotos.

### Bekannt

- In der **Web-App auf dem iPhone** fehlt im Kopfbereich zurzeit das Bild;
  Überschrift und Text stehen dort normal. Auf Android ist alles zu sehen.
  Die Ursache betrifft alle zentral gespeicherten Fotos und wird getrennt
  behoben.

## [1.15.0] – 2026-08-02

### Neu

- **Geräte lassen sich jetzt aus dem mitgelieferten Katalog anlegen.** Im
  Geräteformular steht über dem Namensfeld „Aus dem Gerätekatalog wählen":
  suchen wie in der Bildbibliothek — über Name, Kurzform und gebräuchliche
  Bezeichnungen —, antippen, fertig. Das Gerät bringt dabei mit, was ihr
  sonst gar nicht eintippen könntet: Kurzform, Symbolbild, typische
  Verwendung und die Lernfragen. Bisher half der Katalog nur, wenn ihr den
  Normnamen zufällig genau getroffen habt.
- **Selbst angelegte Geräte könnt ihr für den Katalog vorschlagen.** Auf der
  Geräteseite unter den drei Punkten oben rechts. Der Vorschlag geht an die
  Entwicklung, damit der Typ in einer der nächsten Versionen für alle
  mitgeliefert wird. Vor dem Absenden seht ihr wörtlich, was übermittelt
  wird: Name, Kurzform, Beschreibung und eure Abteilung — **kein Foto**, und
  der Text erscheint öffentlich.

## [1.14.0] – 2026-08-02

### Neu

- **Der geteilte Gerätebestand ist jetzt bedienbar.** Was ihr an einem Gerät
  ändert — Name, Beschreibung, Lernmaterial, Foto oder Piktogramm — geht
  sofort an die ganze Gesamtwehr; ein neu angelegtes Gerät ebenso. Die
  Meldung nach dem Speichern sagt euch, ob es draußen ist.
- **Ihr seht jetzt, wie weit eine Änderung reicht.** Auf der Geräteseite und
  im Bearbeiten-Formular steht, ob das Gerät zum geteilten Bestand der
  Gesamtwehr gehört — und wenn eine Änderung noch beim nächsten
  Aktualisieren rausgeht, steht auch das dort.
- **Geräte entfernen — mit klarer Ansage.** Unter den drei Punkten oben
  rechts. Benutzt keine andere Abteilung das Gerät, wird es überall
  gelöscht. Hängt es anderswo noch in einem Fach oder an einem Exemplar,
  wird es nur archiviert: Dort bleibt es erhalten, aus dem gemeinsamen
  Katalog verschwindet es. Was bei euch selbst daran hängt, nennt die
  Rückfrage vorher beim Namen.

### Behoben

- **Beim Bearbeiten gingen Angaben verloren, die das Formular gar nicht
  zeigt** — Trainingsfragen, typische Verwendung, technische Daten und die
  Zugehörigkeit zum mitgelieferten Katalog. Wer nur den Namen korrigierte,
  räumte sie mit weg. Sie bleiben jetzt stehen.
- Die Geräteliste hält sich von selbst aktuell: Ein gelöschtes oder neu
  angelegtes Gerät ist sofort verschwunden bzw. da, ohne Umweg.

### Hinweis

Ein Foto, das nur auf eurem Gerät liegt (weil der Upload nicht durchkam),
wird nicht an die anderen Abteilungen verteilt — es wäre dort ein toter
Verweis. Es bleibt vorgemerkt und geht mit, sobald der Upload klappt.

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
