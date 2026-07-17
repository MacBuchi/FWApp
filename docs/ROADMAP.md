# FWApp – Roadmap bis zur produktiven Anwendung

Stand: 2026-07-16 · Status-Legende: ✅ fertig · 🔨 geplant

**Fuhrpark der Wehr (Baden-Württemberg, Zielumfang):** HLF 20, LF 20, LF 8/6,
DLK 23/13, AB-G, AB-Mulde, GW-T, RW, ELW, MTW. (Die App liefert ein fiktives
Demo-HLF 20 mit; die echten Beladelisten kommen per Import-Wizard.)

## Wo wir stehen

| Bereich | Status |
| --- | --- |
| Datenmodell + Migrationen (Schema v2, Prüftermine, Instanzen) | ✅ |
| Gerätewart-Assistent (Prüftermine, Ablaufdaten, Dashboard, Badges) | ✅ |
| Zentrale Datenbank (Supabase, Single-Writer-Admin, RLS, Publish/Pull) | ✅ |
| Import-Wizard (Excel/CSV, Spalten-Mapping, Fuzzy-Matching, Alias-Lernen) | ✅ |
| 2D-Schnittdarstellung + Raster-Editor | ✅ |
| Lernmodi (Fach-Quiz, Wo liegt's?, Geräte-Wissen, Drag&Drop, Bild-Quiz) | ✅ |
| Plattformen: Android, iOS, Web (persistent), macOS | ✅ |
| CI (Analyze, Tests, Codegen-Check, Web-Build) | ✅ |
| Release-Pipeline (Auto-Tag + signiertes APK als GitHub-Release) | ✅ |
| Bildbibliothek (110 Symbolbilder, Browser + intuitive Suche, Auto-Zuordnung mit „Symbolbild“-Kennzeichnung) | ✅ (16.07.) |
| Logik-Testabdeckung (Sync 89 %, Inspection 86 %, Import 73 %) | ✅ |
| Inventurassistent (Soll/Ist, Mängeldoku, Report) | ✅ M3 |
| Einsatzassistent (virtuelles Ausladen) | ✅ M4 |
| UI-/Widget-Tests kritischer Flows + Coverage-Gate | ✅ M1 |
| Lernzentriertes Redesign (Dashboard, Rollen, Piktogramme, Grundkatalog) | ✅ |
| Zentrale Gerätefotos (Sync-fähig) | ✅ M2 (Server verifiziert 15.07.; Feldtest iPhone→MacBook offen) |
| Produktiv-Betrieb (Cloud, Verteilung, Backups) | 🔨 M5 |
| Open Source | 🔨 M6 |

**Architektur-Lücke (geschlossen mit M2, 2026-07-15):** `EquipmentItems.imagePath` konnte auf
lokale Dateien des Admin-Geräts zeigen — tot auf Mitglieder-Geräten. Jetzt lädt das Admin-Gerät
Fotos komprimiert in den Storage-Bucket `equipment-images` (Marker `supabase://…` in
`imagePath`), Anzeige über `cached_network_image`, Offline-Precache nach jedem Pull.
Seit M2 gibt es außerdem ein eigenes App-Icon (Flamme auf Rot) statt des Flutter-Standards.

---

## M1 – Qualitätsfundament absichern (~3 Tage)

Ziel: Regressionsschutz für die Flows, deren Fehler Daten beschädigen, bevor neue Features
darauf aufbauen.

1. **Widget-Tests kritischer Flows** (`testWidgets` + in-memory DB):
   - Import-Wizard: Datei → Mapping → Abgleich → Anwenden (mit präparierter CSV in `test/fixtures/`)
   - Gerätewart: Instanz + Prüfung anlegen → Badge/Dashboard-Eintrag → „Erledigt“ → Fälligkeit springt
   - Sync-Settings: Login-Fehlerfall, Publish-Konflikt-Meldung
   - Raster-Editor: Kachel platzieren → Cutaway aktualisiert
2. **Coverage-Gate in CI:** `flutter test --coverage`, Schwellwert 65 % auf `lib/**/data|domain|core`
   (Logik-Schichten), Report als Artefakt. UI-Schicht ohne Schwellwert.
3. **Fehler-Sichtbarkeit:** zentrale `runZonedGuarded`/`FlutterError.onError`-Behandlung mit
   Logausgabe; optional Sentry (kostenloser Tier) — Entscheidung Marcus.
4. Kleinkram aus dem Bestand: Settings-Screen zeigt hartkodierte Bibliotheksversion
   („v1.0.0 – 257 Geräte“) → aus `metadata.json` lesen; tote „Nach Updates suchen“-Aktion entfernen.

**Verifikation:** CI grün mit Gate; mutwilliges Kaputtmachen einer Fälligkeitsberechnung
lässt die Pipeline scheitern.

## M2 – Zentrale Gerätefotos (~4 Tage)

Ziel: Fotos entstehen beim Admin (Kamera/Datei), landen zentral und erscheinen auf allen Geräten.
Löst die Architektur-Lücke und ist Voraussetzung für die Foto-Vervollständigung (245 Geräte ohne Bild).

1. **Supabase Storage Bucket `equipment-images`** (RLS: authenticated read, Upload nur Admin),
   SQL-Migration + Policies.
2. **Upload-Pfad:** Beim Speichern eines Geräts mit lokalem Bild lädt das Admin-Gerät das Bild
   (skaliert, WebP/JPEG ≤ 300 KB) in den Bucket; `imagePath` wird zur Storage-URL.
3. **Anzeige-Pfad:** `resolveImage()` erweitert — Asset-Pfad → Bundle, `http(s)` → `cached_network_image`
   (offline-Cache!), lokaler Pfad → File. Fallback bleibt Platzhalter.
4. **Offline-Garantie für den Einsatz:** Beim Pull werden alle Storage-Bilder vorab in den lokalen
   Cache geladen (Größenbudget, Fortschrittsanzeige in Settings).
5. **Foto-Workflow für die Content-Arbeit:** Im Gerätedetail „Foto aufnehmen“-Button (Kamera auf
   Mobilgerät) → direkt hochladen → veröffentlichen. Damit können die 245 fehlenden Fotos
   nach und nach beim Gerätehaus-Rundgang entstehen.

**Verifikation:** E2E-Test gegen lokalen Stack (Upload → Pull auf zweitem Client → Bild im Cache);
manuell: Foto am iPhone aufnehmen → erscheint auf dem MacBook.

## M3 – Inventurassistent (~4 Tage)

Ziel: Fahrzeug Fach für Fach durchgehen, Soll/Ist abhaken, Fehlbestände dokumentiert.

1. **Datenmodell (Schema v3):** `InventorySessions (id, vehicleId, startedAt, finishedAt, doneBy)` und
   `InventoryChecks (id, sessionId, assignmentId-Snapshot: equipmentId+compartmentId+sollMenge,
   istMenge, status ok|fehlt|beschädigt|falschesFach, note)`. Snapshot statt FK auf Assignments,
   damit Historie Re-Importe überlebt (gleiche Lehre wie bei Prüfungen). Migrationstest.
2. **Ablauf-UI:** Fahrzeug wählen → Cutaway zeigt Fortschritt pro Fach (offen/fertig) → Fach öffnen →
   Geräteliste mit Foto, Soll-Menge, große Touch-Ziele: „✓ vollständig“ / Menge korrigieren /
   Mangel + Notiz. Session unterbrechbar (Zwischenstand persistiert).
3. **Abschluss-Report:** Zusammenfassung (Fehlbestände, Mängel) als Screen + **PDF/CSV-Export**
   (Share-Sheet) für die Dokumentationspflicht. Mängel optional direkt als Instanz-Notiz übernehmen.
4. **Sync:** Sessions sind Teil des publizierten Datenbestands (Tabellen spiegeln wie gehabt) —
   Inventur ist Gerätewart-/Admin-Tätigkeit, Single-Writer bleibt unangetastet.

**Verifikation:** Unit-Tests Report-Aggregation; Widget-Test Abhak-Flow; manuell eine
AB-G-Teilinventur inkl. Export.

## M4 – Einsatzassistent: virtuelles Ausladen (~4 Tage)

Ziel: Im Einsatz zählt Sekunden-Auffindbarkeit — Bilder statt Listen, Entnahme-Tracking.

1. **Einstieg:** „Einsatz starten“ → Fahrzeug(e) + Einsatzart (DeploymentScenario) wählen →
   relevante Geräte werden priorisiert hervorgehoben (Szenario-Matching existiert im Datenmodell).
2. **Ausladen-Ansicht:** Cutaway als Navigationsfläche; Fach → Foto-Grid der Geräte (große Bilder,
   Mengen). Tap = „entnommen“ (Gerät wird markiert, Zähler). Entnommen-Liste als eigene Ansicht —
   beim Aufräumen sieht man, was zurück muss.
3. **Einsatz-Modus-Ergonomie:** Bildschirm-Wachhalten (wakelock), große Kontraste, funktioniert
   zu 100 % offline (nur lokale Daten, keine Sync-Aufrufe).
4. **Einsatz-Log lokal** (Start/Ende, entnommene Geräte) — bewusst NICHT synchronisiert (kein
   Einsatzdokumentationssystem, keine Datenschutz-Grauzone); Export als Text möglich.
5. Ersetzt den bisherigen „Einsatzplanung“-Spielmodus bzw. verschiebt ihn ins Training-Menü.

**Verifikation:** Widget-Test Entnahme-Flow; Feldtest: Flugmodus an, kompletten Ablauf durchspielen.

## M5 – Produktiv-Rollout (~3 Tage + Wartefristen)

Ziel: Die Wehr arbeitet mit der App.

1. **Server-Umgebung: ✅ erledigt durch Self-Hosting (2026-07-14, siehe [SERVER-SETUP.md](SERVER-SETUP.md)).**
   Supabase läuft self-hosted auf VM 104 im Heimnetz (nur LAN/WireGuard, keine Portfreigabe);
   tägliche pg_dump-Backups mit geprobter Restore-Prozedur sind eingerichtet. Der ursprüngliche
   Plan (supabase.com Frankfurt + Keep-Alive + GitHub-Actions-Backup) ist damit überholt.
   Noch offen aus diesem Block:
   - Accounts: individuelle Admin-Accounts (Marcus + Stellvertreter), EIN geteilter
     Mitglieder-Account pro Abteilung (Zugangszettel im Gerätehaus). `profiles.role` per SQL setzen.
     (`admin@fw.local` / `member@fw.local` existieren als Startpunkt.)
   - vzdump: ✅ eigener wöchentlicher Host-Backup-Job für die Sync-VM (2026-07-16).
     Optional bleibt `--onboot 1`.
2. **Erst-Datenbestand:** echte Beladelisten aller Fahrzeuge per Import-Wizard einlesen,
   Raster der Fahrzeuge anordnen, Prüftermine der prüfpflichtigen Geräte erfassen, veröffentlichen.
3. **App-Verteilung:**
   - **Android: ✅ erledigt (2026-07-16).** Release-Pipeline
     ([release.yml](../.github/workflows/release.yml)): Push auf `main` mit neuer
     `pubspec.yaml`-Version erzeugt automatisch Git-Tag `vX.Y.Z` + GitHub-Release mit
     signiertem, vorkonfiguriertem APK (`fwapp-vX.Y.Z.apk`) — direkt herunterladbar
     (Download-Link/QR im Gerätehaus). Signatur über festen Release-Keystore
     (Ablage/Secrets siehe private Notizen); PRs ohne Version-Bump lösen bewusst
     kein Release aus. Play Store optional später.
   - **iOS: ✅ Zwischenlösung Web-App (2026-07-17, Entscheidung Marcus — kein Apple-Account
     nötig):** Flutter-Web-Build als nginx-Container auf dem eigenen Server, `http://…:8080`
     im LAN/WireGuard, „Zum Home-Bildschirm“ in Safari; Deploy per `tool/deploy_web.sh`
     (siehe [SERVER-SETUP.md](SERVER-SETUP.md)). Einschränkung: braucht Serververbindung
     beim Öffnen (kein Offline-Start ohne HTTPS). Falls später echtes iOS-Offline gewünscht:
     Apple Developer Program (99 €/Jahr) → TestFlight, oder Domain + HTTPS für eine volle PWA.
   - **macOS (Admin-Gerät):** lokaler Build reicht für Marcus; für weitere Macs Developer-ID +
     Notarisierung (gleiche Apple-Mitgliedschaft).
   - **Web (Admin im Browser):** `build/web` auf Netlify/Vercel (kostenlos) oder nur lokal starten.
4. **Betriebs-Doku: ✅ erledigt (2026-07-16, [BETRIEB.md](BETRIEB.md)):** Onboarding-Zettel-Vorlage,
   Admin-Handbuch (Import, Prüftermine, Fotos, Inventur, Veröffentlichen), Troubleshooting-Tabelle.
5. **Datenschutz: ✅ dokumentiert in [BETRIEB.md](BETRIEB.md)** (Datensparsamkeits-Konzept,
   Freitextfelder, Betroffenenrechte). Noch offen: Freitext-Konvention („Erledigt von“) im Verein
   abstimmen + kurzer Hinweistext in der App.

**Verifikation:** „Tag-1-Probe“: zwei fremde Geräte (1× Android, 1× iOS) onboarden, Pull,
Flugmodus-Nutzung, Admin ändert + veröffentlicht, Geräte aktualisieren. Backup einspielen geprobt.

## M6 – Open Source (~1 Tag)

1. Lizenz wählen (Empfehlung: MIT für maximale Nachnutzung durch andere Wehren; GPL-3.0, falls
   Verbesserungen verpflichtend offen bleiben sollen) → Entscheidung Marcus.
2. **Echte Wehr-Daten: ✅ aus dem Arbeitsstand entfernt (2026-07-16, Entscheidung Marcus):**
   AB-G-Datensatz, Original-Beladelisten (xlsx/csv) und heruntergeladene Fremdbilder ersetzt
   durch fiktives Demo-HLF 20 (108 Positionen aus dem Normkatalog) + Beispiel-Beladelisten
   in `examples/beladelisten/`. **Noch offen:** Die Originale liegen weiter in der
   Git-Historie — falls auch das raus soll: `git filter-repo` + Force-Push (Entscheidung
   Marcus, bricht bestehende Clones).
3. **README + CONTRIBUTING: ✅ erledigt (2026-07-16):** Außen-README (Architekturüberblick,
   Setup inkl. lokaler Supabase-Stack, Release-Download) und CONTRIBUTING.md (Workflow,
   Codegen-Regel, Architektur-Leitplanken). Screenshots noch offen (brauchen echten Datenbestand).
4. **Repo public + CI-Badge: ✅** (public seit 2026-07-15, Badges im README seit 2026-07-16).

---

## Reihenfolge & Abhängigkeiten

```text
M1 Qualität ──► M2 Fotos ──► M3 Inventur ──► M4 Einsatz ──► M5 Rollout ──► M6 Open Source
   (Fundament)  (braucht      (nutzt Fotos)  (nutzt Fotos)   (braucht M2,     (nach Rollout-
                 Storage)                                     sinnvoll M3/M4)  Erfahrung)
```

- M3 und M4 sind untereinander unabhängig und können getauscht werden.
- Ein **Rollout-Pilot** (M5 nur Schritte 1–2, ohne App-Store-Verteilung) kann direkt nach M2
  starten: Marcus als Admin produktiv, 2–3 Testkameraden per Android-APK. Empfohlen!
- Gesamtaufwand: ~19 Arbeitstage plus Apple-Wartefristen.

## Bewusst NICHT im Plan

- 3D-Fahrzeugmodelle (Entscheidung: 2D-Schnittdarstellung)
- Multi-Tenant / mehrere Abteilungen in einer Instanz (Ausweg `department_id` existiert im Design)
- Mitglieder-Schreibrechte / Konfliktauflösung (Single-Writer bleibt)
- Einsatzdokumentation im rechtlichen Sinn (nur lokales Entnahme-Log)
- KI-gestützter PDF-Import (erst wenn reale unstrukturierte Listen den Wizard überfordern)
