"""fwapp_sicherung.py – Vollständige Sicherung und Wiederherstellung eines
FWApp-Servers (Marcus, 2026-09-23: „bei jedem Update ein vollständiges
Backup, das automatisch eingespielt werden kann, falls etwas schiefgeht").

Wie andere selbst gehostete Pakete das machen, und was davon hier gilt:

- **Nextcloud AIO / Home Assistant:** Vor dem Update eine vollständige
  Sicherung, Container dafür angehalten, Wiederherstellung als ein Schritt.
  → Genau das Muster hier.
- **A/B-Partitionen (RAUC, Mender, Rugix):** tauschen das ganze
  Betriebssystem. Unsere Updates fassen das Betriebssystem nicht an — nur
  den Stack. Ein Abbild der ganzen Karte wäre groß, ließe sich im Betrieb
  nicht konsistent ziehen und sicherte vor allem, was sich nie ändert.
- **Dateisystem-Schnappschüsse (btrfs, ZFS, LVM):** schnell, aber nur mit
  einem Dateisystem, das der Installer nicht voraussetzen kann (Pi OS ist
  ext4), und Postgres auf Copy-on-Write gilt als Fehlerquelle.

**Was gesichert wird: alles, was ein Container beschreiben kann**, und
zwar bei ANGEHALTENEM Stack — eine Datei-Kopie einer laufenden Datenbank
ist keine. Die Liste kommt aus den Containern selbst (`docker inspect`),
nicht aus einer Aufzählung hier: Ein neuer Dienst mit eigenem Volume ist
damit automatisch dabei. Dazu die Dateien des Installers (`server/` mit den
Schlüsseln, `web/`, `kopplung/`) und die Liste der Images samt Digest.

⚠️ **Die erweiterten Dateiattribute müssen mit.** Storage legt den
Inhaltstyp jedes Fotos NICHT in der Datenbank ab, sondern als xattr an der
Datei. Ein tar ohne `--xattrs` stellt Fotos wieder her, die der Browser
nicht mehr als Bild erkennt. Das busybox-tar in den meisten Images kann das
nicht; GNU tar steckt im edge-runtime-Image, das auf jedem FWApp-Server
ohnehin liegt — kein zusätzliches Image, kein Werkzeug auf dem Rechner.

⚠️ **Wiederherstellen ersetzt den INHALT, nie das Verzeichnis** — derselbe
Grund wie in `Server._ersetze`: Ein Bind-Mount hängt am Verzeichnis selbst.

⚠️ **Der Helfer hängt die Daten per `--volumes-from` ein, nie über den
Pfad aus `docker inspect`.** Docker Desktop meldet dort `/host_mnt/…`, einen
Pfad, den es auf dem Rechner gar nicht gibt — die erste Fassung hielt die
Datenbank deshalb für eine Datei und übersprang sie STILL. Aufgefallen ist
es erst beim Zurückspielen im Nachweis. Seitdem gilt zusätzlich
`PFLICHT`: Fehlen Datenbank oder Fotos in einer Sicherung, gibt es keine.
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import tarfile
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

from fwapp_install import Abbruch, Server, lies_env

# Verzeichnisse, die der Installer schreibt und die Container nur lesen.
INSTALLER_ORDNER = ("server", "web", "kopplung")
SICHERUNGEN_BEHALTEN = 2
GNU_TAR = ["--xattrs", "--xattrs-include=*", "--numeric-owner"]
# Ohne diese beiden ist eine Sicherung keine: Datenbank und Fotos.
PFLICHT = ("/var/lib/postgresql/data", "/var/lib/storage")
# Exit-Code des Helfers für „das ist eine Datei, kein Verzeichnis".
KEIN_VERZEICHNIS = 3


@dataclass
class Ziel:
    """Ein Verzeichnis, das ein Container beschreiben kann."""

    name: str  # Dateiname der Sicherung
    container: str  # über ihn hängt der Helfer die Daten ein (--volumes-from)
    pfad: str  # Pfad im Container


# ── Reine Logik ───────────────────────────────────────────────────────────


def ziele_aus_inspect(container: list[dict]) -> list[Ziel]:
    """Aus `docker inspect` der Container: jedes beschreibbare Volume und
    jeder beschreibbare Bind-Mount, jede Quelle nur einmal. Nur lesend
    eingehängte Pfade (Konfiguration, Web-App) sichert der Installer-Teil.
    Ob ein Bind-Mount eine Datei ist, entscheidet erst der Helfer — nur er
    sieht, was der Container sieht."""
    ziele: dict[str, Ziel] = {}
    for c in container:
        cname = c.get("Name", "").lstrip("/")
        for m in c.get("Mounts", []):
            if not m.get("RW") or m.get("Type") not in ("volume", "bind"):
                continue
            quelle = m.get("Name") or m["Source"]
            if quelle in ziele:
                continue
            ziel_name = re.sub(r"[^A-Za-z0-9]+", "_", f"{cname}{m['Destination']}").strip("_")
            ziele[quelle] = Ziel(ziel_name, cname, m["Destination"])
    return sorted(ziele.values(), key=lambda z: z.name)


def fehlende_pflicht(ziele: list[Ziel]) -> list[str]:
    pfade = {z.pfad for z in ziele}
    return [p for p in PFLICHT if p not in pfade]


def helfer_image(compose_texte: list[str]) -> str:
    for text in compose_texte:
        m = re.search(r"^\s*image:\s*(\S*edge-runtime\S*)", text, re.M)
        if m:
            return m.group(1)
    raise Abbruch("Kein edge-runtime-Image in den Compose-Dateien — ohne GNU tar keine Sicherung.")


def platz_reicht(frei: int, bedarf: int) -> bool:
    """Die Sicherung plus Luft für Images und Postgres (1 GiB)."""
    return frei >= bedarf + 1024**3


def sha256(pfad: Path) -> str:
    h = hashlib.sha256()
    with pfad.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


# ── Mit Docker ────────────────────────────────────────────────────────────


class Sicherung:
    def __init__(self, server: Server):
        self.server = server
        self.data = server.data
        self.ordner = self.data / "sicherungen"

    def _docker(self, *args: str, eingabe: Optional[str] = None) -> str:
        return self.server.lauf(*self.server.docker, *args, eingabe=eingabe)

    def _compose_texte(self) -> list[str]:
        env = lies_env((self.server.server / ".env").read_text())
        return [
            (self.server.server / d).read_text()
            for d in env.get("COMPOSE_FILE", "docker-compose.yml").split(":")
            if (self.server.server / d).exists()
        ]

    def ziele(self) -> list[Ziel]:
        ids = self._docker("compose", "ps", "-a", "-q").split()
        if not ids:
            raise Abbruch("Keine Container gefunden — nichts zu sichern.")
        container = json.loads(self._docker("inspect", *ids))
        return ziele_aus_inspect(container)

    def _helfer(self, z: Ziel, helfer: str, skript: str, *extra: str,
                nur_lesen: bool = True) -> tuple[int, str]:
        return self.server.versuch(
            *self.server.docker, "run", "--rm", "--entrypoint", "sh",
            "--volumes-from", f"{z.container}{':ro' if nur_lesen else ''}", *extra,
            helfer, "-c", skript,
        )

    def _verzeichnisse(self, ziele: list[Ziel], helfer: str) -> tuple[list[Ziel], int]:
        """Die Ziele, die im Container Verzeichnisse sind, und ihre Größe."""
        bleiben, summe = [], 0
        for z in ziele:
            rc, aus = self._helfer(
                z, helfer, f'[ -d "{z.pfad}" ] || exit {KEIN_VERZEICHNIS}; du -sb "{z.pfad}"'
            )
            if rc == KEIN_VERZEICHNIS:
                continue
            if rc != 0:
                raise Abbruch(f"Größe von {z.pfad} ({z.container}) nicht lesbar: {aus.strip()}")
            m = re.search(rf"^(\d+)\s+{re.escape(z.pfad)}$", aus, re.M)
            if not m:
                raise Abbruch(f"Größe von {z.pfad} ({z.container}) nicht lesbar: {aus.strip()}")
            bleiben.append(z)
            summe += int(m.group(1))
        return bleiben, summe

    def _groesse_installer(self) -> int:
        summe = 0
        for name in INSTALLER_ORDNER:
            for p in (self.data / name).rglob("*"):
                if p.is_file():
                    summe += p.stat().st_size
        return summe

    def images(self) -> list[dict]:
        liste = []
        for text in self._compose_texte():
            for image in re.findall(r"^\s*image:\s*(\S+)", text, re.M):
                r = self.server.lauf(
                    *self.server.docker, "image", "inspect", "-f", "{{json .RepoDigests}}", image,
                    pruefen=False,
                )
                digests = json.loads(r) if r.strip().startswith("[") else []
                liste.append({"image": image, "digest": digests[0] if digests else ""})
        return liste

    def erstellen(self, anlass: str, version: str) -> Path:
        """Hält den Stack an, sichert, und lässt ihn ANGEHALTEN zurück — der
        Aufrufer entscheidet, womit es weitergeht (neuer Stand oder
        `starten()`)."""
        helfer = helfer_image(self._compose_texte())
        ziele, bedarf = self._verzeichnisse(self.ziele(), helfer)
        fehlt = fehlende_pflicht(ziele)
        if fehlt:
            raise Abbruch(f"Die Sicherung erfasst {', '.join(fehlt)} nicht — keine halbe Sicherung.")
        bedarf += self._groesse_installer()
        self.ordner.mkdir(exist_ok=True)
        frei = shutil.disk_usage(self.ordner).free
        if not platz_reicht(frei, bedarf):
            raise Abbruch(
                f"Zu wenig Platz für eine vollständige Sicherung: {bedarf // 2**20} MB "
                f"nötig, {frei // 2**20} MB frei. Kein Update ohne Sicherung."
            )
        stempel = time.strftime("%Y%m%d-%H%M%S")
        ziel_ordner = self.ordner / f"{stempel}-{anlass}"
        ziel_ordner.mkdir()
        images = self.images()
        self._docker("compose", "stop")
        try:
            for z in ziele:
                rc, aus = self._helfer(
                    z, helfer,
                    f'tar {" ".join(GNU_TAR)} -cpf "/sicherung/{z.name}.tar" -C "{z.pfad}" .',
                    "-v", f"{ziel_ordner}:/sicherung",
                )
                if rc != 0:
                    raise Abbruch(f"Sichern von {z.pfad} ({z.container}): {aus.strip()[-300:]}")
            for name in INSTALLER_ORDNER:
                with tarfile.open(ziel_ordner / f"installer_{name}.tar", "w") as tar:
                    tar.add(self.data / name, arcname=".")
        except Exception:
            shutil.rmtree(ziel_ordner, ignore_errors=True)
            raise
        manifest = {
            "version": version,
            "anlass": anlass,
            "erstellt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "helfer": helfer,
            "ziele": [asdict(z) for z in ziele],
            "images": images,
            "dateien": {p.name: sha256(p) for p in sorted(ziel_ordner.glob("*.tar"))},
        }
        (ziel_ordner / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        return ziel_ordner

    def starten(self) -> None:
        self._docker("compose", "up", "-d", "--remove-orphans")

    def liste(self) -> list[Path]:
        if not self.ordner.exists():
            return []
        return sorted(p for p in self.ordner.iterdir() if (p / "manifest.json").exists())

    def pruefen(self, ordner: Path) -> dict:
        """Integrität vor dem Einspielen: Eine halbe Sicherung über die Daten
        zu legen wäre schlimmer als gar keine."""
        manifest = json.loads((ordner / "manifest.json").read_text())
        for name, erwartet in manifest["dateien"].items():
            if not (ordner / name).exists() or sha256(ordner / name) != erwartet:
                raise Abbruch(f"Sicherung {ordner.name} beschädigt: {name}")
        return manifest

    def einspielen(self, ordner: Path) -> dict:
        """Stellt den Stand der Sicherung wieder her und startet ihn.

        Reihenfolge mit Grund: ERST die Dateien des Installers (damit
        `server/` wieder die alten Compose-Dateien und die alte .env trägt),
        DANN die Container nach dieser alten Beschreibung neu anlegen, ohne
        sie zu starten, und erst in DEREN Volumes die Daten zurückspielen —
        so landen sie genau dort, wo der alte Stand sie sucht, auch wenn der
        neue ein Volume anders genannt hätte."""
        manifest = self.pruefen(ordner)
        self._docker("compose", "stop")
        for name in INSTALLER_ORDNER:
            ziel = self.data / name
            ziel.mkdir(exist_ok=True)
            for alt in ziel.iterdir():
                shutil.rmtree(alt) if alt.is_dir() and not alt.is_symlink() else alt.unlink()
            with tarfile.open(ordner / f"installer_{name}.tar") as tar:
                tar.extractall(ziel, **({"filter": "tar"} if hasattr(tarfile, "tar_filter") else {}))
        # server/ ist jetzt der alte Stand — Compose-Dateien, .env, Images.
        self._docker("compose", "create", "--force-recreate", "--remove-orphans")
        helfer = manifest["helfer"]
        for z in (Ziel(**d) for d in manifest["ziele"]):
            rc, aus = self._helfer(
                z, helfer,
                f'find "{z.pfad}" -mindepth 1 -delete && '
                f'tar {" ".join(GNU_TAR)} -xpf "/sicherung/{z.name}.tar" -C "{z.pfad}"',
                "-v", f"{ordner}:/sicherung:ro", nur_lesen=False,
            )
            if rc != 0:
                raise Abbruch(f"Zurückspielen von {z.pfad} ({z.container}): {aus.strip()[-300:]}")
        self.starten()
        return manifest

    def aufraeumen(self, behalten: int = SICHERUNGEN_BEHALTEN) -> list[str]:
        """Löscht alte Sicherungen und gibt die Images zurück, die eine der
        verbliebenen noch braucht (die darf der Updater nicht löschen)."""
        alle = self.liste()
        for alt in alle[:-behalten] if behalten else alle:
            shutil.rmtree(alt, ignore_errors=True)
        noetig = []
        for s in self.liste():
            noetig += [i["image"] for i in json.loads((s / "manifest.json").read_text())["images"]]
        return noetig


def gesund(server: Server, sekunden: int = 180) -> Optional[str]:
    """Ist der Server wirklich benutzbar? None heißt ja, sonst der Grund.

    Geprüft wird von innen (aus dem Web-Container über das Docker-Netz):
    Von außen scheiterte es an einem Router ohne Hairpin-NAT, obwohl alles
    läuft. Die Kette ist die, die jede App-Anfrage nimmt:

    - Datenbank, Anmeldung und Storage melden sich gesund,
    - Kong → Anmeldung antwortet,
    - Kong → PostgREST → Datenbank: ein echter RPC (`installation_kontakt`,
      ohne Anmeldung aufrufbar) — beweist Schema-Cache und Migrationen,
    - Edge Functions antworten (nicht 502/503),
    - nginx liefert Web-App und Einrichtungs-Datei.
    """
    anon = lies_env((server.server / ".env").read_text()).get("ANON_KEY", "")
    kopf = ["--header", f"apikey: {anon}", "--header", f"Authorization: Bearer {anon}"]
    pruefungen = [
        ("Anmeldung", ["wget", "-qO-", *kopf, "http://supabase-kong:8000/auth/v1/health"]),
        ("Datenbank über die API", [
            "wget", "-qO-", *kopf, "--header", "Content-Type: application/json",
            "--post-data", "{}", "http://supabase-kong:8000/rest/v1/rpc/installation_kontakt",
        ]),
        ("Web-App", ["wget", "-qO-", "http://127.0.0.1/"]),
        ("Einrichtungs-Datei", ["wget", "-qO-", "http://127.0.0.1/.well-known/fwapp.json"]),
    ]
    ende = time.time() + sekunden
    grund = "noch nicht geprüft"
    while time.time() < ende:
        grund = _pruefe_einmal(server, pruefungen)
        if grund is None:
            return None
        time.sleep(5)
    return grund


def _pruefe_einmal(server: Server, pruefungen: list) -> Optional[str]:
    for c in ("supabase-db", "supabase-auth", "supabase-storage"):
        zustand = server.lauf(
            *server.docker, "inspect", "-f", "{{.State.Health.Status}}", c, pruefen=False
        ).strip()
        if zustand != "healthy":
            return f"{c}: {zustand or 'fehlt'}"
    for titel, befehl in pruefungen:
        rc, aus = server.versuch(*server.docker, "exec", "fwapp-web", *befehl)
        if rc != 0:
            return f"{titel}: {aus.strip()[-200:]}"
    # Functions ohne Anmeldung: 401 ist richtig, 502/503 heißt „Runtime tot".
    _, aus = server.versuch(
        *server.docker, "exec", "fwapp-web", "wget", "-S", "-O", "/dev/null",
        "http://supabase-kong:8000/functions/v1/admin-users",
    )
    if re.search(r"HTTP/\S+ 50[23]", aus) or "HTTP/" not in aus:
        return "Edge Functions"
    return None
