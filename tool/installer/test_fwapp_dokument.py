"""test_fwapp_dokument.py – Das Einrichtungsdokument (#249) und sein PDF.

Ein PDF, das kein Leser öffnet, oder eine Anleitung mit Knöpfen, die es
nicht gibt, fiele erst beim KreisDatenMeister auf. Deshalb: Aufbau der
Datei, Inhalt samt Passwörtern, Umbruch, und — am wichtigsten — dass jede
Beschriftung, die die Anleitung zitiert, wirklich in der App steht.

Beim Bau zusätzlich geprüft (nicht in CI, braucht macOS): alle Seiten mit
PDFKit gerendert und angesehen, und der QR-Code AUS der gerenderten Seite
mit dem QR-Erkenner von macOS exakt zurückgelesen.
"""
import re
import unittest
from email import message_from_bytes
from pathlib import Path

import fwapp_dokument as d
import fwapp_install as inst
import fwapp_pdf as p

CONF = {
    "NAME": "Feuerwehr Müßingen",
    "DOMAIN": "app.feuerwehr-muessingen.de",
    "ERREICHBARKEIT": "caddy",
    "DATA_DIR": "/srv/fwapp",
    "KDM_EMAIL": "kdm@landkreis.de",
    "MAIL_ABSENDER": "app@feuerwehr-muessingen.de",
    "SICHERUNG_ZIEL": "/mnt/fwapp-sicherung",
}
KOPPLUNG = '{"fwapp": 1, "name": "Feuerwehr Müßingen", "url": "https://app.feuerwehr-muessingen.de", "anon_key": "eyJx.eyJy.z"}'


def _text(pdf: bytes) -> str:
    """Alle Textstücke der Seiten, wie sie im (unkomprimierten) Strom stehen."""
    roh = pdf.decode("cp1252")
    stuecke = re.findall(r"\((.*?)\) Tj", roh)
    return " ".join(s.replace("\\(", "(").replace("\\)", ")").replace("\\\\", "\\") for s in stuecke)


class Aufbau(unittest.TestCase):
    def setUp(self):
        self.pdf = d.dokument(CONF, "v1.64.0", KOPPLUNG, "SICHER123passwort", "Start456", erstellt=0)

    def test_eine_gueltige_pdf_datei(self):
        self.assertTrue(self.pdf.startswith(b"%PDF-1.4"))
        self.assertTrue(self.pdf.rstrip().endswith(b"%%EOF"))
        # Jeder Eintrag der Querverweistabelle zeigt genau auf sein Objekt —
        # sonst „reparieren" Leser die Datei oder verweigern sie.
        xref = int(re.search(rb"startxref\n(\d+)", self.pdf).group(1))
        eintraege = re.findall(rb"(\d{10}) 00000 n", self.pdf[xref:])
        for nr, versatz in enumerate(eintraege, 1):
            self.assertTrue(self.pdf[int(versatz):].startswith(f"{nr} 0 obj".encode()), nr)

    def test_seitenzahlen_stimmen(self):
        anzahl = len(re.findall(rb"/Type /Page ", self.pdf))
        self.assertGreaterEqual(anzahl, 2)
        self.assertIn(f"Seite {anzahl} von {anzahl}", _text(self.pdf))

    def test_umlaute_als_winansi(self):
        self.assertIn("Feuerwehr Müßingen".encode("cp1252"), self.pdf)


class Inhalt(unittest.TestCase):
    def test_alle_zugangsdaten_und_passwoerter(self):
        text = _text(d.dokument(CONF, "v1.64.0", KOPPLUNG, "SICHER123passwort", "Start456"))
        for erwartet in ("https://app.feuerwehr-muessingen.de", "kdm@landkreis.de", "Start456",
                         "SICHER123passwort", "v1.64.0", "Vertraulich"):
            self.assertIn(erwartet, text)

    def test_spaeter_ohne_startpasswort(self):
        """--dokument kennt das Startpasswort nicht mehr (und es ist dann
        längst geändert)."""
        text = _text(d.dokument(CONF, "v1.64.0", KOPPLUNG, "SICHER123passwort"))
        self.assertIn("bei der Einrichtung vergeben", text)
        self.assertIn("SICHER123passwort", text)

    def test_befehle_mit_den_pfaden_dieser_installation(self):
        text = _text(d.dokument({**CONF, "DATA_DIR": "/daten/fw"}, "v1", KOPPLUNG, "x"))
        self.assertIn("/daten/fw/server/fwapp_update.py", text)
        self.assertIn("sudo rm /daten/fw/update.blocked", text)

    def test_passwort_steht_nach_sudo(self):
        """⚠️ sudo verwirft die Umgebung des Aufrufers — `VAR=… sudo …` käme
        im Updater nie an, die Wiederherstellung nach einem Totalausfall
        scheiterte am falschen Passwort."""
        text = _text(d.dokument(CONF, "v1", KOPPLUNG, "x"))
        self.assertIn("sudo SICHERUNG_PASSWORT=", text)
        self.assertNotRegex(text, r"SICHERUNG_PASSWORT=\S+ sudo")

    def test_fstab_nur_bei_externer_platte(self):
        mit = _text(d.dokument(CONF, "v1", KOPPLUNG, "x"))
        ohne = _text(d.dokument({**CONF, "SICHERUNG_ZIEL": "lokal"}, "v1", KOPPLUNG, "x"))
        self.assertIn("nofail", mit)
        self.assertNotIn("nofail", ohne)


class Anleitung(unittest.TestCase):
    """Die Anleitung nennt Knöpfe beim Namen. Wird einer umbenannt, soll die
    CI rot werden — nicht der KreisDatenMeister vor einem Knopf stehen, den
    es nicht gibt."""

    ZITIERT = (
        "Mit anderem Server verbinden", "QR-Code scannen", "Ich habe eine Einladung",
        "KreisDatenMeister", "Wehr anlegen", "Anlegen und einladen", "Kommandant hinzufügen",
        "Stilllegen", "Reaktivieren", "Feedback senden", "Einstellungen", "Mehr", "Aktionen",
    )

    def test_jede_zitierte_beschriftung_steht_in_der_app(self):
        quellen = " ".join(f.read_text() for f in (inst.REPO / "lib").rglob("*.dart"))
        text = _text(d.dokument(CONF, "v1", KOPPLUNG, "x"))
        for beschriftung in self.ZITIERT:
            with self.subTest(beschriftung=beschriftung):
                self.assertIn(beschriftung, text, "steht nicht (mehr) in der Anleitung")
                self.assertRegex(quellen, rf"'{re.escape(beschriftung)}'",
                                 "gibt es in der App nicht (mehr)")


class Umbruch(unittest.TestCase):
    def test_keine_zeile_breiter_als_die_seite(self):
        lang = "Einrichtungsdokument " * 40 + "Donaudampfschifffahrtsgesellschaftskapitän"
        for fett in (False, True):
            for z in p.umbrechen(lang, 10.5, p.NUTZBAR, fett):
                if " " in z:
                    self.assertLessEqual(p.breite(z, 10.5, fett), p.NUTZBAR)

    def test_befehle_nur_an_leerzeichen_umbrochen(self):
        """Die erste Fassung brach mitten im Wort um — abgetippt ein anderer
        Befehl. Zusammengesetzt wie von der Shell muss das Original
        herauskommen."""
        befehl = "sudo python3 /srv/fwapp/server/fwapp_update.py --conf /srv/fwapp/server/fwapp.conf --zuruecksetzen <name>"
        pdf = p.Pdf("t", "f")
        pdf.code([befehl])
        zeilen = re.findall(r"\((.*?)\) Tj", "\n".join(pdf.seiten[0]))
        shell = "".join(z[:-2] + " " if z.endswith(" \\\\") else z for z in zeilen)
        self.assertEqual(" ".join(shell.split()), befehl)
        self.assertTrue(all(z.endswith("\\\\") for z in zeilen[:-1]))

    def test_zeichen_ausserhalb_von_winansi_brechen_nichts(self):
        self.assertEqual(p._text("Mehr → Einstellungen ✓"), "Mehr › Einstellungen OK")
        self.assertEqual(p._text("🚒"), "?")


class Mail(unittest.TestCase):
    def test_pdf_als_anhang_an_den_kreisdatenmeister(self):
        m = d.dokument_mail(CONF, b"%PDF-1.4 x", neu_eingerichtet=True)
        self.assertEqual(m["To"], "kdm@landkreis.de")
        geparst = message_from_bytes(m.as_bytes())
        anhaenge = [t for t in geparst.walk() if t.get_content_type() == "application/pdf"]
        self.assertEqual(len(anhaenge), 1)
        self.assertEqual(anhaenge[0].get_filename(), "FWApp-Einrichtung-Feuerwehr-Müßingen.pdf")
        self.assertIn("ausdrucken", m.get_body(("plain",)).get_content())


class Bereitstellung(unittest.TestCase):
    def test_der_installer_legt_die_module_auf_den_server(self):
        """--dokument läuft aus server/ — fehlt dort ein Modul, bricht es erst
        beim KreisDatenMeister ab."""
        text = (inst.HIER / "fwapp_install.py").read_text()
        for modul in ("fwapp_dokument.py", "fwapp_pdf.py", "fwapp_qr.py"):
            self.assertIn(f'"{modul}"', text)
        self.assertTrue(all((inst.HIER / m).exists() for m in ("fwapp_dokument.py", "fwapp_pdf.py", "fwapp_qr.py")))
        self.assertIn(Path("tool/installer/fwapp_qr.py").name, [f.name for f in inst.HIER.iterdir()])


if __name__ == "__main__":
    unittest.main()
