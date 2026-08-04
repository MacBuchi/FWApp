/// main.dart – App entry point. Initialises Riverpod and Supabase (when
/// configured), seeds the library, pulls the central dataset, and launches
/// the router.
library;
import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/app_version.dart';
import 'package:fwapp/core/crash/crash_store.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/database/library_seeder.dart';
import 'package:fwapp/core/router/app_router.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/core/sync/image_precache.dart';
import 'package:fwapp/core/theme/app_palette.dart';
import 'package:fwapp/core/theme/app_theme.dart';
import 'package:fwapp/core/utils/image_utils.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/settings/presentation/providers/settings_providers.dart';
import 'package:fwapp/features/splash/presentation/splash_gate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Absturzberichte auf dem Gerät festhalten (Issue #34). Muss vor den
  // Handlern stehen, damit ein Fehler in der Startsequenz schon mitgenommen
  // wird. Schlägt das fehl, laufen die Handler wie bisher rein über appLog.
  try {
    final info = await PackageInfo.fromPlatform();
    // Ohne Build-Nummer: Das Mindestversions-Gate vergleicht reines
    // MAJOR.MINOR.PATCH (Issue #35).
    currentAppVersion = info.version;
    await initCrashStore(
      context: CrashContext(
        appVersion: '${info.version} (Build ${info.buildNumber})',
        device: describeDevice(),
        // Kein Nutzername, keine Region über die Locale hinaus — siehe die
        // PII-Regeln im Kopf von crash_report.dart.
        locale: PlatformDispatcher.instance.locale.toString(),
      ),
    );
  } catch (e, s) {
    appLog.w('Absturzspeicher nicht verfügbar', error: e, stackTrace: s);
  }

  // Central error reporting: uncaught framework and async errors end up in
  // one place instead of dying silently in release builds.
  FlutterError.onError = (details) {
    // Erst sichern, dann loggen: Ein synchroner Schreibvorgang übersteht auch
    // einen sofortigen Prozesstod, alles danach womöglich nicht mehr.
    recordCrash(
      source: 'Flutter framework',
      error: details.exception,
      stackTrace: details.stack,
    );
    appLog.e('Flutter framework error',
        error: details.exception, stackTrace: details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    recordCrash(source: 'Async', error: error, stackTrace: stack);
    appLog.e('Uncaught async error', error: error, stackTrace: stack);
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
      // Self-hosted stack still issues legacy anon keys; publishableKey
      // (sb_publishable_...) requires the new API-key scheme server-side.
      // ignore: deprecated_member_use
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
  } catch (e, s) {
    // Offline or misconfigured – app stays fully usable in local mode.
    appLog.w('Supabase-Init fehlgeschlagen – App startet im Lokalmodus',
        error: e, stackTrace: s);
  }

  // Gemerkte Abteilungswahl (Issue #57 Phase 2) — muss VOR dem ersten
  // Datenbankzugriff feststehen, weil sie die Datei bestimmt. Nur relevant,
  // wenn der Sync aktiv ist; im Lokalmodus gilt immer die eigene Datei.
  String? selectedAbteilung;
  if (supabaseReady) {
    final prefs = await SharedPreferences.getInstance();
    selectedAbteilung = prefs.getString(kSelectedAbteilungPref);
  }

  // Startanimation (Issue #129): die volle Fassung läuft nach Installation
  // und nach jedem Update, sonst die Kurzform. Der Merker wird SOFORT
  // geschrieben, nicht erst nach dem Abspielen — sonst bekäme jemand, dessen
  // App währenddessen abstürzt, die lange Fassung bei jedem Start wieder.
  var vollerSplash = false;
  try {
    // Ohne bekannte Version (PackageInfo oben fehlgeschlagen) bleibt es bei
    // der Kurzform — raten hieße hier, die lange Fassung bei jedem Start zu
    // zeigen.
    final version = currentAppVersion;
    final prefs = await SharedPreferences.getInstance();
    vollerSplash =
        version != null && prefs.getString(kSplashVersionPref) != version;
    if (vollerSplash) {
      await prefs.setString(kSplashVersionPref, version);
    }
  } catch (e) {
    // Eine Verzierung darf den Start nicht kosten: im Zweifel die Kurzform.
    appLog.i('Splash-Merker nicht lesbar', error: e);
  }

  runApp(
    ProviderScope(
      overrides: [
        supabaseReadyProvider.overrideWithValue(supabaseReady),
        selectedAbteilungIdProvider
            .overrideWith((ref) => selectedAbteilung),
      ],
      child: FWApp(vollerSplash: vollerSplash),
    ),
  );
}

class FWApp extends ConsumerStatefulWidget {
  const FWApp({super.key, this.vollerSplash = false});

  /// Startanimation in voller Länge zeigen (Issue #129).
  final bool vollerSplash;

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
    // Nach jedem await prüfen: Wird die App während des Seedens beendet,
    // läuft diese Methode weiter, während das Widget schon abgebaut ist —
    // `ref` wirft dann "Using ref when a widget is about to or has been
    // unmounted is unsafe".
    if (!mounted) return;
    // Pull the central dataset on start when connected and signed in.
    final sync = ref.read(syncServiceProvider);
    final session = ref.read(supabaseClientProvider)?.auth.currentSession;
    if (sync != null && session != null) {
      try {
        await sync.pullIfNewer();
        if (!mounted) return;
        // Gerätetypen der Gesamtwehr (Stufe ②, Issue #99) — eigener,
        // zeilenweiser Weg neben dem Snapshot. Ohne Gesamtwehr ein No-op.
        await ref.read(equipmentTypeSyncProvider)?.sync();
        if (!mounted) return;
        // Warm the offline image cache in the background (M2).
        unawaited(ref.read(imagePrecacheProvider.notifier).run());
      } catch (e) {
        // Offline – last pulled snapshot stays in place.
        appLog.w('Start-Pull fehlgeschlagen (Server nicht erreichbar?)',
            error: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeModeAsync = ref.watch(themeModeProvider);
    // Palette erst nach dem Laden der Preferences bekannt; bis dahin die
    // Standardfarbe, damit der erste Frame nicht farblos aufblitzt.
    final palette = ref.watch(appPaletteProvider).value ?? kAppPalettes.first;

    return MaterialApp.router(
      title: 'Feuerwehr-Lernapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      // Standard: Systemeinstellung; in den Settings überschreibbar.
      themeMode: themeModeAsync.value ?? ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      // Die Animation liegt ÜBER der App, nicht davor: Der Router baut
      // darunter schon auf, es geht keine Startzeit verloren.
      builder: (context, child) => SplashGate(
        voll: widget.vollerSplash,
        child: child ?? const SizedBox.shrink(),
      ),
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
