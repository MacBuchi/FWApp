"""fwapp_sicherung.py – Vollständige Sicherung und Wiederherstellung eines
FWApp-Servers mit BorgBackup (#247, #248).

Zwei Anlässe, ein Mechanismus:

- **Vor jedem Update** (Marcus, 2026-09-23: „ein vollständiges Backup, das
  automatisch eingespielt werden kann") — immer ins LOKALE Archiv unter
  `DATA_DIR/sicherungen/borg`. Es muss da sein, auch wenn keine Platte
  steckt: Ohne Sicherung kein Update. Die letzten zwei bleiben.
- **Wöchentlich, optional** (#248: sonntags nachts, vier behalten) — nach
  `SICHERUNG_ZIEL`: leer = aus, `lokal` = ins lokale Archiv, ein Pfad =
  auf eine externe Platte. Nur die schützt vor einer toten SSD.

**Warum Borg** (Marcus, 2026-09-23, nach Vergleich mit rsync und restic):
Borg zerlegt die Daten in Stücke und legt jedes Stück nur einmal ab — vier
Wochensicherungen kosten etwa einmal die Daten plus die Änderungen, nicht
viermal die Daten. Dazu verschlüsselt (`repokey-blake2`) und komprimiert.
Dasselbe Werkzeug nutzt Nextcloud AIO für genau diesen Zweck; wir nehmen
dessen Image (Alpine, Borg 1.4, amd64 + arm64, datierte Tags) als
Werkzeug-Container — auf dem Rechner muss nichts installiert werden.

**Wie andere es machen**, und warum nicht so: A/B-Partitionen (RAUC,
Mender) tauschen das Betriebssystem, das unsere Updates nie anfassen;
Dateisystem-Schnappschüsse (btrfs, ZFS) setzen ein Dateisystem voraus, das
Pi OS nicht hat. Einzelheiten in docs/INSTALLATION.md.

**Was gesichert wird: alles, was ein Container beschreiben kann**, bei
ANGEHALTENEM Stack — eine Datei-Kopie einer laufenden Datenbank ist keine.
Die Liste kommt aus `docker inspect`, ein neuer Dienst mit Volume ist also
automatisch dabei. Dazu `server/` (Schlüssel, Compose-Dateien), `web/`,
`kopplung/`; Stand und Images stehen im Kommentar des Archivs.

⚠️ **Der Helfer hängt die Daten per `--volumes-from` ein, nie über den
Pfad aus `docker inspect`.** Docker Desktop meldet dort `/host_mnt/…`; die
erste Fassung übersprang deshalb die Datenbank STILL. Seitdem `PFLICHT`:
ohne Datenbank und Fotos keine Sicherung.

⚠️ **Erweiterte Dateiattribute:** Storage legt den Inhaltstyp jedes Fotos
als xattr an der Datei ab. Borg sichert sie unter Linux von sich aus — der
Nachweis prüft es an einem echten PNG.

⚠️ **Erst lesen, dann löschen:** Vor dem Zurückspielen liest
`borg extract --dry-run` das ganze Archiv und prüft jedes Stück. Ein
beschädigtes Archiv fällt so auf, BEVOR die laufenden Daten weg sind.

⚠️ **Wiederherstellen ersetzt den INHALT, nie das Verzeichnis** — ein
Bind-Mount hängt am Verzeichnis selbst (siehe `Server._ersetze`).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from fwapp_install import Abbruch, Server, lies_env

INSTALLER_ORDNER = ("server", "web", "kopplung")
# Ohne diese beiden ist eine Sicherung keine: Datenbank und Fotos.
PFLICHT = ("/var/lib/postgresql/data", "/var/lib/storage")
KEIN_VERZEICHNIS = 3
# Aufbewahrung je Anlass (#248: vier Wochensicherungen).
BEHALTEN = {"vor": 2, "woche": 4, "von-hand": 2}
BORG_FEHLT = "fehlt"


@dataclass
class Ziel:
    """Ein Verzeichnis, das ein Container beschreiben kann."""

    container: str  # über ihn hängt der Helfer die Daten ein (--volumes-from)
    pfad: str  # Pfad im Container — und im Archiv


# ── Reine Logik ───────────────────────────────────────────────────────────


def ziele_aus_inspect(container: list[dict]) -> list[Ziel]:
    """Aus `docker inspect`: jedes beschreibbare Volume und jeder
    beschreibbare Bind-Mount, jede Quelle nur einmal. Ob ein Bind-Mount eine
    Datei ist, entscheidet erst der Helfer — nur er sieht, was der Container
    sieht."""
    ziele: dict[str, Ziel] = {}
    for c in container:
        cname = c.get("Name", "").lstrip("/")
        for m in c.get("Mounts", []):
            if not m.get("RW") or m.get("Type") not in ("volume", "bind"):
                continue
            quelle = m.get("Name") or m["Source"]
            if quelle not in ziele:
                ziele[quelle] = Ziel(cname, m["Destination"])
    return sorted(ziele.values(), key=lambda z: (z.container, z.pfad))


def fehlende_pflicht(ziele: list[Ziel]) -> list[str]:
    pfade = {z.pfad for z in ziele}
    return [p for p in PFLICHT if p not in pfade]


def borg_image(compose_texte: list[str]) -> str:
    """Das Werkzeug steht als Dienst mit Profil in docker-compose.yml: So
    ist es mit dem Release gepinnt und wird vom Updater mitgezogen, ohne je
    zu starten."""
    for text in compose_texte:
        m = re.search(r"^\s*image:\s*(\S*borg\S*)", text, re.M)
        if m:
            return m.group(1)
    raise Abbruch("Kein Borg-Image in den Compose-Dateien — ohne Werkzeug keine Sicherung.")


def borg_kommentar(daten: dict) -> str:
    """⚠️ Borg setzt im Kommentar Platzhalter ein ({now}, {hostname}) — und
    ein JSON-Kommentar besteht aus geschweiften Klammern. Unverdoppelt bricht
    `borg create` mit „Invalid placeholder" ab; gefunden im Nachweis, nachdem
    der erste Probe-Aufruf ohne Kommentar durchgelaufen war."""
    return json.dumps(daten, separators=(",", ":")).replace("{", "{{").replace("}", "}}")


def archiv_name(anlass: str, jetzt: Optional[float] = None) -> str:
    return time.strftime("%Y%m%d-%H%M%S", time.localtime(jetzt)) + f"-{anlass}"


def anlass_von(name: str) -> str:
    """20260923-030000-vor-v1.64.0 → vor; …-woche → woche."""
    rest = name.split("-", 2)[2] if name.count("-") >= 2 else name
    for anlass in BEHALTEN:
        if rest == anlass or rest.startswith(anlass + "-"):
            return anlass
    return rest


def zu_loeschen(namen: list[str]) -> list[str]:
    """Was nach der Aufbewahrungsregel weg kann — je Anlass die neuesten
    `BEHALTEN[anlass]`. Namen beginnen mit einem sortierbaren Zeitstempel."""
    weg = []
    for anlass, anzahl in BEHALTEN.items():
        eigene = sorted(n for n in namen if anlass_von(n) == anlass)
        weg += eigene[:-anzahl] if anzahl else eigene
    return sorted(weg)


def platz_reicht(frei: int, daten: int, archiv_neu: bool) -> bool:
    """Ein neues Archiv braucht die Daten einmal ganz (komprimiert meist
    weniger, das ist der sichere Fall), ein bestehendes nur die Änderungen.
    Dazu 1 GiB Luft für Borgs Arbeitsdateien und Postgres."""
    return frei >= (daten if archiv_neu else 0) + 1024**3


def externes_ziel(ziel: str, data_dir: str) -> Optional[str]:
    """None, wenn das Ziel benutzbar ist, sonst der Grund.

    ⚠️ „Verzeichnis existiert" reicht nicht: Ist die USB-Platte nicht
    eingehängt, gibt es den Einhängepunkt trotzdem — als leeren Ordner auf
    der SSD. Eine Sicherung dorthin läge auf demselben Datenträger wie die
    Daten und schützte vor nichts. Deshalb: anderer Datenträger (st_dev)."""
    if not os.path.isdir(ziel):
        return f"{ziel} gibt es nicht — Platte nicht angeschlossen?"
    if os.stat(ziel).st_dev == os.stat(data_dir).st_dev:
        return f"{ziel} liegt auf derselben Platte wie die Daten — Sicherungsplatte nicht eingehängt?"
    return None


# ── Mit Docker ────────────────────────────────────────────────────────────


class Sicherung:
    """Ein Borg-Archiv. Ohne `repo` das lokale unter DATA_DIR/sicherungen."""

    def __init__(self, server: Server, repo: Optional[Path] = None):
        self.server = server
        self.data = server.data
        self.basis = self.data / "sicherungen"
        self.repo = repo or self.basis / "borg"
        self.cache = self.basis / "cache"
        self.env_datei = self.basis / "borg.env"

    # Werkzeug

    def _compose_texte(self) -> list[str]:
        env = lies_env((self.server.server / ".env").read_text())
        return [
            (self.server.server / d).read_text()
            for d in env.get("COMPOSE_FILE", "docker-compose.yml").split(":")
            if (self.server.server / d).exists()
        ]

    def _env_schreiben(self) -> None:
        # Nach einem Totalausfall steht auf dem NEUEN Rechner ein anderes
        # Passwort in der .env als das des Archivs auf der Platte — dann
        # kommt es aus der Umgebung (siehe docs/INSTALLATION.md).
        passwort = os.environ.get("SICHERUNG_PASSWORT") or lies_env(
            (self.server.server / ".env").read_text()
        ).get("SICHERUNG_PASSWORT")
        if not passwort:
            raise Abbruch("SICHERUNG_PASSWORT fehlt in server/.env — Installer erneut laufen lassen.")
        self.basis.mkdir(parents=True, exist_ok=True)
        self.env_datei.write_text(
            f"BORG_PASSPHRASE={passwort}\n"
            "BORG_REPO=/repo\n"
            "BORG_BASE_DIR=/cache\n"
            # Borg sperrt das Archiv unter dem Rechnernamen. Ein Container
            # hieße jedes Mal anders, und eine liegengebliebene Sperre ließe
            # sich nie als „die eigene" erkennen.
            "BORG_HOST_ID=fwapp-sicherung\n"
            # Dasselbe Archiv ist mal unter /repo, mal (Platte) woanders
            # eingehängt gewesen — für Borg sähe das wie ein Umzug aus.
            "BORG_RELOCATED_REPO_ACCESS_IS_OK=yes\n"
        )
        self.env_datei.chmod(0o600)

    def _borg(self, *args: str, skript: Optional[str] = None, von: tuple[str, ...] = (),
              nur_lesen: bool = True, installer: str = "") -> tuple[int, str]:
        """Borg im Werkzeug-Container. `von`: Container, deren Volumes
        eingehängt werden; `installer`: "ro"/"rw" hängt server/, web/,
        kopplung/ unter /fwapp ein."""
        self._env_schreiben()
        self.repo.mkdir(parents=True, exist_ok=True)
        self.cache.mkdir(parents=True, exist_ok=True)
        befehl = [
            *self.server.docker, "run", "--rm", "--hostname", "fwapp-sicherung",
            "--env-file", str(self.env_datei),
            "-v", f"{self.repo}:/repo", "-v", f"{self.cache}:/cache",
        ]
        if installer:
            for name in INSTALLER_ORDNER:
                (self.data / name).mkdir(exist_ok=True)
                befehl += ["-v", f"{self.data / name}:/fwapp/{name}:{installer}"]
        for c in von:
            befehl += ["--volumes-from", f"{c}:ro" if nur_lesen else c]
        image = borg_image(self._compose_texte())
        if skript is not None:
            befehl += ["--entrypoint", "sh", image, "-c", skript]
        else:
            befehl += ["--entrypoint", "borg", image, *args]
        return self.server.versuch(*befehl)

    def _borg_ok(self, *args: str, **kw) -> str:
        rc, aus = self._borg(*args, **kw)
        if rc != 0:
            # Borgs Meldung steht VORN; das Ende ist oft nur das Echo langer
            # Argumente (der Kommentar) — so ging die erste Ursache verloren.
            raise Abbruch(f"borg {args[0] if args else ''}: {aus.strip()[:400]}")
        return aus

    def vorhanden(self) -> bool:
        return (self.repo / "config").exists()

    # Was gesichert wird

    def ziele(self) -> list[Ziel]:
        ids = self.server.lauf(*self.server.docker, "compose", "ps", "-a", "-q").split()
        if not ids:
            raise Abbruch("Keine Container gefunden — nichts zu sichern.")
        container = json.loads(self.server.lauf(*self.server.docker, "inspect", *ids))
        return ziele_aus_inspect(container)

    def _verzeichnisse(self, ziele: list[Ziel]) -> tuple[list[Ziel], int]:
        """Die Ziele, die im Container Verzeichnisse sind, und ihre Größe."""
        bleiben, summe = [], 0
        for z in ziele:
            rc, aus = self._borg(
                skript=f'[ -d "{z.pfad}" ] || exit {KEIN_VERZEICHNIS}; du -sk "{z.pfad}"',
                von=(z.container,),
            )
            if rc == KEIN_VERZEICHNIS:
                continue
            m = re.search(rf"^(\d+)\s+{re.escape(z.pfad)}$", aus, re.M)
            if rc != 0 or not m:
                raise Abbruch(f"Größe von {z.pfad} ({z.container}) nicht lesbar: {aus.strip()[-300:]}")
            bleiben.append(z)
            summe += int(m.group(1)) * 1024
        return bleiben, summe

    def _groesse_installer(self) -> int:
        return sum(
            p.stat().st_size
            for name in INSTALLER_ORDNER
            for p in (self.data / name).rglob("*")
            if p.is_file()
        )

    def images(self) -> list[dict]:
        liste = []
        for text in self._compose_texte():
            for image in re.findall(r"^\s*image:\s*(\S+)", text, re.M):
                rc, aus = self.server.versuch(
                    *self.server.docker, "image", "inspect", "-f", "{{json .RepoDigests}}", image
                )
                digests = json.loads(aus) if rc == 0 and aus.strip().startswith("[") else []
                liste.append({"image": image, "digest": digests[0] if digests else ""})
        return liste

    # Die drei Handgriffe

    def erstellen(self, anlass: str, version: str) -> str:
        """Hält den Stack an, sichert, und lässt ihn ANGEHALTEN zurück — der
        Aufrufer entscheidet, womit es weitergeht (neuer Stand oder
        `starten()`). Gibt den Namen des Archivs zurück."""
        ziele, daten = self._verzeichnisse(self.ziele())
        fehlt = fehlende_pflicht(ziele)
        if fehlt:
            raise Abbruch(f"Die Sicherung erfasst {', '.join(fehlt)} nicht — keine halbe Sicherung.")
        daten += self._groesse_installer()
        self.repo.mkdir(parents=True, exist_ok=True)
        frei = shutil.disk_usage(self.repo).free
        if not platz_reicht(frei, daten, not self.vorhanden()):
            raise Abbruch(
                f"Zu wenig Platz für die Sicherung in {self.repo}: {frei // 2**20} MB frei, "
                f"Daten {daten // 2**20} MB."
            )
        if not self.vorhanden():
            self._borg_ok("init", "--encryption=repokey-blake2", "/repo")
        name = archiv_name(anlass)
        kommentar = borg_kommentar(
            {"version": version, "anlass": anlass, "images": self.images(),
             "ziele": [{"container": z.container, "pfad": z.pfad} for z in ziele]}
        )
        self.server.lauf(*self.server.docker, "compose", "stop")
        self._borg_ok(
            "create", "--numeric-ids", "--compression", "zstd,3", "--comment", kommentar,
            f"::{name}", *[z.pfad for z in ziele], "/fwapp",
            von=tuple(sorted({z.container for z in ziele})), installer="ro",
        )
        return name

    def starten(self) -> None:
        self.server.lauf(*self.server.docker, "compose", "up", "-d", "--remove-orphans")

    def liste(self) -> list[dict]:
        """Älteste zuerst: Name, Stand, Anlass, Images, Ziele."""
        if not self.vorhanden():
            return []
        aus = self._borg_ok("list", "--format", "{archive}{TAB}{comment}{NL}")
        archive = []
        for zeile in aus.splitlines():
            name, _, kommentar = zeile.partition("\t")
            if not re.match(r"^\d{8}-\d{6}-", name):
                continue
            try:
                info = json.loads(kommentar)
            except json.JSONDecodeError:
                info = {}
            archive.append({"name": name, **info})
        return sorted(archive, key=lambda a: a["name"])

    def einspielen(self, name: str) -> dict:
        """Stellt den Stand eines Archivs wieder her und startet ihn.

        Reihenfolge mit Grund: ERST das Archiv komplett zur Probe lesen
        (beschädigt → nichts angefasst). DANN die Dateien des Installers
        zurück, damit `server/` wieder die alten Compose-Dateien und die alte
        .env trägt; die Container nach dieser alten Beschreibung neu anlegen,
        ohne sie zu starten, und erst in DEREN Volumes die Daten
        zurückspielen — so landen sie genau dort, wo der alte Stand sie
        sucht."""
        info = next((a for a in self.liste() if a["name"] == name), None)
        if info is None or "ziele" not in info:
            raise Abbruch(f"Keine Sicherung {name} in {self.repo}")
        self._borg_ok("extract", "--dry-run", f"::{name}")
        self.server.lauf(*self.server.docker, "compose", "stop")

        loeschen = " && ".join(f'find "/fwapp/{n}" -mindepth 1 -delete' for n in INSTALLER_ORDNER)
        pfade = " ".join(f"fwapp/{n}" for n in INSTALLER_ORDNER)
        self._borg_ok(
            skript=f"{loeschen} && cd / && borg extract --numeric-ids ::{name} {pfade}",
            installer="rw",
        )
        self.server.lauf(
            *self.server.docker, "compose", "create", "--force-recreate", "--remove-orphans"
        )
        ziele = [Ziel(**z) for z in info["ziele"]]
        loeschen = " && ".join(f'find "{z.pfad}" -mindepth 1 -delete' for z in ziele)
        pfade = " ".join(f'"{z.pfad.lstrip("/")}"' for z in ziele)
        self._borg_ok(
            skript=f"{loeschen} && cd / && borg extract --numeric-ids ::{name} {pfade}",
            von=tuple(sorted({z.container for z in ziele})), nur_lesen=False,
        )
        self.starten()
        return info

    def aufraeumen(self) -> list[str]:
        """Löscht nach der Aufbewahrungsregel und gibt die Images zurück, die
        ein verbliebenes Archiv braucht — die darf der Updater nicht löschen,
        sonst ließe sich die Sicherung nicht mehr starten."""
        for name in zu_loeschen([a["name"] for a in self.liste()]):
            self._borg_ok("delete", f"::{name}")
        if self.vorhanden():
            self._borg_ok("compact")
        return [i["image"] for a in self.liste() for i in a.get("images", [])]



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
