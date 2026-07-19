/// settings_providers.dart – Riverpod providers for app settings (theme, sync).
library;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_providers.g.dart';

const _kThemeMode = 'theme_mode'; // 'system' | 'light' | 'dark'
const _kDarkMode = 'dark_mode'; // Alt-Schalter bis v1.4.0 (nur Migration)
const _kSyncEnabled = 'sync_enabled';
const _kSupabaseUrl = 'supabase_url';
const _kSupabaseKey = 'supabase_key';

/// Vorbelegung des eigenen Servers kommt zur Build-Zeit über
/// --dart-define-from-file=config/fwapp.local.json (gitignored; Vorlage:
/// config/fwapp.local.json.example) — instanzspezifische Werte gehören
/// nicht ins öffentliche Repo. Ohne Build-Flags bleibt alles leer und wird
/// in den Settings von Hand eingetragen.
const kDefaultSupabaseUrl =
    String.fromEnvironment('FWAPP_SUPABASE_URL', defaultValue: '');

/// Anon-Key ist clientseitig-öffentlich (steckt in jedem verteilten Build);
/// Datenzugriff schützt RLS.
const kDefaultSupabaseAnonKey =
    String.fromEnvironment('FWAPP_SUPABASE_ANON_KEY', defaultValue: '');

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

/// Design-Modus: Standard folgt der Systemeinstellung; der Nutzer kann
/// explizit Hell oder Dunkel erzwingen.
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  Future<ThemeMode> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final stored = prefs.getString(_kThemeMode);
    if (stored != null) {
      return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
    }
    // Migration vom alten Bool-Schalter: wer Dunkel aktiv hatte, behält
    // Dunkel — alle anderen bekommen den neuen Standard "System".
    if (prefs.getBool(_kDarkMode) == true) {
      await prefs.setString(_kThemeMode, ThemeMode.dark.name);
      return ThemeMode.dark;
    }
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_kThemeMode, mode.name);
    state = AsyncValue.data(mode);
  }
}

@riverpod
class SyncSettingsNotifier extends _$SyncSettingsNotifier {
  @override
  Future<SyncSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final url = prefs.getString(_kSupabaseUrl);
    final key = prefs.getString(_kSupabaseKey);
    return SyncSettings(
      enabled: prefs.getBool(_kSyncEnabled) ?? false,
      supabaseUrl: (url == null || url.isEmpty) ? kDefaultSupabaseUrl : url,
      supabaseKey: (key == null || key.isEmpty) ? kDefaultSupabaseAnonKey : key,
    );
  }

  Future<void> save(SyncSettings s) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kSyncEnabled, s.enabled);
    await prefs.setString(_kSupabaseUrl, s.supabaseUrl);
    await prefs.setString(_kSupabaseKey, s.supabaseKey);
    state = AsyncValue.data(s);
  }
}

class SyncSettings {
  final bool enabled;
  final String supabaseUrl;
  final String supabaseKey;

  const SyncSettings({
    required this.enabled,
    required this.supabaseUrl,
    required this.supabaseKey,
  });
}
