/// kopplung_quelle.dart – Eine Installation holen, prüfen und als Server
/// dieser App eintragen (Issue #238).
///
/// Kein Provider-Code: Diese Funktionen laufen auch in `main()`, bevor es
/// eine ProviderScope gibt (die Web-App sucht dort ihre eigene
/// Installation). Der HTTP-Client ist injizierbar, damit Tests ohne Netz
/// auskommen (AGENTS.md: kein Netzwerk in Unit-Tests).
library;

import 'dart:async';

import 'package:fwapp/features/kopplung/domain/server_kopplung.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Woher die eingetragene Adresse stammt. Entscheidet beim Start im
/// Browser, ob die Datei der eigenen Domain sie überschreiben darf: Was
/// jemand von Hand oder per Code eingetragen hat, gewinnt.
const kServerQuellePref = 'supabase_quelle';

/// Anzeigename der eingetragenen Installation (aus Datei oder QR), damit der
/// Einrichtungs-QR ihn weitergeben kann.
const kServerNamePref = 'supabase_name';

enum ServerQuelle { hand, qr, domain, web }

/// Holt die Beschreibung einer Installation von [adresse].
Future<ServerKopplung> holeKopplung(
  Uri adresse, {
  http.Client? client,
  Duration zeitlimit = const Duration(seconds: 8),
}) async {
  final c = client ?? http.Client();
  try {
    final antwort = await c.get(adresse).timeout(zeitlimit);
    if (antwort.statusCode == 404) {
      throw const KopplungFehler(
        'Unter dieser Adresse ist keine FWApp-Installation eingerichtet.',
      );
    }
    if (antwort.statusCode != 200) {
      throw KopplungFehler(
        'Der Server antwortet nicht wie erwartet (HTTP '
        '${antwort.statusCode}).',
      );
    }
    return ServerKopplung.ausJson(antwort.body);
  } on KopplungFehler {
    rethrow;
  } on TimeoutException {
    throw const KopplungFehler('Der Server antwortet nicht. Adresse prüfen?');
  } catch (_) {
    // Ein Tippfehler in der Domain endet als SocketException mit
    // DNS-Wortlaut — für den Nutzer ist das dieselbe Auskunft.
    throw const KopplungFehler(
      'Diese Adresse ist nicht erreichbar. Vertippt, oder kein Netz?',
    );
  } finally {
    if (client == null) c.close();
  }
}

/// Antwortet der Server wirklich? Geprüft wird VOR dem Speichern, damit
/// niemand mit einer Adresse neu startet, hinter der nichts ist — der
/// Anmeldezwang ließe ihn danach nur noch über die Servereinstellungen
/// hinaus.
Future<void> pruefeServer(
  ServerKopplung k, {
  http.Client? client,
  Duration zeitlimit = const Duration(seconds: 8),
}) async {
  final c = client ?? http.Client();
  try {
    final antwort = await c
        .get(
          Uri.parse('${k.url}/auth/v1/health'),
          headers: {'apikey': k.anonKey},
        )
        .timeout(zeitlimit);
    if (antwort.statusCode != 200) {
      throw KopplungFehler(
        'Der Server ist erreichbar, lehnt aber ab (HTTP '
        '${antwort.statusCode}). Ist der Code aktuell?',
      );
    }
  } on KopplungFehler {
    rethrow;
  } catch (_) {
    throw KopplungFehler(
      'Der Server ${k.anzeige} ist gerade nicht erreichbar.',
    );
  } finally {
    if (client == null) c.close();
  }
}

/// Trägt [k] als Server ein und schaltet die Synchronisation ein. Wirkt
/// nach dem nächsten Start (siehe `core/plattform/neu_laden.dart`).
Future<void> speichereKopplung(
  ServerKopplung k,
  SharedPreferences prefs,
  ServerQuelle quelle,
) async {
  await prefs.setBool('sync_enabled', true);
  await prefs.setString('supabase_url', k.url);
  await prefs.setString('supabase_key', k.anonKey);
  await prefs.setString(kServerQuellePref, quelle.name);
  final name = k.name;
  if (name == null) {
    await prefs.remove(kServerNamePref);
  } else {
    await prefs.setString(kServerNamePref, name);
  }
}

/// Welche Adresse beim Start im BROWSER gilt.
///
/// Die Web-App wird von einer Installation ausgeliefert und soll mit genau
/// dieser sprechen — auch wenn das Bündel mit einer anderen Adresse gebaut
/// wurde (heute baut CI es mit unserer). Deshalb gewinnt die Datei der
/// eigenen Domain über die eingebaute Vorgabe, aber NICHT über eine Adresse,
/// die jemand bewusst eingetragen hat.
///
/// ⚠️ Die Synchronisation wird nur dann eingeschaltet, wenn das Bündel
/// keine eingebaute Adresse hat (das neutrale Bündel des Installers, #241).
/// Unser eigenes Bündel hat eine — dort ändert diese Funktion nur, WOHIN
/// verbunden wird, nicht OB; niemand, der die Web-App heute im Lokalmodus
/// nutzt, steht morgen vor einem Anmeldezwang.
({String url, String key, String? name, bool einschalten})? waehleWebServer({
  required ServerKopplung? eigeneInstallation,
  required String? gespeicherteUrl,
  required String? gespeicherteQuelle,
  required bool hatEingebauteVorgabe,
}) {
  final vonHand =
      (gespeicherteUrl ?? '').isNotEmpty &&
      gespeicherteQuelle != ServerQuelle.web.name;
  if (vonHand || eigeneInstallation == null) return null;
  return (
    url: eigeneInstallation.url,
    key: eigeneInstallation.anonKey,
    name: eigeneInstallation.name,
    einschalten: !hatEingebauteVorgabe,
  );
}
