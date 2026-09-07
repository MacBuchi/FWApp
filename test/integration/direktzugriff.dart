/// direktzugriff.dart – Ein Schreibversuch am RPC vorbei, richtig geprüft (#185).
///
/// Mehrere Tabellen dieses Schemas werden ausschließlich über geprüfte
/// SECURITY-DEFINER-Funktionen beschrieben; direkt schreiben darf niemand.
/// Diese Zusicherung wurde bisher an der Fehlermeldung festgemacht — und das
/// hielt nicht: Am 2026-08-26 zog CI die Supabase-CLI 2.116.0, und zwei Tests
/// kippten auf unverändertem `main`, ohne dass je eine Zeile geschrieben
/// worden wäre.
///
/// Der Grund liegt darin, dass ein abgewehrter Schreibversuch **zwei** Formen
/// hat, je nachdem, woran er scheitert:
///
///   * Fehlt das Tabellenrecht, lehnt Postgres ab: 42501 `permission denied`.
///     PostgREST macht daraus eine [PostgrestException].
///   * Ist das Recht da und nur RLS greift, hängt es am Befehl: Ein INSERT
///     ohne INSERT-Policy scheitert („new row violates row-level security
///     policy", ebenfalls 42501), ein UPDATE dagegen trifft schlicht keine
///     Zeile — `UPDATE 0`, kein Fehler, und PostgREST meldet Erfolg.
///
/// Sicherheitstechnisch ist das derselbe Ausgang: Es ändert sich nichts. Für
/// ein `expect(throwsA(...))` ist es der Unterschied zwischen grün und rot.
/// Deshalb prüft der Aufrufer hier nur noch, dass der Versuch nicht
/// durchgeht — und danach, dass die Daten unversehrt sind.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Führt [versuch] aus und lässt beide Formen der Abwehr gelten.
///
/// Nicht durchgelassen wird ein anderer Fehler als 42501: Eine fehlende
/// Tabelle oder ein Tippfehler im Spaltennamen wirft ebenfalls, und ein Test,
/// der das für „abgewehrt" hält, prüft nichts mehr.
Future<void> erwarteKeinenDurchgriff(Future<void> Function() versuch) async {
  try {
    await versuch();
  } on PostgrestException catch (fehler) {
    expect(
      fehler.code,
      '42501',
      reason: 'Erwartet war die Abwehr (42501 permission denied bzw. '
          'row-level security), nicht: ${fehler.message}',
    );
  }
}
