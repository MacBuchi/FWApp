#!/usr/bin/env python3
"""fwapp_buendel.py – Das Server-Bündel eines Release bauen (Issue #241).

    ./fwapp_buendel.py --version v1.64.0 --aus dist/

Packt alles, was `fwapp_install.py` außerhalb des Web-Bündels braucht, in
`fwapp-server-<version>.tar.gz` — in DERSELBEN Ordnerstruktur wie im Repo.
Der Installer findet Migrationen, Functions und die VM-Skripte relativ zu
sich selbst (`REPO = HIER.parent.parent`); ein Bündel mit anderem Aufbau
hieße zwei Wege, Pfade aufzulösen, und einer davon bliebe ungetestet.

Die Datei `VERSION` an der Wurzel sagt dem Installer, welchen Stand er
einrichtet; ohne sie (Lauf aus dem Repo) gilt „entwicklung".

Läuft in `release.yml`; `test_fwapp_install.py` baut ein Bündel und prüft,
dass jeder Pfad darin liegt, den der Installer anfasst.
"""
from __future__ import annotations

import argparse
import io
import sys
import tarfile
from pathlib import Path
from typing import Optional

HIER = Path(__file__).resolve().parent
REPO = HIER.parent.parent

# Aus tool/vm nur, was der Installer wiederverwendet — der Rest dort gehört
# zu UNSERER VM (Autodeploy, Mail-Brücke) und hat auf fremden Rechnern
# nichts verloren.
VM_DATEIEN = ("fwapp-web-nginx.conf", "fwapp_kopplung.sh", "fwapp_betreiber.sh")


def buendel_dateien(repo: Path) -> list[str]:
    """Die Pfade relativ zum Repo, sortiert."""
    pfade: list[Path] = []
    installer = repo / "tool/installer"
    for p in installer.rglob("*"):
        rel = p.relative_to(installer)
        if not p.is_file() or "__pycache__" in rel.parts:
            continue
        # Tests gehören ins Repo, eine echte fwapp.conf (Passwörter!) nie
        # in ein Bündel — nur die Vorlage.
        if p.name.startswith("test_") or p.name == "fwapp.conf":
            continue
        pfade.append(p)
    pfade += [repo / "tool/vm" / n for n in VM_DATEIEN]
    pfade += sorted((repo / "supabase/migrations").glob("*.sql"))
    pfade += [p for p in (repo / "supabase/functions").rglob("*") if p.is_file()]
    return sorted(str(p.relative_to(repo)) for p in pfade)


def baue(repo: Path, version: str, aus: Path) -> Path:
    aus.mkdir(parents=True, exist_ok=True)
    ziel = aus / f"fwapp-server-{version}.tar.gz"
    with tarfile.open(ziel, "w:gz") as tar:
        for rel in buendel_dateien(repo):
            quelle = repo / rel
            info = tar.gettarinfo(str(quelle), arcname=rel)
            # Keine Besitzer vom Build-Rechner mitschleppen.
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            with quelle.open("rb") as f:
                tar.addfile(info, f)
        daten = f"{version}\n".encode()
        info = tarfile.TarInfo("VERSION")
        info.size = len(daten)
        info.mode = 0o644
        tar.addfile(info, io.BytesIO(daten))
    return ziel


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Server-Bündel bauen (#241)")
    p.add_argument("--version", required=True, help="Tag des Release, z. B. v1.64.0")
    p.add_argument("--aus", default="dist")
    a = p.parse_args(argv)
    print(baue(REPO, a.version, Path(a.aus)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
