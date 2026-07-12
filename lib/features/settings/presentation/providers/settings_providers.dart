/// settings_providers.dart – Riverpod providers for app settings (theme, sync).
library;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_providers.g.dart';

const _kDarkMode = 'dark_mode';
const _kSyncEnabled = 'sync_enabled';
const _kSupabaseUrl = 'supabase_url';
const _kSupabaseKey = 'supabase_key';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) =>
    SharedPreferences.getInstance();

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(_kDarkMode) ?? false;
  }

  Future<void> toggle() async {
    final current = state.value ?? false;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kDarkMode, !current);
    state = AsyncValue.data(!current);
  }
}

@riverpod
class SyncSettingsNotifier extends _$SyncSettingsNotifier {
  @override
  Future<SyncSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return SyncSettings(
      enabled: prefs.getBool(_kSyncEnabled) ?? false,
      supabaseUrl: prefs.getString(_kSupabaseUrl) ?? '',
      supabaseKey: prefs.getString(_kSupabaseKey) ?? '',
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
