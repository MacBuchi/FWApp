"""fwapp_pdf.py – Ein kleiner PDF-Schreiber ohne Fremdpakete (#249).

Gerade genug für das Einrichtungsdokument: A4, Überschriften, Absätze mit
Umbruch, Aufzählungen, Feld-Wert-Zeilen, Befehle in Schreibmaschinenschrift,
hervorgehobene Kästen, ein QR-Code als Vektorgrafik, Fußzeile mit
„Seite x von y".

Die Schriften sind die 14 Standardschriften, die jeder PDF-Leser kennt
(Helvetica, Helvetica-Bold, Courier) — nichts wird eingebettet. Kodiert
wird in WinAnsi (cp1252): Umlaute, ß, „ " – — • gehen, Pfeile und Emojis
nicht; `_text` ersetzt, was fehlt, statt abzubrechen.

⚠️ Der Zeilenumbruch braucht die Breite jedes Zeichens. Die Tabelle unten
sind die Werte aus den Adobe-Metriken (AFM) für Helvetica; für die fette
Schnittbreite wird aufgeschlagen, und der Umbruch lässt Luft. Ein zu breit
geschätztes Wort bricht eine Zeile früher um — harmlos. Ein zu schmal
geschätztes liefe über den Rand, deshalb lieber breiter.
"""
from __future__ import annotations

import time
from typing import Optional

BREITE, HOEHE = 595.28, 841.89  # A4 in Punkt
RAND_L, RAND_R, RAND_O, RAND_U = 56.0, 56.0, 60.0, 64.0
NUTZBAR = BREITE - RAND_L - RAND_R

# Helvetica, Breiten in 1/1000 der Schriftgröße (AFM), ASCII 32–126.
_HELV = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
    1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
    333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
    556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
]
_SONDER = {"ä": 556, "ö": 556, "ü": 556, "Ä": 667, "Ö": 778, "Ü": 722, "ß": 611,
           "„": 333, "“": 333, "”": 333, "‚": 222, "‘": 222, "’": 222, "–": 556,
           "—": 1000, "•": 350, "é": 556, "€": 556, "…": 1000, "·": 278, "›": 333, "‹": 333,
           "»": 556, "«": 556}
# Pfeile gibt es in WinAnsi nicht; „›" liest sich in einem Menüweg genauso.
_ERSATZ = {"→": "›", "←": "<-", "✓": "OK", "✗": "X", "⚠": "!", " ": " "}


def _text(s: str) -> str:
    for alt, neu in _ERSATZ.items():
        s = s.replace(alt, neu)
    return s.encode("cp1252", "replace").decode("cp1252")


def breite(s: str, groesse: float, fett: bool = False, mono: bool = False) -> float:
    if mono:
        return len(s) * 600 * groesse / 1000
    summe = 0
    for c in s:
        o = ord(c)
        summe += _HELV[o - 32] if 32 <= o <= 126 else _SONDER.get(c, 700)
    return summe * groesse / 1000 * (1.08 if fett else 1.0)


def umbrechen(text: str, groesse: float, max_breite: float, fett: bool = False,
              mono: bool = False) -> list[str]:
    zeilen = []
    for absatz in text.split("\n"):
        zeile = ""
        for wort in absatz.split(" "):
            probe = f"{zeile} {wort}" if zeile else wort
            if breite(probe, groesse, fett, mono) <= max_breite * 0.97 or not zeile:
                zeile = probe
            else:
                zeilen.append(zeile)
                zeile = wort
        zeilen.append(zeile)
    return zeilen


def _pdf_string(s: str) -> str:
    s = _text(s).replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    return f"({s})"


class Pdf:
    SCHRIFT = {"normal": "F1", "fett": "F2", "mono": "F3"}

    def __init__(self, titel: str, fusszeile: str):
        self.titel = titel
        self.fusszeile = fusszeile
        self.seiten: list[list[str]] = []
        self._neue_seite()

    # Seiten

    def _neue_seite(self) -> None:
        self.seiten.append([])
        self.y = HOEHE - RAND_O

    def platz(self, hoehe: float) -> None:
        """Bricht um, wenn der nächste Block nicht mehr passt."""
        if self.y - hoehe < RAND_U:
            self._neue_seite()

    def _ops(self, op: str) -> None:
        self.seiten[-1].append(op)

    def _zeile(self, x: float, text: str, groesse: float, art: str = "normal",
               grau: float = 0.0) -> None:
        self._ops(f"BT /{self.SCHRIFT[art]} {groesse:.1f} Tf {grau:.2f} g "
                  f"{x:.2f} {self.y:.2f} Td {_pdf_string(text)} Tj ET")

    # Bausteine

    def abstand(self, pt: float) -> None:
        self.y -= pt

    def titel_block(self, titel: str, untertitel: str) -> None:
        self.platz(60)
        self.y -= 22
        self._zeile(RAND_L, titel, 22, "fett")
        self.y -= 20
        self._zeile(RAND_L, untertitel, 11, grau=0.35)
        self.y -= 14
        self._ops(f"0.78 0.16 0.16 RG 2 w {RAND_L:.2f} {self.y:.2f} m "
                  f"{BREITE - RAND_R:.2f} {self.y:.2f} l S 0 G")
        self.y -= 12

    def abschnitt(self, text: str) -> None:
        self.platz(48)
        self.y -= 22
        self._ops(f"0.78 0.16 0.16 rg {RAND_L:.2f} {self.y - 3:.2f} 4 16 re f 0 g")
        self._zeile(RAND_L + 10, text, 14, "fett")
        self.y -= 10

    def absatz(self, text: str, groesse: float = 10.5, art: str = "normal",
               einzug: float = 0.0) -> None:
        zeilen = umbrechen(text, groesse, NUTZBAR - einzug, art == "fett")
        for z in zeilen:
            self.platz(groesse * 1.45)
            self.y -= groesse * 1.45
            self._zeile(RAND_L + einzug, z, groesse, art)
        self.y -= 5

    def liste(self, punkte: list[str], nummeriert: bool = False, groesse: float = 10.5) -> None:
        for i, punkt in enumerate(punkte, 1):
            marke = f"{i}." if nummeriert else "•"
            zeilen = umbrechen(punkt, groesse, NUTZBAR - 18)
            for j, z in enumerate(zeilen):
                self.platz(groesse * 1.45)
                self.y -= groesse * 1.45
                if j == 0:
                    self._zeile(RAND_L + 2, marke, groesse, "fett" if nummeriert else "normal")
                self._zeile(RAND_L + 18, z, groesse)
            self.y -= 3
        self.y -= 4

    def felder(self, paare: list[tuple[str, str]], hervorheben: tuple[str, ...] = ()) -> None:
        spalte = 150.0
        for name, wert in paare:
            mono = name in hervorheben
            zeilen = umbrechen(wert, 11 if mono else 10.5, NUTZBAR - spalte, mono=mono)
            self.platz(15 * len(zeilen) + 4)
            self.y -= 15
            self._zeile(RAND_L, name, 10.5, "fett")
            for j, z in enumerate(zeilen):
                if j:
                    self.y -= 15
                if mono:
                    w = breite(z, 11, mono=True)
                    self._ops(f"0.93 g {RAND_L + spalte - 3:.2f} {self.y - 4:.2f} "
                              f"{w + 6:.2f} 16 re f 0 g")
                self._zeile(RAND_L + spalte, z, 11 if mono else 10.5, "mono" if mono else "normal")
            self.y -= 4
        self.y -= 6

    def code(self, zeilen: list[str], groesse: float = 8.6) -> None:
        """Befehle zum Abtippen: Schreibmaschinenschrift, grauer Kasten.

        ⚠️ Umbrochen wird nur an Leerzeichen, mit „ \\" am Zeilenende — so
        bleibt der Befehl abgetippt gültig (die Shell setzt die Zeilen
        wieder zusammen). Die erste Fassung brach mitten im Wort um
        („--sic \\ herungen"), und das ergibt einen anderen Befehl. Lange
        Kästen laufen über die Seitengrenze weiter, statt eine halbe Seite
        leer zu lassen."""
        max_zeichen = int((NUTZBAR - 16) / (0.6 * groesse))
        passend: list[str] = []
        for z in zeilen:
            while len(z) > max_zeichen:
                schnitt = z.rfind(" ", 0, max_zeichen - 2)
                if schnitt <= 4:
                    schnitt = max_zeichen - 2  # ein einzelnes überlanges Wort
                passend.append(z[:schnitt] + " \\")
                z = "    " + z[schnitt:].lstrip()
            passend.append(z)
        zeile_h = groesse * 1.35
        while passend:
            frei = int((self.y - RAND_U - 12) // zeile_h)
            if frei < 3:
                self._neue_seite()
                continue
            stueck, passend = passend[:frei], passend[frei:]
            hoehe = len(stueck) * zeile_h + 12
            oben = self.y
            self._ops(f"0.94 g {RAND_L:.2f} {oben - hoehe:.2f} {NUTZBAR:.2f} {hoehe:.2f} re f 0 g")
            self.y -= 6
            for z in stueck:
                self.y -= zeile_h
                self._zeile(RAND_L + 8, z, groesse, "mono", grau=0.1)
            self.y = oben - hoehe - 8

    def kasten(self, titel: str, text: str) -> None:
        """Ein Hinweis, der beim Durchblättern auffällt."""
        zeilen = umbrechen(text, 10, NUTZBAR - 24)
        hoehe = 22 + len(zeilen) * 14 + 8
        self.platz(hoehe + 6)
        oben = self.y - 4
        self._ops(f"1 0.95 0.9 rg 0.78 0.16 0.16 RG 1.2 w {RAND_L:.2f} {oben - hoehe:.2f} "
                  f"{NUTZBAR:.2f} {hoehe:.2f} re B 0 g 0 G")
        self.y = oben - 17
        self._zeile(RAND_L + 12, titel, 11, "fett")
        for z in zeilen:
            self.y -= 14
            self._zeile(RAND_L + 12, z, 10)
        self.y = oben - hoehe - 10

    def qr(self, matrix: list[list[bool]], kante_mm: float, beschriftung: str) -> None:
        kante = kante_mm * 72 / 25.4
        self.platz(kante + 34)
        n = len(matrix)
        modul = kante / (n + 8)  # vier Module Ruhezone je Seite
        x0 = RAND_L + (NUTZBAR - kante) / 2 + 4 * modul
        y0 = self.y - 4 * modul
        rechtecke = []
        for zeile_nr, zeile in enumerate(matrix):
            x = 0
            while x < n:
                if zeile[x]:
                    start = x
                    while x < n and zeile[x]:
                        x += 1
                    rechtecke.append(f"{x0 + start * modul:.3f} {y0 - (zeile_nr + 1) * modul:.3f} "
                                     f"{(x - start) * modul:.3f} {modul:.3f} re")
                else:
                    x += 1
        self._ops("0 g " + " ".join(rechtecke) + " f")
        self.y -= kante + 14
        w = breite(beschriftung, 9)
        self._zeile(RAND_L + (NUTZBAR - w) / 2, beschriftung, 9, grau=0.35)
        self.y -= 10

    # Ausgabe

    def als_bytes(self, erstellt: Optional[float] = None) -> bytes:
        anzahl = len(self.seiten)
        for nr, ops in enumerate(self.seiten, 1):
            rechts = f"Seite {nr} von {anzahl}"
            ops.append(f"BT /F1 8 Tf 0.45 g {RAND_L:.2f} 36 Td {_pdf_string(self.fusszeile)} Tj ET")
            ops.append(f"BT /F1 8 Tf 0.45 g {BREITE - RAND_R - breite(rechts, 8):.2f} 36 Td "
                       f"{_pdf_string(rechts)} Tj ET")

        objekte: list[bytes] = []

        def obj(inhalt: str | bytes) -> int:
            objekte.append(inhalt.encode("cp1252") if isinstance(inhalt, str) else inhalt)
            return len(objekte)

        katalog = obj("")  # Platzhalter, unten gefüllt
        seiten_obj = obj("")
        schriften = {
            name: obj(f"<< /Type /Font /Subtype /Type1 /BaseFont /{basis} "
                      "/Encoding /WinAnsiEncoding >>")
            for name, basis in (("F1", "Helvetica"), ("F2", "Helvetica-Bold"), ("F3", "Courier"))
        }
        res = " ".join(f"/{n} {i} 0 R" for n, i in schriften.items())
        kinder = []
        for ops in self.seiten:
            strom = "\n".join(ops).encode("cp1252")
            inhalt = obj(b"<< /Length %d >>\nstream\n" % len(strom) + strom + b"\nendstream")
            kinder.append(obj(
                f"<< /Type /Page /Parent {seiten_obj} 0 R /MediaBox [0 0 {BREITE} {HOEHE}] "
                f"/Resources << /Font << {res} >> >> /Contents {inhalt} 0 R >>"
            ))
        objekte[katalog - 1] = f"<< /Type /Catalog /Pages {seiten_obj} 0 R >>".encode()
        objekte[seiten_obj - 1] = (
            f"<< /Type /Pages /Kids [{' '.join(f'{k} 0 R' for k in kinder)}] /Count {anzahl} >>"
        ).encode()
        datum = time.strftime("D:%Y%m%d%H%M%S", time.localtime(erstellt))
        info = obj(f"<< /Title {_pdf_string(self.titel)} /Producer (FWApp-Installer) "
                   f"/CreationDate ({datum}) >>")

        aus = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        versatz = []
        for i, inhalt in enumerate(objekte, 1):
            versatz.append(len(aus))
            aus += f"{i} 0 obj\n".encode() + inhalt + b"\nendobj\n"
        xref = len(aus)
        aus += f"xref\n0 {len(objekte) + 1}\n0000000000 65535 f \n".encode()
        for v in versatz:
            aus += f"{v:010d} 00000 n \n".encode()
        aus += (f"trailer\n<< /Size {len(objekte) + 1} /Root {katalog} 0 R /Info {info} 0 R >>\n"
                f"startxref\n{xref}\n%%EOF\n").encode()
        return bytes(aus)
