/// feedback_repository.dart – Schreibt Feature-Wünsche/Bug-Reports in die
/// Supabase-Tabelle `feedback`. Ein GitHub-Actions-Bot macht daraus
/// öffentliche Issues im Repo (siehe tool/feedback_bot.py).
library;
import 'package:supabase_flutter/supabase_flutter.dart';

/// `katalog` ist der Vorschlag für den GLOBALEN Gerätekatalog (Issue #103),
/// `fahrzeug` der für eine fehlende Fahrzeug-Vorlage (Issue #145) — derselbe
/// Weg wie Wunsch und Fehler, nur mit eigenem Label im Issue. Bei beiden
/// Vorschlägen trägt die ERSTE ZEILE den Namen: Daraus baut der Bot die
/// Überschrift. Der Server prüft die vier Werte per Check-Constraint; ein
/// fünfter braucht deshalb IMMER eine Migration, sonst scheitert das Insert
/// stumm mit „Senden fehlgeschlagen".
enum FeedbackType { feature, bug, katalog, fahrzeug }

/// Server-Constraint der `feedback`-Tabelle:
/// `check (char_length(message) between 3 and 2000)`.
/// Längere Nachrichten lehnt Postgres hart ab — passiert bei
/// Absturzberichten mit Log-Anhang schnell (Fund im Feld, v1.6.0: das
/// „Senden fehlgeschlagen" war nie das Netz, sondern dieser Check).
const kFeedbackMaxLength = 2000;

/// Kürzt eine Meldung aufs Server-Limit. Absturzberichte tragen die
/// wichtigste Information vorn (Kopf + Exception + oberste Stack-Frames),
/// deshalb bleibt der Anfang stehen und der Log-Schwanz fällt weg — mit
/// sichtbarer Markierung, damit niemand den Bericht für vollständig hält.
String clampFeedbackMessage(String message) {
  final sauber = message.trim();
  if (sauber.length <= kFeedbackMaxLength) return sauber;
  const marker = '\n\n[… gekürzt — volle Länge überschritt das Server-Limit]';
  return sauber.substring(0, kFeedbackMaxLength - marker.length) + marker;
}

/// Der Text eines Katalog-Vorschlags (Issue #103).
///
/// ⚠️ **Die ERSTE ZEILE ist der Gerätename und nichts sonst** — der Bot
/// baut daraus die Überschrift des Issues. Alles Weitere gehört darunter.
///
/// Bewusst OHNE Foto: Das Repo ist öffentlich, und der Betreiber sieht das
/// Bild ohnehin in der App (lesende Quer-Sicht). Das Katalog-Piktogramm
/// entsteht ohnehin im App-Stil (docs/NUTZERKONZEPT.md §5).
String katalogVorschlagText({
  required String name,
  String? kurzname,
  String beschreibung = '',
  required String abteilung,
}) {
  final zeilen = <String>[
    name.trim(),
    if ((kurzname ?? '').trim().isNotEmpty) 'Kurzform: ${kurzname!.trim()}',
    if (beschreibung.trim().isNotEmpty) 'Beschreibung: ${beschreibung.trim()}',
    'Vorgeschlagen aus der Abteilung: $abteilung',
  ];
  return zeilen.join('\n');
}

/// Sendet eine Meldung im Namen des angemeldeten Nutzers.
/// Wirft, wenn kein Client/Login vorhanden ist oder das Insert scheitert —
/// der Aufrufer zeigt dann die Fehlermeldung.
Future<void> submitFeedback(
  SupabaseClient? client, {
  required FeedbackType type,
  required String message,
}) async {
  if (client == null) {
    throw StateError('Feedback braucht eine aktive Serververbindung.');
  }
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('Feedback braucht einen angemeldeten Nutzer.');
  }
  // Nutzername = Localpart der fw.local-Adresse (rein informativ fürs Issue).
  final email = user.email ?? '';
  final userName = email.contains('@') ? email.split('@').first : null;
  await client.from('feedback').insert({
    'user_id': user.id,
    if (userName != null && userName.isNotEmpty) 'user_name': userName,
    'type': type.name,
    'message': clampFeedbackMessage(message),
  });
}
