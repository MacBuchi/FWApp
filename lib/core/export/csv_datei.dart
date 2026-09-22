/// csv_datei.dart – Wie eine CSV-Datei dieser App aussieht (Issues #178/#176).
///
/// Herausgezogen beim zweiten Nutzer (AGENTS.md, „Zweitverwendung =
/// Extraktion"): Der Inventurbericht und der Bestands-Export müssen
/// **dieselbe** Datei erzeugen. Liefe jeder für sich, unterschieden sie sich
/// beim ersten Ändern in Trenner oder BOM — und das fiele niemandem auf, bis
/// eine der beiden Dateien in Excel als eine einzige Spalte erscheint.
library;

import 'package:csv/csv.dart';

/// Semikolon: Deutsche Tabellenkalkulationen trennen so, und der eigene
/// Importer erkennt es ohnehin selbst.
const kCsvTrenner = ';';

/// Baut die Datei aus Kopfzeile und Zeilen.
///
/// **Warum ein BOM davor steht** (`addBom`). Ohne BOM zeigt Excel unter
/// Windows aus „Beschädigt" ein „BeschÃ¤digt". Der eigene Importer stört
/// sich nicht daran, er entfernt das BOM beim Einlesen
/// (`ImportParser._decodeText`).
///
/// Anführungszeichen, eingebettete Semikolons und Zeilenumbrüche in Notizen
/// erledigt das Paket — von Hand ist genau das die Fehlerquelle.
String alsCsvDatei(List<List<String>> zeilen) =>
    const CsvEncoder(fieldDelimiter: kCsvTrenner, addBom: true).convert(zeilen);

/// Datum in der Form, in der es IN der Datei steht: `TT.MM.JJJJ`.
String csvDatum(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';

/// Datum für einen DATEINAMEN: `JJJJ-MM-TT`, damit eine Ablage von selbst
/// chronologisch sortiert.
String dateinameDatum(DateTime d) =>
    '${d.year}-${_zwei(d.month)}-${_zwei(d.day)}';

/// Macht aus einem Namen einen Dateinamen-Rumpf ohne Zeichen, die ein Mailer
/// oder ein Dateisystem nicht mag.
String dateinameRumpf(String text, {required String wennLeer}) {
  final rumpf = text
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return rumpf.isEmpty ? wennLeer : rumpf;
}

String _zwei(int n) => n.toString().padLeft(2, '0');
