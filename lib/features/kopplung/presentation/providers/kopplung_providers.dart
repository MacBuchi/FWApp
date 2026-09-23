/// kopplung_providers.dart – Die Vorgänge der Server-Kopplung als eine
/// austauschbare Einheit (Issue #238).
///
/// Holen, Prüfen, Speichern und Neustarten gehen alle nach draußen (Netz,
/// SharedPreferences, Browser). Hinter einem Provider lassen sie sich im
/// Widget-Test ersetzen — AGENTS.md: kein Netzwerk in Widget-Tests.
library;

import 'package:fwapp/core/plattform/neu_laden.dart';
import 'package:fwapp/features/kopplung/data/kopplung_quelle.dart';
import 'package:fwapp/features/kopplung/domain/server_kopplung.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'kopplung_providers.g.dart';

class KopplungsDienste {
  const KopplungsDienste();

  Future<ServerKopplung> hole(Uri adresse) => holeKopplung(adresse);

  Future<void> pruefe(ServerKopplung k) => pruefeServer(k);

  Future<void> speichere(ServerKopplung k, ServerQuelle quelle) async =>
      speichereKopplung(k, await SharedPreferences.getInstance(), quelle);

  /// `true`, wenn die App gleich neu startet (Browser). Sonst muss die
  /// Oberfläche um einen Neustart von Hand bitten.
  bool neuStarten() => seiteNeuLaden();

  /// Name der eingetragenen Installation, falls bekannt.
  Future<String?> gespeicherterName() async =>
      (await SharedPreferences.getInstance()).getString(kServerNamePref);
}

@riverpod
KopplungsDienste kopplungsDienste(Ref ref) => const KopplungsDienste();
