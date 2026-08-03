/// membership_rights_test.dart – Schreibrecht je Abteilung (Nutzerkonzept
/// Stufe 1, Issue #98): canEdit/isAdmin aus Mitgliedschaften und
/// Kommandanten-Stellung, plus die Anzeigenamen.
///
/// Der Server erzwingt dasselbe in can_publish_abteilung (E2E-Test) — hier
/// geht es um die UI-Seite: Welche Sicht bekommt Bearbeitungs-Knöpfe?
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/membership_providers.dart';
import 'package:fwapp/core/sync/rollen.dart';
import 'package:fwapp/core/sync/sync_providers.dart';

void main() {
  ProviderContainer build({
    Map<String, String>? mitgliedschaften,
    Set<String>? kommandiert,
    String? selected,
    String? own,
    List<AbteilungInfo> abteilungen = const [],
    String? spiegelRolle,
  }) {
    final container = ProviderContainer(
      overrides: [
        supabaseReadyProvider.overrideWithValue(true),
        meineMitgliedschaftenProvider.overrideWith(
          (ref) async => mitgliedschaften,
        ),
        meineKommandoGesamtwehrenProvider.overrideWith(
          (ref) async => kommandiert,
        ),
        myAbteilungIdProvider.overrideWith((ref) async => own),
        selectedAbteilungIdProvider.overrideWith((ref) => selected),
        abteilungenProvider.overrideWith((ref) async => abteilungen),
        currentUserRoleProvider.overrideWith((ref) async => spiegelRolle),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle(ProviderContainer c) async {
    await c.read(meineMitgliedschaftenProvider.future);
    await c.read(meineKommandoGesamtwehrenProvider.future);
    await c.read(myAbteilungIdProvider.future);
    await c.read(abteilungenProvider.future);
    await c.read(currentUserRoleProvider.future);
  }

  group('canEdit aus Mitgliedschaften', () {
    test('Schreibrolle in der gewählten Abteilung darf bearbeiten', () async {
      final c = build(
        mitgliedschaften: {'A': 'geraetewart'},
        selected: null,
        own: 'A',
      );
      await settle(c);
      expect(c.read(canEditProvider), isTrue);
    });

    test('member in der gewählten Abteilung bleibt Leser — auch wenn '
        'anderswo eine Schreibrolle besteht', () async {
      // DER Kern von Stufe 1: Das Recht klebt an der Abteilung, nicht am
      // Konto. Gerätewart in B macht in A keinen Bearbeiter.
      final c = build(
        mitgliedschaften: {'A': 'member', 'B': 'geraetewart'},
        selected: 'A',
        own: 'A',
      );
      await settle(c);
      expect(c.read(canEditProvider), isFalse);
    });

    test('Gerätewart in zwei Abteilungen darf in beiden bearbeiten', () async {
      final basis = {'A': 'geraetewart', 'B': 'geraetewart'};
      for (final ziel in ['A', 'B']) {
        final c = build(mitgliedschaften: basis, selected: ziel, own: 'A');
        await settle(c);
        expect(
          c.read(canEditProvider),
          isTrue,
          reason: 'Schreibrolle in $ziel muss dort auch gelten',
        );
      }
    });

    test('ohne Mitgliedschaft in der Schwester bleibt sie lesend', () async {
      final c = build(
        mitgliedschaften: {'A': 'geraetewart'},
        selected: 'B',
        own: 'A',
      );
      await settle(c);
      expect(c.read(canEditProvider), isFalse);
    });

    test('der Feuerwehrkommandant schreibt in jeder Abteilung seiner '
        'Gesamtwehr', () async {
      final c = build(
        mitgliedschaften: {'A': 'member'},
        kommandiert: {'GW'},
        selected: 'B',
        own: 'A',
        abteilungen: const [
          AbteilungInfo(
            id: 'A',
            name: 'Stadt',
            status: 'active',
            gesamtwehrId: 'GW',
          ),
          AbteilungInfo(
            id: 'B',
            name: 'Grombach',
            status: 'active',
            gesamtwehrId: 'GW',
          ),
        ],
      );
      await settle(c);
      expect(c.read(canEditProvider), isTrue);
    });

    test('Kommandant einer ANDEREN Gesamtwehr bleibt draußen', () async {
      final c = build(
        mitgliedschaften: {'A': 'member'},
        kommandiert: {'FREMD'},
        selected: 'B',
        own: 'A',
        abteilungen: const [
          AbteilungInfo(
            id: 'B',
            name: 'Grombach',
            status: 'active',
            gesamtwehrId: 'GW',
          ),
        ],
      );
      await settle(c);
      expect(c.read(canEditProvider), isFalse);
    });

    test('Alt-Server (keine Mitgliedschaften): Schwester-Sicht bleibt '
        'lesend, eigene folgt der Spiegel-Rolle', () async {
      final fremd = build(
        mitgliedschaften: null,
        spiegelRolle: 'admin',
        selected: 'B',
        own: 'A',
      );
      await settle(fremd);
      expect(fremd.read(canEditProvider), isFalse);

      final eigene = build(
        mitgliedschaften: null,
        spiegelRolle: 'admin',
        selected: null,
        own: 'A',
      );
      await settle(eigene);
      expect(eigene.read(canEditProvider), isTrue);
    });
  });

  group('isAdmin aus Mitgliedschaften', () {
    test('admin-Mitgliedschaft irgendwo öffnet die Verwaltung', () async {
      final c = build(mitgliedschaften: {'B': 'admin'}, own: 'A');
      await settle(c);
      expect(c.read(isAdminProvider), isTrue);
    });

    test('Kommandant ohne admin-Mitgliedschaft ebenso', () async {
      final c = build(
        mitgliedschaften: {'A': 'member'},
        kommandiert: {'GW'},
        own: 'A',
      );
      await settle(c);
      expect(c.read(isAdminProvider), isTrue);
    });

    test('nur member/geraetewart: keine Verwaltung', () async {
      final c = build(
        mitgliedschaften: {'A': 'geraetewart'},
        kommandiert: const {},
        own: 'A',
      );
      await settle(c);
      expect(c.read(isAdminProvider), isFalse);
    });
  });

  group('rolleAnzeigename', () {
    test('übersetzt die technischen Schlüssel ins Feuerwehrdeutsch', () {
      expect(rolleAnzeigename('admin'), 'Abteilungskommandant');
      expect(rolleAnzeigename('geraetewart'), 'Gerätewart');
      expect(rolleAnzeigename('member'), 'Truppmann');
      expect(rolleAnzeigename('member', echteMail: true), 'Truppführer');
      // Kommandant überstimmt jede Mitgliedschaftsrolle.
      expect(
        rolleAnzeigename('member', kommandant: true),
        'Feuerwehrkommandant',
      );
      expect(rolleAnzeigename(null, kommandant: true), 'Feuerwehrkommandant');
    });
  });

  group('schreibrolleInAbteilung', () {
    // Spiegelt canEditProvider für eine FREI GEWÄHLTE Abteilung — die
    // Abteilungswahl (Issue #96) zeigt die Rechte aller nebeneinander.
    String? rolle(
      String id, {
      String? gesamtwehr,
      Map<String, String>? mitgliedschaften,
      Set<String>? kommandiert,
    }) => schreibrolleInAbteilung(
      abteilungId: id,
      gesamtwehrId: gesamtwehr,
      mitgliedschaften: mitgliedschaften,
      kommandierteGesamtwehren: kommandiert,
    );

    test('Schreibrolle wird beim Namen genannt', () {
      expect(
        rolle('B', mitgliedschaften: {'B': 'geraetewart'}),
        'Gerätewart',
      );
      expect(rolle('B', mitgliedschaften: {'B': 'admin'}), 'Abteilungskommandant');
    });

    test('member und Fremd-Abteilung ergeben Lesezugriff (null)', () {
      expect(rolle('B', mitgliedschaften: {'B': 'member'}), isNull);
      expect(rolle('B', mitgliedschaften: {'A': 'admin'}), isNull);
    });

    test('der Feuerwehrkommandant überstimmt die Mitgliedschaft', () {
      expect(
        rolle(
          'B',
          gesamtwehr: 'GW',
          mitgliedschaften: {'B': 'member'},
          kommandiert: {'GW'},
        ),
        'Feuerwehrkommandant',
      );
      // Fremde Gesamtwehr: die Stellung trägt nicht hinüber.
      expect(
        rolle(
          'B',
          gesamtwehr: 'GW',
          mitgliedschaften: {'B': 'member'},
          kommandiert: {'ANDERE'},
        ),
        isNull,
      );
    });

    test('Alt-Server ohne Mitgliedschaften antwortet nicht (null)', () {
      // Wichtig, weil der Aufrufer dann bei der alten Regel bleiben muss und
      // nicht „nur lesen" für die eigene Abteilung behaupten darf.
      expect(rolle('A', mitgliedschaften: null, kommandiert: {'GW'}), isNull);
    });
  });

  group('darfAbteilungUmbenennen (#119)', () {
    // Zwilling zu darf_mitglieder_verwalten(ziel, null) auf dem Server. Der
    // Server entscheidet, hier geht es nur darum, welcher Stift erscheint —
    // aber ein Stift, der in eine Absage läuft, ist schlimmer als keiner.
    bool darf(
      String id, {
      String? gesamtwehr,
      Map<String, String>? mitgliedschaften,
      Set<String>? kommandiert,
    }) => darfAbteilungUmbenennen(
      abteilungId: id,
      gesamtwehrId: gesamtwehr,
      mitgliedschaften: mitgliedschaften,
      kommandierteGesamtwehren: kommandiert,
    );

    test('der Abteilungskommandant darf seine eigene Abteilung', () {
      expect(darf('A', mitgliedschaften: {'A': 'admin'}), isTrue);
    });

    test('aber KEINE Nachbarabteilung', () {
      // Die Grenze, um die es in #119 überhaupt geht: Wer in A das Sagen hat,
      // benennt deshalb nicht B um.
      expect(
        darf('B', gesamtwehr: 'GW', mitgliedschaften: {'A': 'admin'}),
        isFalse,
      );
    });

    test('der Feuerwehrkommandant darf jede Abteilung seiner Wehr', () {
      expect(
        darf('B',
            gesamtwehr: 'GW',
            mitgliedschaften: const {},
            kommandiert: {'GW'}),
        isTrue,
      );
    });

    test('seine Stellung trägt nicht in eine fremde Gesamtwehr', () {
      expect(
        darf('B',
            gesamtwehr: 'GW',
            mitgliedschaften: const {},
            kommandiert: {'ANDERE'}),
        isFalse,
      );
    });

    test('Gerätewart und Truppführer dürfen nicht', () {
      // Sie pflegen den Bestand, nicht die Aufstellung der Wehr.
      expect(darf('A', mitgliedschaften: {'A': 'geraetewart'}), isFalse);
      expect(darf('A', mitgliedschaften: {'A': 'member'}), isFalse);
    });

    test('Alt-Server ohne Mitgliedschaften zeigt keinen Stift', () {
      expect(darf('A', mitgliedschaften: null, kommandiert: {'GW'}), isFalse);
    });

    test('ohne Gesamtwehr zählt allein die Mitgliedschaft', () {
      // Eine eigenständige Abteilung hat keinen Feuerwehrkommandanten über
      // sich — sonst käme eine frische Installation nie an ihren Namen.
      expect(darf('A', mitgliedschaften: {'A': 'admin'}, kommandiert: {'GW'}),
          isTrue);
      expect(darf('A', mitgliedschaften: {'A': 'member'}, kommandiert: {'GW'}),
          isFalse);
    });
  });
}
