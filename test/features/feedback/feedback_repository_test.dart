/// feedback_repository_test.dart – Längen-Kürzung von Meldungen.
///
/// Hintergrund (Feld-Fund v1.6.0): Die feedback-Tabelle erlaubt maximal
/// 2000 Zeichen. Absturzberichte mit Log-Anhang sind länger; der Insert
/// scheiterte am Check-Constraint und die App meldete irreführend
/// „Internetverbindung prüfen?". Die Kürzung passiert clientseitig,
/// damit auch alte Server-Stände bediente Berichte annehmen.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/feedback/data/feedback_repository.dart';

void main() {
  test('kurze Meldungen bleiben unangetastet (nur getrimmt)', () {
    expect(clampFeedbackMessage('  Kaputt.  '), 'Kaputt.');
  });

  test('genau am Limit wird nicht gekürzt', () {
    final amLimit = 'x' * kFeedbackMaxLength;
    expect(clampFeedbackMessage(amLimit), amLimit);
  });

  test('Überlänge wird aufs Server-Limit gekürzt und sichtbar markiert', () {
    // Ein realistischer Absturzbericht: Kopf + Stack + langer Log-Schwanz.
    final bericht = 'Absturz vom 2026-08-01\n\nNull check operator …\n'
        '${'#0 irgendein Frame\n' * 500}';
    final gekuerzt = clampFeedbackMessage(bericht);

    expect(gekuerzt.length, kFeedbackMaxLength,
        reason: 'länger lehnt der Server-Constraint hart ab');
    expect(gekuerzt, endsWith('[… gekürzt — volle Länge überschritt das '
        'Server-Limit]'));
    // Der Anfang — die wichtigste Information — bleibt stehen.
    expect(gekuerzt, startsWith('Absturz vom 2026-08-01'));
  });
}
