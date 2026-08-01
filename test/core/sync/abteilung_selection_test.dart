/// abteilung_selection_test.dart – Abteilungswahl (Issue #57 Phase 2):
/// Datei-Invariante, Lese-Sperre der Schwester-Sicht und der Umschalter.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/connection/connection.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(databaseFileName('abc-123'),
          isNot(databaseFileName('def-456')));
    });
  });

  group('canEditProvider mit Abteilungswahl', () {
    ProviderContainer build({String? selected, String? own}) {
      final container = ProviderContainer(overrides: [
        supabaseReadyProvider.overrideWithValue(true),
        currentUserRoleProvider
            .overrideWith((ref) async => 'geraetewart'),
        myAbteilungIdProvider.overrideWith((ref) async => own),
        selectedAbteilungIdProvider.overrideWith((ref) => selected),
      ]);
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
    test('merkt die Wahl und stellt den Provider um', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        // Kein Supabase im Test: Der Switcher muss auch ohne Sync-Service
        // funktionieren (Pull scheitert dann leise).
        supabaseClientProvider.overrideWithValue(null),
      ]);
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
