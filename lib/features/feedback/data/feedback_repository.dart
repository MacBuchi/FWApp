/// feedback_repository.dart – Schreibt Feature-Wünsche/Bug-Reports in die
/// Supabase-Tabelle `feedback`. Ein GitHub-Actions-Bot macht daraus
/// öffentliche Issues im Repo (siehe tool/feedback_bot.py).
library;
import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedbackType { feature, bug }

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
