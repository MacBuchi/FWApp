"""fwapp_qr.py – QR-Codes ohne Fremdpakete, für das Einrichtungsdokument (#249).

Der Installer läuft nur mit der Python-Standardbibliothek (ein frischer Pi
hat nichts anderes). Das Einrichtungsdokument soll aber den Kopplungs-QR
tragen, zum Ausdrucken und Aushängen im Gerätehaus — derselbe Text wie in
`/.well-known/fwapp.json` (#238), also rund 250 Zeichen mit dem Anon-Key.

Umfang mit Absicht klein: Byte-Modus, Fehlerkorrektur M (15 % des Codes
dürfen fehlen oder verschmutzt sein — ein Aushang an der Wand), Versionen 1
bis 20 (bis 666 Bytes). Aufbau nach der Referenz von Project Nayuki
(„QR Code generator library", MIT), deren Beschreibung der Norm ISO/IEC
18004 folgt.

Geprüft auf zwei Wegen, weil ein falsch erzeugter QR-Code nicht auffällt,
bis ihn jemand im Gerätehaus nicht scannen kann:
- `test_fwapp_qr.py` vergleicht die Matrix Modul für Modul mit Mustern der
  Referenz-Implementierung (qrcodegen); beim Bau 281 Codes über alle
  Versionen identisch;
- beim Bau mit dem QR-Erkenner von macOS zurückgelesen, Umlaute inklusive.

Kodierung, Fehlerkorrektur, Platzierung und Strafpunkte folgen im Aufbau
eng der Referenz; deshalb ihr Lizenzhinweis:

    QR Code generator library (Python)
    Copyright (c) Project Nayuki. (MIT License)
    https://www.nayuki.io/page/qr-code-generator-library

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    - The above copyright notice and this permission notice shall be
      included in all copies or substantial portions of the Software.
    - The Software is provided "as is", without warranty of any kind,
      express or implied, including but not limited to the warranties of
      merchantability, fitness for a particular purpose and noninfringement.
      In no event shall the authors or copyright holders be liable for any
      claim, damages or other liability, whether in an action of contract,
      tort or otherwise, arising from, out of or in connection with the
      Software or the use or other dealings in the Software.
"""
from __future__ import annotations

from typing import Optional

# Je Version (Index = Version): Fehlerkorrektur-Codewörter je Block und
# Anzahl der Blöcke, Stufe M.
_ECC_JE_BLOCK = [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26]
_BLOECKE = [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16]
_MAX_VERSION = 20
_FORMAT_M = 0  # Formatbits der Stufe M (L=1, M=0, Q=3, H=2)


def _mul(x: int, y: int) -> int:
    """Multiplikation in GF(2^8) mit dem Polynom 0x11D."""
    z = 0
    for i in reversed(range(8)):
        z = (z << 1) ^ ((z >> 7) * 0x11D)
        z ^= ((y >> i) & 1) * x
    return z


def _rs_divisor(grad: int) -> list[int]:
    ergebnis = [0] * (grad - 1) + [1]
    wurzel = 1
    for _ in range(grad):
        for j in range(grad):
            ergebnis[j] = _mul(ergebnis[j], wurzel)
            if j + 1 < grad:
                ergebnis[j] ^= ergebnis[j + 1]
        wurzel = _mul(wurzel, 0x02)
    return ergebnis


def _rs_rest(daten: list[int], divisor: list[int]) -> list[int]:
    rest = [0] * len(divisor)
    for b in daten:
        faktor = b ^ rest.pop(0)
        rest.append(0)
        for i, koeff in enumerate(divisor):
            rest[i] ^= _mul(koeff, faktor)
    return rest


def _roh_module(version: int) -> int:
    """Module für Daten und Fehlerkorrektur (ohne Funktionsmuster)."""
    n = (16 * version + 128) * version + 64
    if version >= 2:
        ausrichtung = version // 7 + 2
        n -= (25 * ausrichtung - 10) * ausrichtung - 55
        if version >= 7:
            n -= 36
    return n


def datenkapazitaet(version: int) -> int:
    """Daten-Codewörter der Version bei Stufe M."""
    return _roh_module(version) // 8 - _ECC_JE_BLOCK[version] * _BLOECKE[version]


def _version_fuer(laenge: int) -> int:
    for v in range(1, _MAX_VERSION + 1):
        zaehlbits = 8 if v <= 9 else 16
        if 4 + zaehlbits + 8 * laenge <= datenkapazitaet(v) * 8:
            return v
    raise ValueError(f"{laenge} Bytes passen in keinen QR-Code bis Version {_MAX_VERSION}")


def _codewoerter(daten: bytes, version: int) -> list[int]:
    kapazitaet = datenkapazitaet(version) * 8
    bits: list[int] = []

    def anhaengen(wert: int, anzahl: int) -> None:
        bits.extend((wert >> i) & 1 for i in reversed(range(anzahl)))

    anhaengen(0b0100, 4)  # Byte-Modus
    anhaengen(len(daten), 8 if version <= 9 else 16)
    for b in daten:
        anhaengen(b, 8)
    anhaengen(0, min(4, kapazitaet - len(bits)))
    anhaengen(0, -len(bits) % 8)
    fuell = 0xEC
    while len(bits) < kapazitaet:
        anhaengen(fuell, 8)
        fuell ^= 0xEC ^ 0x11
    werte = [int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8)]

    # Aufteilen in Blöcke, Fehlerkorrektur je Block, verschränken.
    anzahl, ecc = _BLOECKE[version], _ECC_JE_BLOCK[version]
    roh = _roh_module(version) // 8
    kurze = anzahl - roh % anzahl
    kurz_laenge = roh // anzahl
    divisor = _rs_divisor(ecc)
    bloecke, k = [], 0
    for i in range(anzahl):
        stueck = werte[k:k + kurz_laenge - ecc + (0 if i < kurze else 1)]
        k += len(stueck)
        rest = _rs_rest(stueck, divisor)
        if i < kurze:
            stueck = stueck + [0]
        bloecke.append(stueck + rest)
    ergebnis = []
    for i in range(len(bloecke[0])):
        for j, block in enumerate(bloecke):
            if i != kurz_laenge - ecc or j >= kurze:
                ergebnis.append(block[i])
    return ergebnis


def _ausrichtung(version: int, groesse: int) -> list[int]:
    if version == 1:
        return []
    anzahl = version // 7 + 2
    schritt = (version * 8 + anzahl * 3 + 5) // (anzahl * 4 - 4) * 2
    return list(reversed([groesse - 7 - i * schritt for i in range(anzahl - 1)] + [6]))


class _Matrix:
    def __init__(self, version: int):
        self.version = version
        self.groesse = version * 4 + 17
        self.modul = [[False] * self.groesse for _ in range(self.groesse)]
        self.funktion = [[False] * self.groesse for _ in range(self.groesse)]

    def setze(self, x: int, y: int, dunkel: bool) -> None:
        self.modul[y][x] = dunkel
        self.funktion[y][x] = True

    def funktionsmuster(self) -> None:
        g = self.groesse
        for i in range(g):
            self.setze(6, i, i % 2 == 0)
            self.setze(i, 6, i % 2 == 0)
        for cx, cy in ((3, 3), (g - 4, 3), (3, g - 4)):
            for dy in range(-4, 5):
                for dx in range(-4, 5):
                    x, y = cx + dx, cy + dy
                    if 0 <= x < g and 0 <= y < g:
                        self.setze(x, y, max(abs(dx), abs(dy)) not in (2, 4))
        pos = _ausrichtung(self.version, g)
        letzte = len(pos) - 1
        for i, px in enumerate(pos):
            for j, py in enumerate(pos):
                if (i, j) in ((0, 0), (0, letzte), (letzte, 0)):
                    continue
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        self.setze(px + dx, py + dy, max(abs(dx), abs(dy)) != 1)
        self.formatbits(0)  # reserviert die Plätze; die echten kommen nach der Maske
        if self.version >= 7:
            rest = self.version
            for _ in range(12):
                rest = (rest << 1) ^ ((rest >> 11) * 0x1F25)
            bits = self.version << 12 | rest
            for i in range(18):
                bit = (bits >> i) & 1 == 1
                a, b = g - 11 + i % 3, i // 3
                self.setze(a, b, bit)
                self.setze(b, a, bit)

    def formatbits(self, maske: int) -> None:
        daten = _FORMAT_M << 3 | maske
        rest = daten
        for _ in range(10):
            rest = (rest << 1) ^ ((rest >> 9) * 0x537)
        bits = (daten << 10 | rest) ^ 0x5412
        g = self.groesse

        def bit(i: int) -> bool:
            return (bits >> i) & 1 == 1

        for i in range(6):
            self.setze(8, i, bit(i))
        self.setze(8, 7, bit(6))
        self.setze(8, 8, bit(7))
        self.setze(7, 8, bit(8))
        for i in range(9, 15):
            self.setze(14 - i, 8, bit(i))
        for i in range(8):
            self.setze(g - 1 - i, 8, bit(i))
        for i in range(8, 15):
            self.setze(8, g - 15 + i, bit(i))
        self.setze(8, g - 8, True)  # das immer dunkle Modul

    def daten(self, codewoerter: list[int]) -> None:
        g, i = self.groesse, 0
        rechts = g - 1
        while rechts >= 1:
            if rechts == 6:
                rechts = 5
            for vert in range(g):
                for j in range(2):
                    x = rechts - j
                    aufwaerts = ((rechts + 1) & 2) == 0
                    y = g - 1 - vert if aufwaerts else vert
                    if not self.funktion[y][x] and i < len(codewoerter) * 8:
                        self.modul[y][x] = (codewoerter[i >> 3] >> (7 - (i & 7))) & 1 == 1
                        i += 1
            rechts -= 2

    def maskiere(self, maske: int) -> None:
        for y in range(self.groesse):
            for x in range(self.groesse):
                if self.funktion[y][x]:
                    continue
                umkehren = (
                    (x + y) % 2 == 0,
                    y % 2 == 0,
                    x % 3 == 0,
                    (x + y) % 3 == 0,
                    (x // 3 + y // 2) % 2 == 0,
                    x * y % 2 + x * y % 3 == 0,
                    (x * y % 2 + x * y % 3) % 2 == 0,
                    ((x + y) % 2 + x * y % 3) % 2 == 0,
                )[maske]
                self.modul[y][x] ^= umkehren

    def strafpunkte(self) -> int:
        """Wie ungünstig das Muster für Scanner ist — die Regeln der Norm in
        der Fassung der Referenz, damit dieselbe Maske gewählt wird."""
        g, m, punkte = self.groesse, self.modul, 0
        for zeilen in (m, [list(spalte) for spalte in zip(*m)]):
            for zeile in zeilen:
                farbe, lauf = False, 0
                verlauf = [0] * 7
                for wert in zeile:
                    if wert == farbe:
                        lauf += 1
                        if lauf == 5:
                            punkte += 3
                        elif lauf > 5:
                            punkte += 1
                    else:
                        self._verlauf(lauf, verlauf)
                        if not farbe:
                            punkte += self._suchmuster(verlauf) * 40
                        farbe, lauf = wert, 1
                if farbe:
                    self._verlauf(lauf, verlauf)
                    lauf = 0
                self._verlauf(lauf + g, verlauf)
                punkte += self._suchmuster(verlauf) * 40
        for y in range(g - 1):
            for x in range(g - 1):
                if m[y][x] == m[y][x + 1] == m[y + 1][x] == m[y + 1][x + 1]:
                    punkte += 3
        dunkel = sum(sum(zeile) for zeile in m)
        gesamt = g * g
        punkte += ((abs(dunkel * 20 - gesamt * 10) + gesamt - 1) // gesamt - 1) * 10
        return punkte

    def _verlauf(self, lauf: int, verlauf: list[int]) -> None:
        if verlauf[0] == 0:
            lauf += self.groesse  # heller Rand vor dem ersten Lauf
        verlauf.insert(0, lauf)
        verlauf.pop()

    @staticmethod
    def _suchmuster(v: list[int]) -> int:
        """Zählt Folgen, die wie ein Suchmuster aussehen (1:1:3:1:1 mit
        hellem Rand) — die verwirren Scanner am meisten."""
        n = v[1]
        kern = n > 0 and v[2] == v[4] == v[5] == n and v[3] == n * 3
        return (1 if kern and v[0] >= n * 4 and v[6] >= n else 0) + (
            1 if kern and v[6] >= n * 4 and v[0] >= n else 0
        )


def qr_matrix(text: str, maske: Optional[int] = None) -> list[list[bool]]:
    """Die Module des QR-Codes, Zeile für Zeile, True = dunkel. Ohne
    Randzone — die legt der Zeichner fest (mindestens vier Module)."""
    daten = text.encode("utf-8")
    version = _version_fuer(len(daten))
    codewoerter = _codewoerter(daten, version)
    beste, beste_punkte = None, None
    for kandidat in [maske] if maske is not None else range(8):
        m = _Matrix(version)
        m.funktionsmuster()
        m.daten(codewoerter)
        m.maskiere(kandidat)
        m.formatbits(kandidat)
        punkte = m.strafpunkte()
        if beste_punkte is None or punkte < beste_punkte:
            beste, beste_punkte = m, punkte
    assert beste is not None
    return beste.modul
