/// equipment_enums_test.dart – Round-trip and label coverage of the
/// two-axis classification (EquipmentFunction / DeploymentScenario):
/// jsonKey ↔ fromJson must be lossless, labels must be unique and non-empty.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/features/equipment/domain/entities/equipment_enums.dart';

void main() {
  group('EquipmentFunction', () {
    test('jsonKey ↔ fromJson round-trip for every value', () {
      for (final f in EquipmentFunction.values) {
        expect(EquipmentFunction.fromJson(f.jsonKey), f);
      }
    });

    test('fromJson is case-insensitive and null for unknowns', () {
      expect(EquipmentFunction.fromJson('wasser'), EquipmentFunction.wasser);
      expect(EquipmentFunction.fromJson('WASSER'), EquipmentFunction.wasser);
      expect(EquipmentFunction.fromJson('gibt_es_nicht'), isNull);
    });

    test('labels are unique and non-empty', () {
      final labels = EquipmentFunction.values.map((f) => f.label).toSet();
      expect(labels.length, EquipmentFunction.values.length);
      expect(labels.any((l) => l.trim().isEmpty), isFalse);
    });
  });

  group('DeploymentScenario', () {
    test('jsonKey ↔ fromJson round-trip for every value', () {
      for (final s in DeploymentScenario.values) {
        expect(DeploymentScenario.fromJson(s.jsonKey), s);
      }
    });

    test('jsonKey converts camelCase to UPPER_SNAKE_CASE', () {
      expect(DeploymentScenario.brandInnen.jsonKey, 'BRAND_INNEN');
      expect(DeploymentScenario.vuPkw.jsonKey, 'VU_PKW');
      expect(
          DeploymentScenario.gefahrgutDekon.jsonKey, 'GEFAHRGUT_DEKON');
    });

    test('fromJson is case-insensitive and null for unknowns', () {
      expect(DeploymentScenario.fromJson('brand_innen'),
          DeploymentScenario.brandInnen);
      expect(DeploymentScenario.fromJson('HOCHWASSER'),
          DeploymentScenario.hochwasser);
      expect(DeploymentScenario.fromJson('UNBEKANNT'), isNull);
    });

    test('labels are unique and non-empty', () {
      final labels = DeploymentScenario.values.map((s) => s.label).toSet();
      expect(labels.length, DeploymentScenario.values.length);
      expect(labels.any((l) => l.trim().isEmpty), isFalse);
    });
  });
}
