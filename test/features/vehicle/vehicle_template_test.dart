/// vehicle_template_test.dart – Fahrzeug-Vorlagen: Parser, ausgelieferte
/// Dateien und das Anlegen (Issue #55).
library;
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template.dart';
import 'package:fwapp/features/vehicle/data/vehicle_template_service.dart';

import '../../helpers/test_database.dart';

void main() {
  // Für rootBundle: Der Vorlagen-Service legt fehlende Katalog-Geräte aus
  // dem gebündelten standard_catalog.json nach (Issue #86).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseVehicleTemplate', () {
    test('liest Vorlage mit Beladung vollständig', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'lf20',
        'name': 'LF 20',
        'type': 'LF 20',
        'note': 'Hinweis',
        'compartments': [
          {'label': 'G1', 'position': 0},
          {'label': 'G2', 'position': 1},
        ],
        'loading': {
          'source': 'Feuerwehrschule',
          'source_url': 'https://example.invalid/liste.pdf',
          'items': [
            {'equipment_id': 'std_b_druckschlauch_20m', 'quantity': 14},
          ],
        },
      }))!;

      expect(t.id, 'lf20');
      expect(t.type, 'LF 20');
      expect(t.note, 'Hinweis');
      expect(t.compartments.map((c) => c.label), ['G1', 'G2']);
      expect(t.hasLoading, isTrue);
      expect(t.loading!.source, 'Feuerwehrschule');
      expect(t.loading!.items.single.quantity, 14);
    });

    test('Vorlage ohne Beladung meldet hasLoading = false', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'mtw',
        'name': 'MTW',
        'type': 'MTW',
        'compartments': [
          {'label': 'Laderaum', 'position': 0},
        ],
      }))!;
      expect(t.hasLoading, isFalse);
      expect(t.loading, isNull);
    });

    test('leerer loading-Block zählt nicht als Beladung', () {
      // Sonst böte die UI „mit Normbeladung" an und legte nichts an.
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [],
        'loading': {'source': 'irgendwo', 'items': []},
      }))!;
      expect(t.hasLoading, isFalse);
    });

    test('ergänzt fehlende Positionen fortlaufend', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'A'},
          {'label': 'B'},
        ],
      }))!;
      expect(t.compartments.map((c) => c.position), [0, 1]);
    });

    test('überspringt Fächer und Positionen ohne Pflichtangabe', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'A'},
          {'position': 1},
          {'label': ''},
        ],
        'loading': {
          'source': 's',
          'items': [
            {'equipment_id': 'std_a', 'quantity': 2},
            {'quantity': 5},
          ],
        },
      }))!;
      expect(t.compartments.map((c) => c.label), ['A']);
      expect(t.loading!.items.single.equipmentId, 'std_a');
    });

    test('liefert null statt zu werfen', () {
      expect(parseVehicleTemplate('kein json'), isNull);
      expect(parseVehicleTemplate('[]'), isNull);
      // Pflichtangaben fehlen.
      expect(parseVehicleTemplate('{"name":"X"}'), isNull);
    });

    test('liest die Verortung (Issue #144)', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {
            'label': 'G1',
            'position': 0,
            'seite': 'fahrerseite',
            'laengsposition': 'vorne',
          },
          {'label': 'GR', 'position': 1, 'seite': 'heck'},
          {'label': 'Ablage', 'position': 2},
        ],
      }))!;
      expect(t.compartments[0].seite, 'fahrerseite');
      expect(t.compartments[0].laengsposition, 'vorne');
      expect(t.compartments[1].seite, 'heck');
      expect(t.compartments[1].laengsposition, isNull);
      expect(t.compartments[2].seite, isNull);
    });

    test('liest die Default-Verortung der Positionen (Issue #157)', () {
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'G1', 'position': 0},
          {'label': 'G2', 'position': 1},
        ],
        'loading': {
          'source': 's',
          'items': [
            {'equipment_id': 'std_a', 'quantity': 1, 'compartment': 'G1'},
            {'equipment_id': 'std_b', 'quantity': 2},
            // Tippfehler: Das Label gibt es in der Vorlage nicht. Fällt auf
            // null zurück (→ Sammelfach) statt still ein Fach zu erfinden.
            {'equipment_id': 'std_c', 'quantity': 3, 'compartment': 'G9'},
          ],
        },
      }))!;
      expect(t.hasPlacement, isTrue);
      expect(t.loading!.items[0].compartment, 'G1');
      expect(t.loading!.items[1].compartment, isNull);
      expect(t.loading!.items[2].compartment, isNull);
    });

    test('ohne Verortungen meldet die Vorlage hasPlacement = false', () {
      // Sonst zeigte die UI einen Verteilen-Schalter, der nichts verteilt.
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'G1', 'position': 0},
        ],
        'loading': {
          'source': 's',
          'items': [
            {'equipment_id': 'std_a', 'quantity': 1},
          ],
        },
      }))!;
      expect(t.hasPlacement, isFalse);
    });

    test('eine ungültige Verortung fällt auf null zurück', () {
      // Ein Tippfehler in einer Vorlage darf nicht bis zum Veröffentlichen
      // schlummern (dort prüft der Server per CHECK — und lehnt dann den
      // ganzen Schnappschuss ab). Lieber ein Fach unter „Ohne Seite".
      final t = parseVehicleTemplate(jsonEncode({
        'id': 'x',
        'name': 'X',
        'type': 'X',
        'compartments': [
          {'label': 'G1', 'position': 0, 'seite': 'links'},
          {
            'label': 'G2',
            'position': 1,
            'seite': 'beifahrerseite',
            'laengsposition': 'achtern',
          },
        ],
      }))!;
      expect(t.compartments[0].seite, isNull);
      expect(t.compartments[1].seite, 'beifahrerseite');
      expect(t.compartments[1].laengsposition, isNull);
    });
  });

  group('die ausgelieferten Vorlagen', () {
    late final Map<String, VehicleTemplate> templates = {
      for (final id in kBundledVehicleTemplateIds)
        id: parseVehicleTemplate(
            File('$kVehicleTemplateDir/$id/template.json').readAsStringSync())!,
    };

    late final Set<String> catalogIds = (() {
      final raw = jsonDecode(File(
              'assets/equipment_library/catalog/standard_catalog.json')
          .readAsStringSync());
      final items = raw is List ? raw : (raw as Map)['items'] as List;
      return items.map((e) => (e as Map)['id'] as String).toSet();
    })();

    test('alle im Code gelisteten Vorlagen existieren und sind lesbar', () {
      expect(templates, hasLength(kBundledVehicleTemplateIds.length));
      for (final entry in templates.entries) {
        expect(entry.value.id, entry.key,
            reason: 'die id im JSON muss dem Verzeichnisnamen entsprechen — '
                'sonst lädt der Provider etwas anderes als erwartet');
      }
    });

    test('jede Vorlage ist in pubspec.yaml als Asset eingetragen', () {
      // Ohne Eintrag fehlt die Datei im Build und die Vorlage verschwindet
      // still — im Test läuft sie über das Dateisystem und fällt nicht auf.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final id in kBundledVehicleTemplateIds) {
        expect(pubspec, contains('$kVehicleTemplateDir/$id/template.json'),
            reason: 'Vorlage $id fehlt in den Assets');
      }
    });

    test('jede Vorlage hat Geräteräume', () {
      for (final t in templates.values) {
        expect(t.compartments, isNotEmpty, reason: '${t.id} ohne Geräteräume');
      }
    });

    test('Geräteraum-Positionen sind eindeutig', () {
      for (final t in templates.values) {
        final positions = t.compartments.map((c) => c.position).toList();
        expect(positions.toSet(), hasLength(positions.length),
            reason: '${t.id} hat doppelte Positionen');
      }
    });

    test('jede Beladungsposition verweist auf ein Gerät im Katalog', () {
      // ⚠️ Der wichtigste Test dieser Datei: Eine unbekannte ID fällt zur
      // Laufzeit nicht auf — das Gerät wird beim Anlegen einfach übersprungen,
      // und die Wehr bekommt eine unvollständige Beladung, ohne es zu merken.
      for (final t in templates.values) {
        for (final item in t.loading?.items ?? const []) {
          expect(catalogIds, contains(item.equipmentId),
              reason: '${t.id}: ${item.equipmentId} steht nicht im Katalog');
        }
      }
    });

    test('Beladungspositionen haben plausible Mengen und keine Dubletten', () {
      for (final t in templates.values) {
        final ids = <String>[];
        for (final item in t.loading?.items ?? const []) {
          expect(item.quantity, greaterThan(0),
              reason: '${t.id}: ${item.equipmentId} mit Menge 0');
          ids.add(item.equipmentId);
        }
        expect(ids.toSet(), hasLength(ids.length),
            reason: '${t.id} nennt ein Gerät mehrfach');
      }
    });

    test('jede Vorlage mit Beladung nennt ihre Quelle', () {
      // Ohne Herkunft könnte jemand die Liste für den geprüften Stand der
      // eigenen Wehr halten.
      for (final t in templates.values.where((t) => t.hasLoading)) {
        expect(t.loading!.source, isNotEmpty);
        expect(t.loading!.source.toLowerCase(), contains('din'),
            reason: '${t.id}: die Quelle sollte die Norm benennen');
      }
    });

    test('HLF 20 trägt mehr als LF 20 — die Zusatzbeladung', () {
      // Fachliche Gegenprobe: Das HLF ist ein LF plus TH-Satz.
      final lf = templates['lf20']!;
      final hlf = templates['hlf20']!;
      expect(hlf.loading!.items.length,
          greaterThan(lf.loading!.items.length));
      final hlfIds = hlf.loading!.items.map((i) => i.equipmentId).toSet();
      for (final item in lf.loading!.items) {
        expect(hlfIds, contains(item.equipmentId),
            reason: 'HLF muss die LF-Beladung enthalten');
      }
      expect(hlfIds, containsAll(['std_spreizer', 'std_schneidgeraet']));
    });

    test('Vorlagen ohne Beladung sagen das im Hinweis', () {
      for (final t in templates.values.where((t) => !t.hasLoading)) {
        expect(t.note.toLowerCase(), contains('keine'),
            reason: '${t.id} sollte erklären, warum keine Beladung dabei ist');
      }
    });

    test('jedes Fach jeder Vorlage ist verortet (Issue #144)', () {
      // Der Sinn der Übung: Ein Fahrzeug aus der Vorlage startet mit
      // fertiger Draufsicht, nicht mit „Ohne Seite" quer über den Schirm.
      for (final t in templates.values) {
        for (final c in t.compartments) {
          expect(c.seite, isNotNull, reason: '${t.id}/${c.label} ohne Seite');
        }
      }
    });

    test('die Verortung im JSON ist wörtlich gültig — kein stiller '
        'Rückfall', () {
      // Der Parser lässt Tippfehler auf null zurückfallen; dieser Test
      // benennt sie stattdessen. Deshalb wird hier das ROHE JSON geprüft,
      // nicht das geparste Ergebnis.
      for (final id in kBundledVehicleTemplateIds) {
        final raw = jsonDecode(
                File('$kVehicleTemplateDir/$id/template.json')
                    .readAsStringSync())
            as Map<String, dynamic>;
        for (final c in raw['compartments'] as List) {
          final fach = c as Map;
          expect(istGueltigeSeite(fach['seite'] as String?), isTrue,
              reason: '$id/${fach['label']}: ${fach['seite']}');
          expect(
              istGueltigeLaengsposition(fach['laengsposition'] as String?),
              isTrue,
              reason: '$id/${fach['label']}: ${fach['laengsposition']}');
        }
      }
    });

    test('die Verortung folgt der Konvention der App', () {
      // Ungerade = Fahrerseite, G1/G2 vorne … — dieselbe Regel wie der
      // Vorschlag in der Fächerverwaltung. Eine Vorlage, die anders zählt
      // als der eigene Vorschlags-Knopf, wäre ein Widerspruch im Produkt.
      final hlf = templates['hlf20']!;
      for (final c in hlf.compartments) {
        final seite = seiteAusName(c.label);
        if (seite != null) {
          expect(c.seite, seite, reason: 'hlf20/${c.label}');
        }
        final laengs = laengspositionAusName(c.label);
        if (laengs != null) {
          expect(c.laengsposition, laengs, reason: 'hlf20/${c.label}');
        }
      }
    });

    test('jede Vorlage sagt, dass die Verortung vorbelegt ist', () {
      // Vorbelegt heißt Konvention, nicht Tatsache — der Hinweis gehört
      // in jede Vorlage, damit niemand die Draufsicht für gemessen hält.
      for (final t in templates.values) {
        expect(t.note, contains('vorbelegt'), reason: t.id);
      }
    });

    test('hlf20 und lf20 verorten jede Position auf ein echtes Fach '
        '(Issue #157)', () {
      // Wie bei der Fach-Verortung wird das ROHE JSON geprüft: Der Parser
      // lässt einen Tippfehler still ins Sammelfach zurückfallen — dieser
      // Test benennt ihn stattdessen. Und JEDE Position trägt ein Fach,
      // damit „verteilen" nicht heißt „verteilen, bis auf drei".
      for (final id in ['hlf20', 'lf20']) {
        final raw = jsonDecode(
                File('$kVehicleTemplateDir/$id/template.json')
                    .readAsStringSync())
            as Map<String, dynamic>;
        final labels = (raw['compartments'] as List)
            .map((c) => (c as Map)['label'] as String)
            .toSet();
        for (final i in (raw['loading'] as Map)['items'] as List) {
          final item = i as Map;
          expect(labels, contains(item['compartment']),
              reason: '$id: ${item['equipment_id']} → '
                  '${item['compartment']}');
        }
      }
    });

    test('beim Verteilen bleibt kein Geräteraum leer (Issue #157)', () {
      // Ein leeres Fach nach „verteilen" sähe aus wie ein Fehler im
      // Fahrzeug — die Konvention muss jeden Raum begründen können.
      for (final id in ['hlf20', 'lf20']) {
        final t = templates[id]!;
        final belegt =
            t.loading!.items.map((i) => i.compartment).toSet();
        for (final c in t.compartments) {
          expect(belegt, contains(c.label), reason: '$id/${c.label} leer');
        }
      }
    });

    test('der Mannschaftsraum gehört zu den Vorlagen mit Beladung '
        '(Issue #157)', () {
      // PA, Masken und Leinen liegen in der Kabine — ohne dieses Fach
      // müsste die Konvention den halben Atemschutz in einen G-Raum
      // erfinden.
      for (final id in ['hlf20', 'lf20']) {
        final labels = templates[id]!.compartments.map((c) => c.label);
        expect(labels, contains('Mannschaftsraum'), reason: id);
      }
    });

    test('die TLF-Vorlagen bringen die Trupp-Aufteilung mit', () {
      for (final id in ['tlf3000', 'tlf4000']) {
        final t = templates[id]!;
        expect(t.compartments.map((c) => c.label),
            ['G1', 'G2', 'G3', 'G4', 'Heck (GR)', 'Dach'],
            reason: id);
        expect(t.hasLoading, isFalse,
            reason: '$id: keine belegbare Beladeliste — nur Geräteräume');
      }
    });
  });

  group('VehicleTemplateService', () {
    late AppDatabase db;
    late VehicleTemplateService service;

    setUp(() {
      db = createTestDatabase();
      service = VehicleTemplateService(db);
    });
    tearDown(() => db.close());

    VehicleTemplate template({List<TemplateItem> items = const []}) =>
        VehicleTemplate(
          id: 'test',
          name: 'Testfahrzeug',
          type: 'LF 20',
          note: '',
          compartments: const [
            TemplateCompartment(label: 'G1', position: 0),
            TemplateCompartment(label: 'G2', position: 1),
          ],
          loading: items.isEmpty
              ? null
              : TemplateLoading(source: 'DIN Test', items: items),
        );

    test('legt die Verortung aus der Vorlage an (Issue #144)', () async {
      final result = await service.apply(
        const VehicleTemplate(
          id: 'test',
          name: 'Testfahrzeug',
          type: 'TLF 3000',
          note: '',
          compartments: [
            TemplateCompartment(
                label: 'G1',
                position: 0,
                seite: 'fahrerseite',
                laengsposition: 'vorne'),
            TemplateCompartment(label: 'GR', position: 1, seite: 'heck'),
          ],
        ),
        name: 'X',
        withLoading: false,
      );
      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final g1 = comps.firstWhere((c) => c.label == 'G1');
      expect(g1.seite, 'fahrerseite');
      expect(g1.laengsposition, 'vorne');
      final gr = comps.firstWhere((c) => c.label == 'GR');
      expect(gr.seite, 'heck');
      expect(gr.laengsposition, isNull);
    });

    test('legt Fahrzeug und Geräteräume an', () async {
      final result = await service.apply(
        template(),
        name: 'Florian 1/46',
        withLoading: false,
      );

      expect(result.compartmentCount, 2);
      expect(result.itemCount, 0);

      final vehicle = (await db.vehicleDao.getAll()).single;
      expect(vehicle.name, 'Florian 1/46');
      expect(vehicle.type, 'LF 20', reason: 'der Typ kommt aus der Vorlage');

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      expect(comps.map((c) => c.label), ['G1', 'G2']);
    });

    test('übernimmt Kennzeichen und Bild', () async {
      final result = await service.apply(
        template(),
        name: 'X',
        licensePlate: 'FW-AB 123',
        imagePath: '/pfad/bild.jpg',
        withLoading: false,
      );
      final vehicle =
          (await db.vehicleDao.getAll()).firstWhere((v) => v.id == result.vehicleId);
      expect(vehicle.licensePlate, 'FW-AB 123');
      expect(vehicle.imagePath, '/pfad/bild.jpg');
    });

    test('legt ohne Beladung auch kein Sammelfach an', () async {
      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_x', quantity: 1),
        ]),
        name: 'X',
        withLoading: false,
      );
      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      expect(comps.map((c) => c.label),
          isNot(contains(kUnassignedCompartmentLabel)));
    });

    test('legt die Beladung gesammelt ins Sammelfach', () async {
      // Die Raumzuordnung ist nicht genormt — sie zu erfinden wäre genau da
      // falsch, wo die App zum Lernen dient.
      final equipmentId = await db.equipmentDao.insertEquipment(
        EquipmentItemsCompanion.insert(
          name: 'B-Druckschlauch 20 m',
          libraryEquipmentId: const Value('std_b_druckschlauch_20m'),
        ),
      );

      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_b_druckschlauch_20m', quantity: 14),
        ]),
        name: 'X',
        withLoading: true,
      );

      expect(result.itemCount, 1);
      expect(result.missingEquipment, isEmpty);
      expect(result.compartmentCount, 3, reason: 'zwei Räume plus Sammelfach');

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final unassigned =
          comps.firstWhere((c) => c.label == kUnassignedCompartmentLabel);
      expect(unassigned.position, 2, reason: 'ans Ende, nicht zwischen die G-Räume');

      final assignments =
          await db.assignmentDao.getByCompartment(unassigned.id);
      expect(assignments.single.equipmentId, equipmentId);
      expect(assignments.single.quantity, 14);
    });

    test('das Sammelfach trägt die Kennzeichnung im Namen', () async {
      // Bewusst statt einer Datenbankspalte: überall sichtbar, wo das Fach
      // auftaucht, und weg, sobald der Gerätewart verteilt hat.
      expect(kUnassignedCompartmentLabel.toLowerCase(), contains('ungeprüft'));
    });

    test('legt Positionen aus dem gebündelten Katalog nach (Issue #86)',
        () async {
      // Ausgangslage wie im Feld: Das Gerät hat den zentralen Datenbestand
      // gezogen, der Pull hat den lokalen Bestand ersetzt und der Seeder
      // darf nie wieder laufen — der Katalog fehlt KOMPLETT. Vorher entstand
      // hier ein Fahrzeug ganz ohne Geräte, obwohl „mit Normbeladung"
      // gewählt war.
      expect(await db.equipmentDao.getByLibraryId('std_b_druckschlauch_20m'),
          isNull,
          reason: 'Vorbedingung: Katalog ist nicht geseedet');

      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_b_druckschlauch_20m', quantity: 14),
        ]),
        name: 'X',
        withLoading: true,
      );

      expect(result.itemCount, 1);
      expect(result.missingEquipment, isEmpty);

      final nachgelegt =
          await db.equipmentDao.getByLibraryId('std_b_druckschlauch_20m');
      expect(nachgelegt, isNotNull, reason: 'aus dem Katalog nachgelegt');
      expect(nachgelegt!.isCustom, isFalse);

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final unassigned =
          comps.firstWhere((c) => c.label == kUnassignedCompartmentLabel);
      final assignments =
          await db.assignmentDao.getByCompartment(unassigned.id);
      expect(assignments.single.equipmentId, nachgelegt.id);
      expect(assignments.single.quantity, 14);
    });

    test('verteilt auf Wunsch nach der Default-Verortung (Issue #157)',
        () async {
      final result = await service.apply(
        template(items: const [
          TemplateItem(
              equipmentId: 'std_b_druckschlauch_20m',
              quantity: 14,
              compartment: 'G1'),
          // Ohne Verortung → Sammelfach, auch beim Verteilen.
          TemplateItem(equipmentId: 'std_verteiler_bv', quantity: 2),
        ]),
        name: 'X',
        withLoading: true,
        withPlacement: true,
      );

      expect(result.itemCount, 2);
      expect(result.unassignedCount, 1);
      expect(result.compartmentCount, 3,
          reason: 'zwei Räume plus Sammelfach für den Rest');

      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final g1 = comps.firstWhere((c) => c.label == 'G1');
      final schlauch =
          (await db.equipmentDao.getByLibraryId('std_b_druckschlauch_20m'))!;
      final inG1 = await db.assignmentDao.getByCompartment(g1.id);
      expect(inG1.single.equipmentId, schlauch.id);
      expect(inG1.single.quantity, 14);

      final unassigned =
          comps.firstWhere((c) => c.label == kUnassignedCompartmentLabel);
      final imSammelfach =
          await db.assignmentDao.getByCompartment(unassigned.id);
      expect(imSammelfach, hasLength(1));
    });

    test('ohne die Wahl bleibt die Default-Verortung wirkungslos', () async {
      // Das Opt-in ist der Kern von Issue #157: Verortung in der Vorlage
      // allein darf das Sammelfach-Verhalten nicht ändern.
      final result = await service.apply(
        template(items: const [
          TemplateItem(
              equipmentId: 'std_b_druckschlauch_20m',
              quantity: 14,
              compartment: 'G1'),
        ]),
        name: 'X',
        withLoading: true,
      );
      expect(result.unassignedCount, 1);
      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      final g1 = comps.firstWhere((c) => c.label == 'G1');
      expect(await db.assignmentDao.getByCompartment(g1.id), isEmpty);
    });

    test('lässt das Sammelfach weg, wenn alles verortet ist', () async {
      final result = await service.apply(
        template(items: const [
          TemplateItem(
              equipmentId: 'std_b_druckschlauch_20m',
              quantity: 14,
              compartment: 'G1'),
          TemplateItem(
              equipmentId: 'std_verteiler_bv',
              quantity: 2,
              compartment: 'G2'),
        ]),
        name: 'X',
        withLoading: true,
        withPlacement: true,
      );
      expect(result.itemCount, 2);
      expect(result.unassignedCount, 0);
      expect(result.compartmentCount, 2, reason: 'kein leeres Sammelfach');
      final comps = await db.compartmentDao.getByVehicle(result.vehicleId);
      expect(comps.map((c) => c.label),
          isNot(contains(kUnassignedCompartmentLabel)));
    });

    test('meldet Geräte, die nicht im Katalog stehen', () async {
      final result = await service.apply(
        template(items: const [
          TemplateItem(equipmentId: 'std_gibts_nicht', quantity: 1),
        ]),
        name: 'X',
        withLoading: true,
      );
      expect(result.itemCount, 0);
      expect(result.missingEquipment, ['std_gibts_nicht']);
    });
  });
}
