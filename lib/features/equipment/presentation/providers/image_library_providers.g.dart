// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
