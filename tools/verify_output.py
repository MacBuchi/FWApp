#!/usr/bin/env python3
"""Quick verification of generated AB-G equipment JSON data."""
import json
from pathlib import Path

base = Path("assets/equipment_library/vehicles/ab_g/equipment")
vehicle_dir = Path("assets/equipment_library/vehicles/ab_g")

def check(label, eq_file, keys):
    d = json.loads((base / eq_file).read_text())
    print(f"\n=== {label} ===")
    for k in keys:
        v = d.get(k, "MISSING")
        if isinstance(v, str):
            print(f"  {k}: {v[:110]}")
        else:
            print(f"  {k}: {v}")

# Vetter Rohrdichtkissen
check("Vetter-Rohrdichtkissen RDK7/15",
      "vetter_rohrdichtkissen_1_5_bar_rdk7_15fs.json",
      ["id","equipment_functions","deployment_scenarios","description"])
d = json.loads((base/"vetter_rohrdichtkissen_1_5_bar_rdk7_15fs.json").read_text())
print(f"  training_qs ({len(d['training_questions'])} total):", d["training_questions"][0])
print(f"  manuals:", d["manuals"])

# Chemikalienanzug
check("Chemikalienanzug Typ 1a-ET",
      "chemikalienanzug_typ_1a_et_modell_onesuit_pro_in_tasche.json",
      ["id","equipment_functions","technical_data","deployment_scenarios"])
d = json.loads((base/"chemikalienanzug_typ_1a_et_modell_onesuit_pro_in_tasche.json").read_text())
print(f"  training_qs ({len(d['training_questions'])} total):", d["training_questions"][0])

# KAMLOK fitting
kamlok_files = sorted(f.name for f in base.iterdir() if "kamlok" in f.name)
print("\n=== KAMLOK fittings ===")
for fn in kamlok_files:
    d = json.loads((base/fn).read_text())
    print(f"  {d['id']}")
    print(f"    functions: {d['equipment_functions']}, kupplungen: {d['technical_data'].get('kupplungen','?')}")

# Stromerzeuger
check("Stromerzeuger",
      "stromerzeuger_13_bska_14_inkl_beos_anschluss.json",
      ["id","equipment_functions","description"])

# Loading plan
print("\n=== Loading plan compartments ===")
lp = json.loads((vehicle_dir/"loading_plan.json").read_text())
total = 0
for c in lp["compartments"]:
    total += len(c["items"])
    print(f"  {c['label']:30s}  ({c['id']})  → {len(c['items'])} items")
print(f"  Total items: {total}")

# Metadata
print("\n=== metadata.json ===")
m = json.loads(Path("assets/equipment_library/metadata.json").read_text())
print(" ", m)

# Deduplicated items check (Rettungsschere in G2+TW-6 should have merged scenarios)
print("\n=== Rettungsschere (dedup check) ===")
d = json.loads((base/"rettungsschere_geeignet_fuer_textil_leder_o_ae.json").read_text())
print("  scenarios:", d["deployment_scenarios"])
print("  (should contain both G2-scenarios and TW-6 scenarios)")
