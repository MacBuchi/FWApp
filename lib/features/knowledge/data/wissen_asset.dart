/// wissen_asset.dart – Der mitgelieferte Fragenbestand (Issue #174,
/// Schritt 2).
///
/// **Warum ein eigenes Format neben `party.json`.** Der Party-Topf kennt
/// weder Quellenangabe noch Geltungsbereich noch Mehrfachantworten — er ist
/// für ein Spiel gebaut, nicht für Prüfungsstoff. Fragen mit Fundstelle
/// brauchen mehr Felder, und sie in den alten Topf zu zwängen hieße, ihn zu
/// beiden Zwecken halb passend zu machen.
///
/// **Woher die Fragen stammen.** Aus den Feuerwehr-Dienstvorschriften, der
/// Straßenverkehrs-Ordnung, den Technischen Regeln für Arbeitsstätten, dem
/// Unfallverhütungsrecht und — im Landesteil — aus dem Feuerwehrgesetz und
/// seinen Verwaltungsvorschriften. Alles selbst formuliert, mit Fundstelle.
/// Sämtliche dieser Werke sind amtliche Werke nach § 5 UrhG und damit nicht
/// urheberrechtlich geschützt; die Quellenangabe bleibt trotzdem Pflicht und
/// steht deshalb an jeder Frage.
///
/// ⚠️ **Nicht verwendet und nicht zu verwenden:** die Lehrstoffblätter der
/// Landesfeuerwehrschule (erscheinen mit ISBN im Neckar-Verlag) und
/// DIN-Normtexte. Der Sachverhalt aus einer Norm ist frei, ihr Wortlaut
/// nicht.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

/// Die ausgelieferten Fragenbestände, in Ladereihenfolge: erst das, was
/// überall gilt, dann die Landesbestände.
///
/// ⚠️ **Ein Landesbestand wird trotzdem überall geladen** — gefiltert wird
/// nicht hier, sondern beim Stellen der Frage. Der Grund ist die Wehr, die
/// über eine Landesgrenze hinweg übt oder nachschlägt: Wer das Asset gar
/// nicht erst mitliefert, nimmt ihr die Möglichkeit, und ein Bestand, den
/// niemand sehen kann, ist derselbe wie keiner. Der Geltungsbereich steht an
/// jeder Frage, damit sichtbar ist, wo sie gilt.
const kWissensAssets = <String>[
  'assets/knowledge/bund.json',
  'assets/knowledge/abc.json',
  'assets/knowledge/bw.json',
];

/// Eine Frage, wie sie im Asset steht — noch ohne Datenbank-Identität.
class AssetFrage {
  final Wissensgebiet gebiet;
  final String frage;
  final List<String> antworten;
  final Set<int> richtige;
  final String? erklaerung;
  final Fragenquelle? quelle;
  final Geltungsbereich geltung;
  final String? land;
  final String? kapitel;
  final String? bildPfad;

  const AssetFrage({
    required this.gebiet,
    required this.frage,
    required this.antworten,
    required this.richtige,
    this.erklaerung,
    this.quelle,
    this.geltung = Geltungsbereich.bund,
    this.land,
    this.kapitel,
    this.bildPfad,
  });
}

/// Trimmt und macht aus einer leeren Angabe ein `null` — ein Kapitel namens
/// „" wäre ein Filter, der auf nichts zeigt.
String? leerZuNull(String? wert) {
  final t = wert?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Zerlegt eine Asset-Datei. Unbrauchbare Einträge fallen **einzeln** heraus
/// und werden benannt — eine kaputte Frage darf nicht den ganzen Bestand
/// verhindern, aber sie soll auch nicht stumm verschwinden.
List<AssetFrage> parseWissensAsset(String roh) {
  final Map<String, dynamic> decoded;
  try {
    decoded = jsonDecode(roh) as Map<String, dynamic>;
  } catch (e) {
    appLog.w('Wissens-Asset unlesbar', error: e);
    return const [];
  }

  final ergebnis = <AssetFrage>[];
  for (final eintrag in (decoded['fragen'] as List?) ?? const []) {
    if (eintrag is! Map<String, dynamic>) continue;

    final frage = (eintrag['frage'] as String?)?.trim() ?? '';
    final antworten = ((eintrag['antworten'] as List?) ?? const [])
        .map((a) => a.toString().trim())
        .toList();
    final richtige = <int>{
      for (final r in (eintrag['richtige'] as List?) ?? const [])
        if (r is num) r.toInt(),
    };

    // Dieselbe Prüfung wie im Formular und später im CSV-Import. Was hier
    // durchfällt, wäre auch von Hand nicht anlegbar gewesen.
    final fehler =
        pruefeFrage(frage: frage, antworten: antworten, richtige: richtige);
    if (fehler != null) {
      appLog.w('Wissens-Frage übersprungen ($fehler): "$frage"');
      continue;
    }

    final gebiet = Wissensgebiet.ausSchluessel(eintrag['gebiet'] as String?);
    if (gebiet == null) {
      appLog.w('Wissens-Frage ohne gültiges Gebiet übersprungen: "$frage"');
      continue;
    }

    final quelleRoh = eintrag['quelle'];
    Fragenquelle? quelle;
    if (quelleRoh is Map<String, dynamic>) {
      final werk = (quelleRoh['werk'] as String?)?.trim() ?? '';
      if (werk.isNotEmpty) {
        quelle = Fragenquelle(
          werk: werk,
          fundstelle: (quelleRoh['fundstelle'] as String?)?.trim(),
          stand: (quelleRoh['stand'] as String?)?.trim(),
          url: (quelleRoh['url'] as String?)?.trim(),
        );
      }
    }

    final geltung = Geltungsbereich.ausSchluessel(eintrag['geltung'] as String?);
    final land = (eintrag['land'] as String?)?.trim();
    // Landesrecht ohne Land wäre eine Angabe, die nichts sagt.
    if (geltung == Geltungsbereich.land &&
        (land == null || !kBundeslaender.containsKey(land))) {
      appLog.w('Wissens-Frage mit Landesrecht ohne gültiges Land '
          'übersprungen: "$frage"');
      continue;
    }

    ergebnis.add(AssetFrage(
      gebiet: gebiet,
      frage: frage,
      antworten: antworten,
      richtige: richtige,
      erklaerung: (eintrag['erklaerung'] as String?)?.trim(),
      quelle: quelle,
      geltung: geltung,
      land: geltung == Geltungsbereich.land ? land : null,
      kapitel: leerZuNull(eintrag['kapitel'] as String?),
      bildPfad: leerZuNull(eintrag['bild'] as String?),
    ));
  }
  return ergebnis;
}

/// Lädt alle ausgelieferten Bestände. Eine fehlende Datei kostet ihren
/// Anteil, nicht den ganzen Grundstock.
Future<List<AssetFrage>> ladeWissensAssets() async {
  final alle = <AssetFrage>[];
  for (final pfad in kWissensAssets) {
    try {
      alle.addAll(parseWissensAsset(await rootBundle.loadString(pfad)));
    } catch (e) {
      appLog.w('Wissens-Asset $pfad nicht ladbar', error: e);
    }
  }
  return alle;
}
