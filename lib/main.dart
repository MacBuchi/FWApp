/// main.dart – App entry point. Initialises Riverpod and Supabase (when
/// configured), seeds the library, pulls the central dataset, and launches
/// the router.
library;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/theme/app_theme.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase must be initialised before runApp; config lives in the same
  // SharedPreferences the settings screen writes (restart applies changes).
  var supabaseReady = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('sync_enabled') ?? false;
    final url = prefs.getString('supabase_url') ?? '';
    final key = prefs.getString('supabase_key') ?? '';
    if (enabled && url.isNotEmpty && key.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: key);
      supabaseReady = true;
    }
  } catch (_) {
    // Offline or misconfigured – app stays fully usable in local mode.
  }

  runApp(
    ProviderScope(
      overrides: [supabaseReadyProvider.overrideWithValue(supabaseReady)],
      child: const FWApp(),
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
    _seedAndSync();
  }

  Future<void> _seedAndSync() async {
    final db = ref.read(appDatabaseProvider);
    await LibrarySeeder(db).seedIfNeeded();
    // Pull the central dataset on start when connected and signed in.
    final sync = ref.read(syncServiceProvider);
    final session = ref.read(supabaseClientProvider)?.auth.currentSession;
    if (sync != null && session != null) {
      try {
        await sync.pullIfNewer();
      } catch (_) {
        // Offline – last pulled snapshot stays in place.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkModeAsync = ref.watch(themeModeProvider);
    final isDark = darkModeAsync.value ?? false;

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
