// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geraete_suche_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Jedes Gerät einmal, mit allen Stellen, an denen es im Fuhrpark liegt.
///
/// Geräte **ohne** Fundort sind bewusst mit dabei: Die Suche soll „steht im
/// Katalog, ist aber nirgends verlastet" sagen können statt „nichts
/// gefunden". Bei einer Wehr, die ihre Beladung gerade erst erfasst, ist das
/// der häufigste Fall — und die nützlichste Auskunft.

@ProviderFor(durchsuchbarerBestand)
final durchsuchbarerBestandProvider = DurchsuchbarerBestandProvider._();

/// Jedes Gerät einmal, mit allen Stellen, an denen es im Fuhrpark liegt.
///
/// Geräte **ohne** Fundort sind bewusst mit dabei: Die Suche soll „steht im
/// Katalog, ist aber nirgends verlastet" sagen können statt „nichts
/// gefunden". Bei einer Wehr, die ihre Beladung gerade erst erfasst, ist das
/// der häufigste Fall — und die nützlichste Auskunft.

final class DurchsuchbarerBestandProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GeraetTreffer>>,
          List<GeraetTreffer>,
          FutureOr<List<GeraetTreffer>>
        >
    with
        $FutureModifier<List<GeraetTreffer>>,
        $FutureProvider<List<GeraetTreffer>> {
  /// Jedes Gerät einmal, mit allen Stellen, an denen es im Fuhrpark liegt.
  ///
  /// Geräte **ohne** Fundort sind bewusst mit dabei: Die Suche soll „steht im
  /// Katalog, ist aber nirgends verlastet" sagen können statt „nichts
  /// gefunden". Bei einer Wehr, die ihre Beladung gerade erst erfasst, ist das
  /// der häufigste Fall — und die nützlichste Auskunft.
  DurchsuchbarerBestandProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'durchsuchbarerBestandProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$durchsuchbarerBestandHash();

  @$internal
  @override
  $FutureProviderElement<List<GeraetTreffer>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GeraetTreffer>> create(Ref ref) {
    return durchsuchbarerBestand(ref);
  }
}

String _$durchsuchbarerBestandHash() =>
    r'bcd37f0e00838c0f155ce167d7d670bf1b37f998';
