// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kopplung_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(kopplungsDienste)
final kopplungsDiensteProvider = KopplungsDiensteProvider._();

final class KopplungsDiensteProvider
    extends
        $FunctionalProvider<
          KopplungsDienste,
          KopplungsDienste,
          KopplungsDienste
        >
    with $Provider<KopplungsDienste> {
  KopplungsDiensteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kopplungsDiensteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kopplungsDiensteHash();

  @$internal
  @override
  $ProviderElement<KopplungsDienste> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KopplungsDienste create(Ref ref) {
    return kopplungsDienste(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KopplungsDienste value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KopplungsDienste>(value),
    );
  }
}

String _$kopplungsDiensteHash() => r'cdf7e9eafeb015ebe70cc6384a21b82800c07c7a';
