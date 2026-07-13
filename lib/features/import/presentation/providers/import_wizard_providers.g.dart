// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_wizard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImportWizardNotifier)
final importWizardProvider = ImportWizardNotifierProvider._();

final class ImportWizardNotifierProvider
    extends $NotifierProvider<ImportWizardNotifier, ImportWizardState> {
  ImportWizardNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importWizardProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importWizardNotifierHash();

  @$internal
  @override
  ImportWizardNotifier create() => ImportWizardNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportWizardState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportWizardState>(value),
    );
  }
}

String _$importWizardNotifierHash() =>
    r'4da13c642830bd9cb4d4e0823744d941467f1d6e';

abstract class _$ImportWizardNotifier extends $Notifier<ImportWizardState> {
  ImportWizardState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ImportWizardState, ImportWizardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImportWizardState, ImportWizardState>,
              ImportWizardState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
