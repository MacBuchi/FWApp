/// app_router.dart – GoRouter configuration for all app routes.
///
/// Edit-/Admin-Routen sind zusätzlich zur ausgeblendeten UI per [guardRedirect]
/// geschützt, damit auch Deep-Links (Web!) die Rollenregeln respektieren.
library;
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/auth/presentation/screens/change_password_screen.dart';
import 'package:fwapp/features/auth/presentation/screens/login_screen.dart';
import 'package:fwapp/features/settings/presentation/screens/server_settings_screen.dart';
import 'package:fwapp/features/home/presentation/screens/home_screen.dart';
import 'package:fwapp/features/home/presentation/screens/more_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_list_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_detail_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_form_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_template_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/compartment_manager_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_list_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_detail_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_form_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/image_library_screen.dart';
import 'package:fwapp/features/game/presentation/screens/game_menu_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/compartment_quiz_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/cutaway_quiz_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/drag_drop_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/flashcard_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/image_quiz_screen.dart';
import 'package:fwapp/features/game/deployment/presentation/screens/deployment_mode_screen.dart';
import 'package:fwapp/features/import/presentation/screens/import_wizard_screen.dart';
import 'package:fwapp/features/inspection/presentation/screens/inspection_dashboard_screen.dart';
import 'package:fwapp/features/operation/presentation/screens/operation_setup_screen.dart';
import 'package:fwapp/features/operation/presentation/screens/operation_run_screen.dart';
import 'package:fwapp/features/operation/presentation/screens/operation_summary_screen.dart';
import 'package:fwapp/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:fwapp/features/inventory/presentation/screens/inventory_report_screen.dart';
import 'package:fwapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:fwapp/features/settings/presentation/screens/changelog_screen.dart';
import 'package:fwapp/features/settings/presentation/screens/gesamtwehr_screen.dart';
import 'package:fwapp/features/settings/presentation/screens/user_management_screen.dart';

/// Routen, die Bearbeitungsrechte voraussetzen (Spiegel der UI-Gates:
/// `canEditProvider` blendet genau diese Einstiege aus).
final _editRoutePattern = RegExp(r'^(/vehicles/(new(/template)?|[^/]+/(edit|compartments))'
    r'|/equipment/(new|[^/]+/edit)'
    r'|/import'
    r'|/inspections'
    r'|/inventory(/.*)?)$');

/// Ohne Anmeldung erreichbar: die Anmeldung selbst und der Notausgang, über
/// den man Server-URL und Schlüssel korrigiert. Ohne diese Hintertür säße
/// jemand mit falscher Serveradresse in einer App fest, in die er sich nicht
/// anmelden kann und deren Adresse er nicht mehr ändern darf.
const _publicPaths = {'/login', '/server-settings'};

/// Seiten, die es nur mit Serververbindung gibt.
const _authPaths = {'/login', '/change-password'};

/// Pure Guard-Logik, getrennt vom Router für direkte Testbarkeit.
/// Liefert das Redirect-Ziel oder null (= Navigation erlaubt).
String? guardRedirect({
  required String path,
  required bool canEdit,
  required bool isAdmin,
  required bool supabaseReady,
  required bool loggedIn,
  required bool mustChangePassword,
}) {
  // Anmeldezwang VOR den Rollen-Guards: Ohne Sitzung ist canEdit false,
  // /import liefe sonst erst auf '/' und von dort auf '/login' — zwei
  // Sprünge, bei denen die eigentliche Aussage („melde dich an") verloren
  // geht.
  if (supabaseReady) {
    if (!loggedIn) {
      return _publicPaths.contains(path) ? null : '/login';
    }
    // Initialpasswort vom Zugangszettel: nicht umgehbar. Als Route statt
    // als Dialog, weil ein Dialog nach dem Login auf einem schon
    // abgebauten Kontext landen würde — der Redirect räumt den
    // Login-Screen im selben Moment ab.
    if (mustChangePassword) {
      return path == '/change-password' ? null : '/change-password';
    }
    if (_authPaths.contains(path)) return '/';
  } else if (_authPaths.contains(path)) {
    // Lokalmodus: Es gibt kein Konto, in das man sich setzen könnte. Die
    // App bleibt ohne Server voll benutzbar; /server-settings führt zurück.
    return '/';
  }

  if (_editRoutePattern.hasMatch(path) && !canEdit) return '/';
  // Nutzerverwaltung braucht wie die Mehr-Kachel Admin UND Serververbindung.
  if (path == '/user-management' && !(isAdmin && supabaseReady)) return '/';
  // Abteilung & Gesamtwehr (#57 Phase 3): Server UND Schreibrecht. Bewusst
  // canEdit statt isAdmin — den Anschluss beantragt auch der Gerätewart, nur
  // entscheiden darf er nicht (das prüft der Server).
  if (path == '/gesamtwehr' && !(canEdit && supabaseReady)) return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Die Rolle lädt nach dem Login asynchron nach; der Router muss anstehende
  // Redirects neu bewerten, sobald sich canEdit/isAdmin ändern.
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(canEditProvider, (_, _) => refresh.value++);
  ref.listen(isAdminProvider, (_, _) => refresh.value++);
  // Der Pflichtwechsel kommt ebenfalls asynchron vom Server; ohne diesen
  // Anstoß bliebe jemand mit Initialpasswort auf der Startseite stehen.
  ref.listen(mustChangePasswordProvider, (_, _) => refresh.value++);

  // An-/Abmelden stößt den Redirect an. Bewusst der rohe gotrue-Strom und
  // nicht sessionStreamProvider: Der filtert per distinct auf die Nutzer-ID
  // und startet als AsyncLoading — beides ist für einen Guard falsch.
  final sub = ref.read(supabaseClientProvider)?.auth.onAuthStateChange.listen(
    (_) => refresh.value++,
    // Pflicht, kein Beiwerk: gotrue meldet einen fehlgeschlagenen
    // Token-Refresh (offline!) als Stream-FEHLER. Ohne Handler wird daraus
    // eine unbehandelte Ausnahme, und PlatformDispatcher.onError in
    // main.dart schriebe bei jedem Start ohne Netz einen Absturzbericht.
    onError: (Object e, StackTrace s) => appLog.w(
        'Auth-Ereignisstrom meldet einen Fehler (offline?)',
        error: e,
        stackTrace: s),
  );
  ref.onDispose(() => unawaited(sub?.cancel()));

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => guardRedirect(
      path: state.uri.path,
      canEdit: ref.read(canEditProvider),
      isAdmin: ref.read(isAdminProvider),
      supabaseReady: ref.read(supabaseReadyProvider),
      loggedIn: ref.read(signedInReaderProvider)(),
      // Beim allerersten Redirect steht der Wert noch nicht fest (der
      // Provider lädt); dann gilt „kein Zwang" und der ref.listen oben
      // holt es nach. Sichtbare Folge: ein Sekundenbruchteil Startseite,
      // bevor der Wechsel greift — hingenommen, weil die Alternative ein
      // Ladezustand im Router wäre, der jeden Kaltstart verzögert.
      mustChangePassword: ref.read(mustChangePasswordProvider).value ?? false,
    ),
    routes: _routes,
  );
});

final _routes = [
    // Bewusst AUSSERHALB der ShellRoute: Das sind Vollbild-Übernahmen ohne
    // Navigationsleiste — und außerhalb der Shell gibt es den
    // verschachtelten Navigator gar nicht, an dem v1.6.0 im Feld
    // gescheitert ist (Dialog poppte den Screen dahinter weg, #79).
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/change-password',
      builder: (_, _) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/server-settings',
      builder: (_, _) => const ServerSettingsScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          _AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeScreen(),
        ),
        GoRoute(
          path: '/vehicles',
          builder: (_, _) => const VehicleListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const VehicleFormScreen(),
              routes: [
                GoRoute(
                  path: 'template',
                  builder: (_, _) => const VehicleTemplateScreen(),
                ),
              ],
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => VehicleDetailScreen(
                  vehicleId: int.parse(state.pathParameters['id']!)),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => VehicleFormScreen(
                      editId:
                          int.parse(state.pathParameters['id']!)),
                ),
                GoRoute(
                  path: 'compartments',
                  builder: (_, state) => CompartmentManagerScreen(
                      vehicleId:
                          int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/equipment',
          builder: (_, _) => const EquipmentListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, _) => const EquipmentFormScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => EquipmentDetailScreen(
                  equipmentId:
                      int.parse(state.pathParameters['id']!)),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => EquipmentFormScreen(
                      editId:
                          int.parse(state.pathParameters['id']!)),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/game',
          builder: (_, _) => const GameMenuScreen(),
          routes: [
            GoRoute(
              path: 'compartment-quiz',
              builder: (_, _) => const CompartmentQuizScreen(),
            ),
            GoRoute(
              path: 'cutaway-quiz',
              builder: (_, _) => const CutawayQuizScreen(),
            ),
            GoRoute(
              path: 'flashcards',
              builder: (_, _) => const FlashcardScreen(),
            ),
            GoRoute(
              path: 'drag-drop',
              builder: (_, _) => const DragDropScreen(),
            ),
            GoRoute(
              path: 'image-quiz',
              builder: (_, _) => const ImageRecognitionQuizScreen(),
            ),
            GoRoute(
              path: 'deployment',
              builder: (_, _) => const DeploymentModeScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/inspections',
          builder: (_, _) => const InspectionDashboardScreen(),
        ),
        GoRoute(
          path: '/user-management',
          builder: (_, _) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/gesamtwehr',
          builder: (_, _) => const GesamtwehrScreen(),
        ),
        GoRoute(
          path: '/operation',
          builder: (_, _) => const OperationSetupScreen(),
          routes: [
            GoRoute(
              path: 'run',
              builder: (_, _) => const OperationRunScreen(),
            ),
            GoRoute(
              path: 'summary',
              builder: (_, _) => const OperationSummaryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/inventory',
          builder: (_, _) => const InventorySetupScreen(),
          routes: [
            GoRoute(
              path: 'run/:id',
              builder: (_, state) => InventoryRunScreen(
                  sessionId: int.parse(state.pathParameters['id']!)),
            ),
            GoRoute(
              path: 'report/:id',
              builder: (_, state) => InventoryReportScreen(
                  sessionId: int.parse(state.pathParameters['id']!)),
            ),
          ],
        ),
        GoRoute(
          path: '/import',
          builder: (_, _) => const ImportWizardScreen(),
        ),
        GoRoute(
          path: '/more',
          builder: (_, _) => const MoreScreen(),
        ),
        GoRoute(
          path: '/image-library',
          builder: (_, _) => const ImageLibraryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/changelog',
          builder: (_, _) => const ChangelogScreen(),
        ),
      ],
    ),
];

class _AppShell extends StatelessWidget {
  final String location;
  final Widget child;
  const _AppShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentNavIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: currentIndex >= 0
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/');
                  case 1:
                    context.go('/game');
                  case 2:
                    context.go('/vehicles');
                  case 3:
                    context.go('/more');
                }
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Start'),
                NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school),
                    label: 'Lernen'),
                NavigationDestination(
                    icon: Icon(Icons.fire_truck_outlined),
                    selectedIcon: Icon(Icons.fire_truck),
                    label: 'Fahrzeuge'),
                NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    label: 'Mehr'),
              ],
            )
          : null,
    );
  }

  int _currentNavIndex(String path) {
    if (path == '/') return 0;
    if (path.startsWith('/game')) return 1;
    if (path.startsWith('/vehicles')) return 2;
    if (path.startsWith('/more') ||
        path.startsWith('/equipment') ||
        path.startsWith('/inspections')) {
      return 3;
    }
    return -1; // import, settings – no nav bar
  }
}
