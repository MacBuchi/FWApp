// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Der mitgelieferte Gerätekatalog als Provider.
///
/// Das Formular lud ihn bis Issue #102 roh im `initState`. Als Provider ist
/// er einmal geladen statt pro Formular, und — der eigentliche Grund — im
/// Prüfstand ersetzbar: `rootBundle` liefert in Widget-Tests nie (fake
/// async, AGENTS.md § Stolperfallen), ein Test kann den Katalog aber
/// außerhalb der simulierten Zeit laden und hier hineinreichen.

@ProviderFor(standardCatalog)
final standardCatalogProvider = StandardCatalogProvider._();

/// Der mitgelieferte Gerätekatalog als Provider.
///
/// Das Formular lud ihn bis Issue #102 roh im `initState`. Als Provider ist
/// er einmal geladen statt pro Formular, und — der eigentliche Grund — im
/// Prüfstand ersetzbar: `rootBundle` liefert in Widget-Tests nie (fake
/// async, AGENTS.md § Stolperfallen), ein Test kann den Katalog aber
/// außerhalb der simulierten Zeit laden und hier hineinreichen.

final class StandardCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<StandardCatalog>,
          StandardCatalog,
          FutureOr<StandardCatalog>
        >
    with $FutureModifier<StandardCatalog>, $FutureProvider<StandardCatalog> {
  /// Der mitgelieferte Gerätekatalog als Provider.
  ///
  /// Das Formular lud ihn bis Issue #102 roh im `initState`. Als Provider ist
  /// er einmal geladen statt pro Formular, und — der eigentliche Grund — im
  /// Prüfstand ersetzbar: `rootBundle` liefert in Widget-Tests nie (fake
  /// async, AGENTS.md § Stolperfallen), ein Test kann den Katalog aber
  /// außerhalb der simulierten Zeit laden und hier hineinreichen.
  StandardCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'standardCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$standardCatalogHash();

  @$internal
  @override
  $FutureProviderElement<StandardCatalog> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StandardCatalog> create(Ref ref) {
    return standardCatalog(ref);
  }
}

String _$standardCatalogHash() => r'9f8bd7f4e56ffbd0a05d7d9a215619c95f836758';

/// Lädt die Bibliothek einmalig aus Katalog + aliases.json.

@ProviderFor(imageLibrary)
final imageLibraryProvider = ImageLibraryProvider._();

/// Lädt die Bibliothek einmalig aus Katalog + aliases.json.

final class ImageLibraryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ImageLibraryEntry>>,
          List<ImageLibraryEntry>,
          FutureOr<List<ImageLibraryEntry>>
        >
    with
        $FutureModifier<List<ImageLibraryEntry>>,
        $FutureProvider<List<ImageLibraryEntry>> {
  /// Lädt die Bibliothek einmalig aus Katalog + aliases.json.
  ImageLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageLibraryHash();

  @$internal
  @override
  $FutureProviderElement<List<ImageLibraryEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ImageLibraryEntry>> create(Ref ref) {
    return imageLibrary(ref);
  }
}

String _$imageLibraryHash() => r'923c420b23cbd1aa5280f03356e57e0c9556863e';
