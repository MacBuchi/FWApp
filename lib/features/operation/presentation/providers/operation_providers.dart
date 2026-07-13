/// operation_providers.dart – Ephemeral Einsatz session (virtuelles Ausladen).
/// Deliberately in-memory only: an Einsatz is transient, works fully offline,
/// and is NOT part of the synced dataset (no Einsatzdokumentation im
/// rechtlichen Sinn).
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';

class OperationState {
  final bool active;
  final List<int> vehicleIds;
  final DeploymentScenario? scenario;
  final DateTime? startedAt;

  /// Assignment ids the crew has marked as "entnommen".
  final Set<int> takenAssignmentIds;

  const OperationState({
    this.active = false,
    this.vehicleIds = const [],
    this.scenario,
    this.startedAt,
    this.takenAssignmentIds = const {},
  });

  bool isTaken(int assignmentId) => takenAssignmentIds.contains(assignmentId);

  OperationState copyWith({
    bool? active,
    List<int>? vehicleIds,
    DeploymentScenario? scenario,
    bool clearScenario = false,
    DateTime? startedAt,
    Set<int>? takenAssignmentIds,
  }) =>
      OperationState(
        active: active ?? this.active,
        vehicleIds: vehicleIds ?? this.vehicleIds,
        scenario: clearScenario ? null : (scenario ?? this.scenario),
        startedAt: startedAt ?? this.startedAt,
        takenAssignmentIds: takenAssignmentIds ?? this.takenAssignmentIds,
      );
}

class OperationNotifier extends Notifier<OperationState> {
  @override
  OperationState build() => const OperationState();

  void start({
    required List<int> vehicleIds,
    DeploymentScenario? scenario,
  }) {
    state = OperationState(
      active: true,
      vehicleIds: vehicleIds,
      scenario: scenario,
      startedAt: DateTime.now(),
      takenAssignmentIds: const {},
    );
  }

  void toggleTaken(int assignmentId) {
    final next = {...state.takenAssignmentIds};
    if (!next.add(assignmentId)) next.remove(assignmentId);
    state = state.copyWith(takenAssignmentIds: next);
  }

  void end() => state = const OperationState();
}

final operationProvider =
    NotifierProvider<OperationNotifier, OperationState>(OperationNotifier.new);
