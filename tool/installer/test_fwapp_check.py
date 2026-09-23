"""test_fwapp_check.py – Die Vorab-Prüfung (#240) ohne Netz.

Läuft in CI (Job „Analyze & Test"):
    python3 -m unittest discover -s tool/installer -p 'test_*.py'

Geprüft wird jede Regel einzeln: Schwellen, Sätze, und vor allem der
Mail-Code — er ist der Grund, warum es diese Prüfung gibt (#121: der Server
nahm die Mail an, angekommen ist sie nie).
"""
import contextlib
import io
import smtplib
import ssl
import unittest

import fwapp_check as c

GIB = 1024**3


class FakeSmtp:
    def __init__(self, login_fehler=None, versand_fehler=None):
        self.login_fehler = login_fehler
        self.versand_fehler = versand_fehler
        self.angemeldet = None
        self.gesendet = []

    def login(self, user, pw):
        if self.login_fehler:
            raise self.login_fehler
        self.angemeldet = (user, pw)

    def send_message(self, m):
        if self.versand_fehler:
            raise self.versand_fehler
        self.gesendet.append(m)


CONF = {
    "DOMAIN": "app.musterstadt.de",
    "SMTP_HOST": "smtp.example.org",
    "SMTP_PORT": "587",
    "SMTP_USER": "u",
    "SMTP_PASS": "p",
    "MAIL_ABSENDER": "app@musterstadt.de",
    "TEST_EMPFAENGER": "kdm@musterstadt.de",
}


class Konfiguration(unittest.TestCase):
    def test_liest_datei_und_umgebung_gewinnt(self):
        conf = c.lies_conf(
            "# Kommentar\nDOMAIN=a.de\nNAME=\"Feuerwehr X\"\nSMTP_PASS=aus_datei\n\nkaputt\n",
            {"SMTP_PASS": "aus_umgebung", "HOME": "/x"},
        )
        self.assertEqual(conf["DOMAIN"], "a.de")
        self.assertEqual(conf["NAME"], "Feuerwehr X")
        # Das Passwort muss nicht in der Datei stehen.
        self.assertEqual(conf["SMTP_PASS"], "aus_umgebung")
        # Fremde Umgebungsvariablen landen nicht in der Konfiguration.
        self.assertNotIn("HOME", conf)


class Rechner(unittest.TestCase):
    def test_architektur(self):
        self.assertEqual(c.pruefe_architektur("x86_64").stufe, c.OK)
        self.assertEqual(c.pruefe_architektur("aarch64").stufe, c.OK)
        e = c.pruefe_architektur("armv7l")
        self.assertEqual(e.stufe, c.FEHLER)
        self.assertIn("64-bit", e.hinweis)

    def test_speicher_schwelle_bei_3_5_gib(self):
        # Eine 4-GB-VM meldet etwas weniger als 4 GiB — sie muss durchgehen.
        self.assertEqual(c.pruefe_speicher(int(3.8 * GIB)).stufe, c.OK)
        self.assertEqual(c.pruefe_speicher(2 * GIB).stufe, c.FEHLER)
        self.assertEqual(c.pruefe_speicher(None).stufe, c.HINWEIS)

    def test_platte(self):
        self.assertEqual(c.pruefe_platte(10 * GIB, "/srv").stufe, c.FEHLER)
        self.assertEqual(c.pruefe_platte(20 * GIB, "/srv").stufe, c.WARNUNG)
        self.assertEqual(c.pruefe_platte(100 * GIB, "/srv").stufe, c.OK)

    def test_sd_karte_nur_bei_mmcblk(self):
        self.assertEqual(c.pruefe_sd_karte("/dev/mmcblk0p2").stufe, c.WARNUNG)
        self.assertIsNone(c.pruefe_sd_karte("/dev/nvme0n1p2"))
        self.assertIsNone(c.pruefe_sd_karte(None))

    def test_uhr(self):
        self.assertEqual(c.pruefe_uhr(True).stufe, c.OK)
        self.assertIn("timedatectl", c.pruefe_uhr(False).hinweis)
        self.assertEqual(c.pruefe_uhr(None).stufe, c.HINWEIS)


class DomainUndHttps(unittest.TestCase):
    def test_dns(self):
        self.assertEqual(c.pruefe_dns("a.de", lambda d: ["1.2.3.4"]).stufe, c.OK)
        self.assertEqual(c.pruefe_dns("a.de", lambda d: []).stufe, c.FEHLER)

        def kaputt(d):
            raise OSError("Name or service not known")

        self.assertEqual(c.pruefe_dns("a.de", kaputt).stufe, c.FEHLER)
        self.assertEqual(c.pruefe_dns("", kaputt).stufe, c.FEHLER)

    def _holen(self, antworten):
        def holen(url, apikey=None):
            for teil, antwort in antworten.items():
                if teil in url:
                    if isinstance(antwort, Exception):
                        raise antwort
                    return antwort
            raise AssertionError(url)

        return holen

    def test_alles_gut(self):
        datei = '{"fwapp":1,"url":"https://app.x.de","anon_key":"k"}'
        e = c.pruefe_https(
            "app.x.de",
            self._holen({"well-known": (200, datei), "health": (200, "{}")}),
        )
        self.assertEqual([x.stufe for x in e], [c.OK, c.OK, c.OK])

    def test_zertifikat_und_unerreichbar(self):
        e = c.pruefe_https("x.de", self._holen({"well-known": ssl.SSLError("bad cert")}))
        self.assertEqual(e[0].stufe, c.FEHLER)
        self.assertIn("Zertifikat", e[0].titel)
        e = c.pruefe_https("x.de", self._holen({"well-known": OSError("timeout")}))
        self.assertIn("nicht erreichbar", e[0].titel)

    def test_fehlende_einrichtungsdatei_ist_nur_warnung(self):
        # Der Server läuft, nur die Kopplung per QR/Domain geht nicht.
        e = c.pruefe_https("x.de", self._holen({"well-known": (404, "")}))
        self.assertEqual(e[-1].stufe, c.WARNUNG)
        self.assertIn("fwapp_kopplung.sh", e[-1].hinweis)

    def test_server_lehnt_ab(self):
        datei = '{"fwapp":1,"url":"https://app.x.de","anon_key":"k"}'
        e = c.pruefe_https(
            "x.de", self._holen({"well-known": (200, datei), "health": (401, "")})
        )
        self.assertEqual(e[-1].stufe, c.FEHLER)


class MailDns(unittest.TestCase):
    def test_spf_dmarc_dkim(self):
        self.assertEqual(c.pruefe_spf(["v=spf1 include:x -all"], "a.de").stufe, c.OK)
        self.assertEqual(c.pruefe_spf(["google-site-verification=1"], "a.de").stufe, c.WARNUNG)
        self.assertEqual(c.pruefe_dmarc(["v=DMARC1; p=none"], "a.de").stufe, c.OK)
        self.assertEqual(c.pruefe_dmarc([], "a.de").stufe, c.WARNUNG)
        self.assertEqual(c.pruefe_dkim(None, "", "a.de").stufe, c.HINWEIS)
        self.assertEqual(c.pruefe_dkim(["k=rsa; p=MIGf"], "brevo1", "a.de").stufe, c.OK)
        self.assertEqual(c.pruefe_dkim([], "brevo1", "a.de").stufe, c.WARNUNG)


class Mail(unittest.TestCase):
    def test_smtp_anmeldung(self):
        fake = FakeSmtp()
        e, v = c.pruefe_smtp(CONF, lambda h, p: fake)
        self.assertEqual(e.stufe, c.OK)
        self.assertIs(v, fake)
        self.assertEqual(fake.angemeldet, ("u", "p"))

    def test_smtp_fehler_werden_saetze(self):
        e, v = c.pruefe_smtp(
            CONF,
            lambda h, p: FakeSmtp(login_fehler=smtplib.SMTPAuthenticationError(535, b"no")),
        )
        self.assertEqual(e.stufe, c.FEHLER)
        self.assertIn("SMTP-Schlüssel", e.hinweis)
        self.assertIsNone(v)

        def weg(h, p):
            raise OSError("Connection refused")

        e, _ = c.pruefe_smtp(CONF, weg)
        self.assertIn("nicht erreichbar", e.titel)
        e, _ = c.pruefe_smtp({}, weg)
        self.assertIn("SMTP_HOST", e.titel)

    def test_der_richtige_code_bestaetigt_den_empfang(self):
        fake = FakeSmtp()
        e = c.pruefe_mail_code(CONF, fake, lambda _: "123 456", code="123456")
        self.assertEqual(e.stufe, c.OK)
        # Der Code steht in der Mail — sonst gäbe es nichts zurückzutippen.
        self.assertIn("123456", fake.gesendet[0].get_content())
        self.assertEqual(fake.gesendet[0]["To"], "kdm@musterstadt.de")

    def test_falscher_code_dreimal_blockiert(self):
        antworten = iter(["111111", "222222", "333333"])
        with contextlib.redirect_stdout(io.StringIO()):
            e = c.pruefe_mail_code(CONF, FakeSmtp(), lambda _: next(antworten), code="123456")
        self.assertEqual(e.stufe, c.FEHLER)

    def test_abbrechen_blockiert(self):
        e = c.pruefe_mail_code(CONF, FakeSmtp(), lambda _: "", code="123456")
        self.assertEqual(e.stufe, c.FEHLER)

    def test_ohne_rueckfrage_nur_warnung(self):
        # „Angenommen" ist nicht „angekommen" — deshalb kein ✅.
        e = c.pruefe_mail_code(CONF, FakeSmtp(), None)
        self.assertEqual(e.stufe, c.WARNUNG)
        self.assertIn("nicht bestätigt", e.titel)

    def test_versand_abgelehnt_und_fehlende_adressen(self):
        e = c.pruefe_mail_code(
            CONF, FakeSmtp(versand_fehler=smtplib.SMTPRecipientsRefused({})), None
        )
        self.assertEqual(e.stufe, c.FEHLER)
        e = c.pruefe_mail_code({"MAIL_ABSENDER": "a@b.de"}, FakeSmtp(), None)
        self.assertIn("TEST_EMPFAENGER", e.hinweis)


class Ausgabe(unittest.TestCase):
    def test_exitcode_haengt_nur_an_fehlern(self):
        with contextlib.redirect_stdout(io.StringIO()) as aus:
            code = c.ausgabe([("A", [c.Ergebnis(c.OK, "gut"), c.Ergebnis(c.WARNUNG, "na", "tu was")])])
        self.assertEqual(code, 0)
        self.assertIn("→ tu was", aus.getvalue())
        with contextlib.redirect_stdout(io.StringIO()):
            code = c.ausgabe([("A", [c.Ergebnis(c.FEHLER, "kaputt")])])
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
