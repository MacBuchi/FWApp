/// lerngruppen_meldung_test.dart – Der Melder im Hintergrund (Issue #136):
/// Jede gespeicherte Runde stößt ihn an, ohne dass ein Spielbildschirm davon
/// wissen muss.
///
/// Warum das einen eigenen Test braucht: Der Anstoß hängt am Strom der
/// lokalen Ergebnistabelle, nicht an einem Aufruf in den fünf
/// Spielbildschirmen. Bricht die Verbindung, meldet NIEMAND mehr — und
/// keiner der Bildschirm-Tests würde es merken.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/lerngruppe/presentation/providers/lerngruppe_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import '../../helpers/fake_session.dart';
import '../../helpers/test_database.dart';

class _ZaehlenderDienst extends LerngruppeService {
  int laeufe = 0;
  _ZaehlenderDienst(Ref ref)
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        ref,
      );

  @override
  Future<int> meldeWochenwerte() async {
    laeufe++;
    return 0;
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> ruhe() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('eine gespeicherte Runde stößt das Melden an', () async {
    late _ZaehlenderDienst dienst;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionStreamProvider.overrideWith(
          (ref) => Stream.value(fakeSession()),
        ),
        lerngruppeServiceProvider.overrideWith(
          (ref) => dienst = _ZaehlenderDienst(ref),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Erst die Sitzung da sein lassen, dann den Melder einschalten — so wie
    // in der App, wo die Wurzel ihn per listen hält.
    container.listen(sessionStreamProvider, (_, _) {});
    await ruhe();
    container.listen(lerngruppenAutoMeldungProvider, (_, _) {});
    await ruhe();
    // Einmal beim Start: eine offline gespielte Runde kommt so nach oben.
    expect(dienst.laeufe, 1);

    await db.quizDao.insertResult(
      QuizResultsCompanion.insert(quizType: 'compartment', score: 7, total: 10),
    );
    await ruhe();
    expect(dienst.laeufe, 2);
  });

  test('ohne Anmeldung meldet niemand', () async {
    final dienste = <_ZaehlenderDienst>[];
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sessionStreamProvider.overrideWith((ref) => Stream.value(null)),
        lerngruppeServiceProvider.overrideWith((ref) {
          final d = _ZaehlenderDienst(ref);
          dienste.add(d);
          return d;
        }),
      ],
    );
    addTearDown(container.dispose);

    container.listen(sessionStreamProvider, (_, _) {});
    await ruhe();
    container.listen(lerngruppenAutoMeldungProvider, (_, _) {});
    await db.quizDao.insertResult(
      QuizResultsCompanion.insert(quizType: 'compartment', score: 7, total: 10),
    );
    await ruhe();

    expect(dienste.fold<int>(0, (s, d) => s + d.laeufe), 0);
  });

  test('getSeit liefert die Runden ab Montag 00:00, nicht davor', () async {
    final montag = DateTime(2026, 9, 21);
    for (final (typ, am) in [
      ('alt', montag.subtract(const Duration(seconds: 1))),
      ('genau', montag),
      ('neu', montag.add(const Duration(days: 2))),
    ]) {
      await db.quizDao.insertResult(
        QuizResultsCompanion.insert(
          quizType: typ,
          score: 1,
          total: 1,
          playedAt: Value(am),
        ),
      );
    }
    final seit = await db.quizDao.getSeit(montag);
    expect(seit.map((r) => r.quizType).toSet(), {'genau', 'neu'});
  });
}
