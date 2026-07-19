/// main.dart – App entry point. Initialises Riverpod and Supabase (when
/// configured), seeds the library, pulls the central dataset, and launches
/// the router.
library;
import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/sync/image_precache.dart';
import 'package:fwapp/core/theme/app_theme.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Central error reporting: uncaught framework and async errors end up in
  // one place instead of dying silently in release builds.
  FlutterError.onError = (details) {
    _log.e('Flutter framework error',
        error: details.exception, stackTrace: details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.e('Uncaught async error', error: error, stackTrace: stack);
    return true;
  };

  // Supabase must be initialised before runApp; config lives in the same
  // SharedPreferences the settings screen writes (restart applies changes).
  var supabaseReady = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('sync_enabled') ?? false;
    // Same default fallback as SyncSettingsNotifier: unset/empty prefs mean
    // the preconfigured self-hosted server.
    var url = prefs.getString('supabase_url') ?? '';
    var key = prefs.getString('supabase_key') ?? '';
    if (url.isEmpty) url = kDefaultSupabaseUrl;
    if (key.isEmpty) key = kDefaultSupabaseAnonKey;
    if (enabled && url.isNotEmpty && key.isNotEmpty) {
      await Supabase.initialize(url: url, anonKey: key);
      supabaseReady = true;
      // Lets resolveImage() and the precache fetch from the private bucket.
      supabaseStorageBaseUrl = url.endsWith('/')
          ? url.substring(0, url.length - 1)
          : url;
      supabaseStorageHeaders = () {
        final token =
            Supabase.instance.client.auth.currentSession?.accessToken;
        return {
          'apikey': key,
          if (token != null) 'Authorization': 'Bearer $token',
        };
      };
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
        // Warm the offline image cache in the background (M2).
        unawaited(ref.read(imagePrecacheProvider.notifier).run());
      } catch (_) {
        // Offline – last pulled snapshot stays in place.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeModeAsync = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Feuerwehr-Lernapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Standard: Systemeinstellung; in den Settings überschreibbar.
      themeMode: themeModeAsync.value ?? ThemeMode.system,
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
