/// import_models.dart – Value types for the Beladeliste import wizard
/// (pure Dart, no Flutter/Drift dependencies).
library;

/// One sheet/table of a parsed file, as raw strings.
class ImportTable {
  final String name;
  final List<List<String>> rows;
  const ImportTable({required this.name, required this.rows});
}

class ParsedImportFile {
  final String fileName;
  final List<ImportTable> tables;
  const ParsedImportFile({required this.fileName, required this.tables});
}

/// Which source column maps to which target field. A null vehicleColumn
/// means every row belongs to [fixedVehicleName] (lists without a vehicle
/// column are common). quantityColumn is optional (defaults to 1).
class ColumnMapping {
  final int? vehicleColumn;
  final String fixedVehicleName;
  final int compartmentColumn;
  final int equipmentColumn;
  final int? quantityColumn;
  final bool firstRowIsHeader;

  const ColumnMapping({
    this.vehicleColumn,
    this.fixedVehicleName = '',
    required this.compartmentColumn,
    required this.equipmentColumn,
    this.quantityColumn,
    this.firstRowIsHeader = true,
  });

  bool get isValid =>
      compartmentColumn >= 0 &&
      equipmentColumn >= 0 &&
      compartmentColumn != equipmentColumn &&
      (vehicleColumn != null || fixedVehicleName.trim().isNotEmpty);

  ColumnMapping copyWith({
    int? Function()? vehicleColumn,
    String? fixedVehicleName,
    int? compartmentColumn,
    int? equipmentColumn,
    int? Function()? quantityColumn,
    bool? firstRowIsHeader,
  }) =>
      ColumnMapping(
        vehicleColumn:
            vehicleColumn != null ? vehicleColumn() : this.vehicleColumn,
        fixedVehicleName: fixedVehicleName ?? this.fixedVehicleName,
        compartmentColumn: compartmentColumn ?? this.compartmentColumn,
        equipmentColumn: equipmentColumn ?? this.equipmentColumn,
        quantityColumn:
            quantityColumn != null ? quantityColumn() : this.quantityColumn,
        firstRowIsHeader: firstRowIsHeader ?? this.firstRowIsHeader,
      );
}

/// One data row after applying the column mapping.
class ImportRow {
  final int sourceRowIndex; // 0-based index in the source table
  final String vehicleName;
  final String compartmentLabel;
  final String equipmentName;
  final int quantity;

  const ImportRow({
    required this.sourceRowIndex,
    required this.vehicleName,
    required this.compartmentLabel,
    required this.equipmentName,
    required this.quantity,
  });
}

enum MatchKind {
  /// Exact (normalized) name match against the equipment database.
  exact,

  /// Matched via bundled aliases.json or a learned UserAlias.
  alias,

  /// Similar enough to auto-suggest, needs user confirmation (yellow).
  fuzzy,

  /// No plausible match (red).
  none,
}

class MatchCandidate {
  final int equipmentId;
  final String equipmentName;
  final double score;
  const MatchCandidate({
    required this.equipmentId,
    required this.equipmentName,
    required this.score,
  });
}

class EquipmentMatch {
  final MatchKind kind;

  /// Set for exact/alias/fuzzy: the best candidate.
  final MatchCandidate? best;

  /// Top alternatives (including [best]) for the resolution UI.
  final List<MatchCandidate> suggestions;

  const EquipmentMatch({
    required this.kind,
    this.best,
    this.suggestions = const [],
  });
}

/// The user's final decision for one distinct equipment name.
enum RowAction { useEquipment, createCustom, skip }

class RowDecision {
  final RowAction action;
  final int? equipmentId; // for useEquipment
  final bool rememberAlias; // learn the raw name as UserAlias

  const RowDecision({
    required this.action,
    this.equipmentId,
    this.rememberAlias = false,
  });
}

class ImportApplyResult {
  final int assignmentsWritten;
  final int vehiclesCreated;
  final int compartmentsCreated;
  final int customItemsCreated;
  final int aliasesLearned;
  final int skipped;

  const ImportApplyResult({
    required this.assignmentsWritten,
    required this.vehiclesCreated,
    required this.compartmentsCreated,
    required this.customItemsCreated,
    required this.aliasesLearned,
    required this.skipped,
  });
}
