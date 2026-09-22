/// abteilung_selection_test.dart – Abteilungswahl (Issue #57 Phase 2):
/// Datei-Invariante, Lese-Sperre der Schwester-Sicht und der Umschalter.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/connection/connection.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/snapshot_verlust.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/sync/sync_service.dart';
import 'package:fwapp/features/inventory/data/tag_sync.dart';
import 'package:fwapp/features/inventory/presentation/providers/tag_providers.dart';
import 'package:fwapp/features/vehicle/data/anhang_speicher.dart';
import 'package:fwapp/features/vehicle/presentation/providers/anhang_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../helpers/test_database.dart';

/// Hält fest, WOFÜR gezogen wurde — ohne Server lässt sich das sonst nicht
/// von „gar nicht aufgerufen" unterscheiden.
class _TagSpion extends TagSync {
  _TagSpion(AppDatabase db) : super(db: db);
  final gezogen = <String>[];
  final geschoben = <String>[];

  @override
  Future<int> ziehe(String abteilungId) async {
    gezogen.add(abteilungId);
    return 0;
  }

  @override
  Future<int> schiebe(String abteilungId) async {
    geschoben.add(abteilungId);
    return 0;
  }
}

/// Tut so, als stünde beim Zug etwas auf dem Spiel — ohne Netz und ohne
/// Server lässt sich sonst nicht prüfen, ob der Haken überhaupt ankommt.
class _SyncSpion extends SyncService {
  _SyncSpion(AppDatabase db)
    : super(db, SupabaseClient('http://127.0.0.1:1', 'anon'));
  bool gefragt = false;

  @override
  Future<int?> pullIfNewer({
    bool force = false,
    Future<bool> Function(SnapshotVerlust verlust)? bestaetigen,
  }) async {
    if (bestaetigen == null) return 1;
    gefragt = true;
    final weiter = await bestaetigen(const SnapshotVerlust({'vehicles': 1}));
    return weiter ? 1 : null;
  }
}

class _SpeicherSpion extends AnhangSpeicher {
  _SpeicherSpion(AppDatabase db) : super(db: db);
  final gezogen = <String>[];

  @override
  Future<int> zieheAnhaenge(String abteilungId) async {
    gezogen.add(abteilungId);
    return 0;
  }

  @override
  Future<int> nachreichen({String? abteilungId}) async => 0;
}

void main() {
  group('databaseFileName', () {
    test('eigene Abteilung behält die angestammte Datei', () {
      // DIE Invariante von Phase 2: Unveröffentlichte Arbeit von vor dem
      // Update liegt in fwapp.sqlite — die eigene Abteilung darf niemals
      // auf eine andere Datei zeigen, sonst „verschwindet" sie.
      expect(databaseFileName(null), 'fwapp.sqlite');
    });

    test('Schwester-Abteilungen bekommen eigene Dateien', () {
      expect(databaseFileName('abc-123'), 'fwapp_abc-123.sqlite');
      expect(databaseFileName('abc-123'), isNot(databaseFileName('def-456')));
    });
  });

  group('canEditProvider mit Abteilungswahl', () {
    ProviderContainer build({String? selected, String? own}) {
      final container = ProviderContainer(
        overrides: [
          supabaseReadyProvider.overrideWithValue(true),
          currentUserRoleProvider.overrideWith((ref) async => 'geraetewart'),
          myAbteilungIdProvider.overrideWith((ref) async => own),
          selectedAbteilungIdProvider.overrideWith((ref) => selected),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('eigene Abteilung: Gerätewart darf bearbeiten', () async {
      final c = build(selected: null, own: 'A');
      await c.read(currentUserRoleProvider.future);
      await c.read(myAbteilungIdProvider.future);
      expect(c.read(canEditProvider), isTrue);
    });

    test('Schwester-Sicht: auch der Gerätewart ist nur Leser', () async {
      // Issue-Text wörtlich: In fremden Abteilungen hat der Gerätewart
      // „exakt dieselben Berechtigungen wie der ganz normale User".
      final c = build(selected: 'B', own: 'A');
      await c.read(currentUserRoleProvider.future);
      await c.read(myAbteilungIdProvider.future);
      expect(c.read(canEditProvider), isFalse);
    });

    test('explizit die eigene gewählt: bearbeiten bleibt erlaubt', () async {
      final c = build(selected: 'A', own: 'A');
      await c.read(currentUserRoleProvider.future);
      await c.read(myAbteilungIdProvider.future);
      expect(c.read(canEditProvider), isTrue);
    });
  });

  group('AbteilungSwitcher', () {
    test('zieht auch die Tabellen NEBEN dem Snapshot', () async {
      // ⚠️ Der Fehler, den dieser Test festhält: Bis v1.53.0 zog der
      // Wechsel nur den Snapshot und die Gerätetypen. Wer auf eine
      // Schwester-Abteilung umschaltete, sah deren Fahrzeuge — aber keine
      // Unterlagen und keinen einzigen Code. Die Inventur scannte ins
      // Leere, und nichts sagte einem, dass ein „Jetzt aktualisieren"
      // gefehlt hat.
      SharedPreferences.setMockInitialValues({});
      final db = createTestDatabase();
      addTearDown(db.close);
      final anhaenge = _SpeicherSpion(db);
      final tags = _TagSpion(db);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(null),
          anhangSpeicherProvider.overrideWithValue(anhaenge),
          tagSyncProvider.overrideWithValue(tags),
        ],
      );
      addTearDown(container.dispose);

      await container.read(abteilungSwitcherProvider).switchTo('B');

      expect(anhaenge.gezogen, ['B'], reason: 'Unterlagen der neuen Sicht.');
      expect(tags.gezogen, ['B'], reason: 'Codes der neuen Sicht.');
      expect(
        tags.geschoben,
        ['B'],
        reason:
            'Erst schieben, dann ziehen — sonst überschreibt der Zug '
            'einen gerade vergebenen Code.',
      );
    });

    test('ohne Abteilung bleibt es beim Snapshot', () async {
      // Zurück zur eigenen Abteilung, ohne Server: Es gibt keine ID, in
      // deren Namen geschrieben werden könnte.
      SharedPreferences.setMockInitialValues({});
      final db = createTestDatabase();
      addTearDown(db.close);
      final tags = _TagSpion(db);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(null),
          anhangSpeicherProvider.overrideWithValue(_SpeicherSpion(db)),
          tagSyncProvider.overrideWithValue(tags),
        ],
      );
      addTearDown(container.dispose);

      await container.read(abteilungSwitcherProvider).switchTo(null);
      expect(tags.gezogen, isEmpty);
    });

    test(
      'lehnt jemand den Verlust ab, wird gewechselt aber nicht gezogen',
      () async {
        // ⚠️ Der Weg ZURÜCK in die eigene Abteilung ist der teure Fall: Wer
        // dort etwas angelegt, dann kurz zur Schwester geschaut hat, verlöre
        // es beim Zurückkommen (#214).
        SharedPreferences.setMockInitialValues({});
        final db = createTestDatabase();
        addTearDown(db.close);
        final dienst = _SyncSpion(db);

        final container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(null),
            syncServiceProvider.overrideWithValue(dienst),
            anhangSpeicherProvider.overrideWithValue(_SpeicherSpion(db)),
            tagSyncProvider.overrideWithValue(_TagSpion(db)),
          ],
        );
        addTearDown(container.dispose);

        final gezogen = await container
            .read(abteilungSwitcherProvider)
            .switchTo('B', bestaetigen: (_) async => false);

        expect(gezogen, isFalse);
        expect(
          dienst.gefragt,
          isTrue,
          reason: 'Der Haken muss bis zum Zug durchgereicht werden.',
        );
        expect(
          container.read(selectedAbteilungIdProvider),
          'B',
          reason: 'Gewechselt ist gewechselt — nur geladen wurde nichts.',
        );
      },
    );

    test('stimmt jemand zu, wird gezogen', () async {
      SharedPreferences.setMockInitialValues({});
      final db = createTestDatabase();
      addTearDown(db.close);
      final dienst = _SyncSpion(db);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(null),
          syncServiceProvider.overrideWithValue(dienst),
          anhangSpeicherProvider.overrideWithValue(_SpeicherSpion(db)),
          tagSyncProvider.overrideWithValue(_TagSpion(db)),
        ],
      );
      addTearDown(container.dispose);

      final gezogen = await container
          .read(abteilungSwitcherProvider)
          .switchTo('B', bestaetigen: (_) async => true);

      expect(gezogen, isTrue);
    });

    test('ohne Server ist nichts abgelehnt', () async {
      // ⚠️ „Kein Sync-Dienst" ist nicht „der Nutzer hat nein gesagt". Ein
      // erster Entwurf machte daraus ein `false`, und im Lokalbetrieb stand
      // danach „nichts geladen", obwohl es nie etwas zu laden gab. Gefunden
      // hat das `abteilung_switcher_test.dart`, nicht ich.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      expect(
        await container
            .read(abteilungSwitcherProvider)
            .switchTo('B', bestaetigen: (_) async => false),
        isTrue,
      );
    });

    test('merkt die Wahl und stellt den Provider um', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          // Kein Supabase im Test: Der Switcher muss auch ohne Sync-Service
          // funktionieren (Pull scheitert dann leise).
          supabaseClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(abteilungSwitcherProvider).switchTo('B');
      expect(container.read(selectedAbteilungIdProvider), 'B');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kSelectedAbteilungPref), 'B');

      // Zurück zur eigenen: Auswahl UND Persistenz verschwinden.
      await container.read(abteilungSwitcherProvider).switchTo(null);
      expect(container.read(selectedAbteilungIdProvider), isNull);
      expect(prefs.getString(kSelectedAbteilungPref), isNull);
    });
  });
}
