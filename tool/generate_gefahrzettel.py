#!/usr/bin/env python3
"""Erzeugt die Gefahrzettel und die orangefarbene Warntafel als PNG unter
assets/knowledge/bilder/.

Aufruf:  python3 tool/generate_gefahrzettel.py    (braucht rsvg-convert)

⚠️ **Warum wir sie selbst zeichnen und nicht herunterladen.** Ein Gefahrzettel
ist ein genormtes Zeichen — Form, Hintergrundfarbe, Symbol und Ziffer stehen
im ADR, Abschnitt 5.2.2.2. Diese ANGABEN sind die Vorlage; die Datei, die
daraus entsteht, ist unsere eigene Zeichnung. Damit bleibt wahr, was
test/licenses_test.dart über `assets/knowledge/` behauptet: alles darunter ist
Eigenerzeugnis. Ein aus dem Netz gezogenes Bild wäre es nicht, und bei
Piktogrammen ist die Herkunft selten so klar dokumentiert, wie sie sein
müsste.

Die Zeichnungen sind bewusst schematisch — sie sollen die Klasse erkennbar
machen, nicht eine Aufkleberdruckerei ersetzen. Wer sie verbessert: Die
Vorgaben stehen in ADR 5.2.2.2.2 (Symbol, Symbolfarbe, Hintergrund, Ziffer)
und 5.2.2.2.1.2 (Raute, Innenlinie etwa 5 mm parallel zum Rand).
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets/knowledge/bilder'

# ── Farben nach ADR 5.2.2.2.2 ──────────────────────────────────────────────
ROT = '#D32F2F'
ORANGE = '#F57C00'
GRUEN = '#2E7D32'
GELB = '#FBC02D'
BLAU = '#1565C0'
WEISS = '#FFFFFF'
SCHWARZ = '#000000'

# ── Symbole, je in einer 100×100-Box, Ursprung links oben ─────────────────
# Gezeichnet nach den Beschreibungen des ADR: „Flamme", „Gasflasche",
# „Totenkopf mit gekreuzten Gebeinen", „explodierende Bombe", „Flamme über
# einem Kreis", „Kreis, der von drei sichelförmigen Zeichen überlagert wird",
# „Strahlensymbol", „Flüssigkeiten, die aus zwei Reagenzgläsern ausgeschüttet
# werden und eine Hand und ein Metall angreifen", „sieben senkrechte Streifen".

FLAMME = """
<path d="M54 1 L46 31 C38 43 26 53 26 69 C26 85 40 98 56 98 C72 98 84 85 84 69 C84 57 78 50 73 41 C72 50 69 56 64 60 C71 43 64 19 54 1 Z" fill="{f}"/>
"""

GASFLASCHE = """
<g fill="{f}">
  <rect x="43" y="2" width="14" height="14" rx="2"/>
  <rect x="33" y="14" width="34" height="9" rx="4"/>
  <path d="M50 21 C34 21 27 33 27 47 V86 C27 92 31 96 37 96 H63
           C69 96 73 92 73 86 V47 C73 33 66 21 50 21 Z"/>
</g>
"""

TOTENKOPF = """
<g fill="{f}">
  <g transform="translate(50 64) rotate(-42)">
    <rect x="-44" y="-6" width="88" height="12" rx="6"/>
    <circle cx="-44" cy="-8" r="8"/><circle cx="-44" cy="8" r="8"/>
    <circle cx="44" cy="-8" r="8"/><circle cx="44" cy="8" r="8"/>
  </g>
  <g transform="translate(50 64) rotate(42)">
    <rect x="-44" y="-6" width="88" height="12" rx="6"/>
    <circle cx="-44" cy="-8" r="8"/><circle cx="-44" cy="8" r="8"/>
    <circle cx="44" cy="-8" r="8"/><circle cx="44" cy="8" r="8"/>
  </g>
  <path d="M50 2 C28 2 14 17 14 35 C14 46 20 55 28 60 V70 C28 75 32 79 37 79
           H63 C68 79 72 75 72 70 V60 C80 55 86 46 86 35 C86 17 72 2 50 2 Z"/>
</g>
<g fill="{g}">
  <ellipse cx="35" cy="36" rx="10" ry="11"/>
  <ellipse cx="65" cy="36" rx="10" ry="11"/>
  <path d="M50 47 l7 13 h-14 Z"/>
  <rect x="37" y="68" width="5" height="11"/>
  <rect x="47" y="68" width="5" height="11"/>
  <rect x="57" y="68" width="5" height="11"/>
</g>
"""

BOMBE = """
<g fill="{f}">
  <circle cx="44" cy="64" r="31"/>
  <path d="M64 43 L76 31" stroke="{f}" stroke-width="8" stroke-linecap="round"
        fill="none"/>
  <path d="M82 4 l5 17 l17 -6 l-12 14 l14 12 l-18 -4 l-4 18 l-6 -17 l-16 6
           l11 -14 l-13 -12 l17 4 Z" transform="translate(-6 4) scale(0.86)"/>
</g>
"""

FLAMME_UEBER_KREIS = """
<g fill="{f}">
  <g transform="translate(28 -2) scale(0.44)"><path d="M54 1 L46 31 C38 43 26 53 26 69 C26 85 40 98 56 98 C72 98 84 85 84 69 C84 57 78 50 73 41 C72 50 69 56 64 60 C71 43 64 19 54 1 Z"/></g>
  <circle cx="50" cy="70" r="25" fill="none" stroke="{f}" stroke-width="10"/>
</g>
"""

ANSTECKUNG = """
<g fill="{f}">
  <circle cx="50" cy="50" r="14"/>
  <g fill="none" stroke="{f}" stroke-width="14" stroke-linecap="butt">
    <path d="M28.9 20.9 A34 34 0 0 1 71.1 20.9"/>
    <path d="M83.5 55.3 A34 34 0 0 1 62.4 91.9"/>
    <path d="M37.6 91.9 A34 34 0 0 1 16.5 55.3"/>
  </g>
</g>
"""

STRAHLEN = """
<g fill="{f}">
  <circle cx="50" cy="52" r="12"/>
  <path d="M50 52 L71.7 14.4 A43.4 43.4 0 0 0 28.3 14.4 Z"/>
  <path d="M50 52 L71.7 14.4 A43.4 43.4 0 0 0 28.3 14.4 Z"
        transform="rotate(120 50 52)"/>
  <path d="M50 52 L71.7 14.4 A43.4 43.4 0 0 0 28.3 14.4 Z"
        transform="rotate(240 50 52)"/>
</g>
"""

AETZEND = """
<g fill="{f}">
  <g transform="translate(9 2) rotate(26)">
    <rect x="0" y="0" width="15" height="36" rx="7"/>
  </g>
  <g transform="translate(91 2) rotate(-26)">
    <rect x="-15" y="0" width="15" height="36" rx="7"/>
  </g>
  <path d="M25 37 L33 41 L27 63 L20 61 Z"/>
  <path d="M75 37 L67 41 L73 63 L80 61 Z"/>
  <path d="M0 78 L13 66 H45 L32 78 Z"/>
  <path d="M0 81 H32 V95 H0 Z"/>
  <path d="M55 98 V80 C55 74 63 74 63 80 V60 C63 53 72 53 72 60 V76
           V56 C72 49 81 49 81 56 V78 V64 C81 58 89 58 89 64 V78
           C89 90 81 98 70 98 Z"/>
</g>
"""

STREIFEN = """
<g fill="{f}">
  <rect x="0.5" y="30" width="9" height="70"/>
  <rect x="15.5" y="30" width="9" height="70"/>
  <rect x="30.5" y="30" width="9" height="70"/>
  <rect x="45.5" y="30" width="9" height="70"/>
  <rect x="60.5" y="30" width="9" height="70"/>
  <rect x="75.5" y="30" width="9" height="70"/>
  <rect x="90.5" y="30" width="9" height="70"/>
</g>
"""


class Zettel:
    """Ein Gefahrzettel: Raute, Hintergrund, Symbol, Klassenziffer."""

    def __init__(self, datei, hintergrund, symbol, symbolfarbe, ziffer,
                 zifferfarbe=None, untere_haelfte=None, streifen=None,
                 unterstrichen=False, symbol_box=(100, 30, 78),
                 titel=''):
        self.datei = datei
        self.hintergrund = hintergrund
        self.symbol = symbol
        self.symbolfarbe = symbolfarbe
        self.ziffer = ziffer
        self.zifferfarbe = zifferfarbe or symbolfarbe
        # Zweifarbige Raute (Muster 4.2, 5.2, 8): Farbe der unteren Hälfte.
        self.untere_haelfte = untere_haelfte
        # Sieben senkrechte Streifen im Hintergrund (Muster 4.1).
        self.streifen = streifen
        self.unterstrichen = unterstrichen
        # (Mitte-x, Oben-y, Kantenlaenge) der Symbolbox im 200er-Feld.
        # ⚠️ Die Raute ist oben SCHMAL: Bei y = 40 ist sie nur 76 breit. Ein
        # Symbol, das die halbe Bildhoehe fuellt, ragt dort hinaus und wird
        # abgeschnitten — der erste Entwurf lieferte genau das.
        self.symbol_box = symbol_box
        self.titel = titel

    def svg(self):
        cx, oben, gr = self.symbol_box
        skala = gr / 100
        symbol = ''
        if self.symbol:
            inhalt = self.symbol.format(f=self.symbolfarbe,
                                        g=self.hintergrund)
            symbol = (f'<g clip-path="url(#raute)">'
                      f'<g transform="translate({cx - gr / 2} {oben}) '
                      f'scale({skala})">{inhalt}</g></g>')

        haelften = ''
        if self.untere_haelfte:
            haelften = (f'<rect x="0" y="100" width="200" height="100" '
                        f'fill="{self.untere_haelfte}" clip-path="url(#raute)"/>')
        if self.streifen:
            # Sieben Streifen ueber die ganze Raute (Muster 4.1), mittig.
            balken = ''.join(
                f'<rect x="{100 - 6.5 + (i - 3) * 27}" y="0" width="13" '
                f'height="200" fill="{self.streifen}"/>'
                for i in range(7))
            haelften += f'<g clip-path="url(#raute)">{balken}</g>'

        strich = ''
        if self.unterstrichen:
            strich = (f'<rect x="82" y="182" width="36" height="4" '
                      f'fill="{self.zifferfarbe}"/>')

        return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512"
     height="512" viewBox="0 0 200 200">
  <title>{self.titel}</title>
  <defs>
    <clipPath id="raute">
      <polygon points="100,2 198,100 100,198 2,100"/>
    </clipPath>
  </defs>
  <rect width="200" height="200" fill="#FFFFFF"/>
  <polygon points="100,2 198,100 100,198 2,100" fill="{self.hintergrund}"/>
  {haelften}
  <polygon points="100,2 198,100 100,198 2,100" fill="none"
           stroke="{SCHWARZ}" stroke-width="2"/>
  <polygon points="100,14 186,100 100,186 14,100" fill="none"
           stroke="{self.symbolfarbe}" stroke-width="3"/>
  {symbol}
  <text x="100" y="178" text-anchor="middle" font-size="34"
        font-family="Helvetica, Arial, sans-serif" font-weight="bold"
        fill="{self.zifferfarbe}">{self.ziffer}</text>
  {strich}
</svg>'''


ZETTEL = [
    Zettel('gefahrzettel_klasse_1', ORANGE, BOMBE, SCHWARZ, '1',
           titel='Gefahrzettel Klasse 1 – Explosive Stoffe'),
    Zettel('gefahrzettel_klasse_2_1', ROT, FLAMME, WEISS, '2',
           titel='Gefahrzettel Klasse 2.1 – Entzündbare Gase'),
    Zettel('gefahrzettel_klasse_2_2', GRUEN, GASFLASCHE, WEISS, '2',
           titel='Gefahrzettel Klasse 2.2 – Nicht entzündbare, nicht '
                 'giftige Gase'),
    Zettel('gefahrzettel_klasse_2_3', WEISS, TOTENKOPF, SCHWARZ, '2',
           titel='Gefahrzettel Klasse 2.3 – Giftige Gase'),
    Zettel('gefahrzettel_klasse_3', ROT, FLAMME, WEISS, '3',
           titel='Gefahrzettel Klasse 3 – Entzündbare flüssige Stoffe'),
    Zettel('gefahrzettel_klasse_4_1', WEISS, FLAMME, SCHWARZ, '4',
           streifen=ROT,
           titel='Gefahrzettel Klasse 4.1 – Entzündbare feste Stoffe'),
    Zettel('gefahrzettel_klasse_4_2', WEISS, FLAMME, SCHWARZ, '4',
           untere_haelfte=ROT,
           titel='Gefahrzettel Klasse 4.2 – Selbstentzündliche Stoffe'),
    Zettel('gefahrzettel_klasse_4_3', BLAU, FLAMME, WEISS, '4',
           titel='Gefahrzettel Klasse 4.3 – Stoffe, die mit Wasser '
                 'entzündbare Gase entwickeln'),
    Zettel('gefahrzettel_klasse_5_1', GELB, FLAMME_UEBER_KREIS, SCHWARZ,
           '5.1',
           titel='Gefahrzettel Klasse 5.1 – Entzündend (oxidierend) '
                 'wirkende Stoffe'),
    Zettel('gefahrzettel_klasse_5_2', ROT, FLAMME, SCHWARZ, '5.2',
           untere_haelfte=GELB,
           titel='Gefahrzettel Klasse 5.2 – Organische Peroxide'),
    Zettel('gefahrzettel_klasse_6_1', WEISS, TOTENKOPF, SCHWARZ, '6',
           titel='Gefahrzettel Klasse 6.1 – Giftige Stoffe'),
    Zettel('gefahrzettel_klasse_6_2', WEISS, ANSTECKUNG, SCHWARZ, '6',
           titel='Gefahrzettel Klasse 6.2 – Ansteckungsgefährliche Stoffe'),
    Zettel('gefahrzettel_klasse_7', GELB, STRAHLEN, SCHWARZ, '7',
           untere_haelfte=WEISS,
           titel='Gefahrzettel Klasse 7 – Radioaktive Stoffe'),
    Zettel('gefahrzettel_klasse_8', WEISS, AETZEND, SCHWARZ, '8',
           untere_haelfte=SCHWARZ, zifferfarbe=WEISS,
           titel='Gefahrzettel Klasse 8 – Ätzende Stoffe'),
    Zettel('gefahrzettel_klasse_9', WEISS, STREIFEN, SCHWARZ, '9',
           unterstrichen=True, symbol_box=(100, 4, 96),
           titel='Gefahrzettel Klasse 9 – Verschiedene gefährliche Stoffe'),
]


def warntafel(gefahrnummer='33', unnummer='1203', datei='warntafel_33_1203',
              titel='Orangefarbene Warntafel'):
    """Die orangefarbene Tafel nach ADR 5.3.2.2: Grundlinie 40 cm, Höhe
    30 cm, schwarzer Rand 15 mm, waagerechte Trennlinie in der Mitte. Oben
    die Nummer zur Kennzeichnung der Gefahr, unten die UN-Nummer."""
    return datei, f'''<svg xmlns="http://www.w3.org/2000/svg" width="640"
     height="480" viewBox="0 0 400 300">
  <title>{titel}</title>
  <rect width="400" height="300" fill="#FFFFFF"/>
  <rect x="4" y="4" width="392" height="292" fill="{ORANGE}"
        stroke="{SCHWARZ}" stroke-width="15"/>
  <rect x="12" y="143" width="376" height="15" fill="{SCHWARZ}"/>
  <text x="200" y="120" text-anchor="middle" font-size="96"
        font-family="Helvetica, Arial, sans-serif" font-weight="bold"
        fill="{SCHWARZ}">{gefahrnummer}</text>
  <text x="200" y="258" text-anchor="middle" font-size="96"
        font-family="Helvetica, Arial, sans-serif" font-weight="bold"
        fill="{SCHWARZ}">{unnummer}</text>
</svg>'''


def schreibe(name, svg, breite=512):
    OUT.mkdir(parents=True, exist_ok=True)
    ziel = OUT / f'{name}.png'
    try:
        subprocess.run(
            ['rsvg-convert', '-w', str(breite), '-o', str(ziel)],
            input=svg.encode(), check=True)
    except FileNotFoundError:
        sys.exit('rsvg-convert fehlt — brew install librsvg')
    return ziel


def main():
    erzeugt = []
    for z in ZETTEL:
        erzeugt.append(schreibe(z.datei, z.svg()))
    name, svg = warntafel()
    erzeugt.append(schreibe(name, svg, breite=640))
    # Eine leere Tafel als Aufgabe: „Was gehört oben hin, was unten?"
    name, svg = warntafel(gefahrnummer='X423', unnummer='1428',
                          datei='warntafel_x423_1428',
                          titel='Orangefarbene Warntafel mit X')
    erzeugt.append(schreibe(name, svg, breite=640))

    for pfad in erzeugt:
        print(f'  {pfad.relative_to(ROOT)}  {pfad.stat().st_size // 1024} KB')
    print(f'{len(erzeugt)} Bilder erzeugt.')


if __name__ == '__main__':
    main()
