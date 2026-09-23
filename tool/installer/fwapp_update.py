#!/usr/bin/env python3
"""fwapp_update.py – Einen FWApp-Server auf das nächste Release bringen (#241).

    ./fwapp_update.py --conf /srv/fwapp/server/fwapp.conf           # ein Lauf
    ./fwapp_update.py --conf … --pruefen                              # nur nachsehen

Läuft jede Nacht per systemd-Timer (richtet der Installer ein). Marcus'
Entscheidungen vom 2026-09-23:

- **Kanal:** Standard ist jedes FREIGEGEBENE Release (`UPDATE_KANAL=stabil`),
  auf Wunsch auch Vorabversionen (`vorab`); `aus` schaltet ab. Unser eigener
  Server folgt dagegen `main` über den Autodeploy — er ist das Testfeld.
- **Automatisch nachts, mit Sicherung und Probelauf.** Scheitert etwas,
  bleibt der alte Stand, und der KreisDatenMeister bekommt eine Mail.

Ablauf, und was bei einem Fehler in welchem Schritt passiert:

    1. Release wählen (GitHub-API)       Netz weg → nächste Nacht
    2. Bündel laden, Prüfsummen          Netz weg / Summe falsch → nächste Nacht
    3. Images des Release ziehen          Netz weg → nächste Nacht
    ──── ab hier ist ein Fehler kein Zufall mehr: BLOCKIEREN + Mail ────
    4. Dump (Rückfallpunkt)
    5. Probelauf der neuen Migrationen in einer Wegwerf-Datenbank
    6. Installer des NEUEN Bündels laufen lassen (derselbe idempotente Weg
       wie beim Einrichten — zwei Wege, einen Server in einen Stand zu
       bringen, liefen auseinander). Scheitert er, läuft der Installer des
       ALTEN Bündels noch einmal (steht in installation.json) und holt
       Compose-Dateien, Images, Web-App und Functions zurück.

Bis Schritt 5 ist am laufenden Server nichts verändert. Nach Schritt 6
kann die Datenbank neuer sein als der zurückgeholte Stand, falls eine
Migration trotz Probelauf auf den echten Daten scheiterte — dafür liegt der
Dump aus Schritt 4 bereit, und die Mail nennt ihn. Blockiert heißt:
`DATA_DIR/update.blocked` liegt da, und jeder weitere Lauf tut nichts, bis
jemand sie löscht — lieber stehen bleiben, als dieselbe kaputte Migration
jede Nacht gegen die Daten der Wehr zu werfen. Das Muster stammt aus
`tool/vm/fwapp_autodeploy.sh`, der seit August auf unserem Server läuft.

Nur Python-Standardbibliothek. Die reine Logik steht in Funktionen ohne
Netz und Docker und wird von test_fwapp_update.py geprüft.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.error
import urllib.request
from email.message import EmailMessage
from pathlib import Path, PurePosixPath
from typing import Callable, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fwapp_check import _smtp_oeffnen, lies_conf  # noqa: E402
from fwapp_install import Abbruch, Server, lies_env, offene_migrationen  # noqa: E402

API = "https://api.github.com/repos/MacBuchi/FWApp"
USER_AGENT = "fwapp-update/1.0"
KANAELE = ("stabil", "vorab", "aus")
SICHERUNGEN_BEHALTEN = 7


# Wo es ihn gibt (ab 3.12, teils zurückportiert), zusätzlich zur eigenen
# Prüfung in sichere_mitglieder — ab 3.14 ist er ohnehin Standard.
TAR_FILTER = {"filter": "data"} if hasattr(tarfile, "data_filter") else {}


class Spaeter(Exception):
    """Vorübergehend (Netz, GitHub): nächste Nacht wieder versuchen."""


# ── Reine Logik ───────────────────────────────────────────────────────────


def version_tupel(tag: str) -> Optional[tuple[int, ...]]:
    """v1.64.0 → (1, 64, 0). Alles andere (etwa „entwicklung") → None."""
    m = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", tag.strip())
    return tuple(int(x) for x in m.groups()) if m else None


def asset_namen(tag: str) -> tuple[str, str, str]:
    return f"fwapp-server-{tag}.tar.gz", f"fwapp-web-{tag}.tar.gz", "SHA256SUMS"


def waehle_release(releases: list[dict], kanal: str, installiert: str) -> Optional[dict]:
    """Das neueste passende Release, wenn es neuer ist als der installierte
    Stand. Ohne Bündel-Anhänge kommt ein Release nicht in Frage — so sieht
    jedes Release vor #241 aus."""
    if kanal == "aus":
        return None
    kandidaten = []
    for r in releases:
        v = version_tupel(r.get("tag_name", ""))
        if v is None or r.get("draft"):
            continue
        if r.get("prerelease") and kanal != "vorab":
            continue
        namen = {a.get("name") for a in r.get("assets", [])}
        if not set(asset_namen(r["tag_name"])) <= namen:
            continue
        kandidaten.append((v, r))
    if not kandidaten:
        return None
    v, r = max(kandidaten, key=lambda k: k[0])
    jetzt = version_tupel(installiert)
    # Ein Stand aus dem Repo („entwicklung") geht auf das nächste Release.
    return r if jetzt is None or v > jetzt else None


def lies_summen(text: str) -> dict[str, str]:
    """Format von sha256sum: `<hash>  <name>` (ein Stern vor dem Namen im
    Binärmodus)."""
    summen = {}
    for zeile in text.splitlines():
        teile = zeile.split()
        if len(teile) == 2:
            summen[teile[1].lstrip("*")] = teile[0].lower()
    return summen


def sichere_mitglieder(tar: tarfile.TarFile) -> list[tarfile.TarInfo]:
    """⚠️ Ein Archiv aus dem Netz darf nichts außerhalb seines Ziels
    schreiben: keine absoluten Pfade, kein `..`, keine Verweise, keine
    Gerätedateien. Pi OS bringt Python 3.11 mit — `filter="data"` gibt es
    dort nicht zuverlässig, deshalb von Hand."""
    gut = []
    for m in tar.getmembers():
        pfad = PurePosixPath(m.name)
        if pfad.is_absolute() or ".." in pfad.parts:
            raise Abbruch(f"Unsicherer Pfad im Bündel: {m.name}")
        if not (m.isfile() or m.isdir()):
            raise Abbruch(f"Unerlaubter Eintrag im Bündel: {m.name}")
        gut.append(m)
    return gut


def images_aus_compose(texte: list[str]) -> list[str]:
    images: list[str] = []
    for text in texte:
        for image in re.findall(r"^\s*image:\s*(\S+)", text, re.M):
            if image not in images:
                images.append(image)
    return images


def aelteste(namen: list[str], behalten: int) -> list[str]:
    """Was weg kann: alles außer den `behalten` neuesten (Namen beginnen mit
    einem sortierbaren Zeitstempel)."""
    return sorted(namen)[:-behalten] if behalten else sorted(namen)


def fehler_mail(conf: dict[str, str], von: str, nach: str, schritt: str, text: str) -> EmailMessage:
    data = conf.get("DATA_DIR", "/srv/fwapp")
    m = EmailMessage()
    m["From"] = conf.get("MAIL_ABSENDER", "")
    m["To"] = conf.get("KDM_EMAIL", "")
    m["Subject"] = f"FWApp: Update auf {nach} gescheitert — Updates angehalten"
    # Vor dem Einspielen ist am laufenden Server nichts verändert; danach
    # sagt die Meldung selbst, ob der Rückweg geklappt hat.
    stand = (
        f"Der Server läuft unverändert weiter auf {von}. "
        if schritt != "Einspielen" else ""
    )
    m.set_content(
        f"Das nächtliche Update von {conf.get('NAME') or 'FWApp'} "
        f"({conf.get('DOMAIN', '')}) ist gescheitert.\n\n"
        f"Schritt: {schritt}\n"
        f"Meldung: {text}\n\n"
        f"{stand}Weitere Updates sind angehalten, "
        "damit derselbe Fehler nicht jede Nacht wiederkommt.\n\n"
        "Wenn die Ursache behoben ist:\n"
        f"  sudo rm {data}/update.blocked\n"
        f"  sudo python3 {data}/server/fwapp_update.py --conf {data}/server/fwapp.conf\n\n"
        f"Sicherungen der Datenbank: {data}/backups/\n"
        f"Protokoll: {data}/update.log\n"
    )
    return m


# ── Netz ──────────────────────────────────────────────────────────────────


def _holen(url: str, zeitlimit: int = 60) -> bytes:
    req = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=zeitlimit) as r:
            return r.read()
    except (urllib.error.URLError, OSError) as e:
        raise Spaeter(f"{url}: {e}") from e


# ── Der Lauf ──────────────────────────────────────────────────────────────


class Update:
    def __init__(self, conf: dict[str, str], holen: Callable[..., bytes] = _holen):
        self.conf = conf
        self.data = Path(conf["DATA_DIR"])
        self.server_dir = self.data / "server"
        self.holen = holen
        self.log_datei = self.data / "update.log"
        self.blockiert = self.data / "update.blocked"
        info_datei = self.server_dir / "installation.json"
        self.info = json.loads(info_datei.read_text()) if info_datei.exists() else {}
        self.installiert = self.info.get("version", "entwicklung")
        self.testmodus = bool(self.info.get("testmodus"))
        self.server = Server(conf, self.testmodus)

    def log(self, text: str) -> None:
        zeile = f"{time.strftime('%Y-%m-%d %H:%M:%S')} {text}"
        print(zeile, flush=True)
        with self.log_datei.open("a") as f:
            f.write(zeile + "\n")

    # 1
    def ziel(self) -> Optional[dict]:
        api = self.conf.get("UPDATE_API") or API
        releases = json.loads(self.holen(f"{api}/releases?per_page=30"))
        kanal = self.conf.get("UPDATE_KANAL") or "stabil"
        if kanal not in KANAELE:
            raise Abbruch(f"UPDATE_KANAL={kanal} — erlaubt: {', '.join(KANAELE)}")
        return waehle_release(releases, kanal, self.installiert)

    # 2
    def laden(self, release: dict) -> Path:
        tag = release["tag_name"]
        urls = {a["name"]: a["browser_download_url"] for a in release["assets"]}
        server_tar, web_tar, summen_name = asset_namen(tag)
        summen = lies_summen(self.holen(urls[summen_name]).decode())
        ziel = self.data / "releases" / tag
        if ziel.exists():
            shutil.rmtree(ziel)
        for name, unter in ((server_tar, "server"), (web_tar, "web")):
            daten = self.holen(urls[name], zeitlimit=600)
            ist = hashlib.sha256(daten).hexdigest()
            if summen.get(name) != ist:
                # GitHub liefert selten halbe Dateien — aber dann ist es
                # vorübergehend, kein Grund zum Blockieren.
                raise Spaeter(f"Prüfsumme von {name} passt nicht ({ist[:12]}…)")
            (ziel / unter).mkdir(parents=True)
            archiv = ziel / name
            archiv.write_bytes(daten)
            with tarfile.open(archiv) as tar:
                tar.extractall(ziel / unter, members=sichere_mitglieder(tar), **TAR_FILTER)
            archiv.unlink()
        if not (ziel / "web/index.html").exists():
            raise Abbruch(f"Web-Bündel von {tag} ohne index.html")
        if not (ziel / "server/tool/installer/fwapp_install.py").exists():
            raise Abbruch(f"Server-Bündel von {tag} ohne Installer")
        return ziel

    def _images(self, installer: Path) -> list[str]:
        env = lies_env((self.server_dir / ".env").read_text())
        dateien = env.get("COMPOSE_FILE", "docker-compose.yml").split(":")
        return images_aus_compose(
            [(installer / d).read_text() for d in dateien if (installer / d).exists()]
        )

    # 3
    def images_ziehen(self, installer: Path) -> list[str]:
        images = self._images(installer)
        for image in images:
            r = subprocess.run([*self.server.docker, "pull", "-q", image],
                               capture_output=True, text=True)
            if r.returncode != 0:
                raise Spaeter(f"docker pull {image}: {r.stderr.strip()}")
        return images

    # 4
    def sichern(self, tag: str) -> Path:
        ordner = self.data / "backups"
        ordner.mkdir(exist_ok=True)
        dump = ordner / f"{time.strftime('%Y%m%d-%H%M%S')}-vor-{tag}.dump"
        with dump.open("wb") as f:
            r = subprocess.run(
                [*self.server.docker, "exec", "supabase-db",
                 "pg_dump", "-U", "supabase_admin", "-d", "postgres", "-Fc"],
                stdout=f, stderr=subprocess.PIPE,
            )
        if r.returncode != 0:
            raise Abbruch(f"pg_dump: {r.stderr.decode().strip()}")
        for alt in aelteste([p.name for p in ordner.glob("*.dump")], SICHERUNGEN_BEHALTEN):
            (ordner / alt).unlink()
        return dump

    # 5
    def probelauf(self, migrationen: Path, dump: Path) -> int:
        """Die neuen Migrationen gegen eine Kopie der echten Daten — in einer
        Wegwerf-Datenbank im selben Cluster, wo Rollen und Erweiterungen
        schon existieren. Wie im Autodeploy (fwapp_autodeploy.sh)."""
        angewandt = set(self.server.psql("select name from deploy.applied_migrations;").split())
        offen = offene_migrationen([p.name for p in migrationen.glob("*.sql")], angewandt)
        if not offen:
            return 0
        probe = f"update_probe_{int(time.time())}"
        self.server.psql(f"create database {probe};")
        try:
            self._psql_in(probe, "create schema if not exists auth;"
                                 "create schema if not exists extensions;"
                                 "create schema if not exists storage;")
            # Meldungen zu Besitzern und Event-Triggern sind beim Restore in
            # eine zweite Datenbank normal — deshalb ohne Rückgabeprüfung.
            with dump.open("rb") as f:
                subprocess.run(
                    [*self.server.docker, "exec", "-i", "supabase-db", "pg_restore",
                     "-U", "supabase_admin", "-d", probe, "--no-owner"],
                    stdin=f, capture_output=True,
                )
            for name in offen:
                try:
                    self._psql_in(probe, (migrationen / name).read_text())
                except Abbruch as e:
                    raise Abbruch(f"Probelauf von {name} gescheitert — NICHT eingespielt: {e}") from e
                self.log(f"Probelauf ok: {name}")
        finally:
            self.server.psql(f"drop database if exists {probe} with (force);")
        return len(offen)

    def _psql_in(self, db: str, sql: str) -> None:
        self.server.lauf(
            *self.server.docker, "exec", "-i", "supabase-db", "psql", "-U", "supabase_admin",
            "-d", db, "-v", "ON_ERROR_STOP=1", "-q", eingabe=sql,
        )

    # 6
    def _installer(self, buendel: Path, web: Path, conf_pfad: Path) -> Optional[str]:
        """Lässt den Installer eines Bündels laufen; None heißt: geklappt,
        sonst seine letzte Meldung."""
        befehl = [
            sys.executable, str(buendel / "tool/installer/fwapp_install.py"),
            "--conf", str(conf_pfad), "--web", str(web), "--ohne-pruefung",
        ]
        if self.testmodus:
            befehl.append("--testmodus")
        r = subprocess.run(befehl, capture_output=True, text=True)
        with self.log_datei.open("a") as f:
            f.write(r.stdout + r.stderr)
        if r.returncode == 0:
            return None
        return ([z for z in r.stdout.splitlines() if z.strip()][-1:] or [r.stderr.strip()])[0]

    def einspielen(self, ziel: Path, conf_pfad: Path) -> None:
        fehler = self._installer(ziel / "server", ziel / "web", conf_pfad)
        if fehler is None:
            return
        buendel, web = Path(self.info.get("buendel", "")), Path(self.info.get("web", ""))
        if not (buendel / "tool/installer/fwapp_install.py").exists() or not web.is_dir():
            raise Abbruch(f"{fehler} — altes Bündel nicht mehr da, KEIN Rückweg versucht")
        self.log(f"Neuer Stand scheitert ({fehler}) — hole {self.installiert} zurück")
        zurueck = self._installer(buendel, web, conf_pfad)
        if zurueck is None:
            raise Abbruch(f"{fehler} — {self.installiert} ist zurückgeholt und läuft")
        raise Abbruch(f"{fehler} — und der Rückweg auf {self.installiert} scheiterte auch: {zurueck}")

    def aufraeumen(self, alte_images: list[str], neue_images: list[str], tag: str) -> None:
        """Die Images, die nur der alte Stand brauchte, und alte Bündel. Auf
        dem Pi ist die Platte der Engpass (#239: ≈ 5,2 GB Images)."""
        for image in alte_images:
            if image not in neue_images:
                subprocess.run([*self.server.docker, "rmi", image], capture_output=True)
        # Das Bündel des NEUEN Stands bleibt: Es ist der Rückweg des
        # nächsten Updates.
        releases = self.data / "releases"
        for alt in releases.iterdir():
            if alt.name != tag:
                shutil.rmtree(alt, ignore_errors=True)

    def melden(self, nach: str, schritt: str, text: str) -> None:
        mail = fehler_mail(self.conf, self.installiert, nach, schritt, text)
        host = self.conf.get("SMTP_HOST", "")
        port = int(self.conf.get("SMTP_PORT") or 587)
        if self.testmodus:
            # Mailpit sitzt im Docker-Netz; von hier aus über den Testport.
            host, port = "127.0.0.1", 54325
        try:
            s = _smtp_oeffnen(host, port)
            if self.conf.get("SMTP_USER") and not self.testmodus:
                s.login(self.conf["SMTP_USER"], self.conf.get("SMTP_PASS", ""))
            s.send_message(mail)
            s.quit()
            self.log(f"Mail an {mail['To']} verschickt.")
        except Exception as e:  # noqa: BLE001 — die Mail ist die Meldung; scheitert sie, bleibt das Log
            self.log(f"Mail an {mail['To']} NICHT verschickt: {e}")


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description="FWApp-Server aktualisieren (#241)")
    p.add_argument("--conf", required=True)
    p.add_argument("--pruefen", action="store_true", help="nur nachsehen, nichts ändern")
    a = p.parse_args(argv)
    conf_pfad = Path(a.conf).resolve()
    conf = lies_conf(conf_pfad.read_text(encoding="utf-8"), dict(os.environ))
    u = Update(conf)

    if u.blockiert.exists():
        # Leise: Der Timer soll nicht jede Nacht rot werden, der Grund steht
        # in der Datei und kam per Mail.
        print(f"Blockiert ({u.blockiert}) — Lauf übersprungen.")
        return 0
    sperre = (u.data / "update.lock").open("w")
    try:
        fcntl.flock(sperre, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("Ein anderer Lauf ist aktiv — übersprungen.")
        return 0

    try:
        release = u.ziel()
    except Spaeter as e:
        u.log(f"GitHub nicht erreichbar — nächste Nacht: {e}")
        return 0
    except (Abbruch, json.JSONDecodeError) as e:
        u.log(f"Kein Update: {e}")
        return 1
    if release is None:
        u.log(f"Aktuell ({u.installiert}).")
        return 0
    tag = release["tag_name"]
    if a.pruefen:
        print(f"Update verfügbar: {u.installiert} → {tag}")
        return 0

    u.log(f"Update {u.installiert} → {tag}")
    schritt = "Laden"
    try:
        ziel = u.laden(release)
        installer = ziel / "server/tool/installer"
        schritt = "Images ziehen"
        alte_images = u._images(u.server_dir)
        neue_images = u.images_ziehen(installer)
        schritt = "Sicherung"
        dump = u.sichern(tag)
        u.log(f"Rückfallpunkt: {dump}")
        schritt = "Probelauf der Migrationen"
        u.log(f"{u.probelauf(ziel / 'server/supabase/migrations', dump)} Migration(en) geprobt")
        schritt = "Einspielen"
        u.einspielen(ziel, conf_pfad)
        u.aufraeumen(alte_images, neue_images, tag)
    except Spaeter as e:
        u.log(f"{schritt}: vorübergehend gescheitert — nächste Nacht: {e}")
        return 0
    except (Abbruch, OSError, KeyError, json.JSONDecodeError) as e:
        u.blockiert.write_text(f"{time.strftime('%Y-%m-%d %H:%M:%S')}\n{schritt}: {e}\n")
        u.log(f"BLOCKIERT bei {schritt}: {e}")
        u.melden(tag, schritt, str(e))
        return 1
    u.log(f"Fertig: {tag} läuft.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
