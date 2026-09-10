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

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/game/party/data/party_inhalte.dart';
import 'package:fwapp/core/database/standard_catalog.dart';
import 'package:fwapp/features/knowledge/data/geraetefragen.dart';
import 'package:fwapp/features/knowledge/data/wissen_asset.dart';
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

  /// Legt die Fragen an, die den Fuhrpark kennen.
  ///
  /// Erzeugt aus dem mitgelieferten Katalog (siehe `geraetefragen.dart`),
  /// also **auf jedem Gerät identisch** — deshalb `mitgeliefert` und deshalb
  /// nie hochgeladen: Sie für jede Wehr ein zweites Mal zu speichern wäre
  /// derselbe Fehler, den `wissen_sync.dart` schon für den Party-Topf
  /// vermeidet.
  ///
  /// Erkannt wird wie bei den Geschwistern am Fragetext. Wächst der Katalog,
  /// kommen die neuen Fragen beim nächsten Start dazu; wer eine korrigiert
  /// hat, behält seine Fassung.
  ///
  /// ⚠️ Angelegt werden sie für den GANZEN Katalog, nicht nur für den eigenen
  /// Bestand — gewichtet wird erst im Spiel (`waehleNachBestand`). Wer hier
  /// filterte, hätte die Fragen bei jedem Import neu zu erzeugen, und in der
  /// Wissensdatenbank stünde nichts über das Gerät, das die Nachbarwehr
  /// mitbringt.
  Future<int> seedGeraetefragen(StandardCatalog katalog) async {
    try {
      final vorhanden = {
        for (final f in await _db.wissenDao.getAll()) _schluessel(f.frage),
      };

      var angelegt = 0;
      for (final g in baueGeraetefragen(katalog)) {
        if (!vorhanden.add(_schluessel(g.frage))) continue;
        // Gemischt wird beim Anlegen und nicht beim Erzeugen: Der Generator
        // bleibt damit prüfbar, und die richtige Antwort steht trotzdem nicht
        // auf jedem Gerät an derselben Stelle.
        final antworten = [g.richtige, ...g.falsche]..shuffle();
        await _db.wissenDao.insertFrage(WissensfragenCompanion.insert(
          gebiet: kGeraetefragenGebiet.schluessel,
          frage: g.frage,
          antwortenJson: Value(stringListToJson(antworten)),
          richtigeJson: Value(jsonEncode([antworten.indexOf(g.richtige)])),
          erklaerung: Value(g.erklaerung),
          herkunft: Value(Fragenherkunft.mitgeliefert.schluessel),
          stand: Value(Fragenstand.freigegeben.schluessel),
          quelleWerk: Value(kGeraetefragenQuelle.werk),
          quelleFundstelle: Value(kGeraetefragenQuelle.fundstelle),
          geraet: Value(g.geraet),
        ));
        angelegt++;
      }
      if (angelegt > 0) {
        appLog.i('Wissensdatenbank: $angelegt Gerätefragen angelegt.');
      }
      return angelegt;
    } catch (e, s) {
      appLog.w('Gerätefragen nicht anlegbar', error: e, stackTrace: s);
      return 0;
    }
  }

  /// Legt den ausgelieferten Fachbestand an (Issue #174, Schritt 2).
  ///
  /// Getrennt von [seedIfNeeded], weil die Quelle eine andere ist: Der
  /// Party-Topf ist ein Spiel-Asset ohne Fundstellen, dieser hier ist
  /// Prüfungsstoff mit Quellenangabe. Erkannt wird wie dort am Fragetext —
  /// ein zweiter Start soll ergänzen, nicht verdoppeln, und eine von Hand
  /// korrigierte Frage bleibt, wie sie ist.
  Future<int> seedFachbestand(List<AssetFrage> fragen) async {
    try {
      final vorhanden = {
        for (final f in await _db.wissenDao.getAll()) _schluessel(f.frage),
      };

      var angelegt = 0;
      for (final f in fragen) {
        if (!vorhanden.add(_schluessel(f.frage))) continue;
        await _db.wissenDao.insertFrage(WissensfragenCompanion.insert(
          gebiet: f.gebiet.schluessel,
          frage: f.frage,
          antwortenJson: Value(stringListToJson(f.antworten)),
          richtigeJson: Value(jsonEncode(f.richtige.toList()..sort())),
          erklaerung: Value(f.erklaerung),
          herkunft: Value(Fragenherkunft.mitgeliefert.schluessel),
          stand: Value(Fragenstand.freigegeben.schluessel),
          quelleWerk: Value(f.quelle?.werk),
          quelleFundstelle: Value(f.quelle?.fundstelle),
          quelleStand: Value(f.quelle?.stand),
          quelleUrl: Value(f.quelle?.url),
          geltung: Value(f.geltung.schluessel),
          land: Value(f.land),
          kapitel: Value(f.kapitel),
          bildPfad: Value(f.bildPfad),
        ));
        angelegt++;
      }
      if (angelegt > 0) {
        appLog.i('Wissensdatenbank: $angelegt Fachfragen angelegt.');
      }
      return angelegt;
    } catch (e, s) {
      appLog.w('Fachbestand nicht anlegbar', error: e, stackTrace: s);
      return 0;
    }
  }

  /// Vergleichsform des Fragetexts: Groß-/Kleinschreibung und Leerraum sind
  /// egal, sonst legt ein korrigiertes Leerzeichen die Frage ein zweites Mal
  /// an.
  String _schluessel(String frage) =>
      frage.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
