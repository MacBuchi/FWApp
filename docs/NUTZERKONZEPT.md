# Nutzer- und Rechtekonzept (Zielbild)

> Beschlossen am 2026-08-02 (Konzept Marcus, technisches Review in der
> Session). Dieses Kapitel ist das Zielbild für den Ausbau von Issue #57 und
> wird in Stufen umgesetzt (§7). Bei Widersprüchen zu älteren Aussagen in
> Issues oder ROADMAP gewinnt dieses Dokument; wenn eine Stufe live geht,
> wird der betreffende Abschnitt hier von „Zielbild" auf „umgesetzt"
> gestellt.

## 1. Leitidee

Die Rollen heißen wie im Feuerwehrwesen, damit jeder ohne Handbuch weiß, wer
was darf. Die Komplexität (Einladungen, Freigaben, Zuständigkeiten) liegt
bei den Kommandanten — für Truppführer und Truppmann besteht die App aus:
Abteilung wählen, nachschlagen, lernen.

## 2. Rollen

| Anzeigename | Technischer Schlüssel | Ebene | Kurzbeschreibung |
|---|---|---|---|
| KreisDatenMeister | `operator` (heute: `service_role` auf der VM) | Installation | Betreibt die Instanz, genehmigt neue Gesamtwehren, letzter Wiederherstellungspfad |
| Feuerwehrkommandant | Gesamtwehr-Rolle, **explizit** | Gesamtwehr | Legt Abteilungen an, lädt Abteilungskommandanten ein, verwaltet Mehrfach-Zuständigkeiten |
| Abteilungskommandant | `admin` (je Abteilung) | Abteilung | Nutzerverwaltung seiner Abteilung, lädt Gerätewarte ein, darf die Abteilung archivieren |
| Gerätewart | `geraetewart` (je Abteilung) | Abteilung | Schreibzugriff auf den Bestand, veröffentlicht, erteilt temporäre Rechte |
| Truppführer | `member` | Abteilung(en) | Mail-Konto, lesend; eigener Anzeigename + Avatar; kann temporäre Gerätewart-Rechte bekommen |
| Truppmann | Gastzugang (Code + Name) | — | Immer nur lesend, kein Konto |

Drei Festlegungen dazu:

- **Anzeigenamen sind Anzeigenamen.** In der Datenbank bleiben die
  technischen Schlüssel stabil — einen Anzeigetext ändern kostet nichts,
  ein Enum in der Datenbank kostet eine Migration samt
  Alt-Client-Choreografie.
- **„KreisDatenMeister"** ist bewusst ein augenzwinkernder Kunstname (an
  KBM angelehnt). Er darf gerade *nicht* wie ein reales Feuerwehr-Amt
  klingen, damit niemand eine amtliche Funktion hineinliest.
- **Truppführer/Truppmann** unterscheidet technisch „hat ein Konto" von
  „ist Gast" — nicht den realen Dienstgrad. Ein echter Truppführer, der den
  Gastzugang nutzt, erscheint als Truppmann; das ist Absicht und kein Bug.

## 3. Grundsätze

- **Jede Schreibrolle hängt an einer verifizierten Mail-Adresse.** Das
  Konto entsteht erst mit der Bestätigung; bis dahin ist die Einladung nur
  eine Einladung.
- **Mitgliedschaften statt Konto-Attribut.** Rollen sind Eigenschaften
  einer Mitgliedschaft (`wer` × `Abteilung` × `Rolle`), nicht des Kontos.
  Dieselbe Person kann Gerätewart in zwei Abteilungen sein oder Kommandant
  hier und Truppführer dort. Mehrfach-Zuständigkeiten stellt der
  Feuerwehrkommandant ein.
- **Der Feuerwehrkommandant ist eine explizite Rolle.** Die bisherige
  Herleitung („jeder Abteilungs-Admin der Gesamtwehr darf über
  Gesamtwehr-Dinge entscheiden", `is_gesamtwehr_admin`) widerspricht der
  Hierarchie: Ein Abteilungskommandant ist kein Feuerwehrkommandant.
- **Schreibrechte gelten je Abteilung.** Die Quer-Sicht in
  Schwester-Abteilungen bleibt lesend (Entscheidung 2026-08-01); schreiben
  darf nur, wer dort eine Mitgliedschaft mit Schreibrolle hat.
- **Abteilung löschen heißt archivieren** — an der Abteilung hängt
  Prüfhistorie. Nur Kommandanten dürfen das.
- **Temporäre Gerätewart-Rechte** erteilt der Gerätewart (oder höher)
  aktiv: mit Ablauf (Standard: bis Tagesende), sichtbarem Hinweis beim
  Empfänger und Protokoll (wer wem wann). So können Truppführer z. B. bei
  einer Übung Geräte, Fächer und Fahrzeuge anlegen. Bewusst **keine
  Anfrage-Warteschlange** in der ersten Fassung: Die App hat kein Push —
  eine Anfrage, die niemand bemerkt, ist ein toter Briefkasten, und im
  Übungs-Szenario steht der Gerätewart ohnehin daneben. Rechteänderungen
  wirken nur online — vor der Übung erteilen, nicht im Funkloch-Keller.
- **2FA bleibt freiwillig** (Entscheidung 2026-08-01), wird aber für
  Kommandanten und den KreisDatenMeister ausdrücklich empfohlen.
- **Aussperr-Schutz:** Je Gesamtwehr möglichst zwei Kommandanten. Der
  letzte Rettungsweg (einziger Kommandant, Telefon weg) läuft über den
  KreisDatenMeister auf dem Server — dokumentiert in
  [SERVER-SETUP.md](SERVER-SETUP.md).

## 4. Gerätedatenbank: drei Ebenen

| Ebene | Inhalt | Wer pflegt |
|---|---|---|
| Globaler Katalog | Gerätetypen mit Piktogrammen (`StandardCatalog`, wird mit der App ausgeliefert) | Entwickler, kuratiert über Vorschläge (§5) |
| Gesamtwehr-Bestand | **Gerätetypen** der Wehr: Name, Aliasse, Foto, Symbol — *eine* Datenbasis, keine Aufteilung nach Abteilungen | Gerätewarte aller Abteilungen |
| Abteilung | **Exemplare** (Seriennummern, Prüfungen) und Zuordnungen zu Fächern/Fahrzeugen | Gerätewart der Abteilung |

Der Schnitt zwischen Typ und Exemplar ist fachlich und technisch begründet:
Die physischen Dinge gehören einer Abteilung — was ein C-Strahlrohr *ist*,
teilt man. Und der Sync ist ein Single-Writer-Snapshot **je Abteilung**;
eine über Abteilungen geteilte Tabelle würde beim Veröffentlichen von zwei
Gerätewarten wechselseitig überschrieben. Die Typ-Tabelle bekommt deshalb
einen eigenen, zeilenweisen Sync auf Gesamtwehr-Ebene.

Neu angelegte Gerätetypen landen standardmäßig im Gesamtwehr-Bestand. Der
Anlege-Weg ist immer: erst suchen (Bestand, dann Katalog), dann anlegen —
beim Benennen wählt das Formular automatisch das Katalog-Piktogramm (seit
v1.10.0); ein eigenes Foto ersetzt das Symbol und wird nie überschrieben.

## 5. Katalog-Vorschläge (Dev-Feature dieser Installation)

Wer einen selbst angelegten Gerätetyp für den globalen Katalog vorschlagen
will, tut das über die bestehende Feedback-Pipeline: neuer Typ `katalog` in
der `feedback`-Tabelle, der Bot (`feedback.yml` +
`tool/feedback_bot.py`) macht daraus ein eigens gelabeltes GitHub-Issue.
Die App kennt dabei weiterhin kein Geheimnis — der Service-Key liegt als
GitHub-Secret beim Bot.

Ins Issue gehören nur Name, Aliasse und meldende Abteilung — **kein Foto**:
Das Repo ist öffentlich, und der Betreiber sieht das Foto ohnehin in der
App (Quer-Sicht). Das Katalog-Piktogramm entsteht sowieso im App-Stil.

Das Feature ist seinem Wesen nach „an den Kurator des Katalogs" und damit
ein Dev-Feature dieser Installation. Sollte es je öffentlich werden: Der
geheimnislose Weg ist eine vorbefüllte `issues/new?title=…`-URL im Browser
des Einsenders (braucht dessen GitHub-Konto, keinen Token).

## 6. Abläufe

- **Neue Gesamtwehr:** Anfrage → Mail an den KreisDatenMeister **und**
  Eintrag in seiner Konsole (rollengeschützte Route in der normalen App,
  ohne Navigations-Link — der Schutz ist der Router-Guard, nicht das
  Verstecken). Genehmigt wird ausschließlich angemeldet in der Konsole;
  die Mail nennt Details und verlinkt dorthin. Nach der Genehmigung geht
  die Einladung an den künftigen Feuerwehrkommandanten.
- **Abteilungen** entstehen nur durch den Feuerwehrkommandanten. Die
  Selbstregistrierung (`pending`-Abteilungen aus #57 Phase 1) entfällt
  ersatzlos.
- **Einladungen** verschicken Kommandanten per Mail (GoTrue-Invite über
  die Mail-Brücke); Rolle und Abteilung stecken in der Einladung, das
  Konto zählt erst nach Verifikation.
- **Bootstrap des KreisDatenMeisters** beim Aufsetzen der Installation per
  Setup-Skript auf dem Server — kein lokales Admin-Portal. Seine
  Mail-Adresse (Ziel der Anfrage-Benachrichtigungen) steht in einer
  Konfigurationsdatei **auf dem Server**; ins Repo gehört nur ein
  Platzhalter (`*.example`), nie die echte Adresse — gleiches Muster wie
  beim Brevo-Schlüssel der Mail-Brücke (pro Zugriff gelesen, Tausch ohne
  Neustart).

## 7. Stufenplan

| Stufe | Inhalt | Status |
|---|---|---|
| ① | Mitgliedschaften + expliziter Feuerwehrkommandant + Anzeigenamen. Backfill: bestehende Admins werden Kommandanten ihrer Gesamtwehr (Ist-Verhalten bleibt; Zurückstufen geht danach in der App) | **Umgesetzt (v1.11.0)** |
| ② | Gerätetypen auf Gesamtwehr-Ebene mit eigenem Sync (der größte Brocken) | **Umgesetzt (v1.15.0)** |
| ③ | Einladungen per Mail, temporäre Rechte, Anzeigename + Avatar | Zielbild |
| ④ | KreisDatenMeister-Konsole + Freigabe neuer Gesamtwehren — erst, wenn eine zweite Wehr real absehbar ist; das Schema aus ① trägt sie schon | Zielbild |

Daneben, unabhängig und klein: Katalog-Picker im Geräteformular,
Vorschlag-Flow (§5).

⚠️ Für jede Stufe gilt die Alt-Client-Choreografie aus #57 Phase 1:
Migration einspielen → App-Version ausrollen →
`minimum_supported_version` heben → erst dann neue Wege öffnen.

## 8. Bewusst gestrichen

| Gestrichen | Warum |
|---|---|
| Selbstregistrierung von Abteilungen (`pending`) | Ersetzt durch „Abteilungen entstehen nur aus der Gesamtwehr" — eine Zustandsmaschine weniger |
| Genehmigen/Ablehnen-Links in Mails | Mail-Scanner und Link-Vorschauen rufen GET-Links automatisch ab — das Postfach würde genehmigen, bevor ein Mensch liest |
| Lokales Admin-Portal für den Bootstrap | Angriffsfläche und Bauaufwand für eine einmalige Aktion; ein Setup-Skript tut dasselbe |
| Foto am Katalog-Vorschlag | Öffentliches Repo = öffentliches Foto; unnötig, weil der Betreiber es in der App sieht |
| Anfrage-Warteschlange für temporäre Rechte (v1) | Ohne Push ein toter Briefkasten; der Gerätewart erteilt aktiv |
