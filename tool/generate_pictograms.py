#!/usr/bin/env python3
"""Erzeugt die Piktogramm-Bildbibliothek: pro Katalog-Gerät ein PNG
(Kategorie-Farbe + weiße Silhouette + Kurzlabel) unter
assets/equipment_library/images/<id>.png.

Aufruf:  python3 tool/generate_pictograms.py   (braucht rsvg-convert)

Die Piktogramme sind bewusst schematisch ("Symbolbild") – echte Fotos
ersetzen sie nach und nach über den Kamera-Workflow der App."""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = json.loads(
    (ROOT / 'assets/equipment_library/catalog/standard_catalog.json')
    .read_text())
OUT = ROOT / 'assets/equipment_library/images'

# Kategorie-Farben analog equipmentCategoryStyle() in equipment_avatar.dart.
COLORS = {
    'RETTUNG': '#C62828', 'BRAND': '#D84315', 'WASSER': '#1565C0',
    'PUMPEN': '#283593', 'BELEUCHTUNG': '#FF8F00', 'STROM': '#F9A825',
    'LUEFTUNG': '#0277BD', 'KOMMUNIKATION': '#6A1B9A',
    'MESSGERAETE': '#00695C', 'ABSPERREN': '#EF6C00', 'LOGISTIK': '#4E342E',
    'FUEHRUNG': '#37474F', 'PSA': '#2E7D32', 'ARMATUREN': '#00838F',
    'ABDICHTEN': '#9E9D24', 'DEKON': '#558B2F', 'HANDWERKZEUG': '#546E7A',
}

S = 'stroke="#fff" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="#fff"'


def g(body: str) -> str:
    return f'<g {S}>{body}</g>'


# ── Silhouetten (128×128-Canvas, Glyphenbereich ca. y 18–86) ────────────────
GLYPHS = {
    'hose': g('<circle cx="64" cy="50" r="26"/><circle cx="64" cy="50" r="12"/>'
              '<path d="M88 62 L104 78"/>'),
    'nozzle': g('<path d="M40 82 L64 34 M52 82 L76 34"/>'
                '<path d="M64 34 L76 34 L82 20 L58 20 Z"/>'
                '<path d="M40 82 L52 82"/>'),
    'foam_nozzle': g('<path d="M52 84 L58 48 M76 84 L70 48"/>'
                     '<path d="M58 48 L70 48 L74 20 L54 20 Z"/>'),
    'distributor': g('<path d="M64 84 L64 56"/>'
                     '<path d="M64 56 L36 30 M64 56 L64 26 M64 56 L92 30"/>'
                     '<circle cx="36" cy="26" r="6"/><circle cx="64" cy="20" r="6"/>'
                     '<circle cx="92" cy="26" r="6"/>'),
    'collector': g('<path d="M64 20 L64 48"/>'
                   '<path d="M40 80 L64 48 M88 80 L64 48"/>'
                   '<circle cx="40" cy="84" r="6"/><circle cx="88" cy="84" r="6"/>'),
    'adapter': g('<rect x="42" y="22" width="44" height="24" rx="5"/>'
                 '<rect x="50" y="58" width="28" height="24" rx="5"/>'
                 '<path d="M56 46 L56 58 M72 46 L72 58"/>'),
    'elbow': g('<path d="M40 26 L40 58 Q40 82 66 82 L94 82"/>'
               '<path d="M30 26 L50 26 M94 72 L94 92"/>'),
    'standpipe': g('<path d="M64 88 L64 24"/>'
                   '<path d="M64 42 L40 30 M64 42 L88 30"/>'
                   '<circle cx="36" cy="28" r="6"/><circle cx="92" cy="28" r="6"/>'
                   '<path d="M52 88 L76 88"/>'),
    'hydrant_key': g('<path d="M64 26 L64 86"/><path d="M36 26 L92 26"/>'
                     '<path d="M56 86 L72 86 L72 74 L56 74 Z"/>'),
    'coupling_key': g('<path d="M46 88 L74 44"/>'
                      '<path d="M74 44 A18 18 0 1 0 60 22"/>'),
    'hose_holder': g('<path d="M44 36 Q64 20 84 36 L84 70 Q64 86 44 70 Z"/>'
                     '<path d="M64 20 L64 40"/>'),
    'hose_bridge': g('<path d="M20 82 L44 60 L84 60 L108 82"/>'
                     '<circle cx="54" cy="74" r="7"/><circle cx="74" cy="74" r="7"/>'),
    'valve': g('<path d="M28 62 L64 62 L100 62"/>'
               '<path d="M44 46 L64 62 L44 78 Z M84 46 L64 62 L84 78 Z"/>'
               '<path d="M64 62 L64 34 M50 34 L78 34"/>'),
    'inline_device': g('<path d="M22 58 L42 58 M86 58 L106 58"/>'
                       '<rect x="42" y="42" width="44" height="32" rx="8"/>'
                       '<path d="M64 42 L64 24 M52 24 L76 24"/>'),
    'canister': g('<rect x="38" y="36" width="52" height="50" rx="8"/>'
                  '<path d="M46 36 L46 24 L70 24 L70 36"/>'
                  '<path d="M82 36 L90 26"/>'),
    'bucket_pump': g('<path d="M38 46 L46 86 L82 86 L90 46 Z"/>'
                     '<path d="M60 46 L60 22 M50 22 L70 22"/>'
                     '<path d="M60 34 L86 34"/>'),
    'extinguisher': g('<rect x="48" y="38" width="32" height="48" rx="10"/>'
                      '<path d="M58 38 L58 28 L70 28"/>'
                      '<path d="M70 28 L84 20"/>'),
    'blanket': g('<rect x="34" y="34" width="60" height="52" rx="6"/>'
                 '<path d="M34 52 L94 52 M34 68 L94 68"/>'),
    'beater': g('<path d="M84 20 L44 60"/>'
                '<path d="M44 60 L28 44 Q20 68 36 76 Q52 84 44 60 Z"/>'),
    'scba': g('<rect x="50" y="24" width="28" height="56" rx="14"/>'
              '<path d="M58 24 L58 16 L70 16 L70 24"/>'
              '<path d="M40 40 L50 40 M40 66 L50 66 M40 40 L40 66"/>'),
    'cylinder': g('<rect x="52" y="28" width="24" height="56" rx="12"/>'
                  '<path d="M60 28 L60 18 L68 18 L68 28"/>'),
    'mask': g('<path d="M64 22 Q92 22 90 52 Q88 78 64 84 Q40 78 38 52 Q36 22 64 22 Z"/>'
              '<circle cx="64" cy="66" r="9"/>'
              '<path d="M46 44 L58 48 M82 44 L70 48"/>'),
    'hood': g('<path d="M64 20 Q90 24 88 56 L88 84 L40 84 L40 56 Q38 24 64 20 Z"/>'
              '<circle cx="64" cy="50" r="13"/>'),
    'clipboard': g('<rect x="38" y="24" width="52" height="62" rx="6"/>'
                   '<path d="M54 24 L54 16 L74 16 L74 24"/>'
                   '<path d="M48 44 L80 44 M48 58 L80 58 M48 72 L68 72"/>'),
    'stretcher': g('<path d="M20 56 L108 56"/>'
                   '<rect x="36" y="44" width="56" height="24" rx="10"/>'),
    'basket_stretcher': g('<path d="M24 44 L30 70 Q64 84 98 70 L104 44"/>'
                          '<path d="M40 52 L40 72 M64 54 L64 76 M88 52 L88 72"/>'),
    'board': g('<rect x="50" y="16" width="28" height="90" rx="12"/>'
               '<circle cx="64" cy="34" r="5"/><circle cx="64" cy="58" r="5"/>'
               '<circle cx="64" cy="82" r="5"/>'),
    'harness': g('<path d="M46 20 L46 84 M82 20 L82 84"/>'
                 '<path d="M46 38 L82 38 M46 66 L82 66"/>'
                 '<circle cx="64" cy="52" r="8"/>'),
    'case_cross': g('<rect x="32" y="34" width="64" height="50" rx="8"/>'
                    '<path d="M52 34 L52 26 L76 26 L76 34"/>'
                    f'<path d="M60 48 L68 48 L68 54 L74 54 L74 62 L68 62 L68 68 L60 68 L60 62 L54 62 L54 54 L60 54 Z" {F} stroke="none"/>'),
    'scissors': g('<path d="M40 24 L82 78 M88 24 L46 78"/>'
                  '<circle cx="38" cy="86" r="9"/><circle cx="90" cy="86" r="9"/>'),
    'aed': g(f'<path d="M64 30 C50 12 22 26 34 48 C42 62 64 80 64 80 C64 80 86 62 94 48 C106 26 78 12 64 30 Z"/>'
             f'<path d="M68 36 L56 54 L66 54 L58 72" stroke-width="5"/>'),
    'carabiner': g('<path d="M64 20 Q90 22 88 50 Q86 82 64 86 Q42 82 40 50 Q39 30 52 24"/>'
                   '<path d="M52 24 L64 20"/><path d="M44 42 L56 34"/>'),
    'jump_cushion': g('<rect x="26" y="52" width="76" height="30" rx="12"/>'
                      '<path d="M64 40 L64 18 M54 28 L64 18 L74 28"/>'),
    'spreader': g('<path d="M64 86 L64 58"/>'
                  '<path d="M64 58 L40 24 M64 58 L88 24"/>'
                  '<path d="M40 24 L48 18 M88 24 L80 18"/>'),
    'cutter': g('<path d="M64 84 L64 60"/>'
                '<path d="M64 60 Q40 44 48 20 Q66 34 64 60 Z"/>'
                '<path d="M64 60 Q88 44 80 20 Q62 34 64 60 Z"/>'),
    'ram': g('<rect x="24" y="52" width="44" height="20" rx="6"/>'
             '<rect x="68" y="56" width="28" height="12" rx="4"/>'
             '<path d="M96 62 L106 62 M106 52 L106 72"/>'),
    'power_unit': g('<rect x="30" y="40" width="52" height="42" rx="8"/>'
                    '<path d="M82 52 Q102 52 100 30 M82 68 Q108 68 106 40"/>'
                    '<path d="M42 40 L42 30 L60 30"/>'),
    'airbags': g('<rect x="34" y="62" width="60" height="16" rx="8"/>'
                 '<rect x="38" y="44" width="52" height="16" rx="8"/>'
                 '<path d="M64 34 L64 18 M55 26 L64 18 L73 26"/>'),
    'cribbing': g('<rect x="30" y="66" width="68" height="14" rx="3"/>'
                  '<rect x="38" y="50" width="52" height="14" rx="3"/>'
                  '<rect x="46" y="34" width="36" height="14" rx="3"/>'),
    'winch': g('<rect x="34" y="36" width="42" height="30" rx="8"/>'
               '<path d="M50 66 L50 84 M60 66 L60 84"/>'
               '<path d="M76 50 L98 50 Q104 58 96 64 L90 58"/>'),
    'shackle': g('<path d="M46 54 Q46 22 64 22 Q82 22 82 54"/>'
                 '<path d="M38 54 L54 54 M74 54 L90 54"/>'
                 '<path d="M42 54 L42 66 M86 54 L86 66"/>'),
    'halligan': g('<path d="M64 18 L64 88"/>'
                  '<path d="M48 18 L80 18 M48 18 Q38 22 40 32"/>'
                  '<path d="M64 88 L52 100 M64 88 L76 100"/>'),
    'crowbar': g('<path d="M50 100 L78 32 Q82 20 70 20 Q60 20 62 30"/>'),
    'door': g('<rect x="40" y="20" width="48" height="72" rx="4"/>'
              '<circle cx="76" cy="56" r="4"/>'
              '<path d="M28 62 L40 56 M28 62 L36 68"/>'),
    'bolt_cutter': g('<path d="M56 46 L28 88 M72 46 L100 88"/>'
                     '<path d="M56 46 Q50 26 64 24 Q78 26 72 46"/>'
                     '<path d="M56 46 L72 46"/>'),
    'grinder': g('<circle cx="46" cy="56" r="22"/>'
                 '<path d="M66 48 L104 40 M66 64 L104 62"/>'
                 '<circle cx="46" cy="56" r="5"/>'),
    'recip_saw': g('<rect x="58" y="46" width="40" height="24" rx="8"/>'
                   '<path d="M58 56 L20 56"/>'
                   '<path d="M22 56 L26 50 M30 56 L34 50 M38 56 L42 50 M46 56 L50 50"/>'),
    'chainsaw': g('<rect x="66" y="44" width="34" height="28" rx="8"/>'
                  '<path d="M66 50 L20 50 Q12 58 20 66 L66 66"/>'
                  '<path d="M22 50 L22 66 M32 50 L32 66 M42 50 L42 66 M52 50 L52 66"/>'),
    'chaps': g('<path d="M44 20 L84 20 L82 56 L74 88 L62 88 L64 58 L58 88 L46 88 Z"/>'),
    'glass': g('<rect x="36" y="24" width="56" height="68" rx="4"/>'
               '<path d="M64 40 L52 56 L68 60 L56 78"/>'),
    'steering': g('<circle cx="64" cy="54" r="30"/><circle cx="64" cy="54" r="8"/>'
                  '<path d="M36 50 L56 52 M92 50 L72 52 M64 84 L64 62"/>'),
    'triangle': g('<path d="M64 22 L98 82 L30 82 Z"/>'
                  '<path d="M64 40 L82 72 L46 72 Z"/>'),
    'fold_signal': g('<path d="M64 18 L92 66 L36 66 Z"/>'
                     '<path d="M64 66 L64 92 M48 92 L80 92"/>'),
    'generator': g('<rect x="26" y="42" width="66" height="40" rx="8"/>'
                   '<circle cx="46" cy="62" r="10"/>'
                   '<path d="M70 54 L84 54 M70 70 L84 70 M26 42 L26 32 L54 32"/>'),
    'floodlight': g('<rect x="36" y="26" width="56" height="40" rx="6"/>'
                    '<path d="M46 36 L58 56 M62 36 L74 56 M78 36 L82 44"/>'
                    '<path d="M64 66 L64 88 M46 88 L82 88"/>'),
    'tripod': g('<path d="M64 22 L36 92 M64 22 L92 92 M64 22 L64 92"/>'
                '<path d="M46 66 L82 66"/>'),
    'cable_reel': g('<circle cx="58" cy="56" r="28"/><circle cx="58" cy="56" r="9"/>'
                    '<path d="M86 56 L104 56 L104 72"/>'),
    'power_dist': g('<rect x="34" y="30" width="60" height="52" rx="8"/>'
                    '<circle cx="50" cy="50" r="7"/><circle cx="78" cy="50" r="7"/>'
                    '<circle cx="64" cy="68" r="7"/>'),
    'handlamp': g('<rect x="42" y="40" width="34" height="44" rx="8"/>'
                  '<path d="M50 40 L50 28 L68 28 L68 40"/>'
                  '<path d="M84 50 L100 42 M84 62 L102 62 M84 74 L100 82"/>'),
    'angle_lamp': g('<path d="M50 88 L50 44 L74 44"/>'
                    '<rect x="70" y="34" width="18" height="20" rx="5"/>'
                    '<path d="M94 38 L106 32 M96 48 L108 48"/>'),
    'balloon_light': g('<circle cx="64" cy="40" r="22"/>'
                       '<path d="M64 62 L64 92 M50 92 L78 92"/>'
                       '<path d="M54 34 Q64 28 74 34"/>'),
    'portable_pump': g('<rect x="30" y="40" width="56" height="36" rx="8"/>'
                       '<circle cx="86" cy="58" r="14"/>'
                       '<path d="M30 48 L20 48 M30 68 L20 68 M40 40 L40 30 L66 30"/>'),
    'submersible': g('<rect x="46" y="42" width="36" height="40" rx="8"/>'
                     '<path d="M64 42 L64 22 Q64 16 72 16"/>'
                     '<path d="M40 90 Q48 84 56 90 Q64 96 72 90 Q80 84 88 90"/>'),
    'wet_vac': g('<rect x="40" y="44" width="48" height="40" rx="10"/>'
                 '<path d="M64 44 L64 34 Q64 26 74 26 L88 26"/>'
                 '<circle cx="52" cy="88" r="5"/><circle cx="76" cy="88" r="5"/>'),
    'folding_tank': g('<path d="M28 44 L36 82 L92 82 L100 44"/>'
                      '<path d="M28 44 L100 44"/>'
                      '<path d="M40 58 Q52 52 64 58 Q76 64 88 58"/>'),
    'fan': g('<circle cx="64" cy="54" r="30"/>'
             '<path d="M64 54 Q64 34 76 30 M64 54 Q82 60 82 72 M64 54 Q46 62 38 52 M64 54 Q56 36 44 38"/>'
             '<circle cx="64" cy="54" r="6"/>'),
    'detector': g('<rect x="44" y="24" width="40" height="62" rx="8"/>'
                  '<rect x="52" y="34" width="24" height="16" rx="3"/>'
                  '<circle cx="58" cy="64" r="4"/><circle cx="72" cy="64" r="4"/>'
                  '<path d="M52 76 L76 76"/>'),
    'thermal_cam': g('<rect x="34" y="38" width="44" height="34" rx="8"/>'
                     '<path d="M78 48 L96 40 L96 68 L78 60"/>'
                     '<path d="M46 80 Q54 74 62 80" stroke-width="4"/>'),
    'voltage_tester': g('<path d="M60 16 L60 56 M68 16 L68 56"/>'
                        '<rect x="52" y="56" width="24" height="34" rx="8"/>'
                        '<path d="M70 62 L60 76 L68 76 L60 88" stroke-width="4"/>'),
    'cone': g('<path d="M64 20 L84 80 L44 80 Z"/>'
              '<path d="M34 88 L94 88"/><path d="M52 52 L76 52"/>'),
    'beacon': g('<path d="M48 84 L48 58 Q48 40 64 40 Q80 40 80 58 L80 84 Z"/>'
                '<path d="M64 30 L64 18 M44 34 L36 26 M84 34 L92 26"/>'
                '<path d="M38 88 L90 88"/>'),
    'tape_roll': g('<circle cx="56" cy="50" r="24"/><circle cx="56" cy="50" r="9"/>'
                   '<path d="M78 62 L104 74 M104 66 L104 82 L88 78"/>'),
    'paddle': g('<circle cx="64" cy="40" r="22"/>'
                '<path d="M64 62 L64 96"/>'
                '<circle cx="64" cy="40" r="9"/>'),
    'radio': g('<rect x="46" y="34" width="36" height="54" rx="8"/>'
               '<path d="M54 34 L54 16"/>'
               '<rect x="54" y="44" width="20" height="12" rx="2"/>'
               '<path d="M56 68 L72 68 M56 76 L72 76"/>'),
    'megaphone': g('<path d="M36 50 L36 66 L52 66 L84 84 L84 32 L52 50 Z"/>'
                   '<path d="M92 48 Q100 58 92 68"/>'),
    'helmet': g('<path d="M30 62 Q30 28 64 28 Q98 28 98 62 Z"/>'
                '<path d="M22 70 Q64 80 106 70"/>'
                '<path d="M64 28 L64 16"/>'),
    'belt': g('<path d="M24 54 L104 54 M24 70 L104 70"/>'
              '<rect x="52" y="46" width="24" height="32" rx="6"/>'),
    'rope_coil': g('<circle cx="64" cy="50" r="26"/><circle cx="64" cy="50" r="26" transform="rotate(30 64 50)" stroke-dasharray="10 8"/>'
                   '<path d="M64 76 Q60 88 68 96"/>'),
    'glove': g('<path d="M48 92 L48 44 Q48 36 54 36 L56 44 L56 32 Q56 24 62 24 L64 44 L64 22 Q64 14 70 14 L72 44 L72 28 Q72 20 78 20 L80 48 L88 40 Q94 34 96 44 L84 74 L84 92 Z"/>'),
    'vest': g('<path d="M44 26 L54 20 Q64 30 74 20 L84 26 L84 90 L44 90 Z"/>'
              '<path d="M44 54 L84 54 M44 68 L84 68"/>'),
    'waders': g('<path d="M46 18 L82 18 L82 52 L78 88 L64 88 L66 56 L60 88 L46 88 Z"/>'
                '<path d="M46 30 L58 30 M70 30 L82 30"/>'),
    'ladder': g('<path d="M46 16 L46 96 M82 16 L82 96"/>'
                '<path d="M46 30 L82 30 M46 48 L82 48 M46 66 L82 66 M46 84 L82 84"/>'),
    'toolbox': g('<rect x="30" y="46" width="68" height="38" rx="6"/>'
                 '<path d="M50 46 L50 36 L78 36 L78 46"/>'
                 '<path d="M30 62 L98 62"/>'),
    'spade': g('<path d="M64 14 L64 56"/>'
               '<path d="M56 14 L72 14"/>'
               '<path d="M50 56 L78 56 L78 74 Q78 92 64 96 Q50 92 50 74 Z"/>'),
    'shovel': g('<path d="M64 14 L64 52"/>'
                '<path d="M56 14 L72 14"/>'
                '<path d="M46 52 L82 52 L76 92 L52 92 Z"/>'),
    'broom': g('<path d="M78 14 L58 62"/>'
               '<path d="M58 62 L38 58 L30 92 L66 88 Z"/>'
               '<path d="M40 74 L36 92 M50 76 L46 92 M58 76 L56 90"/>'),
    'hook_pole': g('<path d="M64 100 L64 26"/>'
                   '<path d="M64 26 Q64 14 76 16 M64 34 L50 22"/>'),
    'axe': g('<path d="M78 96 L46 28"/>'
             '<path d="M46 28 L64 20 Q56 40 66 46 L46 28 Z"/>'
             '<path d="M46 28 L34 34"/>'),
    'sledge': g('<path d="M64 96 L64 34"/>'
                '<rect x="40" y="18" width="48" height="20" rx="5"/>'),
    'sack': g('<path d="M50 30 Q42 44 40 62 Q38 88 64 88 Q90 88 88 62 Q86 44 78 30"/>'
              '<path d="M48 30 L80 30 M56 22 L72 22"/>'),
    'tray': g('<path d="M26 48 L34 84 L94 84 L102 48"/>'
              '<path d="M26 48 L102 48"/>'),
    'tow_rope': g('<path d="M20 60 Q40 44 60 60 Q80 76 100 60"/>'
                  '<path d="M20 60 L20 50 M100 60 Q110 66 102 74 L96 68"/>'),
    'jack': g('<path d="M36 88 L92 88"/>'
              '<path d="M44 88 L64 56 L84 88"/>'
              '<path d="M64 56 L64 40 M52 40 L76 40"/>'),
    'wbk_placeholder': '',
}

# Zuordnung Katalog-ID → (Glyph, Label). Label None = short_name (gekürzt).
ITEMS = {
    'std_b_druckschlauch_20m': ('hose', 'B 20'),
    'std_c_druckschlauch_15m': ('hose', 'C 15'),
    'std_d_druckschlauch_15m': ('hose', 'D 15'),
    'std_a_saugschlauch_1_6m': ('hose', 'A Saug'),
    'std_verteiler_bv': ('distributor', 'Verteiler'),
    'std_cm_strahlrohr': ('nozzle', 'CM'),
    'std_bm_strahlrohr': ('nozzle', 'BM'),
    'std_hohlstrahlrohr': ('nozzle', 'HSR'),
    'std_stuetzkruemmer': ('elbow', None),
    'std_sammelstueck': ('collector', None),
    'std_uebergangsstueck_ba': ('adapter', 'A – B'),
    'std_uebergangsstueck_cb': ('adapter', 'B – C'),
    'std_uebergangsstueck_dc': ('adapter', 'C – D'),
    'std_standrohr': ('standpipe', None),
    'std_unterflurhydrantenschluessel': ('hydrant_key', 'UF'),
    'std_oberflurhydrantenschluessel': ('hydrant_key', 'OF'),
    'std_kupplungsschluessel': ('coupling_key', None),
    'std_schlauchhalter': ('hose_holder', None),
    'std_schlauchbruecken': ('hose_bridge', None),
    'std_druckbegrenzungsventil': ('valve', 'DBV'),
    'std_zumischer_z2': ('inline_device', 'Z2'),
    'std_schwerschaumrohr_s2': ('foam_nozzle', 'S2'),
    'std_mittelschaumrohr_m2': ('foam_nozzle', 'M2'),
    'std_schaummittel_kanister': ('canister', 'Schaum'),
    'std_kuebelspritze': ('bucket_pump', None),
    'std_feuerloescher_pg6': ('extinguisher', 'PG 6'),
    'std_feuerloescher_co2': ('extinguisher', 'CO₂'),
    'std_loeschdecke': ('blanket', None),
    'std_feuerpatsche': ('beater', None),
    'std_pressluftatmer': ('scba', 'PA'),
    'std_atemschutzmaske': ('mask', None),
    'std_ersatzflasche_300bar': ('cylinder', '300 bar'),
    'std_fluchthaube': ('hood', None),
    'std_atemschutzueberwachung': ('clipboard', 'ASÜ'),
    'std_krankentrage': ('stretcher', None),
    'std_schleifkorbtrage': ('basket_stretcher', None),
    'std_spineboard': ('board', None),
    'std_ked_system': ('harness', 'KED'),
    'std_verbandkasten': ('case_cross', None),
    'std_rettungsdecke': ('blanket', 'Folie'),
    'std_kleiderschere': ('scissors', None),
    'std_aed': ('aed', 'AED'),
    'std_absturzsicherung': ('carabiner', None),
    'std_sprungretter': ('jump_cushion', 'SP 16'),
    'std_spreizer': ('spreader', None),
    'std_schneidgeraet': ('cutter', None),
    'std_rettungszylinder': ('ram', None),
    'std_hydraulikaggregat': ('power_unit', None),
    'std_hebekissen': ('airbags', None),
    'std_unterbaumaterial': ('cribbing', None),
    'std_mehrzweckzug': ('winch', 'Z 16'),
    'std_anschlagmittel': ('shackle', None),
    'std_halligan': ('halligan', None),
    'std_brechstange': ('crowbar', None),
    'std_tueroeffnungssatz': ('door', None),
    'std_bolzenschneider': ('bolt_cutter', None),
    'std_trennschleifer': ('grinder', None),
    'std_saebelsaege': ('recip_saw', None),
    'std_motorkettensaege': ('chainsaw', None),
    'std_schnittschutz': ('chaps', None),
    'std_glasmanagement': ('glass', None),
    'std_airbag_sicherung': ('steering', None),
    'std_unfalldreieck_satz': ('triangle', None),
    'std_stromerzeuger_5kva': ('generator', '5 kVA'),
    'std_flutlichtstrahler': ('floodlight', '1000 W'),
    'std_stativ': ('tripod', None),
    'std_kabeltrommel_50m': ('cable_reel', '50 m'),
    'std_abzweigstueck_strom': ('power_dist', None),
    'std_handscheinwerfer': ('handlamp', None),
    'std_knickkopflampe': ('angle_lamp', None),
    'std_powermoon': ('balloon_light', None),
    'std_tragkraftspritze': ('portable_pump', 'TS'),
    'std_tauchpumpe_tp4': ('submersible', 'TP 4'),
    'std_tauchpumpe_tp8': ('submersible', 'TP 8'),
    'std_wassersauger': ('wet_vac', None),
    'std_faltbehaelter_5000': ('folding_tank', '5000 l'),
    'std_druckbeluefter': ('fan', None),
    'std_gaswarngeraet': ('detector', 'GAS'),
    'std_co_warner': ('detector', 'CO'),
    'std_waermebildkamera': ('thermal_cam', 'WBK'),
    'std_spannungspruefer': ('voltage_tester', None),
    'std_leitkegel': ('cone', None),
    'std_warnleuchte': ('beacon', None),
    'std_absperrband': ('tape_roll', None),
    'std_winkerkelle': ('paddle', None),
    'std_faltsignal': ('fold_signal', None),
    'std_hrt_funkgeraet': ('radio', 'HRT'),
    'std_megaphon': ('megaphone', None),
    'std_feuerwehrhelm': ('helmet', None),
    'std_haltegurt': ('belt', None),
    'std_feuerwehrleine': ('rope_coil', '30 m'),
    'std_schutzhandschuhe': ('glove', None),
    'std_infektionshandschuhe': ('glove', 'Einmal'),
    'std_warnweste': ('vest', None),
    'std_wathose': ('waders', None),
    'std_steckleiter': ('ladder', '4-tlg.'),
    'std_schiebleiter': ('ladder', '3-tlg.'),
    'std_klappleiter': ('ladder', 'Klapp'),
    'std_werkzeugkasten': ('toolbox', None),
    'std_spaten': ('spade', None),
    'std_schaufel': ('shovel', None),
    'std_besen': ('broom', None),
    'std_einreisshaken': ('hook_pole', None),
    'std_feuerwehraxt': ('axe', None),
    'std_vorschlaghammer': ('sledge', None),
    'std_oelbindemittel': ('sack', 'Ölbinder'),
    'std_auffangbehaelter': ('tray', None),
    'std_kanister_kraftstoff': ('canister', '20 l'),
    'std_abschleppseil': ('tow_rope', None),
    'std_wagenheber': ('jack', None),
}


def darken(hexcol: str, f: float) -> str:
    r, g_, b = (int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
    return f'#{int(r * f):02x}{int(g_ * f):02x}{int(b * f):02x}'


def svg_for(item) -> str:
    glyph_name, label = ITEMS[item['id']]
    label = label if label is not None else (item.get('short_name')
                                             or item['name'])
    if len(label) > 12:
        label = label[:11] + '…'
    funcs = item.get('equipment_functions') or []
    color = COLORS.get(funcs[0] if funcs else '', '#616161')
    font = 17 if len(label) <= 7 else (14 if len(label) <= 10 else 12)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{color}"/>
    <stop offset="1" stop-color="{darken(color, 0.72)}"/>
  </linearGradient></defs>
  <rect width="128" height="128" rx="22" fill="url(#bg)"/>
  {GLYPHS[glyph_name]}
  <rect x="10" y="100" width="108" height="20" rx="10" fill="#000" opacity="0.28"/>
  <text x="64" y="114.5" text-anchor="middle" font-family="Helvetica, Arial, sans-serif"
        font-size="{font}" font-weight="bold" fill="#fff">{label}</text>
</svg>'''


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    catalog_ids = {i['id'] for i in CATALOG['items']}
    missing = catalog_ids - set(ITEMS)
    extra = set(ITEMS) - catalog_ids
    if missing or extra:
        sys.exit(f'Zuordnung unvollständig – fehlend: {sorted(missing)}, '
                 f'überzählig: {sorted(extra)}')
    for item in CATALOG['items']:
        svg = svg_for(item)
        png = OUT / f'{item["id"]}.png'
        subprocess.run(
            ['rsvg-convert', '-w', '256', '-h', '256', '-o', str(png)],
            input=svg.encode(), check=True)
    print(f'{len(CATALOG["items"])} Piktogramme → {OUT}')


if __name__ == '__main__':
    main()
