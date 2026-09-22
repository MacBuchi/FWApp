/// fake_session.dart – Minimal-Session für Widget-Tests, die „angemeldet"
/// sehen sollen, ohne einen Server zu brauchen.
library;

import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;

/// Die Kennung der Testperson — für Tests, die „das bin ich" prüfen.
const kFakeUserId = '00000000-0000-0000-0000-000000000001';

Session fakeSession() => Session(
  accessToken: 'test-token',
  tokenType: 'bearer',
  user: const User(
    id: kFakeUserId,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    email: 'tester@fw.local',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);
