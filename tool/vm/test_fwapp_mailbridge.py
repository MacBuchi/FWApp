"""test_fwapp_mailbridge.py – Was die Mail-Brücke an Brevo weiterreicht.

Geprüft wird die AUSGELIEFERTE Datei (fwapp_mailbridge.py), mit derselben
Attrappe für aiosmtpd wie test/vm/mailbridge_probe.py — das Paket gibt es
nur auf der VM. Statt Brevo zu rufen, merkt sich der Test die Nutzlast.

Anlass (2026-09-24): Der Wochenbericht hängt die Logs als ZIP an. Die Brücke
verwarf Anhänge bis dahin still — der Bericht wäre auf unserer VM ohne Logs
angekommen, und niemand hätte es bemerkt.
"""
import importlib.util
import json
import sys
import types
import unittest
from email.message import EmailMessage
from pathlib import Path

_ctrl = types.ModuleType("aiosmtpd.controller")
_ctrl.Controller = object
sys.modules.setdefault("aiosmtpd", types.ModuleType("aiosmtpd"))
sys.modules.setdefault("aiosmtpd.controller", _ctrl)

_spec = importlib.util.spec_from_file_location(
    "fwapp_mailbridge", Path(__file__).with_name("fwapp_mailbridge.py"))
bruecke = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bruecke)


class _Antwort:
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self):
        return b'{"messageId": "<test>"}'


class _Umschlag:
    def __init__(self, nachricht: EmailMessage):
        self.content = nachricht.as_bytes()
        self.rcpt_tos = [nachricht["To"]]
        self.mail_from = nachricht["From"]


class Weiterleiten(unittest.TestCase):
    def setUp(self):
        self.gesendet = []
        self._alt = (bruecke.urllib.request.urlopen, bruecke.api_key)
        bruecke.urllib.request.urlopen = lambda req, timeout=0: (
            self.gesendet.append(json.loads(req.data)) or _Antwort())
        bruecke.api_key = lambda: "xkeysib-test"

    def tearDown(self):
        bruecke.urllib.request.urlopen, bruecke.api_key = self._alt

    def schicken(self, nachricht):
        antwort = bruecke.BrevoHandler()._weiterleiten(_Umschlag(nachricht))
        self.assertTrue(antwort.startswith("250"), antwort)
        return self.gesendet[-1]

    def nachricht(self):
        m = EmailMessage()
        m["From"] = "FWApp <noreply@x.de>"
        m["To"] = "betrieb@x.de"
        m["Subject"] = "FWApp-Wochenbericht: ✅ alles in Ordnung"
        m.set_content("Bericht")
        return m

    def test_anhang_kommt_bei_brevo_an(self):
        m = self.nachricht()
        m.add_attachment(b"PK\x03\x04zip", maintype="application", subtype="zip",
                         filename="fwapp-logs.zip")
        nutzlast = self.schicken(m)
        self.assertEqual(nutzlast["textContent"].strip(), "Bericht")
        self.assertEqual(nutzlast["attachment"],
                         [{"name": "fwapp-logs.zip", "content": "UEsDBHppcA=="}])

    def test_text_anhang_wird_nicht_zum_mailtext(self):
        m = self.nachricht()
        m.add_attachment("update.log Inhalt", filename="update.log")
        nutzlast = self.schicken(m)
        self.assertEqual(nutzlast["textContent"].strip(), "Bericht")
        self.assertEqual(nutzlast["attachment"][0]["name"], "update.log")

    def test_ohne_anhang_kein_feld(self):
        # Brevo lehnt ein leeres attachment-Feld ab.
        self.assertNotIn("attachment", self.schicken(self.nachricht()))


if __name__ == "__main__":
    unittest.main()
