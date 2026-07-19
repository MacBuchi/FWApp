/// app_router_guard_test.dart – Tests für die Redirect-Guards der
/// Edit-/Admin-Routen (Issue #20): Deep-Links dürfen die UI-Gates
/// (canEdit/isAdmin) nicht umgehen.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/router/app_router.dart';

void main() {
  test('routerProvider baut den Router mit allen Routen und Guards', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    expect(router.configuration.routes, isNotEmpty);
  });

  String? asMember(String path) => guardRedirect(
      path: path, canEdit: false, isAdmin: false, supabaseReady: true);
  String? asEditor(String path) => guardRedirect(
      path: path, canEdit: true, isAdmin: false, supabaseReady: true);
  String? asAdmin(String path) => guardRedirect(
      path: path, canEdit: true, isAdmin: true, supabaseReady: true);

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
              supabaseReady: false),
          '/');
    });
  });
}
