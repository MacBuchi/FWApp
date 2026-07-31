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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Farbthema (Issue #58). Die gewählte ID wird gespeichert, nicht die Farbe —
/// so wandert eine später nachgebesserte Palette automatisch mit. Nur beim
/// eigenen Thema liegt der ARGB-Wert selbst in den Preferences, weil er sonst
/// nirgends steht.

@ProviderFor(AppPaletteNotifier)
final appPaletteProvider = AppPaletteNotifierProvider._();

/// Farbthema (Issue #58). Die gewählte ID wird gespeichert, nicht die Farbe —
/// so wandert eine später nachgebesserte Palette automatisch mit. Nur beim
/// eigenen Thema liegt der ARGB-Wert selbst in den Preferences, weil er sonst
/// nirgends steht.
final class AppPaletteNotifierProvider
    extends $AsyncNotifierProvider<AppPaletteNotifier, AppPalette> {
  /// Farbthema (Issue #58). Die gewählte ID wird gespeichert, nicht die Farbe —
  /// so wandert eine später nachgebesserte Palette automatisch mit. Nur beim
  /// eigenen Thema liegt der ARGB-Wert selbst in den Preferences, weil er sonst
  /// nirgends steht.
  AppPaletteNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appPaletteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appPaletteNotifierHash();

  @$internal
  @override
  AppPaletteNotifier create() => AppPaletteNotifier();
}

String _$appPaletteNotifierHash() =>
    r'e89efa116d2fe0c9f9fdf0a166a26c465e9565e7';

/// Farbthema (Issue #58). Die gewählte ID wird gespeichert, nicht die Farbe —
/// so wandert eine später nachgebesserte Palette automatisch mit. Nur beim
/// eigenen Thema liegt der ARGB-Wert selbst in den Preferences, weil er sonst
/// nirgends steht.

abstract class _$AppPaletteNotifier extends $AsyncNotifier<AppPalette> {
  FutureOr<AppPalette> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppPalette>, AppPalette>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppPalette>, AppPalette>,
              AsyncValue<AppPalette>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
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
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SyncSettings>, SyncSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SyncSettings>, SyncSettings>,
              AsyncValue<SyncSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
