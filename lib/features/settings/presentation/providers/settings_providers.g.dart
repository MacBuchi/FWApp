// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SharedPreferences>,
          SharedPreferences,
          FutureOr<SharedPreferences>
        >
    with
        $FutureModifier<SharedPreferences>,
        $FutureProvider<SharedPreferences> {
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SharedPreferences> create(Ref ref) {
    return sharedPreferences(ref);
  }
}

String _$sharedPreferencesHash() => r'ad13470fe866595ad0f58a3e26f11048d94ef22e';

/// Design-Modus: Standard folgt der Systemeinstellung; der Nutzer kann
/// explizit Hell oder Dunkel erzwingen.

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// Design-Modus: Standard folgt der Systemeinstellung; der Nutzer kann
/// explizit Hell oder Dunkel erzwingen.
final class ThemeModeNotifierProvider
    extends $AsyncNotifierProvider<ThemeModeNotifier, ThemeMode> {
  /// Design-Modus: Standard folgt der Systemeinstellung; der Nutzer kann
  /// explizit Hell oder Dunkel erzwingen.
  ThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();
}

String _$themeModeNotifierHash() => r'858a5cc9795f1395a8ff8fbe92bdbadcbe2880b5';

/// Design-Modus: Standard folgt der Systemeinstellung; der Nutzer kann
/// explizit Hell oder Dunkel erzwingen.

abstract class _$ThemeModeNotifier extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(SyncSettingsNotifier)
final syncSettingsProvider = SyncSettingsNotifierProvider._();

final class SyncSettingsNotifierProvider
    extends $AsyncNotifierProvider<SyncSettingsNotifier, SyncSettings> {
  SyncSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncSettingsNotifierHash();

  @$internal
  @override
  SyncSettingsNotifier create() => SyncSettingsNotifier();
}

String _$syncSettingsNotifierHash() =>
    r'0a183b0dd9fd0f770b167586e5dfc0af5eacdd64';

abstract class _$SyncSettingsNotifier extends $AsyncNotifier<SyncSettings> {
  FutureOr<SyncSettings> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SyncSettings>, SyncSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SyncSettings>, SyncSettings>,
              AsyncValue<SyncSettings>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
