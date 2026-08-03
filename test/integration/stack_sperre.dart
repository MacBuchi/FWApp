/// stack_sperre.dart – Serialisiert die E2E-Dateien gegeneinander.
///
/// `flutter test` fährt Testdateien NEBENLÄUFIG, aber alle E2E-Dateien reden
/// mit **derselben** Datenbank. Und `sync_e2e_test.dart` räumt zwischen seinen
/// Tests global auf: `abteilungen` mit `legacy_mirror = false` **alle** weg,
/// `gesamtwehren` **alle** weg, Profile und Mitgliedschaften zurückgesetzt.
/// Wer parallel dazu eine eigene Gesamtwehr anlegt, verliert sie mitten im
/// Lauf.
///
/// Das war immer schon ein Rennen, es ging nur meistens gut aus. Mit der
/// fünften E2E-Datei (Einladungen) verschoben sich die Zeitfenster, und in CI
/// riss `branding_e2e_test` in `setUpAll` ab:
/// `insert or update on table "gesamtwehr_kommandanten" violates foreign key
/// constraint … Key (gesamtwehr_id)=(…) is not present in table
/// "gesamtwehren"` — die eben angelegte Wehr war zwei Zeilen später weg.
///
/// Die Sperre ist eine Datei, die **atomar** angelegt wird (`exclusive: true`
/// ⇒ `O_EXCL`). Das wirkt über Isolate- UND Prozessgrenzen; ein Flock täte es
/// nicht, weil `package:test` die Dateien in Isolates DESSELBEN Prozesses
/// fährt und fcntl-Sperren dort geteilt wären.
///
/// Bricht ein Lauf hart ab, bleibt die Datei liegen — deshalb gilt sie nach
/// [_veraltetNach] als verwaist und wird übernommen. Lieber ein seltener
/// paralleler Lauf als eine Testsuite, die nach einem Absturz nie wieder
/// startet.
library;
import 'dart:io';

/// So lange darf eine Sperre höchstens stehen, bevor sie als verwaist gilt.
/// Großzügig über der Laufzeit der längsten E2E-Datei (dort Sekunden).
const _veraltetNach = Duration(minutes: 5);

File get _sperrdatei =>
    File('${Directory.systemTemp.path}/fwapp_e2e_stack.lock');

/// Wartet, bis diese Testdatei den Stack allein hat.
Future<void> stackSperreHolen() async {
  final datei = _sperrdatei;
  while (true) {
    try {
      datei.createSync(exclusive: true);
      return;
    } on FileSystemException {
      // Steht schon jemand drin? Nur weiterwarten, wenn er noch lebt.
      try {
        final alter = DateTime.now().difference(datei.lastModifiedSync());
        if (alter > _veraltetNach) {
          datei.deleteSync();
          continue;
        }
      } on FileSystemException {
        // Genau jetzt freigegeben — nächster Versuch greift.
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}

/// Gibt den Stack für die nächste Testdatei frei.
Future<void> stackSperreFreigeben() async {
  try {
    _sperrdatei.deleteSync();
  } on FileSystemException {
    // Schon weg (verwaist übernommen) — kein Grund, den Lauf zu röten.
  }
}
