/// connection_native.dart – SQLite file connection for mobile/desktop.
library;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection({String? abteilungId}) =>
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, databaseFileName(abteilungId)));
      return NativeDatabase.createInBackground(file);
    });

/// Dateiname je Abteilung (Issue #57 Phase 2). Die eigene Abteilung
/// ([abteilungId] = null) behält die angestammte Datei `fwapp.sqlite` —
/// unveröffentlichte Arbeit von vor dem Update darf beim Umstieg nicht
/// verschwinden. Nur Schwester-Sichten bekommen eigene Dateien.
String databaseFileName(String? abteilungId) =>
    abteilungId == null ? 'fwapp.sqlite' : 'fwapp_$abteilungId.sqlite';
