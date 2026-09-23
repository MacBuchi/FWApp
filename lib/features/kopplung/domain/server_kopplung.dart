/// server_kopplung.dart – Was eine Installation beschreibt, damit eine App
/// sie ohne eigenen Build findet (Issue #238, Teil von #234).
///
/// Eine Installation wird durch EINE kleine JSON-Datei beschrieben:
///
///     https://<domain>/.well-known/fwapp.json
///     {"fwapp": 1, "name": "Feuerwehr Musterstadt",
///      "url": "https://api.musterstadt.de", "anon_key": "eyJ…"}
///
/// Derselbe Text steht im Einrichtungs-QR. Alles darin ist ohnehin öffentlich:
/// Der Anon-Key steckt in jeder ausgelieferten App, den Zugriff schützt RLS.
///
/// Reine Dart-Logik ohne Netz: Lesen, Prüfen, Erzeugen. Holen und
/// Speichern stehen in `data/`.
library;

import 'dart:convert';

/// Formatversion der Datei. Eine App, die eine höhere sieht, lehnt ab,
/// statt Felder falsch zu deuten.
const kKopplungFormat = 1;

/// Der feste Pfad unter der Domain einer Installation (RFC 8615).
const kKopplungPfad = '/.well-known/fwapp.json';

class ServerKopplung {
  /// Anzeigename der Installation, z. B. „Feuerwehr Musterstadt". Optional —
  /// ohne ihn zeigt die App die Adresse.
  final String? name;
  final String url;
  final String anonKey;

  const ServerKopplung({this.name, required this.url, required this.anonKey});

  /// Liest die Datei bzw. den QR-Text. Wirft [KopplungFehler] mit einem
  /// Satz, der sagt, was nicht stimmt — ein QR-Code vom falschen Aushang
  /// soll nicht als „FormatException" enden.
  factory ServerKopplung.ausJson(String text) {
    final Object? roh;
    try {
      roh = jsonDecode(text.trim());
    } on FormatException {
      throw const KopplungFehler('Das ist kein Einrichtungs-Code dieser App.');
    }
    if (roh is! Map || roh['fwapp'] == null) {
      throw const KopplungFehler('Das ist kein Einrichtungs-Code dieser App.');
    }
    final format = roh['fwapp'];
    if (format is! int || format > kKopplungFormat) {
      throw const KopplungFehler(
        'Dieser Einrichtungs-Code ist neuer als die App. Bitte die App '
        'aktualisieren.',
      );
    }
    final url = normalisiereServerUrl(roh['url'] as String? ?? '');
    final key = (roh['anon_key'] as String? ?? '').trim();
    if (url == null) {
      throw const KopplungFehler('Im Code fehlt eine gültige Server-Adresse.');
    }
    if (key.isEmpty) {
      throw const KopplungFehler('Im Code fehlt der Schlüssel des Servers.');
    }
    final name = (roh['name'] as String?)?.trim();
    return ServerKopplung(
      name: name == null || name.isEmpty ? null : name,
      url: url,
      anonKey: key,
    );
  }

  /// Der Text für den QR-Code und für die Datei auf dem Server.
  String alsJson() => jsonEncode({
    'fwapp': kKopplungFormat,
    if (name != null) 'name': name,
    'url': url,
    'anon_key': anonKey,
  });

  /// Wie die Installation in der App heißt.
  String get anzeige => name ?? Uri.parse(url).host;
}

class KopplungFehler implements Exception {
  final String text;
  const KopplungFehler(this.text);

  @override
  String toString() => text;
}

/// Macht aus einer Adresse, wie Menschen sie tippen, eine Server-URL: ohne
/// Schrägstrich am Ende, mit Schema. `null`, wenn es keine ist.
///
/// ⚠️ `http://` bleibt erlaubt: Eine Installation im reinen LAN (Pi im
/// Gerätehaus ohne Domain, #241) hat kein Zertifikat. Wer es ohne Schema
/// tippt, bekommt https — das ist der Normalfall im Internet.
String? normalisiereServerUrl(String eingabe) {
  var s = eingabe.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  // Aus den Teilen neu gebaut statt `replace(query: '')` — das hinterließe
  // ein „?" am Ende, und die Adresse wäre eine andere Zeichenkette als die,
  // die in den Einstellungen steht.
  var pfad = uri.path;
  while (pfad.endsWith('/')) {
    pfad = pfad.substring(0, pfad.length - 1);
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: pfad,
  ).toString();
}

/// Wo die Beschreibung einer Installation liegt, wenn jemand nur ihre
/// Domain kennt. Ein eingegebener Pfad wird verworfen — die Datei liegt
/// immer an der Wurzel.
Uri? kopplungsAdresse(String domainEingabe) {
  final basis = normalisiereServerUrl(domainEingabe);
  if (basis == null) return null;
  final uri = Uri.parse(basis);
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: kKopplungPfad,
  );
}
