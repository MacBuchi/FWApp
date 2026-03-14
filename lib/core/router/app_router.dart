/// app_router.dart – GoRouter configuration for all app routes.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fwapp/features/home/presentation/screens/home_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_list_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_detail_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/vehicle_form_screen.dart';
import 'package:fwapp/features/vehicle/presentation/screens/compartment_manager_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_list_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_detail_screen.dart';
import 'package:fwapp/features/equipment/presentation/screens/equipment_form_screen.dart';
import 'package:fwapp/features/game/presentation/screens/game_menu_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/compartment_quiz_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/drag_drop_screen.dart';
import 'package:fwapp/features/game/quiz/presentation/screens/image_quiz_screen.dart';
import 'package:fwapp/features/game/deployment/presentation/screens/deployment_mode_screen.dart';
import 'package:fwapp/features/import/presentation/screens/import_screen.dart';
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
          path: '/import',
          builder: (_, __) => const ImportScreen(),
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
                    context.go('/vehicles');
                  case 2:
                    context.go('/equipment');
                  case 3:
                    context.go('/game');
                }
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home), label: 'Start'),
                NavigationDestination(
                    icon: Icon(Icons.fire_truck), label: 'Fahrzeuge'),
                NavigationDestination(
                    icon: Icon(Icons.inventory_2), label: 'Geräte'),
                NavigationDestination(
                    icon: Icon(Icons.sports_esports), label: 'Training'),
              ],
            )
          : null,
    );
  }

  int _currentNavIndex(String path) {
    if (path == '/') return 0;
    if (path.startsWith('/vehicles')) return 1;
    if (path.startsWith('/equipment')) return 2;
    if (path.startsWith('/game')) return 3;
    return -1; // import, settings – no nav bar
  }
}
