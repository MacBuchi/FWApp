#!/usr/bin/env python3
"""Feedback-Bot der FWApp.

Liest unverarbeitete Zeilen aus der Supabase-Tabelle `feedback` (über das
öffentliche API-Gateway) und erzeugt für jede Meldung ein GitHub-Issue
(feature -> enhancement, bug -> bug); danach stempelt er processed_at.

Benötigte Umgebung: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GH_TOKEN
(liefert der Workflow .github/workflows/feedback.yml).
"""
import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone


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


def main() -> None:
    rows = api(
        "GET",
        "/rest/v1/feedback?processed_at=is.null&order=created_at"
        "&select=id,type,message,user_name,created_at",
    )
    if not rows:
        print("No unprocessed feedback.")
        return

    for row in rows:
        username = row.get("user_name") or "unbekannt"
        is_bug = row["type"] == "bug"
        prefix = "Bug report: " if is_bug else "Feature request: "
        label = "bug" if is_bug else "enhancement"
        title = row["message"].strip().replace("\n", " ")
        title = prefix + title[:60] + ("…" if len(title) > 60 else "")
        if issue_exists(title):
            print(f"Skip (issue already exists): {title}")
        else:
            body = (
                f"> {row['message']}\n\n"
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
