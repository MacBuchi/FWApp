#!/usr/bin/env python3
"""fwapp_check.py – Vorab-Prüfung einer FWApp-Installation (Issue #240).

Beantwortet VOR dem Installieren die Frage „kann das hier klappen?" und
danach jederzeit „ist noch alles in Ordnung?". Ausgabe als Liste, je Punkt
ein Satz, was nicht stimmt und was zu tun ist.

    ./fwapp_check.py --conf fwapp.conf --vorher     # vor der Installation
    ./fwapp_check.py --conf fwapp.conf              # laufende Installation
    ./fwapp_check.py --conf fwapp.conf --ohne-mail-code   # ohne Rückfrage

Entschieden mit Marcus am 2026-09-23 (#234): **Mail ist Pflicht** und wird
mit einem Code geprüft, den man aus der Testmail zurücktippt. „Der Server
hat die Mail angenommen" reicht nicht — genau so sah es aus, als Brevo eine
Einladung wegen DKIM verwarf (Issue #121), und niemand merkte es.

Nur Python-Standardbibliothek: Das Skript läuft auf einem frischen Pi oder
einer frischen VM, bevor irgendetwas installiert ist. Alle Zugriffe nach
draußen (DNS, HTTP, SMTP, System) kommen als Parameter in die Prüf-
funktionen, damit `test_fwapp_check.py` sie ohne Netz prüft.

Exit-Code: 1, wenn mindestens ein Punkt blockiert (❌), sonst 0.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import secrets
import shutil
import smtplib
import socket
import ssl
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from email.message import EmailMessage
from typing import Callable, Iterable, Optional

# Eigener User-Agent: Cloudflare Bot Fight Mode blockt `Python-urllib/3.x`
# mit 403 (AGENTS.md, Feedback-Bot) — die Prüfung meldete sonst „HTTPS
# kaputt", wo nur der Name des Werkzeugs stört.
USER_AGENT = "fwapp-check/1.0"

OK, WARNUNG, FEHLER, HINWEIS = "ok", "warnung", "fehler", "hinweis"
SYMBOL = {OK: "✅", WARNUNG: "⚠️ ", FEHLER: "❌", HINWEIS: "ℹ️ "}

GIB = 1024**3


@dataclass
class Ergebnis:
    stufe: str
    titel: str
    hinweis: str = ""


# ── Konfiguration ─────────────────────────────────────────────────────────


def lies_conf(text: str, umgebung: dict[str, str]) -> dict[str, str]:
    """SCHLUESSEL=wert je Zeile; Umgebungsvariablen gleichen Namens gewinnen
    (ein Passwort muss so nicht in der Datei stehen)."""
    conf: dict[str, str] = {}
    for zeile in text.splitlines():
        zeile = zeile.strip()
        if not zeile or zeile.startswith("#") or "=" not in zeile:
            continue
        k, v = zeile.split("=", 1)
        conf[k.strip()] = v.strip().strip('"').strip("'")
    for k in list(conf) + [
        "SMTP_PASS",
        "SMTP_USER",
        "TEST_EMPFAENGER",
    ]:
        if umgebung.get(k):
            conf[k] = umgebung[k]
    return conf


# ── Rechner ───────────────────────────────────────────────────────────────


def pruefe_architektur(maschine: str) -> Ergebnis:
    m = maschine.lower()
    if m in ("x86_64", "amd64"):
        return Ergebnis(OK, "Architektur: amd64")
    if m in ("aarch64", "arm64"):
        return Ergebnis(OK, "Architektur: arm64")
    if m.startswith("armv"):
        return Ergebnis(
            FEHLER,
            f"Architektur: {maschine} (32 Bit)",
            "Die Server-Images gibt es nur für 64 Bit. Auf dem Raspberry Pi "
            "das 64-Bit-Betriebssystem installieren (Raspberry Pi OS Lite 64-bit).",
        )
    return Ergebnis(FEHLER, f"Architektur: {maschine}", "Nicht unterstützt.")


def pruefe_speicher(gesamt_bytes: Optional[int]) -> Ergebnis:
    """Gemessen (#239): Das nötige Dienste-Set braucht unter Last < 1 GB,
    das ganze System etwa 1,5 GB. Zugesagt sind 4 GB (VM) bzw. 8 GB (Pi 5).
    `MemTotal` meldet etwas weniger als die Nennung, deshalb 3,5 GiB."""
    if gesamt_bytes is None:
        return Ergebnis(HINWEIS, "Arbeitsspeicher: nicht lesbar")
    gib = gesamt_bytes / GIB
    text = f"Arbeitsspeicher: {gib:.1f} GB"
    if gib < 3.5:
        return Ergebnis(
            FEHLER, text, "Mindestens 4 GB nötig (siehe docs/INSTALLATION.md)."
        )
    return Ergebnis(OK, text)


def pruefe_platte(frei_bytes: Optional[int], pfad: str) -> Ergebnis:
    """Der eigentliche Engpass auf dem Pi (#239): ~5,2 GB Images, bei
    Updates kurzzeitig doppelt, dazu Datenbank, Fotos, Backups."""
    if frei_bytes is None:
        return Ergebnis(HINWEIS, f"Freier Platz unter {pfad}: nicht lesbar")
    gib = frei_bytes / GIB
    text = f"Freier Platz unter {pfad}: {gib:.0f} GB"
    if gib < 16:
        return Ergebnis(FEHLER, text, "Mindestens 16 GB frei nötig, 64 GB empfohlen.")
    if gib < 32:
        return Ergebnis(WARNUNG, text, "Reicht zum Start; 64 GB empfohlen.")
    return Ergebnis(OK, text)


def pruefe_sd_karte(wurzel_geraet: Optional[str]) -> Optional[Ergebnis]:
    """Postgres auf einer SD-Karte verschleißt sie und übersteht einen
    Stromausfall schlechter als eine SSD (#239)."""
    if wurzel_geraet and "mmcblk" in wurzel_geraet:
        return Ergebnis(
            WARNUNG,
            "System läuft von einer SD-Karte",
            "Für die Datenbank eine SSD verwenden (NVMe-HAT oder USB) und "
            "DATA_DIR dorthin legen.",
        )
    return None


def pruefe_uhr(ntp_synchron: Optional[bool]) -> Ergebnis:
    """Zwei-Faktor-Codes und Anmelde-Token hängen an der Uhrzeit — geht sie
    um Minuten falsch, schlagen Anmeldungen scheinbar grundlos fehl."""
    if ntp_synchron is None:
        return Ergebnis(HINWEIS, "Uhrzeit: Synchronisation nicht feststellbar")
    if ntp_synchron:
        return Ergebnis(OK, "Uhrzeit: synchronisiert")
    return Ergebnis(
        WARNUNG,
        "Uhrzeit: nicht synchronisiert",
        "Zeitsynchronisation einschalten: sudo timedatectl set-ntp true",
    )


# ── Domain und HTTPS ──────────────────────────────────────────────────────


def pruefe_dns(domain: str, aufloesen: Callable[[str], list[str]]) -> Ergebnis:
    if not domain:
        return Ergebnis(FEHLER, "Domain: nicht eingetragen", "DOMAIN in fwapp.conf setzen.")
    # „192.168.1.20:8080" im LAN: aufgelöst wird der Rechner, nicht der Port.
    host = domain.rsplit(":", 1)[0] if domain.count(":") == 1 else domain
    try:
        adressen = aufloesen(host)
    except OSError:
        adressen = []
    if not adressen:
        return Ergebnis(
            FEHLER,
            f"Domain {domain}: nicht auflösbar",
            "Beim DNS-Anbieter einen Eintrag für diese Domain anlegen "
            "(bei Cloudflare Tunnel legt der Tunnel ihn an).",
        )
    return Ergebnis(OK, f"Domain {domain}: löst auf ({', '.join(adressen[:2])})")


def pruefe_https(
    domain: str, holen: Callable[[str], tuple[int, str]], schema: str = "https"
) -> list[Ergebnis]:
    """Nach der Installation: HTTPS, die Einrichtungs-Datei (#238) und ob
    der Server hinter der darin genannten Adresse antwortet. Im reinen LAN
    (ERREICHBARKEIT=lan) ohne Zertifikat über http."""
    basis = f"{schema}://{domain}"
    try:
        status, text = holen(f"{basis}/.well-known/fwapp.json")
    except ssl.SSLError as e:
        return [Ergebnis(FEHLER, "HTTPS: Zertifikat ungültig", str(e))]
    except OSError as e:
        return [
            Ergebnis(
                FEHLER,
                "HTTPS: nicht erreichbar",
                f"{basis} antwortet nicht ({e}). Tunnel bzw. Portfreigabe prüfen.",
            )
        ]
    ergebnisse = [
        Ergebnis(OK, "HTTPS: erreichbar, Zertifikat gültig")
        if schema == "https"
        else Ergebnis(HINWEIS, "Nur im LAN erreichbar (http, ohne Zertifikat)")
    ]
    if status != 200:
        ergebnisse.append(
            Ergebnis(
                WARNUNG,
                "Einrichtungs-Datei fehlt (/.well-known/fwapp.json)",
                "Ohne sie findet die App den Server nicht per Domain oder QR. "
                "tool/vm/fwapp_kopplung.sh ausführen.",
            )
        )
        return ergebnisse
    try:
        daten = json.loads(text)
        url, key = daten["url"], daten["anon_key"]
    except (ValueError, KeyError, TypeError):
        ergebnisse.append(
            Ergebnis(FEHLER, "Einrichtungs-Datei: ungültig", "Neu erzeugen mit fwapp_kopplung.sh.")
        )
        return ergebnisse
    ergebnisse.append(Ergebnis(OK, "Einrichtungs-Datei: vorhanden"))
    try:
        status, _ = holen(f"{url.rstrip('/')}/auth/v1/health", key)
    except OSError as e:
        status = f"nicht erreichbar ({e})"
    if status == 200:
        ergebnisse.append(Ergebnis(OK, "Server antwortet (Anmeldedienst)"))
    else:
        ergebnisse.append(
            Ergebnis(
                FEHLER,
                f"Server antwortet nicht wie erwartet: {status}",
                "docker compose ps prüfen; stimmen Adresse und Schlüssel in "
                "der Einrichtungs-Datei?",
            )
        )
    return ergebnisse


# ── Mail ──────────────────────────────────────────────────────────────────


def pruefe_spf(txt: Iterable[str], domain: str) -> Ergebnis:
    if any(t.lower().startswith("v=spf1") for t in txt):
        return Ergebnis(OK, f"SPF für {domain}: vorhanden")
    return Ergebnis(
        WARNUNG,
        f"SPF für {domain}: fehlt",
        "Den SPF-Eintrag des Mail-Anbieters als TXT-Record anlegen — ohne "
        "landen Einladungen oft im Spam.",
    )


def pruefe_dmarc(txt: Iterable[str], domain: str) -> Ergebnis:
    if any(t.lower().startswith("v=dmarc1") for t in txt):
        return Ergebnis(OK, f"DMARC für {domain}: vorhanden")
    return Ergebnis(
        WARNUNG,
        f"DMARC für {domain}: fehlt",
        f"TXT-Record _dmarc.{domain} anlegen, z. B. \"v=DMARC1; p=none\".",
    )


def pruefe_dkim(txt: Optional[Iterable[str]], selector: str, domain: str) -> Ergebnis:
    if not selector:
        return Ergebnis(
            HINWEIS,
            "DKIM: nicht geprüft",
            "DKIM_SELECTOR in fwapp.conf setzen (steht beim Mail-Anbieter).",
        )
    if txt is not None and any("v=dkim1" in t.lower() or "p=" in t for t in txt):
        return Ergebnis(OK, f"DKIM ({selector}) für {domain}: vorhanden")
    return Ergebnis(
        WARNUNG,
        f"DKIM ({selector}) für {domain}: fehlt",
        "Den DKIM-Eintrag des Mail-Anbieters anlegen. Ohne ihn verwarf Brevo "
        "bei uns Einladungen (Issue #121).",
    )


def pruefe_smtp(conf: dict[str, str], smtp_oeffnen: Callable[..., object]) -> tuple[Ergebnis, Optional[object]]:
    """Verbindet und meldet sich an. Gibt die offene Verbindung zurück, damit
    die Testmail denselben Weg nimmt, den später GoTrue nimmt."""
    host = conf.get("SMTP_HOST", "")
    if not host:
        return Ergebnis(FEHLER, "Mail: SMTP_HOST fehlt", "In fwapp.conf eintragen."), None
    port = int(conf.get("SMTP_PORT") or 587)
    try:
        verbindung = smtp_oeffnen(host, port)
        if conf.get("SMTP_USER"):
            verbindung.login(conf["SMTP_USER"], conf.get("SMTP_PASS", ""))
    except smtplib.SMTPAuthenticationError:
        return (
            Ergebnis(
                FEHLER,
                f"Mail: Anmeldung an {host} abgelehnt",
                "SMTP_USER / SMTP_PASS prüfen (bei Brevo: SMTP-Schlüssel, nicht "
                "das Konto-Passwort).",
            ),
            None,
        )
    except (OSError, smtplib.SMTPException) as e:
        return (
            Ergebnis(FEHLER, f"Mail: {host}:{port} nicht erreichbar", str(e)),
            None,
        )
    return Ergebnis(OK, f"Mail: Anmeldung an {host}:{port} klappt"), verbindung


def testmail(absender: str, empfaenger: str, code: str) -> EmailMessage:
    m = EmailMessage()
    m["From"] = absender
    m["To"] = empfaenger
    m["Subject"] = "FWApp: Prüfung der Mail-Einrichtung"
    m.set_content(
        "Diese Mail kommt von der Einrichtung eines FWApp-Servers.\n\n"
        f"Prüf-Code: {code}\n\n"
        "Bitte den Code dort eintippen, wo er abgefragt wird. Wer diese Mail "
        "nicht erwartet hat, kann sie ignorieren.\n"
    )
    return m


def pruefe_mail_code(
    conf: dict[str, str],
    verbindung: object,
    frage: Optional[Callable[[str], str]],
    code: Optional[str] = None,
) -> Ergebnis:
    """Schickt die Testmail und lässt den Code zurücktippen. Erst das
    beweist, dass eine Einladung ankommt — dass der Server die Mail
    angenommen hat, bewies bei #121 nichts."""
    empfaenger = conf.get("TEST_EMPFAENGER", "")
    absender = conf.get("MAIL_ABSENDER", "")
    if not empfaenger or not absender:
        return Ergebnis(
            FEHLER,
            "Mail: Testmail nicht möglich",
            "MAIL_ABSENDER und TEST_EMPFAENGER in fwapp.conf eintragen.",
        )
    code = code or f"{secrets.randbelow(1_000_000):06d}"
    try:
        verbindung.send_message(testmail(absender, empfaenger, code))
    except (OSError, smtplib.SMTPException) as e:
        return Ergebnis(FEHLER, "Mail: Versand abgelehnt", str(e))
    if frage is None:
        return Ergebnis(
            WARNUNG,
            f"Mail: an {empfaenger} verschickt, Empfang nicht bestätigt",
            "Ohne --ohne-mail-code laufen lassen, um den Code zurückzutippen.",
        )
    for _ in range(3):
        antwort = frage(f"Code aus der Mail an {empfaenger} (leer = abbrechen): ").strip()
        if not antwort:
            break
        if antwort.replace(" ", "") == code:
            return Ergebnis(OK, f"Mail: kommt an ({empfaenger})")
        print("   Der Code stimmt nicht.")
    return Ergebnis(
        FEHLER,
        "Mail: Empfang nicht bestätigt",
        "Spam-Ordner prüfen; SPF/DKIM beim Mail-Anbieter einrichten. Ohne "
        "Mail gibt es keine Einladungen und keinen Passwort-Reset.",
    )


# ── Zugriffe nach draußen (nur hier, damit die Prüfungen testbar bleiben) ──


def _aufloesen(domain: str) -> list[str]:
    return sorted({a[4][0] for a in socket.getaddrinfo(domain, 443)})


def _holen(url: str, apikey: Optional[str] = None) -> tuple[int, str]:
    kopf = {"User-Agent": USER_AGENT}
    if apikey:
        kopf["apikey"] = apikey
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=kopf), timeout=10) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, ""
    except urllib.error.URLError as e:
        if isinstance(e.reason, ssl.SSLError):
            raise e.reason
        raise OSError(str(e.reason)) from e


def _txt(name: str) -> Optional[list[str]]:
    """TXT-Records über DNS-over-HTTPS — die Standardbibliothek kann kein
    TXT, und `dig` ist auf einem frischen System nicht immer da."""
    url = "https://dns.google/resolve?" + urllib.parse.urlencode({"name": name, "type": "TXT"})
    try:
        status, text = _holen(url)
        if status != 200:
            return None
        return [a["data"].replace('" "', "").strip('"') for a in json.loads(text).get("Answer", []) if a.get("type") == 16]
    except (OSError, ValueError):
        return None


LOKAL = ("127.0.0.1", "localhost", "::1")


def _smtp_oeffnen(host: str, port: int):
    if port == 465:
        return smtplib.SMTP_SSL(host, port, timeout=15, context=ssl.create_default_context())
    s = smtplib.SMTP(host, port, timeout=15)
    s.ehlo()
    if s.has_extn("starttls"):
        s.starttls(context=ssl.create_default_context())
        s.ehlo()
    elif host not in LOKAL:
        # Unverschlüsselt nur auf demselben Rechner — dort sitzt z. B. unsere
        # Mail-Brücke (SMTP → Brevo-API, SERVER-SETUP.md), die kein STARTTLS
        # kann und keins braucht. Über das Netz wäre das Passwort im Klartext.
        s.close()
        raise smtplib.SMTPException(
            f"{host} bietet keine Verschlüsselung (STARTTLS) an — Port 587 "
            "oder 465 des Anbieters verwenden."
        )
    return s


def _speicher() -> Optional[int]:
    try:
        with open("/proc/meminfo") as f:
            for z in f:
                if z.startswith("MemTotal:"):
                    return int(z.split()[1]) * 1024
    except OSError:
        pass
    try:  # macOS, damit die Prüfung auch auf dem Admin-Rechner läuft
        return int(subprocess.run(["sysctl", "-n", "hw.memsize"], capture_output=True, text=True).stdout)
    except (OSError, ValueError):
        return None


def _frei(pfad: str) -> Optional[int]:
    p = pfad
    while p and not os.path.exists(p):
        p = os.path.dirname(p.rstrip("/")) or "/"
    try:
        return shutil.disk_usage(p or "/").free
    except OSError:
        return None


def _wurzel_geraet() -> Optional[str]:
    try:
        return subprocess.run(["findmnt", "-n", "-o", "SOURCE", "/"], capture_output=True, text=True).stdout.strip()
    except OSError:
        return None


def _ntp() -> Optional[bool]:
    try:
        aus = subprocess.run(
            ["timedatectl", "show", "-p", "NTPSynchronized", "--value"],
            capture_output=True,
            text=True,
        ).stdout.strip()
    except OSError:
        return None
    return {"yes": True, "no": False}.get(aus)


# ── Ablauf ────────────────────────────────────────────────────────────────


def alle_pruefungen(conf: dict[str, str], vorher: bool, mit_code: bool) -> list[tuple[str, list[Ergebnis]]]:
    domain = conf.get("DOMAIN", "")
    rechner = [
        pruefe_architektur(platform.machine()),
        pruefe_speicher(_speicher()),
        pruefe_platte(_frei(conf.get("DATA_DIR", "/")), conf.get("DATA_DIR", "/")),
        pruefe_uhr(_ntp()),
    ]
    sd = pruefe_sd_karte(_wurzel_geraet())
    if sd:
        rechner.append(sd)

    netz = [pruefe_dns(domain, _aufloesen)]
    if not vorher and netz[0].stufe != FEHLER:
        schema = "http" if conf.get("ERREICHBARKEIT") == "lan" else "https"
        netz += pruefe_https(domain, _holen, schema)

    mail_domain = conf.get("MAIL_ABSENDER", "@").split("@")[-1]
    mail: list[Ergebnis] = []
    smtp, verbindung = pruefe_smtp(conf, _smtp_oeffnen)
    mail.append(smtp)
    if verbindung is not None:
        mail.append(pruefe_mail_code(conf, verbindung, input if mit_code else None))
        try:
            verbindung.quit()
        except (OSError, smtplib.SMTPException):
            pass
    if mail_domain:
        mail.append(pruefe_spf(_txt(mail_domain) or [], mail_domain))
        mail.append(pruefe_dmarc(_txt(f"_dmarc.{mail_domain}") or [], mail_domain))
        sel = conf.get("DKIM_SELECTOR", "")
        mail.append(pruefe_dkim(_txt(f"{sel}._domainkey.{mail_domain}") if sel else None, sel, mail_domain))

    return [("Rechner", rechner), ("Domain und HTTPS", netz), ("Mail", mail)]


def ausgabe(abschnitte: list[tuple[str, list[Ergebnis]]]) -> int:
    fehler = 0
    for titel, ergebnisse in abschnitte:
        print(f"\n{titel}")
        for e in ergebnisse:
            print(f"  {SYMBOL[e.stufe]} {e.titel}")
            if e.hinweis and e.stufe != OK:
                print(f"     → {e.hinweis}")
            fehler += e.stufe == FEHLER
    print()
    if fehler:
        print(f"❌ {fehler} Punkt(e) blockieren die Installation.")
        return 1
    print("✅ Nichts blockiert.")
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Vorab-Prüfung einer FWApp-Installation (#240)")
    p.add_argument("--conf", default="fwapp.conf", help="Pfad zur fwapp.conf")
    p.add_argument("--vorher", action="store_true", help="vor der Installation: ohne HTTPS/Server-Prüfung")
    p.add_argument("--ohne-mail-code", action="store_true", help="Testmail schicken, aber keinen Code abfragen")
    a = p.parse_args(argv)
    try:
        with open(a.conf, encoding="utf-8") as f:
            conf = lies_conf(f.read(), dict(os.environ))
    except OSError:
        print(f"❌ {a.conf} nicht gefunden. Vorlage: fwapp.conf.example kopieren und ausfüllen.")
        return 1
    return ausgabe(alle_pruefungen(conf, a.vorher, not a.ohne_mail_code))


if __name__ == "__main__":
    sys.exit(main())
