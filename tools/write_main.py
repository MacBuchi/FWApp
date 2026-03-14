import pathlib

main_dart = r"""/// main.dart – App entry point. Initialises Riverpod, seeds the library, and launches the router.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/theme/app_theme.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FWApp(),
    ),
  );
}

class FWApp extends ConsumerStatefulWidget {
  const FWApp({super.key});

  @override
  ConsumerState<FWApp> createState() => _FWAppState();
}

class _FWAppState extends ConsumerState<FWApp> {
  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    final db = ref.read(appDatabaseProvider);
    await LibrarySeeder(db).seedIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final darkModeAsync = ref.watch(themeModeNotifierProvider);
    final isDark = darkModeAsync.valueOrNull ?? false;

    return MaterialApp.router(
      title: 'Feuerwehr-Lernapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', 'DE'),
        Locale('en', 'US'),
      ],
      locale: const Locale('de', 'DE'),
    );
  }
}
"""

pathlib.Path('/Volumes/MacStore/Programming/Flutter/FWApp/lib/main.dart').write_text(main_dart)
print('main.dart written')
