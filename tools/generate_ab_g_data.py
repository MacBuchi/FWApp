#!/usr/bin/env python3
"""generate_ab_g_data.py

Generates structured equipment JSON library data for the AB-G
(Abrollbehälter Gefahrgut) from the official Beladeliste CSV.

One JSON file per unique equipment item is written, plus loading_plan.json
and vehicle.json. Items appearing in multiple compartments are deduplicated;
their deployment_scenarios are merged.

Run from the repo root:
    python3 tools/generate_ab_g_data.py [--csv PATH] [--dry-run]

Output:
    assets/equipment_library/
    ├── metadata.json
    └── vehicles/
        └── ab_g/
            ├── vehicle.json
            ├── loading_plan.json
            └── equipment/
                └── *.json   (one per unique item)
"""

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# ── Project paths ──────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CSV = REPO_ROOT / "2025-01-29 Beladeliste AB-G.csv"
OUT_DIR = REPO_ROOT / "assets/equipment_library"
VEHICLE_DIR = OUT_DIR / "vehicles/ab_g"
EQUIPMENT_DIR = VEHICLE_DIR / "equipment"

# ── Category code → EquipmentFunction(s) ──────────────────────────────────────
CATEGORY_FUNCTIONS: dict[str, list[str]] = {
    "Arm":   ["ARMATUREN"],
    "Arb":   ["LOGISTIK"],    # refined per item via FUNCTION_REFINEMENTS
    "Sond":  ["LOGISTIK"],    # refined per item via FUNCTION_REFINEMENTS
    "Hand":  ["HANDWERKZEUG"],
    "BSF":   ["BELEUCHTUNG"], # refined per item via FUNCTION_REFINEMENTS
    "PSA":   ["PSA"],
    "Mess":  ["MESSGERAETE"],
    "Rett":  ["RETTUNG"],
    "Lösch": ["BRAND"],
}

# Keyword-in-name → refined EquipmentFunction  (checked in order; first match wins)
FUNCTION_REFINEMENTS: list[tuple[str, list[str]]] = [
    ("pumpenmotor",       ["PUMPEN"]),
    ("membranpumpe",      ["PUMPEN"]),
    ("umfüllpumpe",       ["PUMPEN"]),
    ("kreiselpumpe",      ["PUMPEN"]),
    ("schlauchpumpe",     ["PUMPEN"]),
    ("fasspumpe",         ["PUMPEN"]),
    ("pumpwerk",          ["PUMPEN"]),
    ("flachsauger",       ["PUMPEN"]),
    ("restlossauger",     ["PUMPEN"]),
    ("saugkorb",          ["ARMATUREN"]),
    ("stromerzeuger",     ["STROM"]),
    ("abgasschlauch",     ["STROM"]),
    ("betankungsset",     ["STROM"]),
    ("kraftstoffkaniste", ["STROM"]),
    ("leitungstrommel",   ["STROM"]),
    ("verteiler explo",   ["STROM"]),
    ("lüfter",            ["LUEFTUNG"]),
    ("lüftung",           ["LUEFTUNG"]),
    ("kabelleuchte",      ["BELEUCHTUNG"]),
    ("handsprechfunk",    ["KOMMUNIKATION"]),
    ("notebook",          ["KOMMUNIKATION"]),
    ("vetter",            ["ABDICHTEN"]),
    ("leckdicht",         ["ABDICHTEN"]),
    ("dichtkissen",       ["ABDICHTEN"]),
    ("rohrdichtkissen",   ["ABDICHTEN"]),
    ("abdichtbinde",      ["ABDICHTEN"]),
    ("dichtungspfropfen", ["ABDICHTEN"]),
    ("dichtungsband",     ["ABDICHTEN"]),
    ("dichtungskeil",     ["ABDICHTEN"]),
    ("dichtungshanf",     ["ABDICHTEN"]),
    ("dichtungspfropf",   ["ABDICHTEN"]),
    ("befülleinrichtung", ["ABDICHTEN"]),
    ("gully",             ["ABDICHTEN"]),
    ("abdicht",           ["ABDICHTEN"]),
    ("dekon",             ["DEKON"]),
    ("dekontamination",   ["DEKON"]),
    ("auffangwanne",      ["GEFAHRGUT_AUFFANGEN"]),
]

# ── Compartment label → DeploymentScenario list ────────────────────────────────
LOCATION_SCENARIOS: dict[str, list[str]] = {
    "Dach":               ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_PUMPEN"],
    "G1":                 ["GEFAHRGUT_AUFFANGEN", "GEFAHRGUT_PUMPEN", "GEFAHRGUT_ABDICHTEN"],
    "G2":                 ["GEFAHRGUT_MESSEN"],
    "G3":                 ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_AUFFANGEN"],
    "G3/G4":              ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_AUFFANGEN"],
    "G4":                 ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_DEKON"],
    "Heck":               ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_PUMPEN"],
    "TW-1 Auffangen":     ["GEFAHRGUT_AUFFANGEN"],
    "TW-2 Absperrgrenze": ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_AUFFANGEN",
                           "GEFAHRGUT_DEKON", "GEFAHRGUT_MESSEN", "GEFAHRGUT_PUMPEN"],
    "TW-3 Umpumpen":      ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_PUMPEN"],
    "TW-4 Strom/Licht":   ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_AUFFANGEN",
                           "GEFAHRGUT_DEKON", "GEFAHRGUT_PUMPEN"],
    "TW-5 Erstangriff":   ["GEFAHRGUT_ABDICHTEN", "GEFAHRGUT_AUFFANGEN"],
    "TW-6 Dekon":         ["GEFAHRGUT_DEKON"],
}

# ── Compartment display order in the loading plan ─────────────────────────────
COMPARTMENT_ORDER = [
    "Dach", "G1", "G2", "G3", "G3/G4", "G4", "Heck",
    "TW-1 Auffangen", "TW-2 Absperrgrenze", "TW-3 Umpumpen",
    "TW-4 Strom/Licht", "TW-5 Erstangriff", "TW-6 Dekon",
]

# ── Rich per-item overrides ────────────────────────────────────────────────────
# Keyed by a lowercase fragment of the item name (checked via `in`).
# Supported keys: equipment_functions, deployment_scenarios_extra,
#                 description, technical_data, typical_use,
#                 training_questions, images, manuals
ITEM_RICH_OVERRIDES: dict[str, dict] = {
    # ── Vetter sealing equipment ────────────────────────────────────────────────
    "vetter-leckdichtkissen": {
        "equipment_functions": ["ABDICHTEN"],
        "deployment_scenarios_extra": ["GEFAHRGUT_ABDICHTEN"],
        "description": (
            "Pneumatisches Vetter-Leckdichtkissen zum Abdichten undichter Behälter, "
            "Fässer und Wannen. Die Kissen werden von außen auf die Schadensstelle aufgelegt "
            "und mit Druckluft (max. 1,5 bar) aufgeblasen. Geeignet für ebene und leicht "
            "gewölbte Flächen."
        ),
        "technical_data": {"betriebsdruck_max_bar": 1.5, "hersteller": "Vetter GmbH"},
        "typical_use": [
            "Abdichten undichter Kunststoff- oder Stahlfässer",
            "Abdichten beschädigter Tankwände von außen",
            "Einsatz in Verbindung mit Vetter-Steuerorgan und Druckminderer",
        ],
        "training_questions": [
            "Wie wird das Leckdichtkissen korrekt positioniert und befestigt?",
            "Welcher maximale Betriebsdruck darf nicht überschritten werden?",
            "Wie wird ein Vetter-Kissen nach dem Einsatz dekontaminiert und geprüft?",
            "Welche Kissen-Größe ist für welche Schadensfläche geeignet (LD50/30 S)?",
        ],
        "images": [],
        "manuals": ["https://www.vetter-group.com/en/products/leak-sealing-bags/"],
    },
    "vetter-rohrdichtkissen": {
        "equipment_functions": ["ABDICHTEN"],
        "deployment_scenarios_extra": ["GEFAHRGUT_ABDICHTEN"],
        "description": (
            "Pneumatisches Vetter-Rohrdichtkissen zum Abdichten von Rohrbrüchen und "
            "undichten Rohrleitungen von innen. Die Kissen werden in das Rohr eingeführt "
            "und mit Druckluft aufgepumpt. Betriebsdruck 1,5 bar. "
            "Lieferbar in verschiedenen Nennweiten (RDK 7/15, 10/20, 20/40, 30/60)."
        ),
        "technical_data": {"betriebsdruck_max_bar": 1.5, "hersteller": "Vetter GmbH"},
        "typical_use": [
            "Innenseitiges Abdichten gebrochener oder undichter Rohre",
            "Einsatz mit Vetter-Luftzuführungsschlauch und Einzel-Steuerorgan",
        ],
        "training_questions": [
            "Welche RDK-Größe wird für welche Rohrnennweite benötigt?",
            "Wie wird das Rohrdichtkissen korrekt in das Rohr eingebracht?",
            "Was ist bei Kissen mit 'FS'-Kennung besonders zu beachten (Flachstoff-Schutzschicht)?",
            "Wie wird der Luftdruck beim Aufpumpen kontrolliert?",
        ],
        "images": [],
        "manuals": ["https://www.vetter-group.com/en/products/pipe-sealing-bags/"],
    },
    "vetter-leckdicht-bandage": {
        "equipment_functions": ["ABDICHTEN"],
        "deployment_scenarios_extra": ["GEFAHRGUT_ABDICHTEN"],
        "description": (
            "Vetter-Leckdicht-Bandage zum Abdichten von Rissen und Leckagen an "
            "Rohrleitungen durch Umwickeln. Geeignet für zylindrische Flächen mit "
            "definierten Rohrdurchmessern. Typ LB mit Angabe des Durchmesserbereichs "
            "(z. B. LB 5-20 für DN 5–20 mm, LB 20-48 für DN 20–48 mm)."
        ),
        "technical_data": {"betriebsdruck_max_bar": 1.5, "hersteller": "Vetter GmbH"},
        "training_questions": [
            "Wie wird die Leckdicht-Bandage korrekt angelegt und fixiert?",
            "Für welche Rohrdurchmesser ist die jeweilige LB-Größe geeignet?",
            "Was ist der Unterschied zwischen Leckdicht-Bandage und Rohrdichtkissen?",
        ],
        "images": [],
        "manuals": ["https://www.vetter-group.com/de/produkte/leckdicht-bandage/"],
    },
    "vetter-luftzuführungsschlauch": {
        "equipment_functions": ["ABDICHTEN"],
        "description": (
            "Vetter-Luftzuführungsschlauch (10 m) zur Druckluftversorgung von "
            "Vetter-Leck- und Rohrdichtkissen. Farbcodiert: blau für Kissen 1, "
            "grün für Kissen 2 (Zwei-Kissen-System). Anschluss am Einzel-Steuerorgan."
        ),
        "training_questions": [
            "Welche Farbcodierung haben Vetter-Luftzuführungsschläuche und warum?",
            "Wie werden die Schläuche am Steuerorgan angeschlossen?",
        ],
        "images": [],
        "manuals": ["https://www.vetter-group.com/"],
    },
    "vetter einzel-steuerorgan": {
        "equipment_functions": ["ABDICHTEN"],
        "description": (
            "Vetter Einzel-Steuerorgan (1,5 bar) zur manuellen Druckluftsteuerung "
            "eines Vetter-Kissen-Systems. Anschluss über Luftzuführungsschläuche. "
            "Ermöglicht kontrolliertes Aufblasen und Ablassen."
        ),
        "training_questions": [
            "Wie wird das Einzel-Steuerorgan in den Druckluftkreis eingebunden?",
            "Welcher Druck darf am Steuerorgan nicht überschritten werden?",
        ],
        "images": [],
        "manuals": ["https://www.vetter-group.com/"],
    },
    "vetter-druckminderer": {
        "equipment_functions": ["ABDICHTEN"],
        "description": (
            "Vetter-Druckminderer für den Anschluss an Druckluftflaschen (200/300 bar). "
            "Reduziert den Flaschendruck auf den Betriebsdruck der Vetter-Kissen (max. 1,5 bar). "
            "Eingangsdruck 200/300 bar, Ausgangsdruck bis 12 bar einstellbar."
        ),
        "technical_data": {"eingangsdruck_bar": "200/300", "ausgangsdruck_max_bar": 12, "hersteller": "Vetter GmbH"},
        "training_questions": [
            "Warum wird ein Druckminderer bei Vetter-Kissen benötigt?",
            "Auf welchen Ausgangsdruck wird der Druckminderer für Kissen-Systeme eingestellt?",
        ],
        "images": [],
        "manuals": ["https://www.vetter-group.com/"],
    },
    # ── PSA – Chemikalienanzug ──────────────────────────────────────────────────
    "chemikalienanzug": {
        "equipment_functions": ["PSA"],
        "deployment_scenarios_extra": ["GEFAHRGUT_DEKON"],
        "description": (
            "Gasdichter Chemikalienanzug der Kategorie III (PSA) nach EN 943-1, "
            "Typ 1a-ET (anlüftbar mit eigenem Atemanschluss). Modell Onesuit Pro. "
            "Bietet Vollschutz gegen gasförmige und flüssige Chemikalien sowie Aerosole. "
            "Einwegprodukt – nach Kontamination zu entsorgen."
        ),
        "technical_data": {
            "norm": "EN 943-1 Typ 1a-ET",
            "kategorie_psa": "III",
            "einsatz": "Einweg",
            "hersteller": "Dräger / MSA / Kappler",
        },
        "typical_use": [
            "Gasdichte Arbeiten in hochkontaminierten Bereichen",
            "Umpumpen und Probenahme aggressiver Chemikalien",
            "Einsatz nur in Kombination mit Pressluftatmer (PA)",
        ],
        "training_questions": [
            "Welcher Schutztyp nach EN 943 gilt für den Chemikalienanzug Typ 1a-ET?",
            "Wie wird der Chemikalienanzug korrekt angelegt (Reihenfolge, 4-Augen-Prinzip)?",
            "Was ist mit einem kontaminierten Einweg-Chemikalienanzug nach dem Einsatz zu tun?",
            "Welche Einsatzzeit ist im gasdichten Anzug realistisch und von was ist sie abhängig?",
            "Wie erfolgt die Notfallöffnung (Fremdöffnung) von außen?",
        ],
        "images": [],
    },
    "schutzanzug  leichte ausführung typ tychem": {
        "equipment_functions": ["PSA"],
        "description": (
            "Leichter Chemieschutzanzug DuPont™ Tychem® 3000, Typ 3 nach EN 14605. "
            "Schutz gegen flüssige Chemikalien durch gesprühte oder verspritzte Medien "
            "(Spritzschutz). Einwegprodukt mit versiegelten Nähten."
        ),
        "technical_data": {"norm": "EN 14605 Typ 3", "hersteller": "DuPont"},
        "training_questions": [
            "Welchen Schutz bietet Tychem 3000 – was schützt es, was nicht?",
            "Was ist der Unterschied zwischen Chemikalienanzug Typ 1 und Typ 3?",
            "Wird ein Atemschutz zum Tychem-3-Anzug benötigt?",
        ],
        "images": [],
    },
    "atemschutzgerät mit flasche": {
        "equipment_functions": ["PSA"],
        "description": (
            "Pressluftatmer (PA) als umluftunabhängiges Atemschutzgerät (uA-Gerät) mit "
            "Druckluftflasche (300 bar) und Lungenautomaten. Standardausrüstung für den "
            "Innenangriff und den Einsatz in sauerstoffarmer oder schadstoffhaltiger Atmosphäre."
        ),
        "typical_use": [
            "Innenangriff bei Bränden in Gebäuden und Fahrzeugen",
            "Erkundung und Arbeiten in kontaminierten Gefahrgutzonen",
            "Einsatz unter gasdichtem Chemikalienanzug",
        ],
        "training_questions": [
            "Wie wird der Pressluftatmer vor dem Anlegen geprüft (Dichtheitsprüfung, Überdruckprüfung)?",
            "Wie viele Atemzüge bzw. welche Einsatzdauer ergibt sich aus Flaschendruck und Atemvolumen?",
            "Wie läuft die Atemschutzüberwachung nach FwDV 7 ab?",
            "Was ist der Unterschied zwischen Lungenautomaten erster und zweiter Stufe?",
        ],
        "images": [],
    },
    "kombinationsfilter": {
        "equipment_functions": ["PSA"],
        "description": (
            "Kombinationsfilter für Filtergeräte oder Halbmasken. Schützt vor Gasen, "
            "Dämpfen und Partikeln. Standardtyp A2B2E2K2P3 für den Gefahrguteinsatz. "
            "Einsatzgrenzwert beachten – nicht für O₂-Mangel-Situationen geeignet."
        ),
        "training_questions": [
            "Was bedeuten die Buchstaben A, B, E, K und P am Kombinationsfilter?",
            "Ab welcher Gefahrstoffkonzentration darf kein Filtergerät mehr verwendet werden?",
            "Wie wird der Filter auf Unversehrtheit und Ablaufdatum geprüft?",
        ],
        "images": [],
    },
    # ── Messung / Strahlenschutz ────────────────────────────────────────────────
    "dosisleistungsmessgerät": {
        "equipment_functions": ["MESSGERAETE"],
        "deployment_scenarios_extra": ["GEFAHRGUT_MESSEN"],
        "description": (
            "Digitaler Dosisleistungsmesser für ionisierende Strahlung (Alpha, Beta, Gamma) "
            "mit akustischer und optischer Warnschwelle. Einsatz bei Verdacht auf radioaktive "
            "oder nukleare Gefahrstoffe. Anzeigebereich in µSv/h bzw. mSv/h."
        ),
        "training_questions": [
            "In welcher Einheit wird die Dosisleistung angegeben (µSv/h, mSv/h)?",
            "Wie werden die Warnschwellen konfiguriert und welche Richtwerte gelten laut FwDV 500?",
            "In welchem Abstand vom Objekt wird bei der Strahlungsumfeldmessung gemessen?",
            "Was ist der Unterschied zwischen Dosisleistungsmessgerät und Personendosimeter?",
        ],
        "images": [],
        "manuals": ["https://de.wikipedia.org/wiki/Dosimeter"],
    },
    "dosisleistungswarngerät": {
        "equipment_functions": ["MESSGERAETE"],
        "deployment_scenarios_extra": ["GEFAHRGUT_MESSEN"],
        "description": (
            "Tragbares Dosisleistungswarngerät für Feuerwehren mit auditivem und visuellem "
            "Alarm bei Überschreitung eingestellter Grenzwerte. Persönlicher Strahlungsschutz "
            "bei der Erkundung möglicher Strahlungsquellen."
        ),
        "training_questions": [
            "Was ist der Unterschied zwischen Dosisleistungsmessgerät und Dosisleistungswarngerät?",
            "Ab welchem Messwert ist die Einsatzstelle als Strahlungszone zu klassifizieren?",
        ],
        "images": [],
    },
    "dosiswarngerät": {
        "equipment_functions": ["MESSGERAETE"],
        "deployment_scenarios_extra": ["GEFAHRGUT_MESSEN"],
        "description": (
            "Elektronisches Personendosimeter (Dosiswarngerät) zur individuellen "
            "Strahlungsüberwachung von Einsatzkräften. Misst die kumulative Personendosis "
            "und warnt beim Erreichen des Dosisgrenzwerts."
        ),
        "training_questions": [
            "Was misst das Dosiswarngerät und was der Personendosimeter?",
            "Welche jährlichen Dosisgrenzwerte gelten nach Strahlenschutzverordnung?",
        ],
        "images": [],
    },
    "personendosimeter": {
        "equipment_functions": ["MESSGERAETE"],
        "description": (
            "Filmdosimeter-Personendosimeter in Selbstablesung-Gleitschattenkassette zur "
            "Messung der empfangenen Strahlendosis des Trägers. Zur amtlichen Auswertung "
            "vorgesehen – Pflichtausstattung für Einsatzkräfte im Strahlenschutzbereich."
        ),
        "training_questions": [
            "Wie wird ein Filmdosimeter nach dem Einsatz ausgewertet?",
            "Welchen Dosisgrenzwert nach §78 StrlSchV darf eine Einsatzkraft erhalten?",
        ],
        "images": [],
    },
    "kontaminationsmonitor": {
        "equipment_functions": ["MESSGERAETE"],
        "deployment_scenarios_extra": ["GEFAHRGUT_MESSEN", "GEFAHRGUT_DEKON"],
        "description": (
            "Gerät zur Messung von Oberflächenkontaminationen durch Alpha-, Beta- und "
            "Gammastrahlung. Einsatz zur Freigabemessung nach Dekontamination sowie zur "
            "Umfeldüberwachung an der Einsatzstelle."
        ),
        "training_questions": [
            "Für welche Strahlungsarten ist der Kontaminationsmonitor geeignet?",
            "Wie wird die Sonde korrekt über die zu messende Fläche geführt?",
            "Welche Messwerte sigalisieren einen kontaminierten Zustand?",
            "Wie wird das Gerät auf Nullrate (Hintergrundstrahlung) kalibriert?",
        ],
        "images": [],
    },
    "prüfröhrchen": {
        "equipment_functions": ["MESSGERAETE"],
        "description": (
            "Prüfröhrchen-Sortiment zur qualitativen und semiquantitativen Bestimmung von "
            "Gasen und Dämpfen in der Luft. Gasspezifische Röhrchen für häufige Gefahrstoffe "
            "(z. B. Chlor, Ammoniak, H₂S, CO). Einsatz mit Handpumpe (Dräger Accuro o. ä.)."
        ),
        "training_questions": [
            "Wie wird ein Prüfröhrchen korrekt verwendet (Hübe, Ablesung)?",
            "Welche Gefahrstoffe können im AB-G-Einsatz typischerweise auftreten?",
            "Was ist die Nachweisgrenze eines Prüfröhrchens und welche Genauigkeit hat es?",
        ],
        "images": [],
    },
    "ventis": {
        "equipment_functions": ["MESSGERAETE"],
        "description": (
            "Mehrgasmessgerät Industrial Scientific Ventis MX4/5 zur kontinuierlichen "
            "Überwachung von O₂, CO, H₂S und brennbaren Gasen (% LEL) sowie optional VOC. "
            "ATEX-zertifiziert für Zone 1/2. Inklusive Ladestation."
        ),
        "technical_data": {
            "messparameter": ["O2", "CO", "H2S", "LEL", "optional VOC"],
            "norm": "ATEX Kategorie 1G/2G",
            "hersteller": "Industrial Scientific",
        },
        "training_questions": [
            "Welche Gase misst das Ventis-Gerät gleichzeitig?",
            "Was bedeutet '% LEL' und ab welchem Wert ist eine Evakuierung einzuleiten?",
            "Wie wird das Gerät vor dem Einsatz auf Funktion geprüft (Bump-Test)?",
            "Wie lange dauert die Einschaltphase (Kalibrierungsphase) des Geräts?",
        ],
        "images": [],
    },
    # ── Pumpen ────────────────────────────────────────────────────────────────
    "druckluftmembranpumpe": {
        "equipment_functions": ["PUMPEN"],
        "deployment_scenarios_extra": ["VU_PKW", "VU_LKW"],
        "description": (
            "Druckluftbetriebene Membranpumpe, ATEX-zertifiziert (Zone 1), zum Absaugen "
            "und Umpumpen von Kraftstoffen aus PKW- und LKW-Tanks nach Verkehrsunfällen. "
            "Inklusive Schläuchen, Druckminderer und Abzapfpistole."
        ),
        "training_questions": [
            "Warum muss die Membranpumpe ATEX-zertifiziert sein?",
            "Wie wird eine PKW/LKW-Tankentleerung mit der Membranpumpe sicher durchgeführt?",
            "Welche Erdungsmaßnahmen sind beim Umpumpen von Kraftstoffen Pflicht?",
            "Für welche anderen Flüssigkeiten als Kraftstoff ist die Pumpe geeignet?",
        ],
        "images": [],
    },
    "gefahrstoff umfüllpumpe din 14427 kreiselpumpe": {
        "equipment_functions": ["PUMPEN"],
        "description": (
            "Gefahrstoff-Umfüllpumpe nach DIN 14427 als Kreiselpumpe für dünnflüssige "
            "Medien. Motorisch angetrieben, geeignet für aggressive Flüssigkeiten "
            "und wässrige Lösungen mit niedriger Viskosität."
        ),
        "training_questions": [
            "Welche Norm gilt für Feuerwehr-Gefahrstoff-Umfüllpumpen (DIN 14427)?",
            "Für welche Medien ist die Kreiselpumpe geeignet – gibt es Einschränkungen?",
            "Wie wird die Pumpe auf Saug- und Druckseite angeschlossen?",
        ],
        "images": [],
    },
    "gefahrstoff umfüllpumpe din 14427 schlauchpumpe": {
        "equipment_functions": ["PUMPEN"],
        "description": (
            "Gefahrstoff-Umfüllpumpe nach DIN 14427 als Schlauchpumpe (Peristaltikpumpe) "
            "für zähflüssige oder aggressive Medien. Geeignet für Konzentrate, Säuren, "
            "Laugen und viskose Gefahrstoffe."
        ),
        "training_questions": [
            "Welchen Vorteil bietet die Schlauchpumpe gegenüber der Kreiselpumpe bei Gefahrstoffen?",
            "Was ist das Funktionsprinzip einer Peristaltikpumpe?",
            "Welcher Schlauchtyp muss dem Gefahrstoff entsprechend ausgewählt werden?",
        ],
        "images": [],
    },
    "handmembranpumpe": {
        "equipment_functions": ["PUMPEN"],
        "description": (
            "Handmembranpumpe mit Säurekupplung zum manuellen Umpumpen von Gefahrstoffen, "
            "Säuren und Laugen aus kleinen Behältern. Keine Stromversorgung erforderlich. "
            "Geeignet für korrosive Flüssigkeiten – chemikalienresistente Membran."
        ),
        "training_questions": [
            "Welche Medien dürfen mit der Handmembranpumpe umgepumpt werden?",
            "Wie wird der Pumpendruck durch die Membran aufgebaut?",
            "In welchem Intervall sind die Ersatzmembranen zu wechseln?",
        ],
        "images": [],
    },
    # ── Kupplungen / Armaturen ─────────────────────────────────────────────────
    "übergangsstück": {
        "equipment_functions": ["ARMATUREN"],
        "deployment_scenarios_extra": ["GEFAHRGUT_PUMPEN"],
        "description": (
            "Edelstahl-V4A-Übergangsstück zum Verbinden verschiedener Kupplungssysteme "
            "in Gefahrstoff-Pumpenstrecken. Einsatz am AB-G für das Umpumpen aus Tanks, "
            "Containern, Fässern und Tankwagen."
        ),
        "typical_use": [
            "Verbinden verschiedener Kupplungssysteme (VK50, MK50, KAMLOK, Guillemin, Storz, Flansch)",
            "Anpassung zwischen Fahrzeug- und Behälterkupplungen",
            "Aufbau von Pumpenstrecken für Gefahrstoffe",
        ],
        "training_questions": [
            "Welche Kupplungssysteme werden im GW-Gefahrgut-Betrieb typischerweise verwendet?",
            "Was ist der Unterschied zwischen VK50 (Verteiler-Kupplung) und MK50 (Muttergewinde)?",
            "Welches Werkzeug wird zum Anziehen von Tankwagenkupplungen benötigt?",
            "Warum sind die Übergangsstücke aus V4A-Edelstahl gefertigt?",
        ],
        "images": [],
    },
    "blindkappe": {
        "equipment_functions": ["ARMATUREN"],
        "description": (
            "Blindkappe zum Verschließen offener Kupplungsenden und Flanschanschlüsse. "
            "Verhindert das Austreten von Gefahrstoffen aus nicht genutzten Anschlüssen "
            "in der Pumpenstrecke."
        ),
        "training_questions": [
            "Wann und warum werden Blindkappen an Kupplungen eingesetzt?",
            "Welche Dichtungswerkstoffe werden für Blindkappen im Gefahrguteinsatz verwendet?",
        ],
        "images": [],
    },
    "scheibenventil": {
        "equipment_functions": ["ARMATUREN"],
        "description": (
            "Edelstahl-V4A-Scheibenventil (Butterfly Valve) DN 50 mit Viton-Dichtungen, "
            "Tankwagenkupplungen MK50/VK50, Spannring und Betätigungshebel. "
            "Chemikalienresistente Absperrarmatur für Pumpenstrecken am AB-G."
        ),
        "technical_data": {
            "nennweite_dn": 50,
            "material": "Edelstahl V4A",
            "dichtung": "Viton (FKM)",
            "kupplungen": ["MK50", "VK50"],
        },
        "training_questions": [
            "Welchen Vorteil bietet ein Scheibenventil gegenüber einem Kugelventil bei Gefahrstoffen?",
            "Was bedeutet die Viton-Dichtung für die Einsatzmöglichkeiten?",
            "Wie wird ein Scheibenventil auf Dichtigkeit geprüft?",
        ],
        "images": [],
    },
    "saugkorb dn 50": {
        "equipment_functions": ["ARMATUREN"],
        "description": (
            "Saugkorb DN 50 aus Edelstahl V4A als Ansaugschutz für Pumpen. "
            "Verhindert das Ansaugen von Feststoffen und Fremdkörpern, die die Pumpe "
            "beschädigen könnten. Einsatz auf der Saugseite der Umfüllpumpe."
        ),
        "training_questions": [
            "Warum ist ein Saugkorb auf der Saugseite der Pumpe wichtig?",
            "Wie wird der Saugkorb nach dem Einsatz gereinigt?",
        ],
        "images": [],
    },
    "erdungssatz": {
        "equipment_functions": ["STROM"],
        "deployment_scenarios_extra": ["GEFAHRGUT_PUMPEN"],
        "description": (
            "Erdungssatz zur elektrostatischen Erdung von Tanks, Behältern, Fässern "
            "und Pumpen beim Umpumpen brennbarer oder elektrisch leitfähiger Flüssigkeiten. "
            "Verhindert elektrostatische Entladungen als Zündquelle."
        ),
        "typical_use": [
            "Erdung von Tankwagen und Behältern vor dem Umpumpen",
            "Potenzialausgleich zwischen Pumpe, Schlauch und Behälter",
        ],
        "training_questions": [
            "Warum ist eine Erdung beim Umpumpen brennbarer Flüssigkeiten gesetzlich vorgeschrieben?",
            "Wie wird die Erdungsverbindung korrekt hergestellt und geprüft?",
            "Was ist der Unterschied zwischen Schutzerdung und Potentialausgleich?",
        ],
        "images": [],
    },
    # ── Beleuchtung / Strom ────────────────────────────────────────────────────
    "lüfter leader esx": {
        "equipment_functions": ["LUEFTUNG"],
        "description": (
            "Überdrucklüfter Leader ESX 230, ATEX-zertifiziert (Zone 1/21), 230 V elektrisch. "
            "Geeignet für den Einsatz in explosionsgefährdeten Atmosphären (brennbare Dämpfe, "
            "Gase). Einsatz zur Belüftung kontaminierter Bereiche und zum Verdünnen von "
            "Gefahrstoffwolken."
        ),
        "technical_data": {
            "spannung_v": 230,
            "atex_zertifiziert": True,
            "abmessungen_mm": "550 x 550 x 490",
            "hersteller": "Leader SAS",
        },
        "training_questions": [
            "Was bedeutet die ATEX-Zertifizierung des Lüfters?",
            "Wie wird der Lüfter für eine effektive Überdruckbelüftung positioniert?",
            "Welche Schutzausrüstung ist beim Aufbau in explosionsgefährdeter Umgebung Pflicht?",
            "Darf ein nicht-ATEX-Lüfter in einer Gas-Wolke eingesetzt werden?",
        ],
        "images": [],
    },
    "stromerzeuger": {
        "equipment_functions": ["STROM"],
        "description": (
            "Tragbarer Stromerzeuger 13 BSKA 14 mit BEOS-Anschluss für den mobilen "
            "Strombedarf an der Einsatzstelle. Betrieb von Pumpen, Beleuchtung und "
            "Dekon-Einrichtungen ohne Netzanschluss."
        ),
        "training_questions": [
            "Welche Nennleistung (kVA) hat der Stromerzeuger?",
            "Was ist ein BEOS-Anschluss und wofür wird er benötigt?",
            "Welche Sicherheitsmaßnahmen gelten beim Betrieb eines Stromerzeugers im Gefahrgutbereich?",
            "Wie wird der Stromerzeuger geerdet?",
        ],
        "images": [],
    },
    # ── Dekon ─────────────────────────────────────────────────────────────────
    "dekon-dusche": {
        "equipment_functions": ["DEKON"],
        "description": (
            "Mobile Dekon-Dusche Isotemp zur Personendekontamination nach dem Gefahrguteinsatz. "
            "Aufblasbar mit Gebläse, beheiztes Wasser über integrierte Pumpe und Druckminderer. "
            "Aufbauzeit ca. 5 Minuten."
        ),
        "typical_use": [
            "Grob-Dekontamination kontaminierter Einsatzkräfte (gelbe Zone)",
            "Fein-Dekontamination (rote Zone) mit Dekon-Planen-Satz",
        ],
        "training_questions": [
            "Wie wird der Dekon-Platz nach FwDV 500 aufgebaut (Zonen, Abfolge)?",
            "Welche Dekon-Stufen gibt es und welche Schritte enthält jede Stufe?",
            "Welche PSA trägt das Dekon-Personal?",
            "Welche Besonderheiten gelten bei der Dekon von gasdichten Anzügen?",
        ],
        "images": [],
    },
    "beladungssatz dekontamination": {
        "equipment_functions": ["DEKON"],
        "description": (
            "Beladungssatz Dekontamination nach DIN 14800-L2. Enthält alle normierten "
            "Gegenstände zur Durchführung der Personendekontamination gemäß FwDV 500. "
            "Basis für den standardisierten Dekon-Aufbau."
        ),
        "training_questions": [
            "Welche Dekon-Stufen enthält die FwDV 500?",
            "Was beinhaltet der Dekon-Grundbestand nach DIN 14800-L2?",
            "Wie ist der Dekon-Platz aufzubauen und zu kennzeichnen?",
        ],
        "images": [],
        "manuals": ["https://www.feuerwehrverband.de/fachempfehlungen/fwdv-500/"],
    },
    # ── Abdichten / Erstangriff ────────────────────────────────────────────────
    "dichtfix": {
        "equipment_functions": ["ABDICHTEN"],
        "description": (
            "Universal-Abdicht- und Abfüllkupplung 'Dichtfix' als Starterpaket. "
            "Ermöglicht das Abdichten undichter Fässer und Kanister durch eine "
            "universelle Adapterkupplung. Einsatz bei Erstangriff bei Gefahrstoffleckagen."
        ),
        "training_questions": [
            "Wie wird die Dichtfix-Kupplung an einem undichten Spundloch angesetzt?",
            "Für welche Spundloch-Typen und -größen ist das System geeignet?",
        ],
        "images": [],
    },
    "abdichtbinde denso": {
        "equipment_functions": ["ABDICHTEN"],
        "description": (
            "DENSO-Abdichtbinde (selbstklebende Butylkautschuk-Binde) zum schnellen "
            "Abdichten von Rissen und Leckagen an Rohren und Behältern. "
            "Chemikalienbeständig gegen viele Mineralöle und Kraftstoffe."
        ),
        "training_questions": [
            "Wie wird die DENSO-Abdichtbinde korrekt aufgebracht?",
            "Für welche Temperaturbereiche und Medien ist sie geeignet?",
        ],
        "images": [],
    },
    # ── Auffangen ──────────────────────────────────────────────────────────────
    "faltbare auffangwanne": {
        "equipment_functions": ["GEFAHRGUT_AUFFANGEN"],
        "description": (
            "Faltbare Auffangwanne aus PE (Polyethylen) für das Auffangen auslaufender "
            "flüssiger Gefahrstoffe. Schnelle Aufbauzeit, platzsparende Lagerung. "
            "Geeignet für wässrige Gefahrstoffe und Mineralöle."
        ),
        "technical_data": {"material": "Polyethylen (PE)"},
        "training_questions": [
            "Wie wird die faltbare Auffangwanne schnell aufgebaut?",
            "Für welche Chemikalien ist Polyethylen beständig – für welche nicht?",
            "Wie wird eine kontaminierte Auffangwanne nach dem Einsatz entsorgt?",
        ],
        "images": [],
    },
    "plane mit nbr": {
        "equipment_functions": ["GEFAHRGUT_AUFFANGEN"],
        "description": (
            "Großflächige Auffangplane mit beidseitiger NBR-Beschichtung (Nitril-Kautschuk), "
            "4 × 4 m, mit Ösen zur Befestigung. NBR-Beschichtung bietet Beständigkeit gegen "
            "Mineralöle, Kraftstoffe und viele Lösungsmittel."
        ),
        "technical_data": {"material": "NBR-Gummi", "abmessungen_mm": "4000 x 4000"},
        "training_questions": [
            "Warum wird für Auffangplanen eine NBR-Beschichtung verwendet?",
            "Welche Gefahrstoffe dürfen NICHT auf NBR-Planen aufgefangen werden?",
        ],
        "images": [],
    },
    "fass-berge-sack": {
        "equipment_functions": ["GEFAHRGUT_AUFFANGEN"],
        "description": (
            "Bergungssack aus beidseitig NBR-beschichtetem Gewebe (B110), ableitfähig, "
            "für die Aufnahme undichter oder beschädigter Fässer (Ø 800 mm, H 1300 mm). "
            "Mit Ösen, Kordel und 5-cm-Saum. Elektrisch ableitfähig gegen Statik."
        ),
        "training_questions": [
            "Warum ist der Fass-Berge-Sack elektrisch ableitfähig?",
            "Wie wird ein kontaminierter Fass-Berge-Sack nach dem Einsatz behandelt?",
            "Welche maximale Fassgröße passt in den Berge-Sack?",
        ],
        "images": [],
    },
}

# ── Technical data extraction ──────────────────────────────────────────────────
def extract_technical_data(name: str) -> dict:
    """Extract structured technical data from item name string."""
    data: dict = {}
    n = name.strip()

    # Nominal diameter
    dn = re.search(r'\bDN\s*(\d+)', n, re.I)
    if dn:
        data['nennweite_dn'] = int(dn.group(1))

    # Volume
    vol = re.search(r'(\d+[\.,]?\d*)\s*(?:[Ll]tr?\.?|[Ll]\s|[Ll]$)', n)
    if vol:
        try:
            data['volumen_liter'] = float(vol.group(1).replace(',', '.'))
        except ValueError:
            pass

    # Pressure
    bar = re.search(r'(\d+[\.,]?\d*)\s*bar', n, re.I)
    if bar:
        try:
            data['druck_bar'] = float(bar.group(1).replace(',', '.'))
        except ValueError:
            pass

    # Dimensions
    dims = re.search(
        r'(\d+[\.,]?\d*)\s*[xX×]\s*(\d+[\.,]?\d*)(?:\s*[xX×]\s*(\d+[\.,]?\d*))?\s*mm', n)
    if dims:
        parts = [g.replace(',', '.') for g in dims.groups() if g]
        data['abmessungen_mm'] = ' x '.join(parts)

    # DIN / EN norms
    norms = re.findall(r'DIN(?:\s+EN)?\s+[\w\-/]+', n)
    if norms:
        data['normen'] = sorted(set(norms))

    # Material
    nu = n.upper()
    if 'V4A' in nu or 'EDELSTAHL' in nu:
        data['material'] = 'Edelstahl V4A'
    elif re.search(r'\bPE[-\s]|\bPE\b', nu):
        data['material'] = 'Polyethylen (PE)'
    elif 'PVC' in nu:
        data['material'] = 'PVC'
    elif 'NBR' in nu:
        data['material'] = 'NBR-Gummi'
    elif 'FKM' in nu or 'VITON' in nu:
        data['material'] = 'FKM / Viton®'
    elif 'PTFE' in nu:
        data['material'] = 'PTFE'
    elif 'NOMEX' in nu:
        data['material'] = 'Nomex®-Aramid'

    # ATEX / spark-proof
    if 'ATEX' in nu or re.search(r'\bex[- \.]', nu, re.I):
        data['atex_zertifiziert'] = True
    if re.search(r'funkenarm|funkenfrei', nu, re.I):
        data['funkenarm'] = True

    # Coupling types present in name
    couplings = []
    for code in ['VK 50', 'VK50', 'MK 50', 'MK50', 'VK 80', 'VK80',
                 'MK 80', 'MK80', 'MB 50', 'MB50', 'MB 100', 'MB100', 'VB50']:
        if code.replace(' ', '') in nu.replace(' ', ''):
            couplings.append(code.replace(' ', ''))
    for kw, label in [('KAMLOK', 'KAMLOK'), ('GUILLEMIN', 'Guillemin'),
                      ('STORZ', 'Storz-C'), ('FLANSCH', 'Flansch'),
                      ('IBC', 'IBC'), ('TROCKENKUPPLUNG', 'Trockenkupplung')]:
        if kw in nu:
            couplings.append(label)
    if couplings:
        data['kupplungen'] = sorted(set(couplings))

    return data


# ── ID generation ─────────────────────────────────────────────────────────────
def to_id(name: str) -> str:
    """Return a stable, readable snake_case ID for an item name."""
    s = name.lower().strip()
    for src, dst in [('ä','ae'), ('ö','oe'), ('ü','ue'), ('ß','ss'),
                     ('á','a'), ('é','e'), ('ó','o'), ('ú','u')]:
        s = s.replace(src, dst)
    s = re.sub(r'[^\w\s]', '_', s)
    s = re.sub(r'\s+', '_', s)
    s = re.sub(r'_+', '_', s).strip('_')
    if len(s) > 64:
        cut = s[:64].rfind('_')
        s = s[:cut] if cut > 40 else s[:64]
    return s


def to_compartment_id(loc: str) -> str:
    s = loc.lower().strip()
    for src, dst in [('ä','ae'), ('ö','oe'), ('ü','ue'), ('ß','ss')]:
        s = s.replace(src, dst)
    return re.sub(r'[^a-z0-9]+', '_', s).strip('_')


# ── Short name helper ─────────────────────────────────────────────────────────
def make_short_name(name: str) -> str:
    s = name.strip()
    # Strip trailing dimension info
    s = re.sub(
        r'\s+\d+[\.,]?\d*\s*[xX×]\s*\d+[\.,]?\d*(?:\s*[xX×]\s*\d+[\.,]?\d*)?\s*mm\s*$', '', s)
    # Strip common suffix phrases
    for cut_phrase in [' inkl. Zubehör', ' inkl. Schläuche', ' inkl. Halter',
                       ' inkl. Ladehalterung', ' inkl. Ladehalter', ' inkl. Ladeschale',
                       ' inkl. 3-fach', ' auf Rolle', ' in Tasche', ' in Koffer',
                       ' im Koffer', ' im Tragekorb', ' im Tragegestell',
                       ' Fabrikat', ' ca.', ' ca ', ' exkl.',
                       ' aus nichtrostendem Stahl']:
        idx = s.lower().find(cut_phrase.lower())
        if idx > 10:
            s = s[:idx]
    s = s.strip().rstrip(',').rstrip(';')
    if len(s) > 55:
        cut = s[:55].rfind(' ')
        s = s[:cut] if cut > 30 else s[:55]
    return s.strip()


# ── Category description / training templates ─────────────────────────────────
_CAT_DESC = {
    "Arm":   "Armatur bzw. Kupplungsstück für Gefahrstoff-Schlauchsysteme am AB-G.",
    "Arb":   "Arbeitsmittel des AB-G für den Einsatz an der Gefahrguteinsatzstelle.",
    "Sond":  "Sonderausstattung des AB-G für spezifische Gefahrgutlagen.",
    "Hand":  "Handwerkzeug in funkenarmer/-freier Ausführung für den Einsatz in ATEX-Zonen.",
    "BSF":   "Mittel für Beleuchtung, Strom, Signalgebung oder Funk an der Einsatzstelle.",
    "PSA":   "Persönliche Schutzausrüstung (PSA) für den Gefahrguteinsatz.",
    "Mess":  "Messgerät zur Erkundung und Überwachung an der Gefahrguteinsatzstelle.",
    "Rett":  "Rettungs- oder Erste-Hilfe-Ausrüstung für den Gefahrguteinsatz.",
    "Lösch": "Tragbarer Feuerlöscher für Entstehungsbrände an der Einsatzstelle.",
}

_CAT_TYPICAL_USE = {
    "Arm":   ["Verbinden von Pumpen, Schläuchen und Behältern",
              "Umpumpen und Absperren von Gefahrflüssigkeiten",
              "Aufbau von Pumpenstrecken an der Einsatzstelle"],
    "Arb":   ["Unterstützung beim Umpumpen und Auffangen",
              "Transport von Ausrüstung an der Einsatzstelle"],
    "Sond":  ["Einsatz bei Gefahrgutvorfällen",
              "Aufbau der Einsatzstelle (TW-Bereiche)"],
    "Hand":  ["Öffnen und Schließen von Behälterverschlüssen und Armaturen",
              "Arbeiten in explosionsgefährdeter Umgebung (ATEX)"],
    "BSF":   ["Ausleuchtung der Einsatzstelle",
              "Energieversorgung für Pumpen und Dekon-Einrichtungen"],
    "PSA":   ["Schutz der Einsatzkräfte beim Kontakt mit Gefahrstoffen",
              "Einsatz im kontaminierten Bereich"],
    "Mess":  ["Erkundung der Gefahrstoffsituation",
              "Kontinuierliche Überwachung von Messwerten an der Einsatzstelle"],
    "Rett":  ["Menschenrettung und Erste Hilfe",
              "Notfallversorgung bei Verätzungen oder Verletzungen"],
    "Lösch": ["Bekämpfung von Entstehungsbränden",
              "Brandsicherung an der Einsatzstelle"],
}

_CAT_QUESTIONS = {
    "Arm": [
        "Für welche Kupplungsarten ist diese Armatur geeignet?",
        "Welche Dichtungswerkstoffe sind für den Gefahrguteinsatz (Säuren, Laugen) zugelassen?",
        "Wie wird die Armatur vor der Verwendung auf Dichtigkeit geprüft?",
    ],
    "Arb": [
        "Wo ist dieses Arbeitsmittel im AB-G verlastet und welchem TW-Bereich gehört es an?",
        "Welche PSA ist beim Umgang mit Gefahrstoffen Pflicht?",
    ],
    "Sond": [
        "Welchem TW-Bereich (TW-1 bis TW-6) ist dieses Gerät zuzuordnen?",
        "Bei welchen Gefahrgutszenarien kommt es zum Einsatz?",
    ],
    "Hand": [
        "Warum ist dieses Werkzeug funkenarm/-frei ausgeführt?",
        "In welchen ATEX-Gerätekategorien (Zonen 0–2) darf funkenarmes Werkzeug eingesetzt werden?",
        "Wie wird funkenarmes Werkzeug auf Beschädigungen und Ermüdung kontrolliert?",
    ],
    "BSF": [
        "Welche Schutzart (IP) bzw. ATEX-Kategorie hat dieses Gerät?",
        "Was ist beim Betrieb in explosionsgefährdeten Atmosphären (ATEX) zu beachten?",
    ],
    "PSA": [
        "Welchen Schutzbereich bietet diese PSA und welche Normen gelten?",
        "Wie wird die PSA nach dem Einsatz dekontaminiert oder entsorgt?",
        "Wie überprüft man die PSA vor dem Anlegen auf Unversehrtheit?",
    ],
    "Mess": [
        "Was misst dieses Gerät und in welcher Einheit?",
        "In welchem Intervall wird das Gerät kalibriert?",
        "Welche Grenz- und Alarmwerte sind beim Gefahrguteinsatz relevant?",
    ],
    "Rett": [
        "Wann und wie wird dieses Gerät eingesetzt?",
        "Welche Erste-Hilfe-Maßnahmen haben bei Gefahrstoffunfällen Priorität?",
    ],
    "Lösch": [
        "Für welche Brandklassen ist dieser Feuerlöscher zugelassen?",
        "Wie wird der Feuerlöscher auf Einsatzbereitschaft geprüft (Plomben, Druck, Gewicht)?",
        "Welche Sicherheitsmaßnahmen gelten beim Einsatz in Gefahrstoffbereichen?",
    ],
}


# ── Core build function ────────────────────────────────────────────────────────
def get_functions(category: str, name_lower: str) -> list[str]:
    for kw, funcs in FUNCTION_REFINEMENTS:
        if kw in name_lower:
            return funcs
    return CATEGORY_FUNCTIONS.get(category, ["LOGISTIK"])


def get_scenarios(location: str, category: str, name_lower: str) -> list[str]:
    loc = location.strip()
    scenarios = list(LOCATION_SCENARIOS.get(loc, ["GEFAHRGUT_PUMPEN"]))
    if category == "PSA":
        scenarios.append("GEFAHRGUT_DEKON")
    if category == "Lösch":
        return sorted({"BRAND_INNEN", "BRAND_AUSSEN", "BRAND_FAHRZEUG"})
    if "dekon" in name_lower or "dekontamin" in name_lower:
        scenarios.append("GEFAHRGUT_DEKON")
    return sorted(set(scenarios))


def lookup_override(name: str) -> dict:
    """Find the best matching rich override for an item name."""
    nl = name.lower()
    best_key = ""
    best_override: dict = {}
    for key, ov in ITEM_RICH_OVERRIDES.items():
        if key in nl and len(key) > len(best_key):
            best_key = key
            best_override = ov
    return best_override


def build_equipment_json(name: str, category: str, location: str) -> dict:
    eq_id = to_id(name)
    nl = name.lower()
    ov = lookup_override(name)

    functions  = ov.get("equipment_functions") or get_functions(category, nl)
    scenarios  = get_scenarios(location, category, nl)
    extra_sc   = ov.get("deployment_scenarios_extra", [])
    scenarios  = sorted(set(scenarios + extra_sc))

    description   = ov.get("description") or (
        f"{name.strip()}. " + _CAT_DESC.get(category, "Ausrüstungsgegenstand des AB-G.")
    )
    technical_data   = ov.get("technical_data") or extract_technical_data(name)
    typical_use      = ov.get("typical_use") or _CAT_TYPICAL_USE.get(category, [])
    training_qs      = ov.get("training_questions") or _CAT_QUESTIONS.get(category, [])
    images           = ov.get("images", [])
    manuals          = ov.get("manuals", [])

    return {
        "id": eq_id,
        "name": name.strip(),
        "short_name": make_short_name(name),
        "equipment_functions": functions,
        "deployment_scenarios": scenarios,
        "description": description,
        "technical_data": technical_data,
        "typical_use": typical_use,
        "training_questions": training_qs,
        "images": images,
        "manuals": manuals,
        "source": "Beladeliste AB-G, Stand 2025-01-29",
    }


# ── Entry point ────────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate AB-G equipment JSON library data from Beladeliste CSV")
    parser.add_argument("--csv", default=str(DEFAULT_CSV), help="Path to source CSV file")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print statistics only; do not write any files")
    args = parser.parse_args()

    csv_path = Path(args.csv)
    if not csv_path.exists():
        print(f"ERROR: CSV not found: {csv_path}", file=sys.stderr)
        sys.exit(1)

    # ── Read CSV ──────────────────────────────────────────────────────────────
    rows: list[dict] = []
    with open(csv_path, newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            name = row.get('Gegenstand', '').strip()
            if not name:
                continue
            qty_raw = row.get('Stückzahl', '1').strip()
            try:
                qty = int(qty_raw)
            except ValueError:
                qty = 1
            rows.append({
                'name': name,
                'qty': qty,
                'cat': row.get('Kategorie', '').strip(),
                'loc': row.get('Lagerort', '').strip(),
            })

    print(f"Read {len(rows)} rows from {csv_path.name}")

    # ── Build unique equipment map (deduplicate by ID, merge scenarios) ────────
    eq_map: dict[str, dict] = {}
    for row in rows:
        eq = build_equipment_json(row['name'], row['cat'], row['loc'])
        eid = eq['id']
        if eid not in eq_map:
            eq_map[eid] = eq
        else:
            merged = sorted(set(
                eq_map[eid]['deployment_scenarios'] + eq['deployment_scenarios']))
            eq_map[eid]['deployment_scenarios'] = merged

    print(f"Unique equipment items after deduplication: {len(eq_map)}")

    if args.dry_run:
        print("\nDry run – no files written. First 10 items:")
        for eid, eq in list(eq_map.items())[:10]:
            print(f"  {eid}")
            print(f"    name: {eq['name'][:70]}")
            print(f"    functions: {eq['equipment_functions']}")
            print(f"    scenarios: {eq['deployment_scenarios']}")
        return

    # ── Create directories ────────────────────────────────────────────────────
    EQUIPMENT_DIR.mkdir(parents=True, exist_ok=True)

    # ── Write equipment JSON files ────────────────────────────────────────────
    for eid, eq in eq_map.items():
        path = EQUIPMENT_DIR / f"{eid}.json"
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(eq, f, ensure_ascii=False, indent=2)
    print(f"✓ Wrote {len(eq_map)} equipment JSON files  →  {EQUIPMENT_DIR}")

    # ── Build and write loading_plan.json ─────────────────────────────────────
    comp_items: dict[str, list] = defaultdict(list)
    for row in rows:
        comp_items[row['loc']].append({
            "equipment_id": to_id(row['name']),
            "quantity":     row['qty'],
        })

    compartments = []
    seen_locs: set[str] = set()
    for i, loc in enumerate(COMPARTMENT_ORDER):
        if loc in comp_items:
            compartments.append({
                "id":       to_compartment_id(loc),
                "label":    loc,
                "position": i + 1,
                "items":    comp_items[loc],
            })
            seen_locs.add(loc)
    # Append any locations not in the predefined order
    for loc, items in comp_items.items():
        if loc not in seen_locs:
            compartments.append({
                "id":       to_compartment_id(loc),
                "label":    loc,
                "position": len(compartments) + 1,
                "items":    items,
            })

    loading_plan = {
        "vehicle_id":   "ab_g",
        "vehicle_name": "AB-G (Abrollbehälter Gefahrgut)",
        "vehicle_type": "AB-G",
        "description": (
            "Abrollbehälter für Gefahrguteinsätze. Ausgerüstet für die Tätigkeitsbereiche: "
            "Auffangen (TW-1), Absperrgrenze (TW-2), Umpumpen (TW-3), "
            "Strom/Licht (TW-4), Erstangriff (TW-5) und Dekontamination (TW-6)."
        ),
        "source":       "Beladeliste AB-G, Stand 2025-01-29",
        "compartments": compartments,
    }

    lp_path = VEHICLE_DIR / "loading_plan.json"
    with open(lp_path, 'w', encoding='utf-8') as f:
        json.dump(loading_plan, f, ensure_ascii=False, indent=2)
    total_items = sum(len(c["items"]) for c in compartments)
    print(f"✓ Wrote loading_plan.json  →  {len(compartments)} compartments, {total_items} item entries")

    # ── Write vehicle.json ────────────────────────────────────────────────────
    vehicle = {
        "id":           "ab_g",
        "name":         "AB-G",
        "full_name":    "Abrollbehälter Gefahrgut",
        "type":         "AB-G",
        "license_plate": None,
        "image_path":   None,
        "description": (
            "Abrollbehälter für den Gefahrguteinsatz. Enthält Ausrüstung für "
            "Umpumpen, Abdichten, Auffangen, Messen, Dekontamination und PSA."
        ),
        "deployment_scenarios": [
            "GEFAHRGUT_AUFFANGEN",
            "GEFAHRGUT_ABDICHTEN",
            "GEFAHRGUT_DEKON",
            "GEFAHRGUT_MESSEN",
            "GEFAHRGUT_PUMPEN",
        ],
        "images":  [],
        "source":  "Beladeliste AB-G, Stand 2025-01-29",
    }
    vp = VEHICLE_DIR / "vehicle.json"
    with open(vp, 'w', encoding='utf-8') as f:
        json.dump(vehicle, f, ensure_ascii=False, indent=2)
    print(f"✓ Wrote vehicle.json")

    # ── Write / update library metadata.json ──────────────────────────────────
    metadata_path = OUT_DIR / "metadata.json"
    metadata = {
        "version":         "1.0.0",
        "equipment_count": len(eq_map),
        "vehicles":        ["ab_g"],
        "last_updated":    "2026-03-13",
    }
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)
    print(f"✓ Wrote metadata.json  (v1.0.0, {len(eq_map)} items)")

    print(f"\n✅  All done. Output directory: {OUT_DIR}")


if __name__ == "__main__":
    main()
