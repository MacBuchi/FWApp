/// branding_providers.dart – Eigener Kopfbereich der Gesamtwehr (#57 P5).
///
/// Gelesen wird die Zeile aus `gesamtwehr_branding`, geschrieben ausschließlich
/// über die RPC `set_gesamtwehr_branding` (die Tabelle hat bewusst keine
/// Schreib-Policy). Pflegen darf der Feuerwehrkommandant dieser Wehr.
///
/// ⚠️ Local-first: Der Kopf wartet NICHT auf den Server. [gesamtwehrBrandingProvider]
/// liefert sofort den zuletzt bekannten Stand aus den SharedPreferences und
/// frischt ihn im Hintergrund auf. Ohne diesen Zwischenspeicher wäre die
/// Startseite im Funkloch-Keller kopflos — und genau dort wird die App benutzt.
///
/// Manuelle Provider wie der Rest von core/sync (Supabase-Typen vertragen
/// keinen riverpod-Codegen, siehe sync_providers.dart).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/image_sync_service.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Prefs-Schlüssel des zwischengespeicherten Kopfbereichs, eine Zeile je Wehr.
String brandingPrefsKey(String gesamtwehrId) => 'branding_$gesamtwehrId';

/// Die Gesamtwehr, auf die sich die gerade angezeigte Abteilung bezieht.
class GesamtwehrBezug {
  final String id;
  final String? name;
  const GesamtwehrBezug({required this.id, this.name});
}

/// Der gepflegte Kopfbereich einer Gesamtwehr.
class GesamtwehrBranding {
  final String gesamtwehrId;

  /// Überschrift. `null` = die App zeigt den Namen der Gesamtwehr.
  final String? titel;
  final String? willkommenstext;

  /// `supabase://gesamtwehr-branding/<gw>/<millis>.jpg` oder `null`.
  final String? bildPfad;

  const GesamtwehrBranding({
    required this.gesamtwehrId,
    this.titel,
    this.willkommenstext,
    this.bildPfad,
  });

  /// Nichts gepflegt — die Startseite zeigt dann gar keinen Kopf, statt einen
  /// leeren Kasten zu reservieren.
  bool get istLeer =>
      (titel == null || titel!.isEmpty) &&
      (willkommenstext == null || willkommenstext!.isEmpty) &&
      (bildPfad == null || bildPfad!.isEmpty);

  /// Überschrift für die Anzeige: gepflegter Titel, sonst der Wehr-Name.
  String? anzeigeTitel(String? wehrName) =>
      (titel != null && titel!.isNotEmpty) ? titel : wehrName;

  Map<String, dynamic> toJson() => {
        'gesamtwehr_id': gesamtwehrId,
        'title': titel,
        'welcome_text': willkommenstext,
        'image_path': bildPfad,
      };

  static GesamtwehrBranding? fromJson(Map<String, dynamic> json) {
    final id = json['gesamtwehr_id'] as String?;
    if (id == null) return null;
    return GesamtwehrBranding(
      gesamtwehrId: id,
      titel: json['title'] as String?,
      willkommenstext: json['welcome_text'] as String?,
      bildPfad: json['image_path'] as String?,
    );
  }
}

/// Gesamtwehr der aktuell angezeigten Abteilung. Rein abgeleitet — die Liste
/// aus [abteilungenProvider] trägt die Zuordnung bereits, eine eigene Abfrage
/// wäre eine zweite Wahrheit.
final aktuelleGesamtwehrProvider =
    FutureProvider<GesamtwehrBezug?>((ref) async {
  final gewaehlt = ref.watch(selectedAbteilungIdProvider);
  final abteilung = gewaehlt ?? await ref.watch(myAbteilungIdProvider.future);
  if (abteilung == null) return null;
  final alle = await ref.watch(abteilungenProvider.future);
  for (final a in alle) {
    if (a.id == abteilung && a.gesamtwehrId != null) {
      return GesamtwehrBezug(id: a.gesamtwehrId!, name: a.gesamtwehrName);
    }
  }
  return null;
});

/// Darf der Angemeldete den Auftritt DIESER Wehr pflegen?
///
/// Bewusst enger als `canEdit`: Den geteilten Gerätebestand pflegt jeder
/// Gerätewart der Gesamtwehr, wie die Wehr sich nach außen zeigt aber nur ihr
/// Feuerwehrkommandant (NUTZERKONZEPT.md §2). Der Server prüft dasselbe noch
/// einmal — hier geht es nur darum, keine Knöpfe zu zeigen, die scheitern.
final darfBrandingPflegenProvider = FutureProvider<bool>((ref) async {
  final bezug = await ref.watch(aktuelleGesamtwehrProvider.future);
  if (bezug == null) return false;
  final kommandiert = await ref.watch(meineKommandoGesamtwehrenProvider.future);
  return kommandiert != null && kommandiert.contains(bezug.id);
});

final gesamtwehrBrandingProvider =
    AsyncNotifierProvider<GesamtwehrBrandingNotifier, GesamtwehrBranding?>(
  GesamtwehrBrandingNotifier.new,
);

class GesamtwehrBrandingNotifier extends AsyncNotifier<GesamtwehrBranding?> {
  @override
  Future<GesamtwehrBranding?> build() async {
    final bezug = await ref.watch(aktuelleGesamtwehrProvider.future);
    if (bezug == null) return null;

    var entsorgt = false;
    ref.onDispose(() => entsorgt = true);

    final zwischenstand = await _ausSpeicher(bezug.id);
    // Auffrischen läuft nebenher: Der Kopf steht sofort, der Server korrigiert
    // ihn, sobald er antwortet. Absichtlich nicht abgewartet — sonst hinge die
    // Startseite offline am Zeitablauf der Netzabfrage.
    unawaited(_vomServer(bezug.id, () => entsorgt));
    return zwischenstand;
  }

  Future<void> _vomServer(String gesamtwehrId, bool Function() entsorgt) async {
    final client = ref.read(supabaseClientProvider);
    final session = ref.read(sessionStreamProvider).value;
    if (client == null || session == null) return;
    try {
      final row = await client
          .from('gesamtwehr_branding')
          .select('gesamtwehr_id, title, welcome_text, image_path')
          .eq('gesamtwehr_id', gesamtwehrId)
          .maybeSingle();
      final frisch = row == null
          ? GesamtwehrBranding(gesamtwehrId: gesamtwehrId)
          : GesamtwehrBranding.fromJson(row);
      await _inSpeicher(gesamtwehrId, frisch);
      if (!entsorgt()) state = AsyncData(frisch);
    } catch (e) {
      // Kein Netz oder Alt-Server: Der zwischengespeicherte Stand bleibt
      // stehen. Ein leerer Kopf wäre hier die schlechtere Antwort.
      appLog.i('Kopfbereich nicht ladbar (offline oder Alt-Server?)', error: e);
    }
  }

  Future<GesamtwehrBranding?> _ausSpeicher(String gesamtwehrId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roh = prefs.getString(brandingPrefsKey(gesamtwehrId));
      if (roh == null) return null;
      return GesamtwehrBranding.fromJson(
          jsonDecode(roh) as Map<String, dynamic>);
    } catch (e) {
      appLog.w('Zwischengespeicherter Kopfbereich unlesbar', error: e);
      return null;
    }
  }

  Future<void> _inSpeicher(
      String gesamtwehrId, GesamtwehrBranding? branding) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = brandingPrefsKey(gesamtwehrId);
      if (branding == null || branding.istLeer) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(branding.toJson()));
      }
    } catch (e) {
      appLog.w('Kopfbereich nicht zwischenspeicherbar', error: e);
    }
  }
}

final brandingServiceProvider = Provider<BrandingService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : BrandingService(client, ref);
});

/// Schreibweg des Kopfbereichs.
class BrandingService {
  final SupabaseClient _client;
  final Ref _ref;

  BrandingService(this._client, this._ref);

  /// Lädt ein Kopfbild hoch und gibt seinen Marker zurück. [bisher] wird
  /// best-effort aus dem Bucket geräumt.
  Future<String> bildHochladen({
    required String gesamtwehrId,
    required Uint8List bytes,
    String? bisher,
  }) =>
      ImageSyncService(_client).uploadBrandingImage(
        gesamtwehrId: gesamtwehrId,
        bytes: bytes,
        previousPath: bisher,
      );

  /// ⚠️ Schreibt IMMER alle drei Felder. `null` heißt „gelöscht", nicht
  /// „unverändert" — die Maske schickt deshalb stets ihren vollen Stand. Beim
  /// Typ-Sync hat genau diese Verwechslung einmal beinahe das Foto der ganzen
  /// Gesamtwehr gekostet (siehe AGENTS.md).
  Future<void> speichern({
    required String gesamtwehrId,
    String? titel,
    String? willkommenstext,
    String? bildPfad,
  }) async {
    await _client.rpc('set_gesamtwehr_branding', params: {
      'gw': gesamtwehrId,
      'neuer_titel': titel,
      'neuer_text': willkommenstext,
      'neues_bild': bildPfad,
    });
    _ref.invalidate(gesamtwehrBrandingProvider);
  }
}
