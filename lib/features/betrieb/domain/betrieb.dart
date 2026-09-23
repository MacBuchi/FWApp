/// betrieb.dart – Was die Konsole des KreisDatenMeisters über eine
/// Gesamtwehr weiß und was sie daraus ableitet (Issue #101).
///
/// Reine Dart-Logik: Modell, Warnstufen, Texte und der Ablauf „ernennen,
/// sonst einladen". Die Rechte prüft der Server (`kdm_*`-Funktionen, alle
/// hinter `ist_betreiber()`); hier steht nur, wie die App es zeigt.
library;

/// Ein Feuerwehrkommandant, wie `kdm_gesamtwehren` ihn herausgibt.
class KdmKommandant {
  final String userId;
  final String name;
  final String? email;
  const KdmKommandant({required this.userId, required this.name, this.email});

  factory KdmKommandant.fromJson(Map<String, dynamic> json) => KdmKommandant(
    userId: json['user_id'] as String,
    name:
        (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : 'Unbenannt',
    email: json['email'] as String?,
  );
}

/// Eine Gesamtwehr aus Sicht des Betreibers.
class KdmWehr {
  final String id;
  final String name;
  final DateTime? stillgelegtAm;
  final List<({String id, String name})> abteilungen;
  final int mitglieder;
  final List<KdmKommandant> kommandanten;
  final int offeneEinladungen;
  final DateTime? zuletztVeroeffentlicht;

  const KdmWehr({
    required this.id,
    required this.name,
    this.stillgelegtAm,
    this.abteilungen = const [],
    this.mitglieder = 0,
    this.kommandanten = const [],
    this.offeneEinladungen = 0,
    this.zuletztVeroeffentlicht,
  });

  factory KdmWehr.fromJson(Map<String, dynamic> json) => KdmWehr(
    id: json['id'] as String,
    name: json['name'] as String,
    stillgelegtAm: DateTime.tryParse(json['stillgelegt_am'] as String? ?? ''),
    abteilungen: [
      for (final a in (json['abteilungen'] as List? ?? const []))
        (id: (a as Map)['id'] as String, name: a['name'] as String),
    ],
    mitglieder: (json['mitglieder'] as num?)?.toInt() ?? 0,
    kommandanten: [
      for (final k in (json['kommandanten'] as List? ?? const []))
        KdmKommandant.fromJson((k as Map).cast<String, dynamic>()),
    ],
    offeneEinladungen: (json['offene_einladungen'] as num?)?.toInt() ?? 0,
    zuletztVeroeffentlicht:
        DateTime.tryParse(
          json['zuletzt_veroeffentlicht'] as String? ?? '',
        )?.toLocal(),
  );

  bool get stillgelegt => stillgelegtAm != null;

  /// Worauf der Betreiber achten muss — `null`, wenn alles in Ordnung ist.
  ///
  /// Der Aussperr-Schutz (NUTZERKONZEPT §3) empfiehlt zwei Kommandanten je
  /// Wehr. Eine Wehr ohne Kommandanten ist schlimmer: Dort kann niemand
  /// Abteilungen anlegen oder einladen — außer dem Betreiber. Eine offene
  /// Einladung entschärft das, deshalb steht sie im Text.
  KdmWarnung? get warnung {
    if (stillgelegt) return null;
    if (kommandanten.isEmpty) {
      return offeneEinladungen > 0
          ? const KdmWarnung(
            'Noch kein Kommandant — Einladung ist unterwegs.',
            dringend: false,
          )
          : const KdmWarnung(
            'Kein Kommandant: Niemand kann hier einladen oder Abteilungen '
            'anlegen.',
            dringend: true,
          );
    }
    if (kommandanten.length == 1) {
      return const KdmWarnung(
        'Nur ein Kommandant — fällt er aus, ist die Wehr ausgesperrt.',
        dringend: false,
      );
    }
    return null;
  }
}

class KdmWarnung {
  final String text;
  final bool dringend;
  const KdmWarnung(this.text, {required this.dringend});
}

/// „zuletzt veröffentlicht am 23.09.2026" bzw. „noch nie veröffentlicht" —
/// das schnellste Zeichen, ob eine Wehr die App wirklich benutzt.
String veroeffentlichtText(DateTime? wann) =>
    wann == null
        ? 'noch nie veröffentlicht'
        : 'zuletzt veröffentlicht am ${wann.day.toString().padLeft(2, '0')}.'
            '${wann.month.toString().padLeft(2, '0')}.${wann.year}';

/// Wie ein Kommandant dazukam.
enum KommandantWeg { ernannt, eingeladen }

/// Macht [email] zum Feuerwehrkommandanten: hat die Adresse schon ein Konto,
/// sofort (`kdm_ernenne_kommandant`); sonst per Einladung.
///
/// Die Reihenfolge ist Absicht: Einladen geht für eine Adresse mit Konto
/// gar nicht (der Server lehnt ab), Ernennen für eine ohne Konto ebenso.
/// Erst ernennen zu versuchen spart dem Betreiber die Frage, ob die Person
/// schon ein Konto hat — die kann er meist nicht beantworten.
Future<KommandantWeg> kommandantHinzufuegen({
  required Future<void> Function() ernenne,
  required Future<void> Function() ladeEin,
}) async {
  try {
    await ernenne();
    return KommandantWeg.ernannt;
  } catch (e) {
    if (!istOhneKonto(e)) rethrow;
  }
  await ladeEin();
  return KommandantWeg.eingeladen;
}

/// Die Ablehnung von `kdm_ernenne_kommandant`, wenn es kein Konto gibt.
bool istOhneKonto(Object fehler) =>
    fehler.toString().contains('Kein bestaetigtes Konto');

/// Servermeldungen (ASCII, knapp) als Satz. Die Einladungsfehler kommen aus
/// der Edge Function schon übersetzt; Unbekanntes bleibt im Original.
String betriebFehlerText(Object fehler) {
  final roh = fehler.toString();
  if (roh.contains('Nur fuer den KreisDatenMeister')) {
    return 'Das darf nur der KreisDatenMeister dieser Installation.';
  }
  if (roh.contains('Name der Wehr und der ersten Abteilung')) {
    return 'Bitte den Namen der Wehr und ihrer ersten Abteilung eingeben.';
  }
  if (roh.contains('Diese Gesamtwehr gibt es nicht')) {
    return 'Diese Gesamtwehr gibt es nicht mehr.';
  }
  if (roh.contains('SocketException') ||
      roh.contains('ClientException') ||
      roh.contains('Failed host lookup')) {
    return 'Keine Verbindung zum Server.';
  }
  return roh.replaceFirst('Exception: ', '');
}
