/// feedback_repository.dart – Schreibt Feature-Wünsche/Bug-Reports in die
/// Supabase-Tabelle `feedback`. Ein GitHub-Actions-Bot macht daraus
/// öffentliche Issues im Repo (siehe tool/feedback_bot.py).
library;
import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedbackType { feature, bug }

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
    'message': message.trim(),
  });
}
