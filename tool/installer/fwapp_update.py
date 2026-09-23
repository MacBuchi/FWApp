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
    4. Dump der Datenbank (Grundlage des Probelaufs, portabel)
    5. Probelauf der neuen Migrationen in einer Wegwerf-Datenbank
    6. VOLLSTÄNDIGE Sicherung bei angehaltenem Stack (fwapp_sicherung.py):
       Datenbank-Dateien, Fotos samt Attributen, Schlüssel, Konfiguration,
       Web-App, Functions, Image-Liste. Ohne sie kein Update.
    7. Installer des NEUEN Bündels, danach die Gesundheitsprüfung
       (`gesund`: ein echter Weg App → Kong → PostgREST → Datenbank, nicht
       nur „Container läuft"). Scheitert eins von beiden, wird die
       Sicherung aus Schritt 6 AUTOMATISCH eingespielt und erneut geprüft.

Bis Schritt 5 ist am laufenden Server nichts verändert; ab Schritt 6 gibt
es einen vollständigen Stand, der sich ohne Zutun zurückholen lässt.
Blockiert heißt: `DATA_DIR/update.blocked` liegt da, und jeder weitere Lauf
tut nichts, bis jemand sie löscht — lieber stehen bleiben, als dieselbe
kaputte Version jede Nacht gegen die Daten der Wehr zu werfen. Das Muster
stammt aus `tool/vm/fwapp_autodeploy.sh`.

Von Hand, jederzeit:

    ./fwapp_update.py --conf … --sichern               # vollständige Sicherung jetzt
    ./fwapp_update.py --conf … --sicherungen           # welche gibt es?
    ./fwapp_update.py --conf … --zuruecksetzen <name>  # diesen Stand zurückholen

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
from fwapp_check import lies_conf  # noqa: E402
from fwapp_install import Abbruch, Server, lies_env, offene_migrationen, sende_mail  # noqa: E402
from fwapp_sicherung import Sicherung, externes_ziel, gesund  # noqa: E402

API = "https://api.github.com/repos/MacBuchi/FWApp"
USER_AGENT = "fwapp-update/1.0"
KANAELE = ("stabil", "vorab", "aus")
DUMPS_BEHALTEN = 7


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


def hinweis_mail(conf: dict[str, str], betreff: str, text: str) -> EmailMessage:
    m = EmailMessage()
    m["From"] = conf.get("MAIL_ABSENDER", "")
    m["To"] = conf.get("KDM_EMAIL", "")
    m["Subject"] = f"FWApp: {betreff}"
    m.set_content(
        f"{conf.get('NAME') or 'FWApp'} ({conf.get('DOMAIN', '')})\n\n{text}\n\n"
        f"Protokoll: {conf.get('DATA_DIR', '/srv/fwapp')}/update.log\n"
    )
    return m


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
        "Vollständige Sicherungen anzeigen und bei Bedarf zurückholen:\n"
        f"  sudo python3 {data}/server/fwapp_update.py --conf {data}/server/fwapp.conf --sicherungen\n"
        f"  sudo python3 {data}/server/fwapp_update.py --conf {data}/server/fwapp.conf "
        "--zuruecksetzen <name>\n\n"
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
    def dump(self, tag: str) -> Path:
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
        for alt in aelteste([p.name for p in ordner.glob("*.dump")], DUMPS_BEHALTEN):
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

    # 6 + 7
    def umstellen(self, ziel: Path, conf_pfad: Path, sicherung: Sicherung) -> None:
        """Vollständig sichern, neuen Stand einrichten, prüfen — und bei
        einem Fehler die Sicherung automatisch zurückspielen."""
        try:
            stand = sicherung.erstellen(f"vor-{ziel.name}", self.installiert)
        except Exception as e:
            # Der Stack steht womöglich; der alte Stand ist unverändert.
            sicherung.starten()
            raise Abbruch(f"Vollständige Sicherung gescheitert ({e}) — alter Stand läuft wieder, "
                          "kein Update ohne Sicherung") from e
        self.log(f"Vollständige Sicherung: {stand}")

        befehl = [
            sys.executable, str(ziel / "server/tool/installer/fwapp_install.py"),
            "--conf", str(conf_pfad), "--web", str(ziel / "web"), "--ohne-pruefung",
        ]
        if self.testmodus:
            befehl.append("--testmodus")
        r = subprocess.run(befehl, capture_output=True, text=True)
        with self.log_datei.open("a") as f:
            f.write(r.stdout + r.stderr)
        if r.returncode != 0:
            fehler = ([z for z in r.stdout.splitlines() if z.strip()][-1:] or [r.stderr.strip()])[0]
        else:
            fehler = gesund(self.server)
            if fehler:
                fehler = f"nach dem Einrichten nicht benutzbar: {fehler}"
        if fehler is None:
            return

        self.log(f"Neuer Stand scheitert ({fehler}) — spiele {stand} ein")
        try:
            sicherung.einspielen(stand)
            zurueck = gesund(self.server)
        except Exception as e:  # noqa: BLE001 — jeder Fehler hier gehört in die Mail
            zurueck = str(e)
        if zurueck is None:
            raise Abbruch(f"{fehler} — Sicherung {stand} automatisch eingespielt, "
                          f"{self.installiert} läuft wieder mit den Daten von vor dem Update")
        raise Abbruch(f"{fehler} — und das Einspielen der Sicherung {stand} scheiterte "
                      f"auch ({zurueck}). Server braucht Hilfe von Hand.")

    def aufraeumen(self, alte_images: list[str], neue_images: list[str], sicherung: Sicherung,
                   tag: str) -> None:
        """Alte Sicherungen, alte Bündel und die Images, die weder der neue
        Stand noch eine verbliebene Sicherung braucht — eine Sicherung ohne
        ihre Images ließe sich nicht mehr starten. Auf dem Pi ist die Platte
        der Engpass (#239: ≈ 5,2 GB Images)."""
        noetig = set(neue_images) | set(sicherung.aufraeumen())
        for image in alte_images:
            if image not in noetig:
                subprocess.run([*self.server.docker, "rmi", image], capture_output=True)
        releases = self.data / "releases"
        for alt in releases.iterdir():
            if alt.name != tag:
                shutil.rmtree(alt, ignore_errors=True)

    def melden(self, nach: str, schritt: str, text: str) -> None:
        self.mail(fehler_mail(self.conf, self.installiert, nach, schritt, text))

    def mail(self, nachricht: EmailMessage) -> None:
        grund = sende_mail(self.conf, self.testmodus, nachricht)
        if grund is None:
            self.log(f"Mail an {nachricht['To']} verschickt.")
        else:
            # Die Mail ist die Meldung; scheitert sie, bleibt das Protokoll.
            self.log(f"Mail an {nachricht['To']} NICHT verschickt: {grund}")


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description="FWApp-Server aktualisieren (#241)")
    p.add_argument("--conf", required=True)
    p.add_argument("--pruefen", action="store_true", help="nur nachsehen, nichts ändern")
    p.add_argument("--sichern", action="store_true", help="vollständige Sicherung jetzt")
    p.add_argument("--sicherungen", action="store_true", help="vorhandene Sicherungen zeigen")
    p.add_argument("--zuruecksetzen", metavar="NAME", help="diese Sicherung einspielen")
    p.add_argument("--dokument", action="store_true",
                   help="Einrichtungsdokument neu erzeugen und an den KreisDatenMeister schicken")
    p.add_argument("--woche", action="store_true",
                   help="wöchentliche Sicherung nach SICHERUNG_ZIEL (Timer, sonntags)")
    a = p.parse_args(argv)
    conf_pfad = Path(a.conf).resolve()
    conf = lies_conf(conf_pfad.read_text(encoding="utf-8"), dict(os.environ))
    u = Update(conf)

    sicherung = Sicherung(u.server)
    if a.sicherungen:
        for titel, s in archive(u):
            print(f"{titel} ({s.repo}):")
            for arch in s.liste():
                print(f"   {arch['name']}   Stand {arch.get('version', '?')}")
        return 0
    if a.woche:
        return woche(u)
    if a.dokument:
        pfad, grund = u.server.dokument(u.installiert)
        print(f"✅ {pfad}" + (f"\n   per Mail an {u.conf.get('KDM_EMAIL')}" if grund is None
                              else f"\n❌ Mail NICHT verschickt: {grund}"))
        return 0 if grund is None else 1
    if a.sichern or a.zuruecksetzen:
        return von_hand(u, sicherung, a.sichern, a.zuruecksetzen)

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
        schritt = "Dump"
        dump = u.dump(tag)
        u.log(f"Dump: {dump}")
        schritt = "Probelauf der Migrationen"
        u.log(f"{u.probelauf(ziel / 'server/supabase/migrations', dump)} Migration(en) geprobt")
        schritt = "Einspielen"
        u.umstellen(ziel, conf_pfad, sicherung)
        u.aufraeumen(alte_images, neue_images, sicherung, tag)
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


def externe_sicherung(u: Update) -> tuple[Optional[Sicherung], Optional[str]]:
    """Das Archiv auf der Platte aus SICHERUNG_ZIEL — oder der Grund, warum
    es gerade keins gibt. `lokal` ist kein externes Ziel."""
    ziel = (u.conf.get("SICHERUNG_ZIEL") or "").strip()
    if not ziel or ziel == "lokal":
        return None, None
    grund = externes_ziel(ziel, str(u.data))
    if grund:
        return None, grund
    return Sicherung(u.server, Path(ziel) / "fwapp-borg"), None


def archive(u: Update) -> list[tuple[str, Sicherung]]:
    liste = [("Auf diesem Rechner", Sicherung(u.server))]
    extern, _ = externe_sicherung(u)
    if extern:
        liste.append(("Auf der Sicherungsplatte", extern))
    return liste


def _sperre(u: Update, warten: bool):
    sperre = (u.data / "update.lock").open("w")
    try:
        fcntl.flock(sperre, fcntl.LOCK_EX | (0 if warten else fcntl.LOCK_NB))
    except OSError:
        return None
    return sperre


def woche(u: Update) -> int:
    """Die wöchentliche Sicherung (#248). Optional: ohne SICHERUNG_ZIEL tut
    sie nichts. Fehlt die Platte, gibt es eine Mail — blockiert wird nichts,
    die Sicherung vor jedem Update liegt ohnehin lokal."""
    ziel = (u.conf.get("SICHERUNG_ZIEL") or "").strip()
    if not ziel:
        print("Wöchentliche Sicherung ist aus (SICHERUNG_ZIEL leer).")
        return 0
    if ziel == "lokal":
        s = Sicherung(u.server)
    else:
        s, grund = externe_sicherung(u)
        if s is None:
            u.log(f"Wöchentliche Sicherung ausgefallen: {grund}")
            u.mail(hinweis_mail(u.conf, "wöchentliche Sicherung ausgefallen",
                                f"{grund}\n\nDie Platte anschließen und einhängen; die nächste "
                                "Sicherung läuft am kommenden Sonntag, oder sofort mit:\n"
                                f"  sudo python3 {u.server_dir}/fwapp_update.py "
                                f"--conf {u.server_dir}/fwapp.conf --woche"))
            return 0
    # Ein Update, das gerade läuft, darf fertig werden — dann sichern.
    sperre = _sperre(u, warten=True)  # noqa: F841 — hält die Sperre bis zum Ende
    try:
        name = s.erstellen("woche", u.installiert)
    except Exception as e:  # noqa: BLE001 — jeder Fehler gehört in die Mail
        s.starten()
        u.log(f"Wöchentliche Sicherung gescheitert: {e}")
        u.mail(hinweis_mail(u.conf, "wöchentliche Sicherung gescheitert", str(e)))
        return 1
    s.starten()
    fehler = gesund(u.server)
    try:
        s.aufraeumen()
    except Abbruch as e:
        u.log(f"Aufräumen der Sicherungen: {e}")
    u.log(f"Wöchentliche Sicherung: {name} in {s.repo}")
    if fehler:
        u.mail(hinweis_mail(u.conf, "Server nach der Sicherung nicht benutzbar",
                            f"Die Sicherung {name} ist fertig, aber danach meldet der Server: {fehler}"))
        return 1
    return 0


def von_hand(u: Update, sicherung: Sicherung, sichern: bool, name: Optional[str]) -> int:
    sperre = _sperre(u, warten=False)
    if sperre is None:
        print("Ein Update läuft gerade — später noch einmal.")
        return 1
    try:
        if sichern:
            stand = sicherung.erstellen("von-hand", u.installiert)
            sicherung.starten()
            fehler = gesund(u.server)
            sicherung.aufraeumen()
            u.log(f"Vollständige Sicherung von Hand: {stand}")
            if fehler:
                print(f"⚠️ Gesichert, aber der Server meldet danach: {fehler}")
                return 1
            print(f"✅ {stand}")
            return 0
        # Zuerst das lokale Archiv, dann die Platte — derselbe Name kommt
        # nicht zweimal vor (Zeitstempel).
        treffer = [s for _, s in archive(u) if any(a["name"] == name for a in s.liste())]
        if not treffer:
            vorhanden = [a["name"] for _, s in archive(u) for a in s.liste()]
            print(f"❌ Keine Sicherung {name} — vorhanden: {', '.join(vorhanden) or 'keine'}")
            return 1
        info = treffer[0].einspielen(name)
        fehler = gesund(u.server)
        # Sonst holte das nächste nächtliche Update genau den Stand zurück,
        # von dem man gerade weggegangen ist.
        u.blockiert.write_text(
            f"{time.strftime('%Y-%m-%d %H:%M:%S')}\nVon Hand auf {name} zurückgesetzt "
            f"(Stand {info.get('version', '?')}). Updates erst nach rm {u.blockiert}.\n"
        )
        u.log(f"Von Hand zurückgesetzt auf {name} (Stand {info.get('version', '?')})")
        if fehler:
            print(f"❌ Eingespielt, aber der Server meldet: {fehler}")
            return 1
        print(f"✅ {name} läuft (Stand {info.get('version', '?')}). Nächtliche Updates sind "
              f"angehalten, bis {u.blockiert} gelöscht ist.")
        return 0
    except Abbruch as e:
        print(f"❌ {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
