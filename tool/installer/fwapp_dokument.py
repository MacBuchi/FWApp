"""fwapp_dokument.py – Das Einrichtungsdokument für den KreisDatenMeister (#249).

Marcus, 2026-09-24: Nach dem Einrichten entsteht ein Dokument mit allen
Angaben und Passwörtern und einer Bedienungsanleitung, und es geht per Mail
an den KreisDatenMeister. Das ist, was andere Geräte als „Notfallblatt"
beilegen: alles, was man braucht, wenn der Mensch, der den Server
eingerichtet hat, nicht erreichbar ist.

Inhalt: Zugangsdaten (mit Passwörtern), der Kopplungs-QR zum Aushängen,
die ersten Schritte in der App, was nachts von selbst passiert, und die
Notfall-Befehle MIT den Pfaden dieser Installation — abtippen statt
übersetzen.

⚠️ **Passwörter im Dokument sind gewollt** (Marcus). Ein passwortgeschütztes
PDF wäre mit der Standardbibliothek nur mit RC4 zu haben, und das gäbe
falsche Sicherheit. Stattdessen sagt das Dokument oben groß: ausdrucken,
sicher ablegen, Mail löschen. Das Startpasswort des Kontos muss beim ersten
Anmelden ohnehin geändert werden; das Sicherungs-Passwort ist der Wert,
der wirklich zählt.
"""
from __future__ import annotations

import time
from email.message import EmailMessage
from pathlib import Path
from typing import Optional

from fwapp_pdf import Pdf
from fwapp_qr import qr_matrix

KANAL_TEXT = {
    "stabil": "jedes freigegebene Release",
    "vorab": "auch Vorabversionen (neuer, aber noch nicht erprobt)",
    "aus": "aus — Updates nur von Hand",
}
ERREICHBARKEIT_TEXT = {
    "caddy": "eigene Domain mit HTTPS (Caddy, Zertifikat automatisch)",
    "tunnel": "Cloudflare Tunnel",
    "lan": "nur im Netz des Gerätehauses",
}


def _url(conf: dict[str, str]) -> str:
    schema = "http" if conf.get("ERREICHBARKEIT") == "lan" else "https"
    return f"{schema}://{conf.get('DOMAIN', '')}"


def sicherung_text(ziel: str) -> str:
    ziel = ziel.strip()
    if not ziel:
        return "keine wöchentliche Sicherung (vor jedem Update wird trotzdem gesichert)"
    if ziel == "lokal":
        return "sonntags 2:30 auf diesem Rechner, vier bleiben"
    return f"sonntags 2:30 auf die externe Platte {ziel}, vier bleiben"


def dokument(conf: dict[str, str], version: str, kopplung_json: str,
             sicherungs_passwort: str, startpasswort: Optional[str] = None,
             erstellt: Optional[float] = None) -> bytes:
    """Das PDF. `startpasswort` nur direkt nach der Einrichtung — später
    kennt es niemand mehr (und es ist dann längst geändert)."""
    name = conf.get("NAME") or conf.get("DOMAIN", "FWApp")
    data = conf.get("DATA_DIR", "/srv/fwapp")
    srv = f"{data}/server"
    u = f"sudo python3 {srv}/fwapp_update.py --conf {srv}/fwapp.conf"
    datum = time.strftime("%d.%m.%Y", time.localtime(erstellt))
    url = _url(conf)

    pdf = Pdf(f"FWApp – Einrichtung {name}", f"{name} · Einrichtungsdokument · VERTRAULICH")
    pdf.titel_block(f"FWApp – {name}", f"Einrichtungsdokument und Bedienungsanleitung · "
                    f"Stand {datum} · Version {version}")
    pdf.kasten(
        "Vertraulich — enthält Passwörter",
        "Bitte ausdrucken und sicher ablegen (z. B. im Ordner beim Kommandanten oder im "
        "Tresor), danach diese Mail löschen. Wer das Sicherungs-Passwort nicht hat, kann "
        "nach einem Ausfall des Servers keine Sicherung mehr lesen.",
    )

    pdf.abschnitt("1. Zugangsdaten")
    felder = [
        ("Web-App", url),
        ("KreisDatenMeister", conf.get("KDM_EMAIL", "")),
        ("Startpasswort", startpasswort or "bei der Einrichtung vergeben (beim ersten "
                                           "Anmelden geändert)"),
        ("Sicherungs-Passwort", sicherungs_passwort),
        ("Erreichbarkeit", ERREICHBARKEIT_TEXT.get(conf.get("ERREICHBARKEIT", ""), "")),
        ("Daten auf dem Server", data),
    ]
    pdf.felder(felder, hervorheben=("Sicherungs-Passwort",) + (("Startpasswort",) if startpasswort else ()))

    pdf.abschnitt("2. Handys und Tablets verbinden")
    pdf.liste([
        "Android: die App (APK) von github.com/MacBuchi/FWApp/releases installieren. Auf der "
        "Anmeldeseite „Mit anderem Server verbinden“ → „QR-Code scannen“ und diesen Code "
        f"scannen — oder dort die Adresse {conf.get('DOMAIN', '')} eingeben.",
        f"iPhone und Computer: im Browser {url} öffnen. Die Web-App kennt ihren Server von "
        "selbst.",
    ])
    pdf.absatz("Diese Seite kann im Gerätehaus aushängen — der Code enthält kein Passwort, "
               "nur die Adresse und den öffentlichen Schlüssel des Servers.")
    pdf.qr(qr_matrix(kopplung_json), 62, f"Einrichtungs-Code für {name}")

    pdf.abschnitt("3. Erste Schritte in der App")
    pdf.liste([
        f"In der Web-App ({url}) mit der Mail des KreisDatenMeisters und dem Startpasswort "
        "anmelden. Die App verlangt sofort ein neues Passwort.",
        "Mehr → Einstellungen → „KreisDatenMeister“ → „Wehr anlegen“: Name der Gesamtwehr (z. B. "
        "„Feuerwehr Musterstadt“), erste Abteilung und die Mail des Feuerwehrkommandanten "
        "eintragen, dann „Anlegen und einladen“.",
        "Der Kommandant bekommt eine Mail mit einem sechsstelligen Code. Auf der Anmeldeseite "
        "wählt er „Ich habe eine Einladung“ und gibt Mail-Adresse und Code ein. Weitere Abteilungen und "
        "alle Mitglieder lädt er danach selbst ein.",
        "Für jede weitere Wehr dasselbe. Die Übersicht zeigt je Wehr den Kommandanten und wann "
        "zuletzt veröffentlicht wurde.",
    ], nummeriert=True)
    pdf.absatz("Was der KreisDatenMeister sonst tut (Menü „Aktionen“ an jeder Wehr):", art="fett")
    pdf.liste([
        "„Kommandant hinzufügen“ — wenn der Kommandant wechselt oder sein Konto verloren ist. "
        "Hat die Adresse schon ein Konto, wird die Person sofort Kommandant, sonst kommt eine "
        "Einladung.",
        "„Stilllegen“ — die Wehr kann danach nichts mehr veröffentlichen und niemanden "
        "einladen; Lesen und Lernen gehen weiter, gelöscht wird nichts. „Reaktivieren“ macht "
        "es rückgängig.",
    ])

    pdf.abschnitt("4. Was der Server von selbst tut")
    kanal = conf.get("UPDATE_KANAL") or "stabil"
    pdf.felder([
        ("Updates", f"jede Nacht gegen 3 Uhr — {KANAL_TEXT.get(kanal, kanal)}"),
        ("Vor jedem Update", "vollständige Sicherung; geht etwas schief, wird sie automatisch "
                             "zurückgespielt"),
        ("Wöchentlich", sicherung_text(conf.get("SICHERUNG_ZIEL", ""))),
        ("Bei Problemen", f"Mail an {conf.get('KDM_EMAIL', '')} mit dem, was zu tun ist"),
    ])
    pdf.absatz(
        "Kommt eine Mail „Update … gescheitert — Updates angehalten“, läuft der Server weiter "
        "(auf dem alten Stand oder dem zurückgespielten). Updates bleiben angehalten, bis "
        "jemand die Ursache prüft — die Mail nennt die Befehle."
    )

    pdf.abschnitt("5. Notfall-Befehle")
    pdf.absatz("Am Server anmelden (Bildschirm und Tastatur oder SSH), dann:")
    pdf.code([
        "# Ist alles in Ordnung? (Rechner, Domain, HTTPS, Mail)",
        f"sudo python3 {srv}/fwapp_check.py --conf {srv}/fwapp.conf",
        "",
        "# Welche Sicherungen gibt es?",
        f"{u} --sicherungen",
        "",
        "# Einen Stand zurückholen (Name aus der Liste; hält danach die Updates an)",
        f"{u} --zuruecksetzen <name>",
        "",
        "# Updates wieder freigeben, wenn alles stimmt",
        f"sudo rm {data}/update.blocked",
        "",
        "# Jetzt sichern / jetzt aktualisieren / dieses Dokument neu schicken",
        f"{u} --sichern",
        f"{u}",
        f"{u} --dokument",
    ])

    pdf.abschnitt("6. Totalausfall: neuer Rechner")
    pdf.absatz(
        "Ist der Server kaputt oder gestohlen, braucht es drei Dinge: einen neuen Rechner "
        "(Raspberry Pi 5 mit 8 GB oder eine VM mit 4 GB), die Sicherungsplatte und das "
        "Sicherungs-Passwort von Seite 1."
    )
    pdf.liste([
        "Den neuen Rechner wie beim ersten Mal einrichten — Installer aus dem aktuellen Release, "
        "dieselbe fwapp.conf (Domain, Mail, Sicherungsziel).",
        "Die Sicherungsplatte anschließen und einhängen.",
        "Mit dem ALTEN Sicherungs-Passwort die letzte Sicherung zurückholen (siehe unten). "
        "Danach gelten wieder die alten Schlüssel — verbundene Handys und dieser "
        "Einrichtungs-Code bleiben gültig.",
    ], nummeriert=True)
    # ⚠️ Das Passwort NACH sudo setzen: sudo verwirft die Umgebung des
    # Aufrufers, `SICHERUNG_PASSWORT=… sudo …` käme nie im Updater an.
    mit_pw = f"sudo SICHERUNG_PASSWORT=<Sicherungs-Passwort> python3 {srv}/fwapp_update.py --conf {srv}/fwapp.conf"
    pdf.code([
        f"{mit_pw} --sicherungen",
        f"{mit_pw} --zuruecksetzen <name>",
        f"sudo rm {data}/update.blocked",
    ])
    if conf.get("SICHERUNG_ZIEL", "").strip() not in ("", "lokal"):
        pdf.absatz("Die Sicherungsplatte wird über /etc/fstab eingehängt (UUID aus "
                   "„lsblk -f“; nofail = der Rechner startet auch ohne sie):")
        pdf.code([f"UUID=<uuid>  {conf['SICHERUNG_ZIEL'].strip()}  ext4  defaults,nofail  0  2"])

    kontakt = conf.get("KDM_KONTAKT", "").strip()
    pdf.abschnitt("7. Hilfe")
    pdf.absatz(
        (f"Kontakt dieser Installation: {kontakt}. " if kontakt else "")
        + "Fehler in der App und Wünsche: in der App unter Mehr → „Feedback senden“, oder als "
        "Issue auf github.com/MacBuchi/FWApp. Ausführliche Technik: docs/INSTALLATION.md im selben Repository."
    )
    return pdf.als_bytes(erstellt)


def dokument_mail(conf: dict[str, str], pdf: bytes, neu_eingerichtet: bool) -> EmailMessage:
    name = conf.get("NAME") or conf.get("DOMAIN", "FWApp")
    m = EmailMessage()
    m["From"] = conf.get("MAIL_ABSENDER", "")
    m["To"] = conf.get("KDM_EMAIL", "")
    m["Subject"] = f"FWApp: Einrichtungsdokument für {name}"
    anlass = ("der FWApp-Server ist eingerichtet." if neu_eingerichtet
              else "hier das Einrichtungsdokument, wie angefordert.")
    m.set_content(
        f"Hallo,\n\n{anlass}\n\n"
        "Im Anhang stehen alle Zugangsdaten, der Einrichtungs-Code für die Handys, die ersten "
        "Schritte und die Notfall-Befehle.\n\n"
        "WICHTIG: Das Dokument enthält Passwörter, darunter das Passwort der Sicherungen. "
        "Bitte ausdrucken, sicher ablegen und diese Mail danach löschen. Ohne das "
        "Sicherungs-Passwort lässt sich nach einem Ausfall des Servers keine Sicherung "
        "mehr lesen.\n\n"
        f"Web-App: {_url(conf)}\n"
    )
    datei = "".join(c if c.isalnum() else "-" for c in name).strip("-")
    m.add_attachment(pdf, maintype="application", subtype="pdf",
                     filename=f"FWApp-Einrichtung-{datei}.pdf")
    return m


def aus_server(conf: dict[str, str], env: dict[str, str], version: str,
               startpasswort: Optional[str] = None) -> bytes:
    """Baut das Dokument aus den Dateien einer laufenden Installation."""
    kopplung = Path(conf["DATA_DIR"], "kopplung", "fwapp.json").read_text().strip()
    return dokument(conf, version, kopplung, env.get("SICHERUNG_PASSWORT", ""), startpasswort)
