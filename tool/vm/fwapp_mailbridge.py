#!/usr/bin/env python3
"""fwapp_mailbridge.py – lokale SMTP-Annahme, Versand über die Brevo-HTTP-API.

Warum diese Brücke existiert (Issue #57 Etappe 1):
Die Betriebs-VM hat KEIN IPv4 (CGNAT/DS-Lite + Fritz!Box-ARP-Sperre) und
smtp-relay.brevo.com hat keinen AAAA-Eintrag — klassisches SMTP zu Brevo ist
von dieser VM aus unmöglich. api.brevo.com hat IPv6, aber Docker-Bridge-Netze
auf der VM haben keinen IPv6-Ausgang (gemessen am 2026-08-01: Bridge-Netz 000,
Host-Netz 401). Deshalb läuft diese Brücke als systemd-Dienst DIREKT AUF DEM
HOST: GoTrue spricht lokal SMTP, die Brücke übersetzt zur HTTP-API.

Bind-Adresse ist bewusst das Gateway des supabase_default-Netzes (172.18.0.1):
Container erreichen sie über ihre Default-Route, Geräte im LAN haben keine
Route dorthin — kein offener Relay-Port im Heimnetz.

Der API-Key liegt NUR auf der VM (~/brevo-api-key.txt, chmod 600) und wird
pro Versand frisch gelesen — ein Key-Tausch wirkt ohne Neustart.

Installation: siehe docs/SERVER-SETUP.md (Abschnitt Mail-Brücke).
"""

import email.parser
import email.policy
import email.utils
import json
import logging
import os
import signal
import urllib.error
import urllib.request

from aiosmtpd.controller import Controller

BIND_HOST = os.environ.get("MAILBRIDGE_BIND", "172.18.0.1")
BIND_PORT = int(os.environ.get("MAILBRIDGE_PORT", "2500"))
KEY_FILE = os.environ.get(
    "MAILBRIDGE_KEY_FILE", os.path.expanduser("~/brevo-api-key.txt")
)
API_URL = "https://api.brevo.com/v3/smtp/email"

log = logging.getLogger("mailbridge")


def api_key() -> str:
    with open(KEY_FILE, encoding="ascii") as f:
        return f.read().strip()


class BrevoHandler:
    async def handle_DATA(self, server, session, envelope):
        try:
            return self._weiterleiten(envelope)
        except Exception:
            log.exception("Weiterleitung fehlgeschlagen")
            return "451 Requested action aborted: local error in processing"

    def _weiterleiten(self, envelope):
        msg = email.parser.BytesParser(policy=email.policy.default).parsebytes(
            envelope.content
        )
        name, addr = email.utils.parseaddr(str(msg.get("From", "")))
        sender = {"email": addr or envelope.mail_from}
        if name:
            sender["name"] = name

        text = html = None
        for part in msg.walk():
            if part.get_content_maintype() == "multipart":
                continue
            ct = part.get_content_type()
            if ct == "text/plain" and text is None:
                text = part.get_content()
            elif ct == "text/html" and html is None:
                html = part.get_content()

        payload = {
            "sender": sender,
            "to": [{"email": r} for r in envelope.rcpt_tos],
            "subject": str(msg.get("Subject", "")),
        }
        if html:
            payload["htmlContent"] = html
        if text:
            payload["textContent"] = text
        if not (html or text):
            # Brevo verlangt mindestens einen Inhalt — leer ist keine Option.
            payload["textContent"] = "(kein Inhalt)"

        req = urllib.request.Request(
            API_URL,
            data=json.dumps(payload).encode(),
            headers={
                "api-key": api_key(),
                "content-type": "application/json",
                "accept": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                antwort = json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace")[:500]
            log.error("Brevo lehnt ab (%s): %s", e.code, body)
            # 451 statt 250: GoTrue soll den Fehlschlag sehen, nicht schlucken.
            return f"451 upstream rejected ({e.code})"

        log.info(
            "Angenommen: an %s, Brevo-Message-Id %s",
            ",".join(envelope.rcpt_tos),
            antwort.get("messageId"),
        )
        return "250 Message accepted for delivery"


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )
    api_key()  # Ohne lesbaren Key soll der Dienst gar nicht erst starten.
    controller = Controller(BrevoHandler(), hostname=BIND_HOST, port=BIND_PORT)
    controller.start()
    log.info("Mail-Brücke lauscht auf %s:%d", BIND_HOST, BIND_PORT)
    signal.sigwait({signal.SIGTERM, signal.SIGINT})
    controller.stop()


if __name__ == "__main__":
    main()
