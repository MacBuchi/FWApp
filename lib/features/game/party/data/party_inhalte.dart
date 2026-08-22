/// party_inhalte.dart – Lädt den mitgelieferten Fragen- und Aufgabentopf des
/// Party-Modus aus [kPartyAsset] (Issue #160).
///
/// **Warum ein Asset und kein Code:** Der Topf lebt von Nachschub. Wer eine
/// Frage ergänzt oder eine falsche korrigiert, soll eine JSON-Datei anfassen
/// und nichts neu bauen müssen. `test/features/game/party_inhalte_test.dart`
/// prüft die ausgelieferte Datei bei jedem Lauf durch — ein Tippfehler im
/// Index fällt damit in der CI auf und nicht am Kameradschaftsabend.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'party_inhalte.g.dart';

const kPartyAsset = 'assets/game/party.json';

/// Nachprüfbares Feuerwehrwissen.
const kKategorieWissen = 'wissen';

/// Reiner Spaß — die Klischees, um die das Issue ausdrücklich gebeten hat.
const kKategorieKlischee = 'klischee';

const kPartyKategorien = {kKategorieWissen, kKategorieKlischee};

/// Eine Frage aus dem Asset, noch ungemischt.
class UnerwarteteFrage {
  final String frage;
  final List<String> antworten;
  final int richtig;
  final String kategorie;
  final String? erklaerung;

  const UnerwarteteFrage({
    required this.frage,
    required this.antworten,
    required this.richtig,
    required this.kategorie,
    this.erklaerung,
  });

  /// Baut die Spielfrage und mischt dabei die Antworten.
  ///
  /// Ohne das Mischen stünde die richtige Antwort immer an derselben Stelle
  /// wie in der Datei — wer die Datei einmal gesehen hat, bräuchte danach
  /// kein Feuerwehrwissen mehr.
  PartyFrage zuPartyFrage(Random zufall) {
    final gemischt = [...antworten]..shuffle(zufall);
    return PartyFrage(
      art: PartyFrageArt.unerwartet,
      text: frage,
      antworten: gemischt.map(PartyAntwort.new).toList(),
      richtig: gemischt.indexOf(antworten[richtig]),
      erklaerung: erklaerung,
    );
  }
}

class PartyInhalte {
  final List<UnerwarteteFrage> fragen;

  /// Die Alternative zum Schluck (siehe `PartySpiel`).
  final List<String> aufgaben;

  const PartyInhalte({required this.fragen, required this.aufgaben});

  static const leer = PartyInhalte(fragen: [], aufgaben: []);
}

/// Zerlegt den Asset-Inhalt. Unbrauchbare Einträge fallen einzeln heraus,
/// statt die ganze Datei zu verwerfen: Eine kaputte Frage soll nicht den
/// ganzen Modus abschalten.
PartyInhalte parsePartyInhalte(String raw) {
  final Map<String, dynamic> decoded;
  try {
    decoded = jsonDecode(raw) as Map<String, dynamic>;
  } catch (e) {
    appLog.w('Party-Inhalte unlesbar', error: e);
    return PartyInhalte.leer;
  }

  final fragen = <UnerwarteteFrage>[];
  for (final eintrag in (decoded['fragen'] as List?) ?? const []) {
    if (eintrag is! Map<String, dynamic>) continue;
    final frage = (eintrag['frage'] as String?)?.trim() ?? '';
    final antworten = ((eintrag['antworten'] as List?) ?? const [])
        .map((a) => a.toString())
        .toList();
    final richtig = eintrag['richtig'];
    final kategorie = eintrag['kategorie'] as String? ?? kKategorieWissen;
    if (frage.isEmpty ||
        antworten.length < 2 ||
        richtig is! int ||
        richtig < 0 ||
        richtig >= antworten.length) {
      appLog.w('Party-Frage übersprungen: "$frage"');
      continue;
    }
    fragen.add(UnerwarteteFrage(
      frage: frage,
      antworten: antworten,
      richtig: richtig,
      kategorie: kategorie,
      erklaerung: (eintrag['erklaerung'] as String?)?.trim(),
    ));
  }

  final aufgaben = ((decoded['aufgaben'] as List?) ?? const [])
      .map((a) => a.toString().trim())
      .where((a) => a.isNotEmpty)
      .toList();

  return PartyInhalte(fragen: fragen, aufgaben: aufgaben);
}

/// Der mitgelieferte Topf. Fehlt oder bricht das Asset, bleibt der Modus
/// spielbar — dann eben nur mit Fragen aus dem eigenen Bestand.
@riverpod
Future<PartyInhalte> partyInhalte(Ref ref) async {
  try {
    return parsePartyInhalte(await rootBundle.loadString(kPartyAsset));
  } catch (e) {
    appLog.w('Party-Inhalte nicht ladbar', error: e);
    return PartyInhalte.leer;
  }
}
