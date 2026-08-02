/// membership_providers.dart – Eigene Mitgliedschaften und Kommandanten-
/// Stellung (Nutzerkonzept Stufe 1, Issue #98).
///
/// RLS gibt auf beiden Tabellen nur die eigenen Zeilen heraus — die Selects
/// brauchen deshalb keinen Filter. Ältere Server (vor der Stufe-1-Migration)
/// kennen die Tabellen nicht; dann liefern die Provider `null`, und
/// `canEditProvider`/`isAdminProvider` fallen auf die Spiegel-Rolle
/// (`profiles.role`) mit der alten Regel „Schwester-Sicht nur lesend" zurück.
///
/// Manuelle Provider wie der Rest von core/sync (Supabase-Typen vertragen
/// keinen riverpod-Codegen, siehe sync_providers.dart).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';

/// abteilung_id → Rolle ('admin' | 'geraetewart' | 'member').
/// `null` = abgemeldet, Lokalmodus oder Server ohne Mitgliedschaften.
final meineMitgliedschaftenProvider = FutureProvider<Map<String, String>?>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  try {
    final rows = await client.from('memberships').select('abteilung_id, role');
    return {
      for (final r in rows) r['abteilung_id'] as String: r['role'] as String,
    };
  } catch (e) {
    appLog.i('Mitgliedschaften nicht ladbar (Alt-Server?)', error: e);
    return null;
  }
});

/// Gesamtwehren, deren Feuerwehrkommandant der Angemeldete ist.
/// `null` = wie oben; leer = niemandes Kommandant.
final meineKommandoGesamtwehrenProvider = FutureProvider<Set<String>?>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final session = ref.watch(sessionStreamProvider).value;
  if (client == null || session == null) return null;
  try {
    final rows = await client
        .from('gesamtwehr_kommandanten')
        .select('gesamtwehr_id');
    return {for (final r in rows) r['gesamtwehr_id'] as String};
  } catch (e) {
    appLog.i('Kommandanten-Stellung nicht ladbar (Alt-Server?)', error: e);
    return null;
  }
});
