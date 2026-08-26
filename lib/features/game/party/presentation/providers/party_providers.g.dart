// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'party_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Baut die Fragen aus dem Bestand: „In welchem Fach?" und „Was ist das?".
///
/// [vehicleId] `null` heißt: alle Fahrzeuge. Beides kann leer bleiben — eine
/// frische Installation hat weder Beladung noch Fotos, und der Modus läuft
/// dann aus dem mitgelieferten Topf.

@ProviderFor(partyTopf)
final partyTopfProvider = PartyTopfFamily._();

/// Baut die Fragen aus dem Bestand: „In welchem Fach?" und „Was ist das?".
///
/// [vehicleId] `null` heißt: alle Fahrzeuge. Beides kann leer bleiben — eine
/// frische Installation hat weder Beladung noch Fotos, und der Modus läuft
/// dann aus dem mitgelieferten Topf.

final class PartyTopfProvider
    extends
        $FunctionalProvider<
          AsyncValue<PartyTopf>,
          PartyTopf,
          FutureOr<PartyTopf>
        >
    with $FutureModifier<PartyTopf>, $FutureProvider<PartyTopf> {
  /// Baut die Fragen aus dem Bestand: „In welchem Fach?" und „Was ist das?".
  ///
  /// [vehicleId] `null` heißt: alle Fahrzeuge. Beides kann leer bleiben — eine
  /// frische Installation hat weder Beladung noch Fotos, und der Modus läuft
  /// dann aus dem mitgelieferten Topf.
  PartyTopfProvider._({
    required PartyTopfFamily super.from,
    required int? super.argument,
  }) : super(
         retry: null,
         name: r'partyTopfProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$partyTopfHash();

  @override
  String toString() {
    return r'partyTopfProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PartyTopf> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PartyTopf> create(Ref ref) {
    final argument = this.argument as int?;
    return partyTopf(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PartyTopfProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$partyTopfHash() => r'63647566c87d027e3ae128e5bc372e0e93c991aa';

/// Baut die Fragen aus dem Bestand: „In welchem Fach?" und „Was ist das?".
///
/// [vehicleId] `null` heißt: alle Fahrzeuge. Beides kann leer bleiben — eine
/// frische Installation hat weder Beladung noch Fotos, und der Modus läuft
/// dann aus dem mitgelieferten Topf.

final class PartyTopfFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PartyTopf>, int?> {
  PartyTopfFamily._()
    : super(
        retry: null,
        name: r'partyTopfProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Baut die Fragen aus dem Bestand: „In welchem Fach?" und „Was ist das?".
  ///
  /// [vehicleId] `null` heißt: alle Fahrzeuge. Beides kann leer bleiben — eine
  /// frische Installation hat weder Beladung noch Fotos, und der Modus läuft
  /// dann aus dem mitgelieferten Topf.

  PartyTopfProvider call(int? vehicleId) =>
      PartyTopfProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'partyTopfProvider';
}

/// Die laufende Partie. `null` heißt: es läuft keine.
///
/// `keepAlive`, obwohl der Modus flüchtig ist: Eine autoDispose-Fassung wäre
/// weg, sobald der Party-Schirm kurz verlassen wird — eine Wischgeste nach
/// hinten würde mitten im Spiel alle Punkte löschen. Beendet wird die Partie
/// ausdrücklich über [beenden].

@ProviderFor(PartySpiel)
final partySpielProvider = PartySpielProvider._();

/// Die laufende Partie. `null` heißt: es läuft keine.
///
/// `keepAlive`, obwohl der Modus flüchtig ist: Eine autoDispose-Fassung wäre
/// weg, sobald der Party-Schirm kurz verlassen wird — eine Wischgeste nach
/// hinten würde mitten im Spiel alle Punkte löschen. Beendet wird die Partie
/// ausdrücklich über [beenden].
final class PartySpielProvider
    extends $NotifierProvider<PartySpiel, PartyStand?> {
  /// Die laufende Partie. `null` heißt: es läuft keine.
  ///
  /// `keepAlive`, obwohl der Modus flüchtig ist: Eine autoDispose-Fassung wäre
  /// weg, sobald der Party-Schirm kurz verlassen wird — eine Wischgeste nach
  /// hinten würde mitten im Spiel alle Punkte löschen. Beendet wird die Partie
  /// ausdrücklich über [beenden].
  PartySpielProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'partySpielProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$partySpielHash();

  @$internal
  @override
  PartySpiel create() => PartySpiel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PartyStand? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PartyStand?>(value),
    );
  }
}

String _$partySpielHash() => r'95fafbdb69835fdc5b341348cc1f82a771773558';

/// Die laufende Partie. `null` heißt: es läuft keine.
///
/// `keepAlive`, obwohl der Modus flüchtig ist: Eine autoDispose-Fassung wäre
/// weg, sobald der Party-Schirm kurz verlassen wird — eine Wischgeste nach
/// hinten würde mitten im Spiel alle Punkte löschen. Beendet wird die Partie
/// ausdrücklich über [beenden].

abstract class _$PartySpiel extends $Notifier<PartyStand?> {
  PartyStand? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PartyStand?, PartyStand?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PartyStand?, PartyStand?>,
              PartyStand?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
