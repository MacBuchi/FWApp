// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_check.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Bekommt dieses Gerät auch Vorabversionen angeboten? (Issue #169, Vorbild
/// PilzBuddy #269 und MitFahrBar.)
///
/// Der Riegel steht HIER und nicht nur in der Oberfläche: Wo der Update-Weg
/// gar nicht läuft, ist der Schalter aus — sonst ließe er sich umlegen, ohne
/// dass je etwas passieren kann.
///
/// Gilt nur für dieses Gerät. Der Vorab-Kanal ist eine Entscheidung über das
/// eigene Handy, keine über die Wehr: Wer 25 Kameraden zwangsweise in
/// ungetestete Stände schickt, hat kein Testgerät, sondern ein Problem.

@ProviderFor(PrereleaseUpdates)
final prereleaseUpdatesProvider = PrereleaseUpdatesProvider._();

/// Bekommt dieses Gerät auch Vorabversionen angeboten? (Issue #169, Vorbild
/// PilzBuddy #269 und MitFahrBar.)
///
/// Der Riegel steht HIER und nicht nur in der Oberfläche: Wo der Update-Weg
/// gar nicht läuft, ist der Schalter aus — sonst ließe er sich umlegen, ohne
/// dass je etwas passieren kann.
///
/// Gilt nur für dieses Gerät. Der Vorab-Kanal ist eine Entscheidung über das
/// eigene Handy, keine über die Wehr: Wer 25 Kameraden zwangsweise in
/// ungetestete Stände schickt, hat kein Testgerät, sondern ein Problem.
final class PrereleaseUpdatesProvider
    extends $AsyncNotifierProvider<PrereleaseUpdates, bool> {
  /// Bekommt dieses Gerät auch Vorabversionen angeboten? (Issue #169, Vorbild
  /// PilzBuddy #269 und MitFahrBar.)
  ///
  /// Der Riegel steht HIER und nicht nur in der Oberfläche: Wo der Update-Weg
  /// gar nicht läuft, ist der Schalter aus — sonst ließe er sich umlegen, ohne
  /// dass je etwas passieren kann.
  ///
  /// Gilt nur für dieses Gerät. Der Vorab-Kanal ist eine Entscheidung über das
  /// eigene Handy, keine über die Wehr: Wer 25 Kameraden zwangsweise in
  /// ungetestete Stände schickt, hat kein Testgerät, sondern ein Problem.
  PrereleaseUpdatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'prereleaseUpdatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$prereleaseUpdatesHash();

  @$internal
  @override
  PrereleaseUpdates create() => PrereleaseUpdates();
}

String _$prereleaseUpdatesHash() => r'477a81bdedfaa0cad02321f98faa18a9e880a03b';

/// Bekommt dieses Gerät auch Vorabversionen angeboten? (Issue #169, Vorbild
/// PilzBuddy #269 und MitFahrBar.)
///
/// Der Riegel steht HIER und nicht nur in der Oberfläche: Wo der Update-Weg
/// gar nicht läuft, ist der Schalter aus — sonst ließe er sich umlegen, ohne
/// dass je etwas passieren kann.
///
/// Gilt nur für dieses Gerät. Der Vorab-Kanal ist eine Entscheidung über das
/// eigene Handy, keine über die Wehr: Wer 25 Kameraden zwangsweise in
/// ungetestete Stände schickt, hat kein Testgerät, sondern ein Problem.

abstract class _$PrereleaseUpdates extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
