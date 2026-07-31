/// app_router.dart – GoRouter configuration for all app routes.
///
/// Edit-/Admin-Routen sind zusätzlich zur ausgeblendeten UI per [guardRedirect]
/// geschützt, damit auch Deep-Links (Web!) die Rollenregeln respektieren.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/home/presentation/screens/home_screen.dart';
import 'package:fwapp/features/home/presentation/screens/more_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_list_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_detail_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_form_screen.dart';
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
import 'package:fwapp/features/settings/presentation/screens/user_management_screen.dart';

/// Routen, die Bearbeitungsrechte voraussetzen (Spiegel der UI-Gates:
/// `canEditProvider` blendet genau diese Einstiege aus).
final _editRoutePattern = RegExp(r'^(/vehicles/(new|[^/]+/(edit|compartments))'
    r'|/equipment/(new|[^/]+/edit)'
    r'|/import'
    r'|/inspections'
    r'|/inventory(/.*)?)$');

/// Pure Guard-Logik, getrennt vom Router für direkte Testbarkeit.
/// Liefert das Redirect-Ziel oder null (= Navigation erlaubt).
String? guardRedirect({
  required String path,
  required bool canEdit,
  required bool isAdmin,
  required bool supabaseReady,
}) {
  if (_editRoutePattern.hasMatch(path) && !canEdit) return '/';
  // Nutzerverwaltung braucht wie die Mehr-Kachel Admin UND Serververbindung.
  if (path == '/user-management' && !(isAdmin && supabaseReady)) return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Die Rolle lädt nach dem Login asynchron nach; der Router muss anstehende
  // Redirects neu bewerten, sobald sich canEdit/isAdmin ändern.
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(canEditProvider, (_, _) => refresh.value++);
  ref.listen(isAdminProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => guardRedirect(
      path: state.uri.path,
      canEdit: ref.read(canEditProvider),
      isAdmin: ref.read(isAdminProvider),
      supabaseReady: ref.read(supabaseReadyProvider),
    ),
    routes: _routes,
  );
});

final _routes = [
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
