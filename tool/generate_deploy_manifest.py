#!/usr/bin/env python3
"""generate_deploy_manifest.py – erzeugt deploy/manifest.json (Issue #74).

Warum es das Manifest gibt: Der Autodeploy auf der VM erreicht GitHub nur
über raw.githubusercontent.com (IPv6) — und raw liefert ausschließlich
einzelne Dateien, kein Verzeichnis-Listing. Das Manifest IST das Listing:
sortierte Migrationsliste und alle Edge-Function-Dateien, jeweils mit
SHA-256, damit die VM jeden Download verifizieren kann.

Aufruf:
  python3 tool/generate_deploy_manifest.py           # schreibt deploy/manifest.json
  python3 tool/generate_deploy_manifest.py --check   # CI-Guard: Drift = Fehler

Der --check-Modus folgt dem Drift-Guard-Muster des Repos (Codegen,
Manifest ↔ Assets): Alles, was aus etwas anderem erzeugt wird, wird in CI
gegen seine Quelle geprüft — ein vergessenes Manifest hieße sonst, dass
der Autodeploy neue Migrationen schlicht nie sieht.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MIGRATIONS = REPO / "supabase" / "migrations"
FUNCTIONS = REPO / "supabase" / "functions"
MANIFEST = REPO / "deploy" / "manifest.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build() -> dict:
    migrations = [
        {"name": p.name, "sha256": sha256(p)}
        # Sortierung = Einspiel-Reihenfolge (Zeitstempel-Präfix).
        for p in sorted(MIGRATIONS.glob("*.sql"))
    ]
    functions = {
        # Pfad relativ zu supabase/functions/, mit / auch unter Windows.
        p.relative_to(FUNCTIONS).as_posix(): sha256(p)
        for p in sorted(FUNCTIONS.rglob("*"))
        if p.is_file() and not p.name.endswith(".orig")
    }
    return {
        "comment": "Generiert von tool/generate_deploy_manifest.py — nicht "
                   "von Hand pflegen. Gelesen von tool/vm/fwapp_autodeploy.sh "
                   "über raw.githubusercontent.com (Issue #74, Route A).",
        "migrations": migrations,
        "functions": functions,
    }


def main() -> int:
    manifest = build()
    rendered = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"

    if "--check" in sys.argv:
        if not MANIFEST.exists():
            print("FEHLER: deploy/manifest.json fehlt. "
                  "python3 tool/generate_deploy_manifest.py ausführen.")
            return 1
        if MANIFEST.read_text() != rendered:
            print("FEHLER: deploy/manifest.json ist nicht aktuell — "
                  "Migrationen oder Functions haben sich geändert.")
            print("Beheben: python3 tool/generate_deploy_manifest.py && "
                  "Ergebnis committen.")
            return 1
        print(f"OK: Manifest aktuell ({len(manifest['migrations'])} "
              f"Migrationen, {len(manifest['functions'])} Function-Dateien).")
        return 0

    MANIFEST.parent.mkdir(exist_ok=True)
    MANIFEST.write_text(rendered)
    print(f"Geschrieben: {MANIFEST.relative_to(REPO)} "
          f"({len(manifest['migrations'])} Migrationen, "
          f"{len(manifest['functions'])} Function-Dateien).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
