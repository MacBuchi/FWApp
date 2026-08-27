/// wissen_seeder.dart – Der mitgelieferte Grundstock der Wissensdatenbank
/// (Issue #174).
///
/// **Warum aus dem Asset und nicht aus einer Migration.** Eine Migration
/// läuft einmal und ist danach unantastbar (append-only). Die Einordnung
/// einer Frage ist aber eine redaktionelle Entscheidung, die man korrigieren
/// können muss — steht sie in einer Migration, ist sie für immer so falsch,
/// wie sie eingespielt wurde. Aus dem Asset lässt sie sich mit der nächsten
/// App-Version richtigstellen.
///
/// **Warum die Fragen nicht einfach im Asset bleiben.** Weil man sie dort
/// nicht suchen, nicht ergänzen und nicht freigeben kann — genau das war der
/// Wunsch. Das Asset ist ab jetzt die Aussaat, nicht der Bestand.
library;

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

class WissenSeeder {
  final AppDatabase _db;
  const WissenSeeder(this._db);

  /// Legt fehlende mitgelieferte Fragen an. Mehrfach aufrufbar.
  ///
  /// Erkannt wird eine vorhandene Frage am **Fragetext**, nicht an einer ID:
  /// Das Asset hat keine stabilen Kennungen, und ein zweiter Lauf soll den
  /// Bestand ergänzen, nicht verdoppeln. Wer eine mitgelieferte Frage
  /// bearbeitet hat, behält seine Fassung — der Seeder fasst Vorhandenes
  /// nicht an.
  Future<int> seedIfNeeded(PartyInhalte inhalte) async {
    try {
      final vorhanden = {
        for (final f in await _db.wissenDao.getAll()) _schluessel(f.frage),
      };

      var angelegt = 0;
      for (final f in inhalte.fragen) {
        if (!vorhanden.add(_schluessel(f.frage))) continue;
        final gebiet = Wissensgebiet.ausSchluessel(f.gebiet) ??
            // Ohne Gebiet im Asset: Klischees bleiben Klischees, alles
            // andere landet im organisatorischen Sammelbecken, statt sich
            // ein Sachgebiet anzumaßen.
            (f.kategorie == kKategorieKlischee
                ? Wissensgebiet.klischee
                : Wissensgebiet.rechtUndOrganisation);

        await _db.wissenDao.insertFrage(WissensfragenCompanion.insert(
          gebiet: gebiet.schluessel,
          frage: f.frage,
          antwortenJson: Value(stringListToJson(f.antworten)),
          richtigeJson: Value(stringListToJson(['${f.richtig}'])
              .replaceAll('"', '')),
          erklaerung: Value(f.erklaerung),
          herkunft: Value(Fragenherkunft.mitgeliefert.schluessel),
          // Ausgeliefertes ist geprüft — es wartet auf niemanden.
          stand: Value(Fragenstand.freigegeben.schluessel),
        ));
        angelegt++;
      }
      if (angelegt > 0) {
        appLog.i('Wissensdatenbank: $angelegt Fragen aus dem Asset angelegt.');
      }
      return angelegt;
    } catch (e, s) {
      // Ohne Grundstock ist die App ärmer, aber nicht kaputt — der
      // Party-Modus fällt auf seine Beladungsfragen zurück.
      appLog.w('Wissens-Grundstock nicht anlegbar', error: e, stackTrace: s);
      return 0;
    }
  }

  /// Vergleichsform des Fragetexts: Groß-/Kleinschreibung und Leerraum sind
  /// egal, sonst legt ein korrigiertes Leerzeichen die Frage ein zweites Mal
  /// an.
  String _schluessel(String frage) =>
      frage.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
