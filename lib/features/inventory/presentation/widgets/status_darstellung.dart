/// status_darstellung.dart – Farbe und Symbol eines Inventur-Prüfstatus.
///
/// Herausgezogen, als der Abschlussbericht dieselbe Zuordnung brauchte wie
/// die Prüfliste (Issue #178). Vorher stand sie zweimal da und war bereits
/// auseinandergelaufen: Die Liste kannte ein eigenes Symbol für „beschädigt",
/// der Bericht zeigte für alles außer „fehlt" dasselbe Warndreieck.
///
/// Den zugehörigen Text liefert `statusText` aus `data/inventory_export.dart`
/// — bewusst dieselbe Quelle wie für die CSV-Datei, damit die Beschriftung in
/// der App und im Bericht nicht auseinanderlaufen kann.
library;

import 'package:flutter/material.dart';
import 'package:fwapp/core/database/app_database.dart';

/// Farbe und Symbol für [status].
///
/// „In Reparatur" ist bewusst blau und nicht rot: Das Gerät ist bekannt und
/// unterwegs, das ist ein Vorgang und kein Loch in der Beladung.
(Color, IconData) statusDarstellung(String status) => switch (status) {
      InventoryChecks.statusOk => (Colors.green, Icons.check_circle),
      InventoryChecks.statusMissing => (Colors.red, Icons.cancel),
      InventoryChecks.statusDamaged => (Colors.orange, Icons.warning),
      InventoryChecks.statusRepair => (Colors.blue, Icons.build_circle),
      _ => (Colors.grey, Icons.radio_button_unchecked),
    };
