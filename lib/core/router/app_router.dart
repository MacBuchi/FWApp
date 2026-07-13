/// app_router.dart – GoRouter configuration for all app routes.
library;
import 'package:flutter/material.dart';
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

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/vehicles',
          builder: (_, __) => const VehicleListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, __) => const VehicleFormScreen(),
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
          builder: (_, __) => const EquipmentListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (_, __) => const EquipmentFormScreen(),
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
          builder: (_, __) => const GameMenuScreen(),
          routes: [
            GoRoute(
              path: 'compartment-quiz',
              builder: (_, __) => const CompartmentQuizScreen(),
            ),
            GoRoute(
              path: 'cutaway-quiz',
              builder: (_, __) => const CutawayQuizScreen(),
            ),
            GoRoute(
              path: 'flashcards',
              builder: (_, __) => const FlashcardScreen(),
            ),
            GoRoute(
              path: 'drag-drop',
              builder: (_, __) => const DragDropScreen(),
            ),
            GoRoute(
              path: 'image-quiz',
              builder: (_, __) => const ImageRecognitionQuizScreen(),
            ),
            GoRoute(
              path: 'deployment',
              builder: (_, __) => const DeploymentModeScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/inspections',
          builder: (_, __) => const InspectionDashboardScreen(),
        ),
        GoRoute(
          path: '/operation',
          builder: (_, __) => const OperationSetupScreen(),
          routes: [
            GoRoute(
              path: 'run',
              builder: (_, __) => const OperationRunScreen(),
            ),
            GoRoute(
              path: 'summary',
              builder: (_, __) => const OperationSummaryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/inventory',
          builder: (_, __) => const InventorySetupScreen(),
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
          builder: (_, __) => const ImportWizardScreen(),
        ),
        GoRoute(
          path: '/more',
          builder: (_, __) => const MoreScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

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
