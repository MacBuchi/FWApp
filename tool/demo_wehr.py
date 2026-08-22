"""demo_wehr.py – Stammdaten der fiktiven Demo-Gesamtwehr (Issue #158).

Eine Datei, zwei Leser: `seed_demo_wehr.py` legt danach an, und
`feedback_bot.py` erkennt daran, dass eine Meldung aus einer Vorführung
kommt und deshalb kein öffentliches Issue verdient. Stünde der Slug an
beiden Stellen, würde eine Umbenennung die Filterung still aushebeln.

⚠️ Hier stehen bewusst KEINE Zugangsdaten. Das Repo ist öffentlich und der
Server öffentlich erreichbar; das Passwort kommt aus `FWAPP_DEMO_PASSWORD`
und gehört nach `docs/private/` (siehe docs/BETRIEB.md).
"""

# Die Stadt Freiwilligen und ihr Ortsteil Ehrenberg sind erfunden. Der Name
# muss auf dem Bildschirm sofort als Demo lesbar sein: Screenshots aus dieser
# Wehr landen in README und Nutzer-Doku, und niemand soll sie für eine echte
# Wehr halten.
GESAMTWEHR_NAME = "Feuerwehr Freiwilligen"
GESAMTWEHR_SLUG = "feuerwehr-freiwilligen"

ABTEILUNGEN = [
    {"slug": "abteilung-freiwilligen", "name": "Abteilung Freiwilligen"},
    {"slug": "abteilung-ehrenberg", "name": "Abteilung Ehrenberg"},
]

# ⚠️ **Dieses eine Passwort ist mit Absicht öffentlich.** Es steckt in jedem
# verteilten Build (lib/features/settings/domain/zugang_teilen.dart) und ist
# damit aus einem APK lesbar. Genau deshalb gehört es ausschließlich dem
# LESENDEN Konto: `demo.mitglied` veröffentlicht nie, und hinter der
# Demo-Wehr liegt kein echtes Wehrdatum. Die drei arbeitenden Konten behalten
# das geheime Passwort aus FWAPP_DEMO_PASSWORD (docs/private/).
#
# Wer sich damit anmeldet, kann es auch ändern und die nächsten aussperren.
# Das ist kein Versehen, sondern der Preis: Ein Lauf dieses Skripts setzt es
# zurück (siehe docs/BETRIEB.md).
MITGLIED_PASSWORT = "demo-freiwilligen"

# Je Rolle ein Konto — erst damit ist vorführbar, was die Rollen unterscheidet
# (Nutzerverwaltung, Veröffentlichen, Nur-Lesen). Der Localpart ist die
# Anmeldung UND der Nutzername in der Verwaltung, deshalb das `demo.`-Präfix:
# In einer Vorführung neben echten Konten muss auf den ersten Blick klar sein,
# welche Zeile die Demo ist.
KONTEN = [
    {
        "email": "demo.kommandant@fw.local",
        "anzeigename": "Andreas Keller",
        "abteilung": "abteilung-freiwilligen",
        "rolle": "admin",
        "feuerwehrkommandant": True,
    },
    {
        "email": "demo.abteilungskommandant@fw.local",
        "anzeigename": "Martina Roth",
        "abteilung": "abteilung-ehrenberg",
        "rolle": "admin",
        "feuerwehrkommandant": False,
    },
    {
        "email": "demo.geraetewart@fw.local",
        "anzeigename": "Stefan Gruber",
        "abteilung": "abteilung-freiwilligen",
        "rolle": "geraetewart",
        "feuerwehrkommandant": False,
    },
    {
        "email": "demo.mitglied@fw.local",
        "anzeigename": "Lena Vogt",
        "abteilung": "abteilung-freiwilligen",
        "rolle": "member",
        "feuerwehrkommandant": False,
        # Das geteilte Konto: bekommt MITGLIED_PASSWORT statt des geheimen.
        "oeffentlich": True,
    },
]

# Fahrzeuge je Abteilung, aus den gebündelten Vorlagen. HLF 20 und LF 20 sind
# die einzigen Vorlagen MIT Normbeladung — je Abteilung eines davon, damit auf
# beiden Seiten der Gesamtwehr etwas zu lernen und zu inventarisieren ist.
# Kennzeichen frei erfunden (das Kürzel FRW ist nirgends vergeben).
FAHRZEUGE = {
    "abteilung-freiwilligen": [
        {"vorlage": "hlf20", "name": "HLF 20", "kennzeichen": "FRW-FW 20"},
        {"vorlage": "mtw", "name": "MTW", "kennzeichen": "FRW-FW 10"},
    ],
    "abteilung-ehrenberg": [
        {"vorlage": "lf20", "name": "LF 20", "kennzeichen": "FRW-FW 21"},
    ],
}
