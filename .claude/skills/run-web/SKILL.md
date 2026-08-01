---
name: run-web
description: FWApp als Web-App lokal starten und mit Playwright durchklicken, um eine Änderung in der echten App zu sehen. Nutzen, wenn die App gestartet, bedient oder per Screenshot geprüft werden soll — oder wenn zu prüfen ist, ob etwas wirklich funktioniert und nicht nur der Test grün ist.
---

# FWApp im Browser bedienen

Die Playwright-Technik für Flutter-Web (Semantics-Baum wecken, Klicken über
Koordinaten, Dateidialoge) steht im Benutzer-Skill **`flutter-run-web`** —
sie gilt unverändert und wird hier **nicht wiederholt**. Dieses Dokument
beschreibt nur, was an FWApp anders ist als an den übrigen Apps.

> **Warum überhaupt im Browser klicken?** Weil grüne Tests nicht dasselbe
> sind wie eine funktionierende App. Der Dialog-Absturz in v1.6.0 war
> hierfür der Beleg: Der Widget-Test war grün, weil sein Prüfstand einen
> flachen Navigator hatte — die echte App hat einen verschachtelten
> (ShellRoute), und dort riss derselbe Code den Screen weg. Ein einziger
> Durchklick hätte das gezeigt.

## 1. FWApp hat keinen Demo-Modus

MitFahrBar startet ohne Backend mit erfundenen Daten — **FWApp nicht.** Ohne
Server-Vorbelegung bleiben URL und Key leer, und die App verlangt sie in den
Einstellungen. Es gibt genau zwei sinnvolle Ziele:

**a) Lokaler Supabase-Stack** — der Normalfall, weil er echtes Auth, echte
RLS und einen Mail-Fänger mitbringt:

```bash
supabase start                          # im Repo-Wurzelverzeichnis
bash tool/setup_local_supabase.sh       # legt admin@/geraetewart@/member@fw.local an, pw test1234
```

Der Build zeigt dorthin (Demo-Keys, in jedem lokalen Stack identisch —
kein Geheimnis, sie stehen so auch in `tool/setup_local_supabase.sh`):

```bash
export PATH="$(git rev-parse --show-toplevel)/../SDK/flutter/bin:$PATH"
flutter build web \
  --dart-define=FWAPP_SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=FWAPP_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
```

**b) Der eigene Server** — nur wenn der Testfall echte Bestandsdaten
braucht: `flutter build web --dart-define-from-file=config/fwapp.local.json`.
⚠️ Das ist **die Produktion der Wehr**. Lesen ja, Schreiben nur mit
ausdrücklicher Absprache; für Schreib-Abläufe gehört der lokale Stack her.

Ausliefern und bedienen dann wie im Benutzer-Skill beschrieben
(`cd build/web && python3 -m http.server 8731`).

## 2. Mails ansehen: Mailpit statt Postfach

Der lokale Stack fängt jede Mail ab — GoTrue schickt sie nirgendwohin.
Sichtbar unter **<http://127.0.0.1:54324>** (`[local_smtp] port` in
`supabase/config.toml`). Das ist der Weg, um Einladung, Bestätigung und
**Passwort-Reset** (Issue #57 Phase 4) wirklich zu prüfen: Mail auslösen,
in Mailpit den Link kopieren, im Browser öffnen, den Reset zu Ende gehen.

Der produktive Weg läuft dagegen über die Brücke auf der VM
(`docs/SERVER-SETUP.md` → Mail-Brücke) — der ist **nicht** Teil dieses
Skills und wird nicht zum Testen benutzt: Jede dort ausgelöste Mail geht an
eine echte Adresse.

## 3. Was der Browser bei FWApp nicht zeigt

Ein grüner Durchklick im Browser ist kein Freibrief für ein Release — diese
Wege existieren dort schlicht nicht:

- **In-App-Update und Mindestversions-Gate** (`ota_update`, APK-Installation)
  — nur auf einem Android-Gerät prüfbar; Checkliste in `docs/BETRIEB.md`.
- **Kamera und Gerätefotos** — der Web-Pfad ist ein anderer als auf dem
  Gerät; genau dort saßen die v1.6.0-Abstürze.
- **Offline-Betrieb mit lokaler Datenbank** — Drift läuft im Browser über
  IndexedDB statt SQLite; Sync-Eigenheiten des Geräts bildet das nicht ab.

## 4. Zum Schluss

Server beenden, und weil FWApp-Builds Konfiguration über die Kommandozeile
bekommen (nie über geänderte Dateien), muss das Arbeitsverzeichnis danach
sauber sein:

```bash
git status --short
```
