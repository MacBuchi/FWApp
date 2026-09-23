#!/usr/bin/env python3
"""fwapp_bericht.py – Der Wochenbericht an den KreisDatenMeister.

    ./fwapp_bericht.py --conf /srv/fwapp/server/fwapp.conf            # schicken
    ./fwapp_bericht.py --conf … --ansehen                             # nur zeigen

Marcus, 2026-09-24: „Bekommt der KreisDatenMeister schon wöchentlich einen
Error- und Health-Report? (Links zu Logfiles, Auffälligkeiten, Auslastung)"
— bis dahin nicht: Mails gab es nur, wenn etwas scheiterte. Das hat eine
Lücke, die man erst bemerkt, wenn es zu spät ist: Fällt der Mailversand
aus, kommt auch keine Fehlermail mehr. Ein Bericht, der JEDE Woche kommt,
ist deshalb selbst ein Lebenszeichen — bleibt er aus, stimmt etwas nicht.

Inhalt, jeweils mit Ampel: Stand und Updates, Sicherungen, Auslastung
(Platte, Speicher, Last, Temperatur), Dienste (Neustarts, Gesundheit),
Auffälligkeiten aus den Logs der Woche (gezählt und gruppiert), Zertifikat,
Nutzung. Die Logs der Woche hängen als ZIP an.

⚠️ **Keine Links zu Logdateien.** Die Logs liegen nur auf dem Server; ein
Link bräuchte eine Webseite, die sie ausliefert — eine neue Angriffsfläche
für einen Server, der sonst nichts nach außen zeigt. Stattdessen: Auszüge
im Text, die ganze Woche als Anhang, die Pfade für den Blick vor Ort.

Läuft auf zwei Arten von Server, gesteuert über die Konfiguration:
- **Installer-Installation** (#241): die Vorgaben passen von selbst —
  DATA_DIR, installation.json, update.log, Borg-Sicherungen.
- **Unsere VM** (docs/SERVER-SETUP.md): eigene Datei
  `tool/vm/fwapp-bericht.conf.example` mit den Pfaden dort (Autodeploy-Log,
  pg_dump-Ordner, version.json der Web-App).

Nur Python-Standardbibliothek. Die Auswertung (Fehler erkennen und
gruppieren, Schwellen, Ampel, Text) steht in Funktionen ohne Docker und
wird von test_fwapp_bericht.py geprüft.
"""
from __future__ import annotations

import argparse
import calendar
import io
import json
import os
import re
import socket
import ssl
import subprocess
import sys
import time
import zipfile
from dataclasses import dataclass, field
from email.message import EmailMessage
from pathlib import Path
from typing import Callable, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fwapp_check import lies_conf  # noqa: E402
from fwapp_install import sende_mail  # noqa: E402

OK, HINWEIS, PROBLEM = "ok", "hinweis", "problem"
SYMBOL = {OK: "✅", HINWEIS: "⚠️", PROBLEM: "❌"}
WOCHE = 7 * 24 * 3600
ANHANG_MAX = 3 * 1024 * 1024  # Brevo und die meisten Postfächer vertragen das sicher


@dataclass
class Befund:
    stufe: str
    text: str


@dataclass
class Abschnitt:
    titel: str
    zeilen: list[str] = field(default_factory=list)
    befunde: list[Befund] = field(default_factory=list)


# ── Logs auswerten ────────────────────────────────────────────────────────

# Was in den Logs der Dienste einen Fehler meint. Bewusst eng: Ein Bericht,
# der jede Woche „312 Auffälligkeiten" meldet, liest nach dem dritten Mal
# niemand mehr.
_FEHLER = re.compile(
    r'"level"\s*:\s*"(error|fatal|panic)"'  # GoTrue, Storage, Realtime (JSON)
    r'|\blevel=(error|fatal|panic)\b'
    r'|\b(ERROR|FATAL|PANIC|CRITICAL)\b'  # Postgres, Python
    r'|\[(error|crit|alert|emerg)\]'  # nginx
    r'|Traceback \(most recent call last\)'
    r'|\bpanic:'
    r'|" 5\d\d \d',  # HTTP 5xx in Zugriffslogs (Kong, nginx)
)
# Was sicher kein Fehler ist, obwohl es danach aussieht.
_KEIN_FEHLER = re.compile(
    r"ERROR:\s+relation \"auth\.schema_migrations\""
    r"|could not receive data from client: Connection reset by peer"
    # Kong beim Anhalten — passiert bei JEDER Wochensicherung (der Stack
    # wird dafür gestoppt) und hieße sonst jede Woche „Auffälligkeit".
    r"|process exiting"
)
_ZEIT = re.compile(r"\d{4}-\d\d-\d\d[T ][\d:.,]+(Z|[+-]\d\d:?\d\d)?")
_UUID = re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", re.I)
_HEX = re.compile(r"\b[0-9a-f]{12,}\b", re.I)
_IP = re.compile(r"\b\d{1,3}(\.\d{1,3}){3}(:\d+)?\b")
_ZAHL = re.compile(r"\b\d+(\.\d+)?(ms|s|µs|us)?\b")


def ist_fehler(zeile: str) -> bool:
    return bool(_FEHLER.search(zeile)) and not _KEIN_FEHLER.search(zeile)


def normalisiere(zeile: str) -> str:
    """Macht aus einer Logzeile ihre „Sorte": ohne Zeitstempel, IDs,
    Adressen und Zahlen. Dieselbe Meldung mit anderer Anfrage-ID ist
    dieselbe Auffälligkeit."""
    s = _ZEIT.sub("", zeile)
    s = _UUID.sub("<id>", s)
    s = _HEX.sub("<hex>", s)
    s = _IP.sub("<ip>", s)
    s = _ZAHL.sub("<n>", s)
    return re.sub(r"\s+", " ", s).strip()[:180]


def fehler_auswerten(zeilen: list[str], top: int = 3) -> tuple[int, list[tuple[int, str]]]:
    """Anzahl der Fehlerzeilen und die häufigsten Sorten mit einem Beispiel."""
    sorten: dict[str, list] = {}
    anzahl = 0
    for z in zeilen:
        if not ist_fehler(z):
            continue
        anzahl += 1
        sorte = normalisiere(z)
        eintrag = sorten.setdefault(sorte, [0, z.strip()[:200]])
        eintrag[0] += 1
    haeufig = sorted(sorten.values(), key=lambda e: -e[0])[:top]
    return anzahl, [(n, beispiel) for n, beispiel in haeufig]


# ── Schwellen ─────────────────────────────────────────────────────────────


def bewerte_platte(pfad: str, gesamt: int, frei: int) -> Befund:
    anteil = frei / gesamt if gesamt else 0
    text = f"{pfad}: {frei / 1024**3:.1f} GB frei von {gesamt / 1024**3:.0f} GB ({anteil:.0%})"
    if frei < 2 * 1024**3 or anteil < 0.05:
        return Befund(PROBLEM, text + " — Platte fast voll, Updates und Sicherungen scheitern bald")
    if frei < 8 * 1024**3 or anteil < 0.15:
        return Befund(HINWEIS, text + " — wird knapp")
    return Befund(OK, text)


def bewerte_speicher(gesamt_kb: int, verfuegbar_kb: int) -> Befund:
    anteil = verfuegbar_kb / gesamt_kb if gesamt_kb else 0
    text = f"Arbeitsspeicher: {verfuegbar_kb / 1024**2:.1f} GB frei von {gesamt_kb / 1024**2:.1f} GB"
    return Befund(HINWEIS if anteil < 0.10 else OK, text)


def bewerte_last(last15: float, kerne: int) -> Befund:
    text = f"Systemlast (15 min): {last15:.2f} bei {kerne} Kernen"
    return Befund(HINWEIS if last15 > kerne else OK, text)


def bewerte_temperatur(grad: Optional[float]) -> Optional[Befund]:
    if grad is None:
        return None
    text = f"Temperatur: {grad:.0f} °C"
    if grad >= 80:
        return Befund(PROBLEM, text + " — der Pi drosselt; Kühlung prüfen")
    return Befund(HINWEIS if grad >= 70 else OK, text)


def bewerte_zertifikat(domain: str, tage: Optional[int], fehler: str = "") -> Befund:
    if tage is None:
        return Befund(HINWEIS, f"Zertifikat von {domain}: nicht prüfbar von hier ({fehler})")
    text = f"Zertifikat von {domain}: noch {tage} Tage gültig"
    if tage < 7:
        return Befund(PROBLEM, text + " — Erneuerung scheitert offenbar")
    return Befund(HINWEIS if tage < 21 else OK, text)


def bewerte_sicherung(art: str, alter_s: Optional[float], max_tage: float) -> Befund:
    if alter_s is None:
        return Befund(PROBLEM, f"{art}: keine gefunden")
    tage = alter_s / 86400
    text = f"{art}: zuletzt vor {tage:.1f} Tagen"
    return Befund(PROBLEM if tage > max_tage else OK, text)


def bewerte_container(name: str, status: str, gesund: str, neustarts: int,
                      gestartet_vor_s: Optional[float]) -> Befund:
    if status != "running":
        return Befund(PROBLEM, f"{name}: {status}")
    if gesund == "unhealthy":
        return Befund(PROBLEM, f"{name}: ungesund")
    if neustarts:
        return Befund(HINWEIS, f"{name}: {neustarts} automatische Neustarts (abgestürzt?)")
    text = f"{name}: läuft"
    if gestartet_vor_s is not None and gestartet_vor_s < WOCHE:
        text += f", neu gestartet vor {gestartet_vor_s / 86400:.1f} Tagen"
    return Befund(OK, text)


def gesamtstufe(abschnitte: list[Abschnitt]) -> str:
    stufen = {b.stufe for a in abschnitte for b in a.befunde}
    return PROBLEM if PROBLEM in stufen else HINWEIS if HINWEIS in stufen else OK


def betreff(name: str, abschnitte: list[Abschnitt]) -> str:
    probleme = sum(b.stufe == PROBLEM for a in abschnitte for b in a.befunde)
    hinweise = sum(b.stufe == HINWEIS for a in abschnitte for b in a.befunde)
    if probleme:
        zustand = f"❌ {probleme} Problem{'e' if probleme > 1 else ''}"
    elif hinweise:
        zustand = f"⚠️ {hinweise} Hinweis{'e' if hinweise > 1 else ''}"
    else:
        zustand = "✅ alles in Ordnung"
    return f"FWApp-Wochenbericht {name}: {zustand}"


def als_text(name: str, abschnitte: list[Abschnitt], jetzt: Optional[float] = None) -> str:
    kopf = [
        f"Wochenbericht {name} — {time.strftime('%d.%m.%Y %H:%M', time.localtime(jetzt))}",
        "",
    ]
    wichtig = [(a.titel, b) for a in abschnitte for b in a.befunde if b.stufe != OK]
    if wichtig:
        kopf.append("Auf einen Blick:")
        kopf += [f"  {SYMBOL[b.stufe]} {b.text}  ({titel})" for titel, b in wichtig]
    else:
        kopf.append("Auf einen Blick: ✅ alles in Ordnung.")
    kopf.append("")
    teile = []
    for a in abschnitte:
        teile.append(f"── {a.titel} " + "─" * max(3, 60 - len(a.titel)))
        teile += [f"  {SYMBOL[b.stufe]} {b.text}" for b in a.befunde]
        teile += [f"  {z}" for z in a.zeilen]
        teile.append("")
    teile.append(
        "Dieser Bericht kommt jede Woche. Bleibt er aus, ist der Server oder sein "
        "Mailversand gestört — dann lohnt ein Blick vor Ort."
    )
    return "\n".join(kopf + teile) + "\n"


# ── Sammeln ───────────────────────────────────────────────────────────────


def _lauf(*befehl: str, zeitlimit: int = 120) -> tuple[int, str]:
    try:
        r = subprocess.run(list(befehl), capture_output=True, text=True, timeout=zeitlimit,
                           errors="replace")
        return r.returncode, r.stdout + r.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)


def _liste(conf: dict[str, str], schluessel: str, vorgabe: list[str]) -> list[str]:
    wert = conf.get(schluessel)
    if wert is None:
        return vorgabe
    return [os.path.expanduser(t.strip()) for t in wert.split(",") if t.strip()]


class Bericht:
    def __init__(self, conf: dict[str, str], lauf: Callable[..., tuple[int, str]] = _lauf):
        self.conf = conf
        self.lauf = lauf
        self.docker = os.environ.get("DOCKER", "docker").split()
        data = conf.get("DATA_DIR", "")
        self.data = Path(data) if data else None
        self.logs_fuer_anhang: dict[str, str] = {}

    def _docker(self, *args: str, zeitlimit: int = 120) -> tuple[int, str]:
        return self.lauf(*self.docker, *args, zeitlimit=zeitlimit)

    def container(self) -> list[dict]:
        projekte = _liste(self.conf, "BERICHT_PROJEKTE", ["fwapp"] if self.data else [])
        filter_ = [a for p in projekte for a in ("--filter", f"label=com.docker.compose.project={p}")]
        rc, ids = self._docker("ps", "-a", "-q", *filter_)
        if rc != 0 or not ids.split():
            return []
        rc, roh = self._docker("inspect", *ids.split())
        return json.loads(roh) if rc == 0 else []

    # Abschnitte

    def stand(self) -> Abschnitt:
        a = Abschnitt("Stand und Updates")
        version_datei = self.conf.get("BERICHT_VERSION_DATEI") or (
            str(self.data / "server/installation.json") if self.data else "")
        if version_datei and Path(version_datei).exists():
            try:
                a.zeilen.append(f"Version: {json.loads(Path(version_datei).read_text()).get('version', '?')}")
            except json.JSONDecodeError:
                a.zeilen.append(f"Version: {version_datei} unlesbar")
        sperren = _liste(self.conf, "BERICHT_SPERRDATEIEN",
                         [str(self.data / "update.blocked")] if self.data else [])
        for s in sperren:
            if Path(s).exists():
                grund = " ".join(Path(s).read_text().split())[:300]
                a.befunde.append(Befund(PROBLEM, f"Updates angehalten ({s}): {grund}"))
        if not any(b.stufe == PROBLEM for b in a.befunde):
            a.befunde.append(Befund(OK, "Updates laufen"))
        for log in _liste(self.conf, "BERICHT_LOGDATEIEN",
                          [str(self.data / "update.log")] if self.data else []):
            zeilen = self._letzte_woche(Path(log))
            if zeilen is None:
                continue
            self.logs_fuer_anhang[Path(log).name] = "\n".join(zeilen)
            markant = [z for z in zeilen if re.search(r"BLOCKIERT|gescheitert|Fertig:|Update .* → ", z)]
            a.zeilen += [f"{Path(log).name}: {z[:160]}" for z in markant[-5:]]
        return a

    @staticmethod
    def _letzte_woche(pfad: Path) -> Optional[list[str]]:
        """Zeilen der letzten sieben Tage aus einem Log mit Datum vorn."""
        if not pfad.exists():
            return None
        grenze = time.strftime("%Y-%m-%d", time.localtime(time.time() - WOCHE))
        return [z for z in pfad.read_text(errors="replace").splitlines()
                if re.match(r"\d{4}-\d\d-\d\d", z) is None or z[:10] >= grenze]

    def sicherungen(self) -> Abschnitt:
        a = Abschnitt("Sicherungen")
        ordner = self.conf.get("BERICHT_DUMP_ORDNER")
        if ordner:
            dumps = sorted(Path(os.path.expanduser(ordner)).glob("*.dump"),
                           key=lambda p: p.stat().st_mtime)
            alter = time.time() - dumps[-1].stat().st_mtime if dumps else None
            a.befunde.append(bewerte_sicherung("Datenbank-Dump", alter, 2))
            if dumps:
                a.zeilen.append(f"{len(dumps)} Dumps in {ordner}, neuester "
                                f"{dumps[-1].stat().st_size / 1024**2:.1f} MB")
        if self.data and (self.data / "sicherungen/borg/config").exists():
            try:
                from fwapp_install import Server
                from fwapp_sicherung import Sicherung, externes_ziel

                server = Server(self.conf, testmodus=False)
                archive = Sicherung(server).liste()
                vor = [x for x in archive if "-vor-" in x["name"]]
                a.zeilen.append(f"Vor Updates: {len(vor)} Sicherungen"
                                + (f", zuletzt {vor[-1]['name'][:15]}" if vor else ""))
                ziel = (self.conf.get("SICHERUNG_ZIEL") or "").strip()
                if ziel:
                    if ziel == "lokal":
                        woche = [x for x in archive if x["name"].endswith("-woche")]
                    else:
                        grund = externes_ziel(ziel, str(self.data))
                        if grund:
                            a.befunde.append(Befund(PROBLEM, f"Sicherungsplatte: {grund}"))
                            woche = None
                        else:
                            woche = [x for x in Sicherung(server, Path(ziel) / "fwapp-borg").liste()
                                     if x["name"].endswith("-woche")]
                    if woche is not None:
                        alter = (time.time() - time.mktime(time.strptime(woche[-1]["name"][:15],
                                                                          "%Y%m%d-%H%M%S"))
                                 if woche else None)
                        a.befunde.append(bewerte_sicherung("Wochensicherung", alter, 8))
                        a.zeilen.append(f"Wochensicherungen: {len(woche)} von 4")
                else:
                    a.befunde.append(Befund(HINWEIS, "Keine wöchentliche Sicherung eingerichtet "
                                                     "(SICHERUNG_ZIEL)"))
            except Exception as e:  # noqa: BLE001 — ein unlesbares Archiv ist ein Befund, kein Abbruch
                a.befunde.append(Befund(PROBLEM, f"Sicherungen nicht lesbar: {e}"))
        if not a.befunde and not a.zeilen:
            a.befunde.append(Befund(HINWEIS, "Keine Sicherung konfiguriert"))
        return a

    def auslastung(self) -> Abschnitt:
        a = Abschnitt("Auslastung")
        pfade = _liste(self.conf, "BERICHT_PLATTEN", [str(self.data)] if self.data else ["/"])
        ziel = (self.conf.get("SICHERUNG_ZIEL") or "").strip()
        if ziel and ziel != "lokal" and os.path.isdir(ziel):
            pfade.append(ziel)
        gesehen = set()
        for pfad in pfade:
            try:
                st = os.statvfs(pfad)
            except OSError:
                continue
            geraet = os.stat(pfad).st_dev
            if geraet in gesehen:
                continue
            gesehen.add(geraet)
            a.befunde.append(bewerte_platte(pfad, st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize))
        try:
            mem = dict(z.split(":", 1) for z in Path("/proc/meminfo").read_text().splitlines())
            a.befunde.append(bewerte_speicher(int(mem["MemTotal"].split()[0]),
                                              int(mem["MemAvailable"].split()[0])))
        except (OSError, KeyError, ValueError):
            pass
        try:
            a.befunde.append(bewerte_last(os.getloadavg()[2], os.cpu_count() or 1))
        except OSError:
            pass
        try:
            grad = int(Path("/sys/class/thermal/thermal_zone0/temp").read_text()) / 1000
        except (OSError, ValueError):
            grad = None
        t = bewerte_temperatur(grad)
        if t:
            a.befunde.append(t)
        if Path("/var/run/reboot-required").exists():
            a.befunde.append(Befund(HINWEIS, "Das Betriebssystem wartet auf einen Neustart "
                                             "(Sicherheitsupdates)"))
        try:
            a.zeilen.append(f"Läuft seit {float(Path('/proc/uptime').read_text().split()[0]) / 86400:.0f} Tagen")
        except (OSError, ValueError):
            pass
        return a

    def dienste(self, container: list[dict]) -> Abschnitt:
        a = Abschnitt("Dienste")
        jetzt = time.time()
        rc, stats = self._docker("stats", "--no-stream", "--format", "{{.Name}}\t{{.MemUsage}}")
        speicher = dict(z.split("\t", 1) for z in stats.splitlines() if "\t" in z) if rc == 0 else {}
        for c in sorted(container, key=lambda c: c["Name"]):
            name = c["Name"].lstrip("/")
            state = c.get("State", {})
            gestartet = state.get("StartedAt", "")[:19]
            try:
                # Docker meldet UTC — timegm, nicht mktime (das läse Ortszeit).
                vor = jetzt - calendar.timegm(time.strptime(gestartet, "%Y-%m-%dT%H:%M:%S"))
            except ValueError:
                vor = None
            a.befunde.append(bewerte_container(
                name, state.get("Status", "?"), (state.get("Health") or {}).get("Status", ""),
                int(c.get("RestartCount", 0)), vor))
            if name in speicher:
                a.zeilen.append(f"{name}: {speicher[name].split('/')[0].strip()} Speicher")
        if not container:
            a.befunde.append(Befund(PROBLEM, "Keine Container gefunden"))
        return a

    def auffaelligkeiten(self, container: list[dict]) -> Abschnitt:
        a = Abschnitt("Auffälligkeiten in den Logs (7 Tage)")
        grenze = int(self.conf.get("BERICHT_FEHLER_GRENZE") or 50)
        for c in sorted(container, key=lambda c: c["Name"]):
            name = c["Name"].lstrip("/")
            rc, aus = self._docker("logs", "--since", "168h", "--timestamps", name, zeitlimit=300)
            if rc != 0:
                continue
            zeilen = aus.splitlines()
            self.logs_fuer_anhang[f"{name}.log"] = "\n".join(zeilen[-20000:])
            anzahl, haeufig = fehler_auswerten(zeilen)
            if not anzahl:
                continue
            a.befunde.append(Befund(HINWEIS if anzahl >= grenze else OK,
                                    f"{name}: {anzahl} Fehlerzeilen"))
            for n, beispiel in haeufig:
                a.zeilen.append(f"{name} ({n}×): {beispiel[:150]}")
        if not a.befunde:
            a.befunde.append(Befund(OK, "Keine Fehlerzeilen"))
        return a

    def erreichbarkeit(self) -> Optional[Abschnitt]:
        domain = self.conf.get("DOMAIN", "")
        if not domain or self.conf.get("ERREICHBARKEIT") == "lan":
            return None
        a = Abschnitt("Erreichbarkeit")
        tage, fehler = zertifikat_tage(domain.split(":")[0])
        a.befunde.append(bewerte_zertifikat(domain, tage, fehler))
        return a

    def nutzung(self) -> Optional[Abschnitt]:
        db = self.conf.get("BERICHT_DB_CONTAINER") or "supabase-db"
        abfragen = {
            "Gesamtwehren": "select count(*) from public.gesamtwehren",
            "Konten": "select count(*) from auth.users",
            "davon angemeldet in den letzten 7 Tagen":
                "select count(*) from auth.users where last_sign_in_at > now() - interval '7 days'",
            "Fotos und Anhänge": "select count(*) || ' (' || pg_size_pretty(coalesce(sum((metadata->>'size')::bigint), 0)) || ')' from storage.objects",
            "Datenbank": "select pg_size_pretty(pg_database_size('postgres'))",
        }
        a = Abschnitt("Nutzung")
        for titel, sql in abfragen.items():
            rc, aus = self._docker("exec", db, "psql", "-U", "supabase_admin", "-d", "postgres",
                                   "-Atc", sql)
            if rc == 0 and aus.strip():
                a.zeilen.append(f"{titel}: {aus.strip().splitlines()[-1]}")
        return a if a.zeilen else None

    def erstellen(self) -> list[Abschnitt]:
        container = self.container()
        teile = [self.stand(), self.sicherungen(), self.auslastung(), self.dienste(container),
                 self.auffaelligkeiten(container), self.erreichbarkeit(), self.nutzung()]
        return [t for t in teile if t is not None]

    def anhang(self) -> bytes:
        return logs_zip(self.logs_fuer_anhang, ANHANG_MAX)


def logs_zip(logs: dict[str, str], maximal: int) -> bytes:
    """Die Logs der Woche als ZIP. Wird es zu groß, werden die längsten
    Logs von vorn gekürzt (das Neueste bleibt) — lieber ein gekürzter
    Anhang als eine Mail, die der Mailserver abweist."""
    inhalt = dict(logs)
    for _ in range(12):
        puffer = io.BytesIO()
        with zipfile.ZipFile(puffer, "w", zipfile.ZIP_DEFLATED) as z:
            for name, text in sorted(inhalt.items()):
                z.writestr(name, text)
        daten = puffer.getvalue()
        if len(daten) <= maximal or not inhalt:
            return daten
        laengster = max(inhalt, key=lambda n: len(inhalt[n]))
        text = inhalt[laengster]
        inhalt[laengster] = "[… gekürzt, der Anhang wäre zu groß …]\n" + text[len(text) // 2:]
    return daten


def zertifikat_tage(host: str, port: int = 443) -> tuple[Optional[int], str]:
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((host, port), timeout=10) as roh:
            with ctx.wrap_socket(roh, server_hostname=host) as s:
                bis = ssl.cert_time_to_seconds(s.getpeercert()["notAfter"])
        return int((bis - time.time()) // 86400), ""
    except (OSError, ssl.SSLError, KeyError, ValueError) as e:
        return None, str(e)[:120]


def mail(conf: dict[str, str], betreff_text: str, text: str, anhang: bytes) -> EmailMessage:
    m = EmailMessage()
    m["From"] = conf.get("MAIL_ABSENDER", "")
    m["To"] = conf.get("BERICHT_AN") or conf.get("KDM_EMAIL", "")
    m["Subject"] = betreff_text
    m.set_content(text)
    if anhang:
        m.add_attachment(anhang, maintype="application", subtype="zip",
                         filename=f"fwapp-logs-{time.strftime('%Y-%m-%d')}.zip")
    return m


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description="FWApp-Wochenbericht")
    p.add_argument("--conf", required=True)
    p.add_argument("--ansehen", action="store_true", help="nur ausgeben, nicht schicken")
    p.add_argument("--testmodus", action="store_true", help=argparse.SUPPRESS)
    a = p.parse_args(argv)
    conf = lies_conf(Path(a.conf).read_text(encoding="utf-8"), dict(os.environ))
    name = conf.get("NAME") or conf.get("DOMAIN") or socket.gethostname()
    bericht = Bericht(conf)
    abschnitte = bericht.erstellen()
    text = als_text(name, abschnitte)
    titel = betreff(name, abschnitte)
    if a.ansehen:
        print(titel + "\n")
        print(text)
        return 0
    info = Path(conf.get("DATA_DIR", "/nonexistent"), "server/installation.json")
    testmodus = a.testmodus or (info.exists() and json.loads(info.read_text()).get("testmodus", False))
    grund = sende_mail(conf, testmodus, mail(conf, titel, text, bericht.anhang()))
    ziel = conf.get("BERICHT_AN") or conf.get("KDM_EMAIL", "")
    print(f"{titel}\n" + (f"per Mail an {ziel}" if grund is None else f"❌ Mail NICHT verschickt: {grund}"))
    return 0 if grund is None else 1


if __name__ == "__main__":
    sys.exit(main())
