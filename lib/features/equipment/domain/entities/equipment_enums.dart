/// equipment_enums.dart – Two-axis classification system (§9).
/// EquipmentFunction: what the device technically does.
/// DeploymentScenario: in which incident type the equipment is used.
library;

enum EquipmentFunction {
  rettung,
  brand,
  wasser,
  pumpen,
  beleuchtung,
  strom,
  lueftung,
  kommunikation,
  messgeraete,
  absperren,
  logistik,
  fuehrung,
  psa,
  armaturen,
  abdichten,
  dekon,
  handwerkzeug;

  String get label => switch (this) {
        rettung => 'Rettung',
        brand => 'Brand',
        wasser => 'Wasser',
        pumpen => 'Pumpen',
        beleuchtung => 'Beleuchtung',
        strom => 'Strom / Energie',
        lueftung => 'Lüftung',
        kommunikation => 'Kommunikation',
        messgeraete => 'Messgeräte',
        absperren => 'Absperren',
        logistik => 'Logistik',
        fuehrung => 'Führung',
        psa => 'Persönliche Schutzausrüstung',
        armaturen => 'Armaturen / Kupplungen',
        abdichten => 'Abdichten / Leckdichtung',
        dekon => 'Dekontamination',
        handwerkzeug => 'Handwerkzeug',
      };

  String get jsonKey => name.toUpperCase();

  static EquipmentFunction? fromJson(String value) {
    final upper = value.toUpperCase();
    for (final e in values) {
      if (e.jsonKey == upper) return e;
    }
    return null;
  }
}

enum DeploymentScenario {
  // Brand
  brandInnen,
  brandAussen,
  brandVegetation,
  brandFahrzeug,
  // Verkehrsunfall
  vuPkw,
  vuLkw,
  vuBus,
  vuBahn,
  // Technische Hilfeleistung
  thKlemmt,
  thSturm,
  thBaum,
  thEinsturz,
  thTier,
  thWasser,
  // Gefahrgut
  gefahrgutMessen,
  gefahrgutAbdichten,
  gefahrgutPumpen,
  gefahrgutAuffangen,
  gefahrgutDekon,
  // Wasser / Sonstiges
  hochwasser,
  wasserrettung,
  absturzsicherung,
  hoehenrettung;

  String get label => switch (this) {
        brandInnen => 'Brand Innen',
        brandAussen => 'Brand Außen',
        brandVegetation => 'Vegetationsbrand',
        brandFahrzeug => 'Fahrzeugbrand',
        vuPkw => 'VU PKW',
        vuLkw => 'VU LKW',
        vuBus => 'VU Bus',
        vuBahn => 'VU Bahn / Schiene',
        thKlemmt => 'TH – Person eingeklemmt',
        thSturm => 'TH – Sturm',
        thBaum => 'TH – Baum',
        thEinsturz => 'TH – Einsturz',
        thTier => 'TH – Tier in Not',
        thWasser => 'TH – Wasser',
        gefahrgutMessen => 'Gefahrgut – Messen / Erkunden',
        gefahrgutAbdichten => 'Gefahrgut – Abdichten',
        gefahrgutPumpen => 'Gefahrgut – Umpumpen',
        gefahrgutAuffangen => 'Gefahrgut – Auffangen',
        gefahrgutDekon => 'Gefahrgut – Dekontamination',
        hochwasser => 'Hochwasser',
        wasserrettung => 'Wasserrettung',
        absturzsicherung => 'Absturzsicherung',
        hoehenrettung => 'Höhenrettung',
      };

  String get jsonKey {
    // Convert camelCase to UPPER_SNAKE_CASE
    final s = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => '_${m.group(0)}',
    );
    return s.toUpperCase();
  }

  static DeploymentScenario? fromJson(String value) {
    final upper = value.toUpperCase();
    for (final e in values) {
      if (e.jsonKey == upper) return e;
    }
    return null;
  }
}
