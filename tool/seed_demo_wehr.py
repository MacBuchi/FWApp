#!/usr/bin/env python3
"""seed_demo_wehr.py – Legt die fiktive Gesamtwehr „Feuerwehr Freiwilligen"
auf einem Supabase-Stand an (Issue #158): zwei Abteilungen, vier Konten (je
eine Rolle) und den Bestand aus den gebündelten Fahrzeug-Vorlagen.

    export SUPABASE_URL=http://127.0.0.1:54321      # oder der Prod-Endpunkt
    export SUPABASE_SERVICE_ROLE_KEY=…              # lokal vorbelegt
    export FWAPP_DEMO_PASSWORD=…                    # Pflicht außerhalb localhost
    python3 tool/seed_demo_wehr.py

**Wiederholbar, nicht einmalig.** Ein zweiter Lauf legt nichts doppelt an:
Gesamtwehr, Abteilungen und Konten werden über Slug bzw. Adresse gefunden,
und der Bestand geht über `publish_snapshot` — dieselbe RPC, die auch die App
beim Veröffentlichen ruft, und die den Bestand der Abteilung vollständig
ERSETZT. Das ist keine Bequemlichkeit, sondern die Bauart: Auf dem lokalen
Stack löscht `sync_e2e_test` zwischen seinen Tests ALLE Gesamtwehren
(AGENTS.md) — eine von Hand geklickte Demo wäre nach einem Testlauf weg.

⚠️ **Reihenfolge Abteilung → Konten ist unumstößlich.** `handle_new_user()`
steckt jedes neue Konto ohne `abteilung_id` in den Signup-Metadaten in die
`legacy_mirror`-Abteilung — auf dem Produktivserver ist das die ECHTE Wehr.
Deshalb entstehen hier zuerst die Demo-Abteilungen, und die ID geht beim
Anlegen mit; ohne sie bricht das Skript ab, statt zu raten.

⚠️ **Zugangsdaten stehen nicht im Repo.** Das Passwort kommt aus der Umgebung
und gehört nach `docs/private/` (docs/BETRIEB.md). Gegen einen Nicht-Localhost
läuft das Skript ohne gesetztes Passwort gar nicht erst los.
"""
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from demo_wehr import (ABTEILUNGEN, FAHRZEUGE, GESAMTWEHR_NAME,
                       GESAMTWEHR_SLUG, KONTEN)

REPO = Path(__file__).resolve().parent.parent

# Der öffentlich bekannte Demo-Schlüssel des lokalen Stacks — auf jeder
# Maschine derselbe, wie in tool/setup_local_supabase.sh.
LOKAL_URL = "http://127.0.0.1:54321"
LOKAL_SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9s"
    "ZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0."
    "EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
)
LOKAL_PASSWORT = "test1234"

KATALOG = REPO / "assets/equipment_library/catalog/standard_catalog.json"
VORLAGEN = REPO / "assets/vehicle_templates"
# Spiegelt kPictogramDir aus lib/core/utils/image_utils.dart: ein Asset-Pfad,
# kein Gerätepfad — er muss auf jedem Gerät auflösbar bleiben.
PIKTOGRAMM_DIR = "assets/equipment_library/images/"

URL = os.environ.get("SUPABASE_URL", LOKAL_URL).rstrip("/")
KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", LOKAL_SERVICE_KEY)


# ── HTTP ─────────────────────────────────────────────────────────────────

def _request(method, pfad, body=None, headers=None):
    kopf = {
        "apikey": KEY,
        "Content-Type": "application/json",
        # Cloudflare (Bot-Fight-Mode) blockt den Default-UA von urllib mit
        # 403 — gleiche Begründung wie im Feedback-Bot.
        "User-Agent": "fwapp-demo-seed/1.0",
    }
    # Legacy-service_role-Keys sind JWTs und gehören zusätzlich in den
    # Authorization-Header; neue sb_secret_*-Keys nutzen nur apikey.
    if KEY.startswith("eyJ"):
        kopf["Authorization"] = f"Bearer {KEY}"
    kopf.update(headers or {})
    daten = json.dumps(body).encode() if body is not None else None
    anfrage = urllib.request.Request(URL + pfad, data=daten, headers=kopf,
                                     method=method)
    try:
        with urllib.request.urlopen(anfrage) as antwort:
            text = antwort.read().decode()
            return json.loads(text) if text.strip() else None
    except urllib.error.HTTPError as fehler:
        detail = fehler.read().decode(errors="replace")[:500]
        raise RuntimeError(
            f"{method} {pfad} → HTTP {fehler.code}: {detail}") from None


def rest(method, pfad, body=None, prefer=None, token=None):
    headers = {}
    if prefer:
        headers["Prefer"] = prefer
    if token:
        # PostgREST leitet die Rolle aus dem Authorization-Header ab; der
        # apikey bleibt der Service-Key, weil er nur das Gateway passiert.
        headers["Authorization"] = f"Bearer {token}"
    return _request(method, "/rest/v1" + pfad, body, headers)


def anmelden(email, passwort):
    """Meldet ein Konto an und liefert das Zugangs-Token."""
    antwort = _request("POST", "/auth/v1/token?grant_type=password",
                       {"email": email, "password": passwort})
    return antwort["access_token"]


# ── Schritt 1+2: Gesamtwehr und Abteilungen ──────────────────────────────

def gesamtwehr_anlegen():
    treffer = rest("GET", f"/gesamtwehren?slug=eq.{GESAMTWEHR_SLUG}"
                          "&select=id,name")
    if treffer:
        print(f"  Gesamtwehr vorhanden: {treffer[0]['name']}")
        return treffer[0]["id"]
    neu = rest("POST", "/gesamtwehren",
               {"name": GESAMTWEHR_NAME, "slug": GESAMTWEHR_SLUG},
               prefer="return=representation")
    print(f"  Gesamtwehr angelegt: {GESAMTWEHR_NAME}")
    return neu[0]["id"]


def abteilung_anlegen(gesamtwehr_id, slug, name):
    treffer = rest("GET", f"/abteilungen?slug=eq.{slug}"
                          "&select=id,name,status,legacy_mirror,gesamtwehr_id")
    if treffer:
        vorhanden = treffer[0]
        # Der teuerste denkbare Irrtum: Der Slug zeigt auf die Abteilung, die
        # den Alt-Client-Spiegel führt — auf Prod ist das die echte Wehr, und
        # publish_snapshot würde deren Bestand ersetzen.
        if vorhanden["legacy_mirror"]:
            sys.exit(f"ABBRUCH: Abteilung '{slug}' ist die legacy_mirror-"
                     "Abteilung (auf Prod die ECHTE Wehr). Hier wird nichts "
                     "überschrieben.")
        if vorhanden["gesamtwehr_id"] != gesamtwehr_id:
            sys.exit(f"ABBRUCH: Abteilung '{slug}' gehört zu einer anderen "
                     "Gesamtwehr.")
        print(f"  Abteilung vorhanden: {vorhanden['name']}")
        return vorhanden["id"]
    neu = rest("POST", "/abteilungen",
               {"gesamtwehr_id": gesamtwehr_id, "name": name, "slug": slug,
                # 'active', nicht 'pending': Eine Abteilung ohne Freigabe darf
                # lokal alles, aber nicht veröffentlichen — und genau das
                # macht dieses Skript im letzten Schritt.
                "status": "active", "legacy_mirror": False},
               prefer="return=representation")
    print(f"  Abteilung angelegt: {name}")
    return neu[0]["id"]


# ── Schritt 3: Konten ────────────────────────────────────────────────────

def benutzer_suchen(email):
    seite = 1
    while seite <= 20:
        antwort = _request("GET", f"/auth/v1/admin/users?per_page=200&page={seite}")
        nutzer = antwort.get("users", [])
        for u in nutzer:
            if (u.get("email") or "").lower() == email.lower():
                return u["id"]
        if len(nutzer) < 200:
            return None
        seite += 1
    return None


def konto_anlegen(konto, abteilung_id, passwort):
    """Legt das Konto an oder zieht ein vorhandenes auf den Sollstand."""
    if not abteilung_id:
        sys.exit("ABBRUCH: Keine Abteilungs-ID — ohne sie landet das Konto in "
                 "der legacy_mirror-Abteilung (auf Prod die echte Wehr).")
    rumpf = {
        "email": konto["email"],
        "password": passwort,
        "email_confirm": True,
        "user_metadata": {"abteilung_id": abteilung_id},
    }
    try:
        neu = _request("POST", "/auth/v1/admin/users", rumpf)
        print(f"  Konto angelegt: {konto['email']}")
        return neu["id"]
    except RuntimeError:
        # Schon vorhanden (GoTrue antwortet 422). Passwort und Metadaten
        # trotzdem nachziehen, damit ein zweiter Lauf einen bekannten Stand
        # herstellt statt einen halb geänderten.
        benutzer_id = benutzer_suchen(konto["email"])
        if not benutzer_id:
            raise
        _request("PUT", f"/auth/v1/admin/users/{benutzer_id}", rumpf)
        print(f"  Konto aktualisiert: {konto['email']}")
        return benutzer_id


def rollen_setzen(benutzer_id, konto, abteilung_id, gesamtwehr_id):
    rest("POST", "/memberships",
         {"user_id": benutzer_id, "abteilung_id": abteilung_id,
          "role": konto["rolle"]},
         prefer="resolution=merge-duplicates,return=minimal")
    if konto["feuerwehrkommandant"]:
        rest("POST", "/gesamtwehr_kommandanten",
             {"user_id": benutzer_id, "gesamtwehr_id": gesamtwehr_id},
             prefer="resolution=merge-duplicates,return=minimal")
    # Anzeigename direkt, nicht über mein_profil_setzen(): die RPC schreibt
    # ausschließlich auf auth.uid() — das ist ihre Absicherung, kein Umweg,
    # den man mit dem Service-Key nehmen sollte. Der Avatar bleibt leer; ihn
    # in der Vorführung selbst zu wählen ist ein eigener Vorführschritt.
    rest("PATCH", f"/profiles?id=eq.{benutzer_id}",
         {"anzeigename": konto["anzeigename"], "abteilung_id": abteilung_id},
         prefer="return=minimal")
    # Alt-Client-Spiegel (profiles.role) aus den Mitgliedschaften nachziehen.
    rest("POST", "/rpc/sync_profile_mirror", {"target": benutzer_id})


# ── Schritt 4: Bestand aus den Vorlagen ──────────────────────────────────

def jetzt():
    return datetime.now(timezone.utc).isoformat()


def katalog_laden():
    roh = json.loads(KATALOG.read_text(encoding="utf-8"))
    return roh["items"] if isinstance(roh, dict) else roh


def vorlage_laden(vorlagen_id):
    pfad = VORLAGEN / vorlagen_id / "template.json"
    return json.loads(pfad.read_text(encoding="utf-8"))


def bestand_bauen(fahrzeuge):
    """Baut die publish_snapshot-Payload — Spalte für Spalte wie die App.

    Spiegelt `VehicleTemplateService.apply(withLoading: true, withPlacement:
    true)`: Jede Beladungsposition nennt ihr Fach selbst, es gibt also nichts
    zu erfinden. Was kein Fach findet, landet — wie in der App — im Sammelfach
    statt seine Position zu verlieren.
    """
    zeitstempel = jetzt()
    katalog = katalog_laden()

    # Der ganze Standard-Katalog, nicht nur die belegten Positionen: So sieht
    # der Bestand aus, den ein frisch eingerichtetes Gerät veröffentlicht.
    geraete = []
    id_nach_katalog_id = {}
    for nummer, eintrag in enumerate(katalog, start=1):
        id_nach_katalog_id[eintrag["id"]] = nummer
        geraete.append({
            "id": nummer,
            "name": eintrag["name"],
            "short_name": eintrag.get("short_name"),
            "equipment_functions_json":
                json.dumps(eintrag.get("equipment_functions", [])),
            "deployment_scenarios_json": "[]",
            "description": eintrag.get("description", ""),
            "image_path": PIKTOGRAMM_DIR + eintrag["id"] + ".png",
            "training_url": None,
            "library_equipment_id": eintrag["id"],
            "is_custom": False,
            "extra_attributes_json": "{}",
            "training_questions_json":
                json.dumps(eintrag.get("training_questions", [])),
            "typical_use_json": json.dumps(eintrag.get("typical_use", [])),
            "updated_at": zeitstempel,
        })

    autos, faecher, zuordnungen = [], [], []
    fehlend = []
    for auto_nr, fahrzeug in enumerate(fahrzeuge, start=1):
        vorlage = vorlage_laden(fahrzeug["vorlage"])
        autos.append({
            "id": auto_nr,
            "name": fahrzeug["name"],
            "type": vorlage["type"],
            "license_plate": fahrzeug.get("kennzeichen"),
            "image_path": None,
            "created_at": zeitstempel,
            "updated_at": zeitstempel,
        })
        fach_id_nach_label = {}
        for fach in vorlage["compartments"]:
            fach_nr = len(faecher) + 1
            fach_id_nach_label[fach["label"]] = fach_nr
            faecher.append({
                "id": fach_nr,
                "vehicle_id": auto_nr,
                "label": fach["label"],
                "position": fach.get("position", 0),
                "grid_row": None,
                "grid_col": None,
                "grid_col_span": 1,
                "seite": fach.get("seite"),
                "laengsposition": fach.get("laengsposition"),
                "updated_at": zeitstempel,
            })

        beladung = (vorlage.get("loading") or {}).get("items", [])
        sammelfach_id = None
        for position in beladung:
            geraet_id = id_nach_katalog_id.get(position["equipment_id"])
            if geraet_id is None:
                fehlend.append(position["equipment_id"])
                continue
            ziel = fach_id_nach_label.get(position.get("compartment"))
            if ziel is None:
                if sammelfach_id is None:
                    sammelfach_id = len(faecher) + 1
                    faecher.append({
                        "id": sammelfach_id,
                        "vehicle_id": auto_nr,
                        "label": "Normbeladung (ungeprüft) – noch zuzuordnen",
                        "position": len(vorlage["compartments"]),
                        "grid_row": None, "grid_col": None,
                        "grid_col_span": 1,
                        "seite": None, "laengsposition": None,
                        "updated_at": zeitstempel,
                    })
                ziel = sammelfach_id
            zuordnungen.append({
                "id": len(zuordnungen) + 1,
                "compartment_id": ziel,
                "equipment_id": geraet_id,
                "quantity": position.get("quantity", 1),
                "updated_at": zeitstempel,
            })

    if fehlend:
        # Vorlage und Katalog sind auseinandergelaufen — das darf nicht still
        # bleiben, sonst entsteht ein Fahrzeug mit Löchern in der Beladung.
        sys.exit(f"ABBRUCH: {len(fehlend)} Positionen stehen in keiner "
                 f"Katalog-Zeile: {sorted(set(fehlend))[:5]}")

    return {
        "vehicles": autos,
        "equipment_items": geraete,
        "compartments": faecher,
        "equipment_assignments": zuordnungen,
        "equipment_instances": [],
        "inspection_schedules": [],
        "inspection_log": [],
    }


def app_version():
    """Die Version aus pubspec.yaml — der Server prüft daran sein Minimum."""
    for zeile in (REPO / "pubspec.yaml").read_text(encoding="utf-8").splitlines():
        if zeile.startswith("version:"):
            return zeile.split(":", 1)[1].strip().split("+")[0]
    return None


def bestand_veroeffentlichen(abteilung_id, fahrzeuge, token):
    stand = rest("GET", f"/abteilungen?id=eq.{abteilung_id}&select=version")
    payload = bestand_bauen(fahrzeuge)
    neue_version = rest("POST", "/rpc/publish_snapshot", {
        "abteilung": abteilung_id,
        "expected_version": stand[0]["version"],
        "payload": payload,
        "client_version": app_version(),
    }, token=token)
    print(f"  Bestand veröffentlicht (Version {neue_version}): "
          f"{len(payload['vehicles'])} Fahrzeuge, "
          f"{len(payload['compartments'])} Fächer, "
          f"{len(payload['equipment_items'])} Geräte, "
          f"{len(payload['equipment_assignments'])} Zuordnungen")


# ── Ablauf ───────────────────────────────────────────────────────────────

def ist_lokal(url):
    wirt = urlparse(url).hostname or ""
    return wirt in ("127.0.0.1", "localhost", "::1", "0.0.0.0")


def main():
    lokal = ist_lokal(URL)
    passwort = os.environ.get("FWAPP_DEMO_PASSWORD") or (
        LOKAL_PASSWORT if lokal else "")
    if not passwort:
        sys.exit("ABBRUCH: FWAPP_DEMO_PASSWORD ist Pflicht, sobald das Ziel "
                 "nicht localhost ist. Das Passwort gehört nach docs/private/, "
                 "nicht ins Repo.")
    if not lokal and passwort == LOKAL_PASSWORT:
        sys.exit("ABBRUCH: Das lokale Testpasswort taugt nicht für einen "
                 "öffentlich erreichbaren Server.")

    print(f"Ziel: {URL}")
    gesamtwehr_id = gesamtwehr_anlegen()

    abteilung_ids = {}
    for abteilung in ABTEILUNGEN:
        abteilung_ids[abteilung["slug"]] = abteilung_anlegen(
            gesamtwehr_id, abteilung["slug"], abteilung["name"])

    kommandant_email = None
    for konto in KONTEN:
        abteilung_id = abteilung_ids[konto["abteilung"]]
        benutzer_id = konto_anlegen(konto, abteilung_id, passwort)
        rollen_setzen(benutzer_id, konto, abteilung_id, gesamtwehr_id)
        if konto["feuerwehrkommandant"]:
            kommandant_email = konto["email"]

    # Der Feuerwehrkommandant veröffentlicht in beiden Abteilungen: Genau das
    # erlaubt ihm can_publish_abteilung, und damit läuft der Bestand über den
    # echten Rechteweg statt am Service-Key vorbei in die Tabellen.
    token = anmelden(kommandant_email, passwort)
    for abteilung in ABTEILUNGEN:
        fahrzeuge = FAHRZEUGE.get(abteilung["slug"], [])
        if not fahrzeuge:
            continue
        print(f"  {abteilung['name']}:")
        bestand_veroeffentlichen(abteilung_ids[abteilung["slug"]], fahrzeuge,
                                 token)

    print(f"\nFertig. Gesamtwehr „{GESAMTWEHR_NAME}“ mit "
          f"{len(ABTEILUNGEN)} Abteilungen und {len(KONTEN)} Konten steht.")
    print("Anmeldung: " + ", ".join(k["email"] for k in KONTEN))


if __name__ == "__main__":
    main()
