/// app_router_guard_test.dart – Tests für die Redirect-Guards der
/// Edit-/Admin-Routen (Issue #20): Deep-Links dürfen die UI-Gates
/// (canEdit/isAdmin) nicht umgehen.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/sync/mfa_providers.dart';

void main() {
  test('routerProvider baut den Router mit allen Routen und Guards', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    expect(router.configuration.routes, isNotEmpty);
  });

  // Die Rollen-Fälle laufen alle als angemeldet ohne Pflichtwechsel — sonst
  // schlüge der Anmeldezwang zu, bevor die Rollenregel überhaupt greift.
  String? asMember(String path) => guardRedirect(
      path: path,
      canEdit: false,
      isAdmin: false,
      supabaseReady: true,
      loggedIn: true,
      mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false);
  String? asEditor(String path) => guardRedirect(
      path: path,
      canEdit: true,
      isAdmin: false,
      supabaseReady: true,
      loggedIn: true,
      mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false);
  String? asAdmin(String path) => guardRedirect(
      path: path,
      canEdit: true,
      isAdmin: true,
      supabaseReady: true,
      loggedIn: true,
      mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false);
  /// Nicht angemeldet auf einer verbundenen Installation.
  String? ausgeloggt(String path) => guardRedirect(
      path: path,
      canEdit: false,
      isAdmin: false,
      supabaseReady: true,
      loggedIn: false,
      mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false);
  /// Reiner Lokalmodus (kein Server konfiguriert).
  String? lokal(String path) => guardRedirect(
      path: path,
      canEdit: true,
      isAdmin: true,
      supabaseReady: false,
      loggedIn: false,
      mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false);
  /// Angemeldet, aber noch mit dem Initialpasswort vom Zugangszettel.
  String? mitInitialpasswort(String path) => guardRedirect(
      path: path,
      canEdit: true,
      isAdmin: true,
      supabaseReady: true,
      loggedIn: true,
      mustChangePassword: true,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false);

  group('guardRedirect – Anmeldezwang (#57 Phase 4)', () {
    test('ohne Sitzung führt jeder Weg auf die Anmeldung', () {
      for (final pfad in [
        '/',
        '/vehicles',
        '/vehicles/7',
        '/game/flashcards',
        '/more',
        '/settings',
        '/changelog',
        '/image-library',
        '/user-management',
        '/gesamtwehr',
      ]) {
        expect(ausgeloggt(pfad), '/login', reason: pfad);
      }
    });

    test('Edit-Routen landen auf der Anmeldung, nicht auf der Startseite', () {
      // Sichert die Regelreihenfolge: Ohne Sitzung ist canEdit false, die
      // Rollenregel würde sonst auf '/' schicken und die eigentliche
      // Aussage („melde dich an") ginge unterwegs verloren.
      expect(ausgeloggt('/import'), '/login');
      expect(ausgeloggt('/vehicles/new'), '/login');
      expect(ausgeloggt('/inventory/run/3'), '/login');
    });

    test('Anmeldung und Notausgang bleiben offen', () {
      expect(ausgeloggt('/login'), isNull);
      expect(ausgeloggt('/server-settings'), isNull,
          reason: 'sonst säße man mit falscher Serveradresse fest');
    });

    test('Angemeldete werden von der Anmeldung weggeschickt', () {
      expect(asMember('/login'), '/');
      expect(asMember('/change-password'), '/');
    });

    test('Lokalmodus bleibt ohne Anmeldung voll nutzbar', () {
      expect(lokal('/'), isNull);
      expect(lokal('/vehicles'), isNull);
      expect(lokal('/import'), isNull);
      expect(lokal('/settings'), isNull);
      expect(lokal('/server-settings'), isNull);
    });

    test('Lokalmodus kennt keine Anmeldung', () {
      expect(lokal('/login'), '/');
      expect(lokal('/change-password'), '/');
    });
  });

  group('guardRedirect – Passwort-Zurücksetzen (#57 Phase 4, Etappe 2)', () {
    /// Die halbe Sitzung aus verifyOTP: angemeldet, aber das neue Passwort
    /// steht noch nicht.
    String? beimZuruecksetzen(String path) => guardRedirect(
        path: path,
        canEdit: true,
        isAdmin: true,
        supabaseReady: true,
        loggedIn: true,
        mustChangePassword: false,
        recoveryPending: true,
        mfaPending: false,
        mussZweiFaktor: false);

    test('die halbe Sitzung springt nicht in die App', () {
      // Ohne diese Regel wäre jemand angemeldet, ohne sein Passwort zu
      // kennen — und der Vorgang bliebe auf halbem Weg stehen.
      expect(beimZuruecksetzen('/'), '/login');
      expect(beimZuruecksetzen('/settings'), '/login');
      expect(beimZuruecksetzen('/import'), '/login');
    });

    test('der Anmelde-Screen bleibt stehen, bis es vorbei ist', () {
      expect(beimZuruecksetzen('/login'), isNull);
    });

    test('sie schlägt sogar den Pflichtwechsel', () {
      // Sonst risse der Pflichtwechsel den Screen weg, während der Nutzer
      // gerade dabei ist, sich genau so ein Passwort zu setzen.
      expect(
          guardRedirect(
              path: '/login',
              canEdit: true,
              isAdmin: true,
              supabaseReady: true,
              loggedIn: true,
              mustChangePassword: true,
              recoveryPending: true,
        mfaPending: false,
        mussZweiFaktor: false),
          isNull);
    });

    test('nach dem Zurücksetzen führt der Weg wieder in die App', () {
      expect(asAdmin('/login'), '/');
    });
  });

  group('guardRedirect – zweiter Faktor (#57 Phase 4, Etappe 3)', () {
    /// Passwort stimmt, Code fehlt noch: Die Sitzung steht auf aal1.
    String? codeFehlt(String path) => guardRedirect(
        path: path,
        canEdit: true,
        isAdmin: true,
        supabaseReady: true,
        loggedIn: true,
        mustChangePassword: false,
        recoveryPending: false,
        mfaPending: true,
        mussZweiFaktor: false);

    /// Admin nach Ablauf der Frist, noch ohne eingerichteten Faktor.
    String? ohneFaktor(String path) => guardRedirect(
        path: path,
        canEdit: true,
        isAdmin: true,
        supabaseReady: true,
        loggedIn: true,
        mustChangePassword: false,
        recoveryPending: false,
        mfaPending: false,
        mussZweiFaktor: true);

    test('ohne Code kommt niemand in die App', () {
      // Ohne diese Regel wäre der zweite Faktor eine Zierde: Wer die
      // Code-Eingabe wegtippt, wäre trotzdem drin.
      expect(codeFehlt('/'), '/login');
      expect(codeFehlt('/user-management'), '/login');
      expect(codeFehlt('/settings'), '/login');
    });

    test('die Code-Eingabe selbst bleibt stehen', () {
      expect(codeFehlt('/login'), isNull);
    });

    test('nach Fristablauf führt der Weg über die Einrichtung', () {
      expect(ohneFaktor('/'), '/zwei-faktor');
      expect(ohneFaktor('/user-management'), '/zwei-faktor');
      expect(ohneFaktor('/zwei-faktor'), isNull);
    });

    test('mit Faktor ist die Einrichtung keine Sackgasse', () {
      expect(asAdmin('/zwei-faktor'), '/');
    });

    test('der fehlende Code schlägt die Einrichtungspflicht', () {
      // Sonst schöbe die Pflicht den Nutzer aus der Code-Eingabe heraus,
      // bevor die Sitzung überhaupt vollständig ist.
      expect(
          guardRedirect(
              path: '/login',
              canEdit: true,
              isAdmin: true,
              supabaseReady: true,
              loggedIn: true,
              mustChangePassword: false,
              recoveryPending: false,
              mfaPending: true,
              mussZweiFaktor: true),
          isNull);
    });
  });

  group('mussZweiFaktorEinrichten', () {
    final vorher = kZweiFaktorPflichtAb.subtract(const Duration(days: 1));
    final nachher = kZweiFaktorPflichtAb.add(const Duration(days: 1));

    test('vor der Frist zwingt nichts', () {
      expect(
          mussZweiFaktorEinrichten(
              rolle: 'admin', hatFaktor: false, jetzt: vorher),
          isFalse);
    });

    test('nach der Frist trifft es Admins ohne Faktor', () {
      expect(
          mussZweiFaktorEinrichten(
              rolle: 'admin', hatFaktor: false, jetzt: nachher),
          isTrue);
    });

    test('wer eingerichtet hat, wird nicht behelligt', () {
      expect(
          mussZweiFaktorEinrichten(
              rolle: 'admin', hatFaktor: true, jetzt: nachher),
          isFalse);
    });

    test('Gerätewarte und Mitglieder bleiben außen vor', () {
      // Bewusst nur Admins: Ein Mitglied meldet sich mit einem Zettel an
      // und hat nichts zu verlieren, was nicht im Gerätehaus aushängt.
      for (final rolle in ['geraetewart', 'member', null]) {
        expect(
            mussZweiFaktorEinrichten(
                rolle: rolle, hatFaktor: false, jetzt: nachher),
            isFalse,
            reason: '$rolle');
      }
    });
  });

  group('guardRedirect – Pflichtwechsel des Initialpassworts', () {
    test('führt von überall auf den Wechsel', () {
      expect(mitInitialpasswort('/'), '/change-password');
      expect(mitInitialpasswort('/settings'), '/change-password');
      expect(mitInitialpasswort('/import'), '/change-password');
      expect(mitInitialpasswort('/login'), '/change-password');
    });

    test('der Wechsel selbst ist erreichbar', () {
      expect(mitInitialpasswort('/change-password'), isNull);
    });

    test('ohne Flag ist der Wechsel keine Sackgasse', () {
      expect(asMember('/change-password'), '/');
    });

    test('Abmelden schlägt den Pflichtwechsel', () {
      // Der einzige Ausweg aus dem Wechsel-Screen ist „Abmelden" — danach
      // muss die Anmeldung gewinnen, nicht wieder der Wechsel.
      expect(
          guardRedirect(
              path: '/',
              canEdit: false,
              isAdmin: false,
              supabaseReady: true,
              loggedIn: false,
              mustChangePassword: true,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false),
          '/login');
    });
  });

  group('guardRedirect – keine Redirect-Schleifen', () {
    // Eine Schleife wäre auf dem Gerät ein Weißbild (go_router bricht nach
    // 5 Sprüngen ab) — kein anderer Test fängt das.
    String? folge(String start,
        {required bool ready,
        required bool loggedIn,
        required bool mustChange}) {
      var pfad = start;
      for (var i = 0; i < 5; i++) {
        final ziel = guardRedirect(
          path: pfad,
          canEdit: loggedIn,
          isAdmin: loggedIn,
          supabaseReady: ready,
          loggedIn: loggedIn,
          mustChangePassword: mustChange,
          recoveryPending: false,
          mfaPending: false,
          mussZweiFaktor: false,
        );
        if (ziel == null) return pfad;
        pfad = ziel;
      }
      return null; // kam nie zur Ruhe
    }

    test('jede Kombination kommt binnen weniger Sprünge zur Ruhe', () {
      for (final start in ['/', '/import', '/login', '/server-settings']) {
        for (final ready in [true, false]) {
          for (final loggedIn in [true, false]) {
            for (final mustChange in [true, false]) {
              expect(
                  folge(start,
                      ready: ready,
                      loggedIn: loggedIn,
                      mustChange: mustChange),
                  isNotNull,
                  reason: 'Schleife ab $start '
                      '(ready=$ready, loggedIn=$loggedIn, '
                      'mustChange=$mustChange)');
            }
          }
        }
      }
    });
  });

  group('guardRedirect – Mitglieder (read-only)', () {
    test('Edit-Routen werden auf Start umgeleitet', () {
      expect(asMember('/vehicles/new'), '/');
      expect(asMember('/vehicles/7/edit'), '/');
      expect(asMember('/vehicles/7/compartments'), '/');
      expect(asMember('/equipment/new'), '/');
      expect(asMember('/equipment/12/edit'), '/');
      expect(asMember('/import'), '/');
      expect(asMember('/inspections'), '/');
      expect(asMember('/inventory'), '/');
      expect(asMember('/inventory/run/3'), '/');
      expect(asMember('/user-management'), '/');
      expect(asMember('/gesamtwehr'), '/');
    });

    test('Lese-Routen bleiben erreichbar', () {
      expect(asMember('/'), isNull);
      expect(asMember('/vehicles'), isNull);
      expect(asMember('/vehicles/7'), isNull);
      expect(asMember('/equipment/12'), isNull);
      expect(asMember('/game/flashcards'), isNull);
      expect(asMember('/image-library'), isNull);
      expect(asMember('/settings'), isNull);
      expect(asMember('/more'), isNull);
    });
  });

  group('guardRedirect – Gerätewart/Admin', () {
    test('Gerätewart darf bearbeiten, aber nicht in die Nutzerverwaltung', () {
      expect(asEditor('/vehicles/7/edit'), isNull);
      expect(asEditor('/import'), isNull);
      expect(asEditor('/inventory/report/1'), isNull);
      expect(asEditor('/user-management'), '/');
    });

    test('Admin darf alles', () {
      expect(asAdmin('/vehicles/new'), isNull);
      expect(asAdmin('/user-management'), isNull);
    });

    test('Nutzerverwaltung braucht Serververbindung (Lokalmodus: kein Ziel)',
        () {
      expect(
          guardRedirect(
              path: '/user-management',
              canEdit: true,
              isAdmin: true,
              supabaseReady: false,
              loggedIn: true,
              mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false),
          '/');
    });

    test('Abteilung & Gesamtwehr: Gerätewart ja, Mitglied nein (#57 Phase 3)',
        () {
      // Bewusst canEdit statt isAdmin — den Anschluss beantragt auch der
      // Gerätewart. Über die Freigabe entscheidet der Server, nicht der Guard.
      expect(asEditor('/gesamtwehr'), isNull);
      expect(asAdmin('/gesamtwehr'), isNull);
      expect(
          guardRedirect(
              path: '/gesamtwehr',
              canEdit: true,
              isAdmin: true,
              supabaseReady: false,
              loggedIn: true,
              mustChangePassword: false,
      recoveryPending: false,
      mfaPending: false,
      mussZweiFaktor: false),
          '/',
          reason: 'ohne Server gibt es keine Abteilungen');
    });
  });
}
