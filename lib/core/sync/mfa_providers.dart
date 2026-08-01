/// mfa_providers.dart – Zwei-Faktor-Anmeldung per TOTP (Issue #57 Phase 4,
/// Etappe 3).
///
/// Warum überhaupt: Ein Admin kann Konten anlegen, Rollen vergeben und den
/// Datenbestand der ganzen Wehr überschreiben. Ein abgeschautes oder
/// wiederverwendetes Passwort reicht dafür heute aus — der zweite Faktor
/// macht daraus einen Diebstahl, der auch das Telefon braucht.
///
/// Der Zwang gilt für Admins, nicht für alle: Mitglieder melden sich mit
/// einem Zettel an und haben nichts zu verlieren, was nicht ohnehin im
/// Gerätehaus aushängt.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ab wann Admins ohne zweiten Faktor nicht mehr weiterarbeiten können.
///
/// Die Frist ist kein Selbstzweck: Wer die App am Einsatzabend öffnet, soll
/// nicht zwischen Tür und Angel eine Authenticator-App einrichten müssen.
/// Vorher weist die App darauf hin, danach führt der Weg über die
/// Einrichtung. Zum Verschieben genügt es, dieses Datum zu ändern.
final kZweiFaktorPflichtAb = DateTime.utc(2026, 9, 1);

/// Hat dieses Konto einen bestätigten zweiten Faktor?
///
/// `listFactors` braucht eine Sitzung; ohne Anmeldung ist die Antwort leer
/// statt ein Fehler — der Aufrufer soll sich nicht um den Sonderfall
/// kümmern müssen.
final mfaFaktorenProvider = FutureProvider<List<Factor>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  // Nach An-/Abmelden neu laden — sonst zeigt die Einrichtung den Stand
  // des vorherigen Kontos.
  ref.watch(sessionStreamProvider);
  if (client == null || client.auth.currentSession == null) return const [];
  try {
    final antwort = await client.auth.mfa.listFactors();
    return antwort.totp;
  } catch (_) {
    // Ein alter Server ohne MFA-Endpunkt ist kein Fehlerfall, sondern
    // schlicht ein Server ohne zweiten Faktor.
    return const [];
  }
});

/// Hat das Konto einen Faktor, der auch bestätigt ist?
///
/// Ein angefangener, nie bestätigter Faktor zählt nicht — sonst käme jemand
/// mit einem halben Einrichtungsversuch durch die Pflicht.
final hatZweitenFaktorProvider = Provider<bool>((ref) =>
    (ref.watch(mfaFaktorenProvider).value ?? const [])
        .any((f) => f.status == FactorStatus.verified));

/// Steht die Anmeldung noch offen, weil der zweite Faktor fehlt?
///
/// `signInWithPassword` liefert bereits eine Sitzung (Stufe aal1), bevor der
/// Code eingegeben ist. Ohne dieses Flag würde der Router genau dort
/// weiterschalten und der zweite Faktor wäre eine Zierde: Wer ihn wegtippt,
/// wäre trotzdem drin. Der Anmelde-Screen setzt es selbst zurück — auch,
/// wenn der Nutzer abbricht.
final mfaOffenProvider = StateProvider<bool>((ref) => false);

/// Verlangt die Sitzung eine Erhöhung auf aal2?
///
/// `nextLevel` ist aal2, sobald ein bestätigter Faktor existiert;
/// `currentLevel` bleibt aal1, bis der Code stimmt.
bool brauchtZweitenFaktor(SupabaseClient client) {
  final stufen = client.auth.mfa.getAuthenticatorAssuranceLevel();
  return stufen.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
      stufen.currentLevel != AuthenticatorAssuranceLevels.aal2;
}

/// Muss dieses Konto den zweiten Faktor JETZT einrichten?
///
/// Reine Funktion, damit die Frist ohne laufende App prüfbar ist.
bool mussZweiFaktorEinrichten({
  required String? rolle,
  required bool hatFaktor,
  required DateTime jetzt,
}) =>
    rolle == 'admin' && !hatFaktor && !jetzt.isBefore(kZweiFaktorPflichtAb);

/// Zerlegt den TOTP-Schlüssel in Blöcke zu vier Zeichen.
///
/// Wer ihn abtippt, weil das Telefon die eigene Anzeige nicht scannen kann,
/// verliert sonst die Stelle.
String schluesselLesbar(String secret) {
  final s = secret.replaceAll(' ', '').toUpperCase();
  final blocks = <String>[];
  for (var i = 0; i < s.length; i += 4) {
    blocks.add(s.substring(i, i + 4 > s.length ? s.length : i + 4));
  }
  return blocks.join(' ');
}
