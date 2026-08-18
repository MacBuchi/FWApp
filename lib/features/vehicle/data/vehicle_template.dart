/// vehicle_template.dart – Fahrzeug-Vorlagen: Geräteraum-Aufteilung und, wo
/// belegbar, die Normbeladung (Issue #55).
///
/// **Warum nicht jede Vorlage eine Beladung hat:** Die DIN schreibt vor, *was*
/// an Bord sein muss — nicht, in *welchem* Geräteraum es liegt. Die Zuordnung
/// unterscheidet sich von Wehr zu Wehr, und genau sie ist der Lernstoff dieser
/// App. Eine erfundene Zuordnung wäre also ausgerechnet dort falsch, wo es
/// darauf ankommt. Deshalb landet die Beladung in einem eigenen Sammelfach,
/// aus dem der Gerätewart sie auf die echten Räume verteilt.
///
/// Seit Issue #157 gibt es dazu ein **Opt-in**: Positionen können eine
/// Default-Verortung nach der verbreiteten Konvention tragen, und wer beim
/// Anlegen ausdrücklich das Verteilen wählt, bekommt sie in die Fächer statt
/// ins Sammelfach — derselbe Zug wie bei der Fach-Verortung (#144): Wer eine
/// Vorlage wählt, wählt ein Konventions-Gerüst, und alles bleibt einzeln
/// korrigierbar. Ohne die Wahl ändert sich nichts am Sammelfach-Weg.
///
/// Vorlagen ohne öffentlich belegbare Liste bringen nur die Geräteräume mit.
/// Nachtragen heißt: eine `template.json` um den `loading`-Block ergänzen —
/// kein Code.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/compartment/domain/fahrzeug_seiten.dart';

/// Verzeichnis der mitgelieferten Vorlagen.
const kVehicleTemplateDir = 'assets/vehicle_templates';

/// Label des Sammelfachs, in dem die Vorlagen-Beladung landet.
///
/// Trägt die Kennzeichnung im Namen statt in einer Datenbankspalte: Sie ist
/// damit überall sichtbar, wo das Fach auftaucht, und verschwindet von selbst,
/// sobald der Gerätewart die Geräte verteilt und das Fach löscht.
const kUnassignedCompartmentLabel = 'Normbeladung (ungeprüft) – noch zuzuordnen';

/// Ein Geräteraum der Vorlage.
class TemplateCompartment {
  final String label;
  final int position;

  /// Verortung (Issue #144): Seite und Längsposition, vorbelegt nach der
  /// verbreiteten Konvention. Anders als beim Bestand (#126/#141) ist das
  /// KEIN stilles Setzen: Wer eine Vorlage wählt, wählt ausdrücklich ein
  /// Konventions-Gerüst — auch die Fachnamen sind Konvention — und jedes
  /// Fach bleibt danach einzeln korrigierbar. Der Hinweis der Vorlage
  /// sagt es dazu.
  final String? seite;
  final String? laengsposition;

  const TemplateCompartment({
    required this.label,
    required this.position,
    this.seite,
    this.laengsposition,
  });
}

/// Eine Beladungsposition der Vorlage.
class TemplateItem {
  /// Katalog-ID (`std_…`) — Vorlagen verweisen nur auf den Grundkatalog.
  final String equipmentId;
  final int quantity;

  /// Default-Verortung (Issue #157): Label eines Geräteraums DERSELBEN
  /// Vorlage, oder `null` für das Sammelfach. Lebt bewusst hier und nicht
  /// am Katalog: Dasselbe Standrohr liegt auf einem LF 10 woanders als auf
  /// einem HLF 20, und die Fächerschnitte unterscheiden sich je Typ.
  final String? compartment;

  const TemplateItem({
    required this.equipmentId,
    required this.quantity,
    this.compartment,
  });
}

/// Die Beladung einer Vorlage samt Herkunftsangabe.
class TemplateLoading {
  /// Woher die Liste stammt — gehört in die UI, damit niemand sie für den
  /// geprüften Stand der eigenen Wehr hält.
  final String source;
  final String? sourceUrl;
  final List<TemplateItem> items;

  const TemplateLoading({
    required this.source,
    required this.items,
    this.sourceUrl,
  });
}

/// Eine Fahrzeug-Vorlage.
class VehicleTemplate {
  final String id;
  final String name;
  final String type;
  final String note;
  final List<TemplateCompartment> compartments;

  /// `null`, wenn für den Typ keine belegbare Liste vorliegt.
  final TemplateLoading? loading;

  const VehicleTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.note,
    required this.compartments,
    this.loading,
  });

  bool get hasLoading => loading != null && loading!.items.isNotEmpty;

  /// Bringt die Vorlage eine Default-Verortung mit (Issue #157)? Nur dann
  /// bietet die Oberfläche das Verteilen überhaupt an.
  bool get hasPlacement =>
      loading?.items.any((i) => i.compartment != null) ?? false;
}

/// Liest eine Vorlage aus ihrem JSON. Rein, damit der Test sie direkt füttern
/// kann. Liefert `null`, wenn Pflichtangaben fehlen — eine kaputte Vorlage
/// darf die Auswahl nicht sprengen, sie fällt einfach heraus.
VehicleTemplate? parseVehicleTemplate(String raw) {
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;

    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final type = json['type'] as String?;
    if (id == null || name == null || type == null) return null;

    final compartments = <TemplateCompartment>[];
    var index = 0;
    for (final c in (json['compartments'] as List?) ?? const []) {
      if (c is! Map) continue;
      final label = c['label'] as String?;
      if (label == null || label.isEmpty) continue;
      final seite = c['seite'] as String?;
      final laengsposition = c['laengsposition'] as String?;
      compartments.add(TemplateCompartment(
        label: label,
        position: (c['position'] as num?)?.toInt() ?? index,
        // Nur Werte, die auch der Server annimmt (CHECK-Zwilling in
        // fahrzeug_seiten.dart): Ein Tippfehler in einer Vorlage fiele
        // sonst erst beim Veröffentlichen auf — und dann mit dem ganzen
        // Schnappschuss. Lieber ein Fach unter „Ohne Seite".
        seite: istGueltigeSeite(seite) ? seite : null,
        laengsposition:
            istGueltigeLaengsposition(laengsposition) ? laengsposition : null,
      ));
      index++;
    }

    TemplateLoading? loading;
    final loadingJson = json['loading'];
    if (loadingJson is Map<String, dynamic>) {
      // Nur Labels, die es in DIESER Vorlage gibt: Ein Tippfehler fiele
      // sonst erst am fertigen Fahrzeug auf — als Position, die wortlos in
      // einem falschen Fach fehlt. So landet sie im Sammelfach, und der
      // Vorlagen-Test benennt den Tippfehler laut (Issue #157).
      final labels = compartments.map((c) => c.label).toSet();
      final items = <TemplateItem>[];
      for (final i in (loadingJson['items'] as List?) ?? const []) {
        if (i is! Map) continue;
        final equipmentId = i['equipment_id'] as String?;
        if (equipmentId == null || equipmentId.isEmpty) continue;
        final compartment = i['compartment'] as String?;
        items.add(TemplateItem(
          equipmentId: equipmentId,
          quantity: (i['quantity'] as num?)?.toInt() ?? 1,
          compartment: labels.contains(compartment) ? compartment : null,
        ));
      }
      if (items.isNotEmpty) {
        loading = TemplateLoading(
          source: loadingJson['source'] as String? ?? 'Quelle nicht angegeben',
          sourceUrl: loadingJson['source_url'] as String?,
          items: items,
        );
      }
    }

    return VehicleTemplate(
      id: id,
      name: name,
      type: type,
      note: json['note'] as String? ?? '',
      compartments: compartments,
      loading: loading,
    );
  } catch (e) {
    appLog.w('Fahrzeug-Vorlage unlesbar', error: e);
    return null;
  }
}

/// Die IDs der mitgelieferten Vorlagen, in Anzeigereihenfolge.
///
/// Bewusst eine Liste im Code statt eines Verzeichnis-Scans: Flutter-Assets
/// lassen sich zur Laufzeit nicht auflisten, ohne den `AssetManifest` zu
/// lesen — und die Reihenfolge wäre dann alphabetisch statt fachlich sortiert.
const kBundledVehicleTemplateIds = [
  'lf10',
  'lf20',
  'hlf20',
  'tsf_w',
  'tlf3000',
  'tlf4000',
  'dlk23_12',
  'rw',
  'gw_l',
  'mtw',
  'elw1',
];

/// Lädt die mitgelieferten Vorlagen. Unlesbare fallen still heraus.
final vehicleTemplatesProvider =
    FutureProvider<List<VehicleTemplate>>((ref) async {
  final templates = <VehicleTemplate>[];
  for (final id in kBundledVehicleTemplateIds) {
    try {
      final raw =
          await rootBundle.loadString('$kVehicleTemplateDir/$id/template.json');
      final template = parseVehicleTemplate(raw);
      if (template != null) templates.add(template);
    } catch (e) {
      appLog.w('Fahrzeug-Vorlage $id nicht ladbar', error: e);
    }
  }
  return templates;
});
