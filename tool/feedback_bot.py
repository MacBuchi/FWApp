#!/usr/bin/env python3
"""Feedback-Bot der FWApp.

Liest unverarbeitete Zeilen aus der Supabase-Tabelle `feedback` (über das
öffentliche API-Gateway) und erzeugt für jede Meldung ein GitHub-Issue
(feature -> enhancement, bug -> bug); danach stempelt er processed_at.

Meldungen von Konten, die ausschliesslich zur Demo-Gesamtwehr gehoeren
(tool/demo_wehr.py, Issue #158), werden nur abgestempelt: Eine Vorfuehrung
soll den Dialog zeigen duerfen, ohne ein oeffentliches Issue zu erzeugen.

Benötigte Umgebung: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GH_TOKEN
(liefert der Workflow .github/workflows/feedback.yml).
"""
import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone

from demo_wehr import GESAMTWEHR_SLUG


# Meldungsart -> (Titel-Präfix, GitHub-Label). `katalog` ist der Vorschlag
# für den mitgelieferten Gerätekatalog (Issue #103), `fahrzeug` der für eine
# fehlende Fahrzeug-Vorlage (Issue #145); die Labels müssen im Repo
# existieren, sonst lehnt `gh issue create` den Aufruf ab.
KINDS = {
    "feature": ("Feature request: ", "enhancement"),
    "bug": ("Bug report: ", "bug"),
    "katalog": ("Katalog-Vorschlag: ", "katalog-vorschlag"),
    "fahrzeug": ("Fahrzeug-Vorschlag: ", "fahrzeug-vorschlag"),
}

# Bei diesen Arten trägt die ERSTE ZEILE den Namen und sonst nichts (siehe
# die Hinweise im Feedback-Dialog) — daraus wird die Issue-Überschrift.
FIRST_LINE_TITLE = ("katalog", "fahrzeug")


def run(*cmd: str) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        # Den echten Fehler im Workflow-Log sichtbar machen.
        print(f"::error::Command failed: {' '.join(cmd)}\n{result.stderr}",
              file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, cmd)
    return result.stdout.strip()


def issue_exists(title: str) -> bool:
    out = run("gh", "issue", "list", "--state", "all", "--limit", "100",
              "--search", title, "--json", "title")
    return any(item["title"] == title for item in json.loads(out or "[]"))


def api(method: str, path: str, body=None):
    url = os.environ["SUPABASE_URL"] + path
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    headers = {
        "apikey": key,
        "Content-Type": "application/json",
        # Cloudflare (Bot-Fight-Mode) blockt den Default-UA
        # "Python-urllib/3.x" mit 403 — eigener UA nötig.
        "User-Agent": "fwapp-feedback-bot/1.0",
    }
    # Legacy-service_role-Keys sind JWTs und gehören zusätzlich in den
    # Authorization-Header; neue sb_secret_*-Keys nutzen nur apikey.
    if key.startswith("eyJ"):
        headers["Authorization"] = f"Bearer {key}"
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, headers=headers,
                                     method=method)
    with urllib.request.urlopen(request) as response:
        text = response.read().decode()
        return json.loads(text) if text else None


def mark_processed(row_ids: list[str]) -> None:
    if not row_ids:
        return
    now = datetime.now(timezone.utc).isoformat()
    api("PATCH", f"/rest/v1/feedback?id=in.({','.join(row_ids)})",
        {"processed_at": now})


def demo_konten(user_ids: list[str]) -> set[str]:
    """Die Konten aus [user_ids], die ausschliesslich zur Demo-Wehr gehoeren.

    Der Feedback-Dialog bleibt in der Demo bedienbar — er soll ja vorfuehrbar
    sein —, aber eine Vorfuehrung darf kein oeffentliches Issue erzeugen
    (Issue #158). Gefiltert wird ueber die Mitgliedschaften, nicht ueber
    `profiles.abteilung_id`: Die Spalte ist nur der Alt-Client-Spiegel.

    ⚠️ Bewusst nur, wer NUR in der Demo-Wehr Mitglied ist. Wer sich zum
    Vorfuehren zusaetzlich in die Demo-Wehr setzt, soll sein echtes Feedback
    nicht verlieren — ein still verschlucktes Anliegen faellt niemandem auf.
    """
    if not user_ids:
        return set()
    gesamtwehr = api("GET", f"/rest/v1/gesamtwehren?slug=eq.{GESAMTWEHR_SLUG}"
                            "&select=id")
    if not gesamtwehr:
        return set()  # Keine Demo-Wehr eingerichtet — nichts zu filtern.
    demo_abteilungen = {
        row["id"] for row in api(
            "GET", f"/rest/v1/abteilungen?gesamtwehr_id=eq.{gesamtwehr[0]['id']}"
                   "&select=id")
    }
    if not demo_abteilungen:
        return set()
    liste = ",".join(user_ids)
    mitgliedschaften: dict[str, set[str]] = {}
    for row in api("GET", f"/rest/v1/memberships?user_id=in.({liste})"
                          "&select=user_id,abteilung_id"):
        mitgliedschaften.setdefault(row["user_id"], set()).add(
            row["abteilung_id"])
    return {uid for uid, abteilungen in mitgliedschaften.items()
            if abteilungen and abteilungen <= demo_abteilungen}


def main() -> None:
    rows = api(
        "GET",
        "/rest/v1/feedback?processed_at=is.null&order=created_at"
        "&select=id,type,message,user_name,created_at,user_id",
    )
    if not rows:
        print("No unprocessed feedback.")
        return

    aus_der_demo = demo_konten([row["user_id"] for row in rows])

    for row in rows:
        if row["user_id"] in aus_der_demo:
            # Abstempeln statt ueberspringen: Eine ungestempelte Zeile laege
            # bei jedem Lauf wieder oben auf dem Stapel.
            print(f"Skip (Demo-Wehr): {row['message'][:40]}")
            mark_processed([row["id"]])
            continue
        username = row.get("user_name") or "unbekannt"
        kind = row["type"]
        prefix, label = KINDS.get(kind, KINDS["feature"])
        # Bei den Vorschlägen (Katalog, Fahrzeug) trägt die ERSTE ZEILE den
        # Namen und sonst nichts — daraus wird die Überschrift. Bei Wunsch
        # und Fehler ist die ganze Meldung ein Fließtext, dort werden die
        # Zeilenumbrüche flachgeklopft.
        source = row["message"].strip()
        title = (source.split("\n", 1)[0] if kind in FIRST_LINE_TITLE
                 else source.replace("\n", " ")).strip()
        title = prefix + title[:60] + ("…" if len(title) > 60 else "")
        if issue_exists(title):
            print(f"Skip (issue already exists): {title}")
        else:
            # Jede Zeile zitieren: Ein Katalog-Vorschlag ist mehrzeilig, und
            # ein einzelnes ">" davor liest sich als eine Zeile plus Rest.
            quoted = "\n".join(
                f"> {line}" if line else ">" for line in source.splitlines())
            body = (
                f"{quoted}\n\n"
                f"Eingereicht in der App von **{username}** "
                f"am {row['created_at'][:10]}.\n\n"
                f"_Automatisch erstellt vom Feedback-Bot._"
            )
            run("gh", "issue", "create", "--title", title,
                "--body", body, "--label", label)
            print(f"Issue created [{label}]: {title}")
        # Jede Zeile sofort stempeln, damit ein späterer Abbruch nie
        # Duplikate erzeugt.
        mark_processed([row["id"]])

    print("Done.")


if __name__ == "__main__":
    main()
