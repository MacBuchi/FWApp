"""test_fwapp_qr.py – Der QR-Encoder für das Einrichtungsdokument (#249).

Ein falsch erzeugter QR-Code fällt erst auf, wenn ihn im Gerätehaus jemand
nicht scannen kann. Deshalb vergleicht dieser Test Modul für Modul mit der
Referenz-Implementierung von Project Nayuki (Python-Paket `qrcodegen`, MIT),
nach deren Beschreibung `fwapp_qr.py` gebaut ist. Die Muster unten hat sie
erzeugt (Stufe M, Byte-Modus, automatische Maskenwahl) — je Zeile eine
Hex-Zahl, höchstes Bit = linkes Modul.

Beim Bau zusätzlich geprüft (nicht in CI, braucht macOS bzw. pip):
281 Codes über die Versionen 1–20 mit qrcodegen identisch, und der
Kopplungs-QR vom QR-Erkenner von macOS exakt zurückgelesen, Umlaute
inklusive. ⚠️ segno taugt NICHT als Referenz: Es hängt an einer
Byte-Grenze ein zusätzliches Null-Byte an — gültig, aber ein anderer Code.
"""
import unittest

import fwapp_qr as q

REFERENZ = {
    'FWApp': (
        "1fc27f 104c41 17515d 17525d "
        "175d5d 105e41 1fd57f 1400 "
        "17c27c 8a3ce 4656a 1a3cd "
        "a5126 1124 1fca9e 10583e "
        "175a9a 175be4 175d64 1047ec "
        "1fd52a "
    ),
    'https://app.musterstadt.de': (
        "1fd757f 105ed41 174685d 1759e5d "
        "174835d 1047141 1fd557f 10100 "
        "16ed44b 1fa65a2 8c71b0 1502b2c "
        "c5bfd7 83e771 b49816 1030771 "
        "5429ff 17b15 1fd1557 105b713 "
        "17445f9 175245f 175a3d6 10438d4 "
        "1fdb83f "
    ),
    '{"fwapp": 1, "name": "Feuerwehr Müßingen", "url": "https://app.feuerwehr-musterstadt.de", "anon_key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"}': (
        "1fc69bb0eb06b027f 1047cb0e21ac1a141 175a5a05803da355d 1752666c334ef0e5d "
        "175ae5a07e951095d 1059cc5ec733ccc41 1fd5555555555557f 1796c8c61183800 "
        "17c9f39d7de6f417c d846d32130e8a40c b7c9008f6c84c024 c3d85696a370143b "
        "865e4f92382bcbf3 1817962e13858bc1d f4717637562dfa40 f3ba227c53058858 "
        "7c3685be7cef8bf8 522df46c08f38e0a 16dfc536af00df1f0 18128eaaff71e5248 "
        "ef5b49323c0b4d3f 1f0963b420be1be13 ad29b84deae366dc 1efd18609147f15 "
        "6ebd19aaf8e9ac78 170166cc42ad1ae0a beaa1260a24e22d9 1382ab96f0b1cfd8a "
        "11c364302b2e9eb55 429b9ee63a61be86 3f17ed87fabd3ff6 13160db2c5e85e518 "
        "158ec8b5653e5356 1d1c6c9044f94fd17 17f8a2e07e17a19f8 1d0a6a0ba8b57375b "
        "167aad805742f85c2 12ab97284e9531533 243097d836bf513e 158b69f9016cd97c8 "
        "1ffd227b9746fa183 10ac32246d3cab4b0 c6ce02db779de18c d3917966ad85ae59 "
        "105d376ee966f054a 39e75f04e9618c77 187ee001e363c7218 14071d52061be61bb "
        "34d152789e214d39 1b18723e6bbe3bc75 f6b58f7302d8340c 513066fe471c99d0 "
        "a6df7996f6230924 c3f671c26ac38d5d 6f134f8a2aed823c 122d4cbc7cd90f5cb "
        "d5d5337fdc8321f6 11e8b646ac0a715 1fc0a887d60091b53 1056b08e463dc5d19 "
        "17500faaffa6d69fe 1756c0115fb61bd66 1751f1a7e7f8a6632 104d2445e306b2b0a "
        "1fd414ffd5ac1ac44 "
    ),
}


def _matrix(zeilen: str, groesse: int) -> list[list[bool]]:
    return [[c == "1" for c in format(int(z, 16), f"0{groesse}b")] for z in zeilen.split()]


class Referenz(unittest.TestCase):
    def test_modul_fuer_modul_wie_die_referenz(self):
        for text, zeilen in REFERENZ.items():
            groesse = len(zeilen.split())
            with self.subTest(bytes=len(text.encode())):
                self.assertEqual(q.qr_matrix(text), _matrix(zeilen, groesse))

    def test_kopplungs_qr_ist_version_12(self):
        """Mit dem Anon-Key rund 260 Bytes — der Fall, den der Aushang hat."""
        text = [t for t in REFERENZ if t.startswith("{")][0]
        self.assertEqual(len(q.qr_matrix(text)), 12 * 4 + 17)


class Grenzen(unittest.TestCase):
    def test_kapazitaet_stufe_m(self):
        # Norm, Tabelle 9: Datencodewörter bei Stufe M; Version 20 hat
        # 3 Blöcke à 41 und 13 à 42.
        self.assertEqual([q.datenkapazitaet(v) for v in (1, 2, 10, 20)], [16, 28, 216, 669])

    def test_die_letzte_passende_laenge(self):
        # 669 Codewörter minus Modus (4 Bit) und Länge (16 Bit) = 666 Bytes.
        self.assertEqual(len(q.qr_matrix("x" * 666)), 20 * 4 + 17)
        with self.assertRaises(ValueError):
            q.qr_matrix("x" * 667)


if __name__ == "__main__":
    unittest.main()
