// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'party_inhalte.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Der mitgelieferte Topf. Fehlt oder bricht das Asset, bleibt der Modus
/// spielbar — dann eben nur mit Fragen aus dem eigenen Bestand.

@ProviderFor(partyInhalte)
final partyInhalteProvider = PartyInhalteProvider._();

/// Der mitgelieferte Topf. Fehlt oder bricht das Asset, bleibt der Modus
/// spielbar — dann eben nur mit Fragen aus dem eigenen Bestand.

final class PartyInhalteProvider
    extends
        $FunctionalProvider<
          AsyncValue<PartyInhalte>,
          PartyInhalte,
          FutureOr<PartyInhalte>
        >
    with $FutureModifier<PartyInhalte>, $FutureProvider<PartyInhalte> {
  /// Der mitgelieferte Topf. Fehlt oder bricht das Asset, bleibt der Modus
  /// spielbar — dann eben nur mit Fragen aus dem eigenen Bestand.
  PartyInhalteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'partyInhalteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$partyInhalteHash();

  @$internal
  @override
  $FutureProviderElement<PartyInhalte> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PartyInhalte> create(Ref ref) {
    return partyInhalte(ref);
  }
}

String _$partyInhalteHash() => r'5c6c1e84e86a5b736577d3fc5890b79eca75b855';
