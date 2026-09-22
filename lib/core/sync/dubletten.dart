/// dubletten.dart – Zwei Einträge, die dasselbe Gerät meinen (Issue #67).
///
/// **Wo das herkommt.** Seit Schema 17 überlebt unveröffentlichte Arbeit den
/// Zug: Wer am Übungsabend zu zweit erfasst, hat danach BEIDE Erfassungen
/// lokal stehen. Das ist der Sinn der Sache — aber wenn beide dasselbe
/// Strahlrohr gemeint und es nur verschieden geschrieben haben, stünde es
/// nach dem Veröffentlichen zweimal im Bestand der Wehr. Das fällt erst
/// Wochen später bei der Inventur auf, und dann weiß niemand mehr, welcher
/// der beiden Einträge der gepflegte ist.
///
/// **Was geprüft wird**, in zwei Stufen mit verschiedener Beweislast:
///
/// 1. **Dieselbe Stelle** — gleiches Fahrzeug, gleicher Geräteraum, ähnlicher
///    Name. Der Ort ist hier das starke Argument: Zwei Geräte mit fast
///    gleichem Namen im selben Fach sind fast immer eines. Deshalb genügt
///    weniger Namensähnlichkeit.
/// 2. **Derselbe Typ** — ähnlicher Name, egal wo. Schwächer, aber nötig:
///    Ein Gerätetyp gehört der ganzen Wehr (Issue #99), und zwei Einträge
///    für dasselbe Gerät verschmutzen den Katalog dauerhaft, auch wenn sie
///    in verschiedenen Fächern liegen. Hier wird strenger verglichen, weil
///    ein Fehlalarm über den ganzen Bestand streut.
///
/// ⚠️ **Gefragt wird nur zu Geräten, die HIER neu entstanden sind.** Zwei
/// längst veröffentlichte Einträge sind keine Folge des Zusammenführens,
/// sondern Bestandsdaten — die ungefragt anzufassen wäre etwas anderes als
/// das, was der Gerätewart gerade tut. Das hat einen angenehmen Nebeneffekt:
/// Nach einem erfolgreichen Veröffentlichen ist nichts mehr unveröffentlicht,
/// also fragt die Prüfung zu denselben Paaren nie wieder. Eine Entscheidung
/// „die sind verschieden" braucht deshalb keinen Speicher.
library;

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/utils/equipment_naming.dart';

/// Ab hier gilt ein Paar im SELBEN Geräteraum als verdächtig.
///
/// Niedriger als die Katalog-Schwelle, weil der Ort schon die halbe Antwort
/// ist: „Strahlrohr C" und „Rohr C-Storz" im selben Fach sind ein Gerät.
const kPositionSchwelle = 0.60;

/// Ab hier gilt ein Paar irgendwo im Bestand als verdächtig.
///
/// Deutlich strenger — hier fehlt das Ortsargument, und ein Fehlalarm
/// betrifft nicht ein Fach, sondern den Katalog der ganzen Wehr. Praktisch
/// schlagen damit Schreibweisen und Endungen an („Schlauchhalter" /
/// „Schlauchhalterung"), nicht zwei verwandte, aber verschiedene Geräte.
const kKatalogSchwelle = 0.80;

enum DublettenArt {
  /// Gleiches Fahrzeug, gleicher Geräteraum.
  position,

  /// Ähnlicher Name irgendwo im Bestand.
  katalog,
}

/// Zwei Geräte-Einträge, die vermutlich dasselbe meinen.
class Dublette {
  const Dublette({
    required this.art,
    required this.behalten,
    required this.aufgeben,
    required this.aehnlichkeit,
    required this.ort,
  });

  final DublettenArt art;

  /// Der Vorschlag, welcher Eintrag bleibt. Voreingestellt ist der bereits
  /// veröffentlichte: Seine ID ist oben der Schlüssel, und die Geräte der
  /// anderen Mitglieder hängen daran. Der Nutzer darf tauschen.
  final EquipmentItemData behalten;
  final EquipmentItemData aufgeben;

  final double aehnlichkeit;

  /// Wo das zu sehen ist — „HLF 20 · G1" oder „G1 und Heck".
  final String ort;

  /// Dasselbe Paar, mit vertauschten Rollen.
  Dublette getauscht() => Dublette(
    art: art,
    behalten: aufgeben,
    aufgeben: behalten,
    aehnlichkeit: aehnlichkeit,
    ort: ort,
  );

  /// Stabiler Schlüssel für das Paar, unabhängig von der Reihenfolge.
  String get schluessel {
    final a = behalten.id < aufgeben.id ? behalten.id : aufgeben.id;
    final b = behalten.id < aufgeben.id ? aufgeben.id : behalten.id;
    return '$a:$b';
  }
}

/// Sucht Dubletten im lokalen Bestand — teuerste Rechnung ist ein
/// Namensvergleich je Paar, das reicht für einen Bestand dieser Größe.
Future<List<Dublette>> findeDubletten(AppDatabase db) async {
  final geraete = await db.equipmentDao.getAll();
  if (geraete.length < 2) return const [];

  final nachId = {for (final g in geraete) g.id: g};
  // Einmal normalisieren statt in jedem Vergleich erneut.
  final norm = {for (final g in geraete) g.id: normalizeEquipmentName(g.name)};
  final tokens = {for (final g in geraete) g.id: namensTokens(g.name)};

  double aehnlich(int a, int b) =>
      aehnlichkeitVorbereitet(norm[a]!, tokens[a]!, norm[b]!, tokens[b]!);

  // ⚠️ Nur Paare, an denen etwas Unveröffentlichtes hängt — siehe Kopf.
  bool frischEntstanden(int a, int b) => nachId[a]!.dirty || nachId[b]!.dirty;

  final gefunden = <String, Dublette>{};

  Dublette bauen(DublettenArt art, int a, int b, double wert, String ort) {
    // Der veröffentlichte Eintrag bleibt vorgeschlagen; sind beide neu,
    // gewinnt der ältere (die kleinere ID).
    final erst = nachId[a]!;
    final zweit = nachId[b]!;
    final behalten =
        erst.dirty && !zweit.dirty
            ? zweit
            : (!erst.dirty && zweit.dirty ? erst : (a < b ? erst : zweit));
    return Dublette(
      art: art,
      behalten: behalten,
      aufgeben: behalten.id == erst.id ? zweit : erst,
      aehnlichkeit: wert,
      ort: ort,
    );
  }

  // ── 1. Dieselbe Stelle ────────────────────────────────────────────────
  final faecher = await db.select(db.compartments).get();
  final fahrzeuge = await db.select(db.vehicles).get();
  final fahrzeugNachId = {for (final v in fahrzeuge) v.id: v};
  final zuordnungen = await db.select(db.equipmentAssignments).get();

  final jeFach = <int, List<int>>{};
  for (final z in zuordnungen) {
    (jeFach[z.compartmentId] ??= []).add(z.equipmentId);
  }
  final fachNachId = {for (final f in faecher) f.id: f};

  for (final eintrag in jeFach.entries) {
    final geraeteImFach = eintrag.value.toSet().toList()..sort();
    if (geraeteImFach.length < 2) continue;
    final fach = fachNachId[eintrag.key];
    if (fach == null) continue;
    final fahrzeug = fahrzeugNachId[fach.vehicleId];
    final ort = '${fahrzeug?.name ?? 'Fahrzeug'} · ${fach.label}';

    for (var i = 0; i < geraeteImFach.length; i++) {
      for (var j = i + 1; j < geraeteImFach.length; j++) {
        final a = geraeteImFach[i];
        final b = geraeteImFach[j];
        if (!frischEntstanden(a, b)) continue;
        final wert = aehnlich(a, b);
        if (wert < kPositionSchwelle) continue;
        final d = bauen(DublettenArt.position, a, b, wert, ort);
        gefunden[d.schluessel] = d;
      }
    }
  }

  // ── 2. Derselbe Typ, egal wo ──────────────────────────────────────────
  //
  // Wo ein Gerät liegt, steht als Hinweis dabei — ohne das ist ein Paar aus
  // zwei Namen für den Gerätewart nicht zu entscheiden.
  final fachDesGeraets = <int, String>{};
  for (final z in zuordnungen) {
    final fach = fachNachId[z.compartmentId];
    if (fach == null) continue;
    fachDesGeraets.putIfAbsent(z.equipmentId, () => fach.label);
  }

  final ids = geraete.map((g) => g.id).toList()..sort();
  for (var i = 0; i < ids.length; i++) {
    for (var j = i + 1; j < ids.length; j++) {
      final a = ids[i];
      final b = ids[j];
      if (gefunden.containsKey('$a:$b')) continue;
      if (!frischEntstanden(a, b)) continue;
      final wert = aehnlich(a, b);
      if (wert < kKatalogSchwelle) continue;
      final ortA = fachDesGeraets[a];
      final ortB = fachDesGeraets[b];
      final ort =
          ortA == null && ortB == null
              ? 'noch keinem Fach zugeordnet'
              : '${ortA ?? 'ohne Fach'} und ${ortB ?? 'ohne Fach'}';
      final d = bauen(DublettenArt.katalog, a, b, wert, ort);
      gefunden[d.schluessel] = d;
    }
  }

  final liste = gefunden.values.toList();
  // Das Wahrscheinlichste zuerst — und die Position vor dem Katalog, weil
  // sie die sicherere Aussage ist.
  liste.sort((x, y) {
    final nachArt = x.art.index.compareTo(y.art.index);
    if (nachArt != 0) return nachArt;
    return y.aehnlichkeit.compareTo(x.aehnlichkeit);
  });
  return liste;
}

/// Führt [aufgeben] in [behalten] zusammen: Alles, was am aufgegebenen
/// Gerät hängt, zeigt danach auf das behaltene, und der aufgegebene Eintrag
/// verschwindet.
///
/// ⚠️ **Erst umhängen, dann löschen.** Alle Verweise auf `equipment_items`
/// stehen auf `onDelete: cascade` — würde zuerst gelöscht, nähme der
/// aufgegebene Eintrag die Beladung, die Einheiten und mit ihnen die
/// aufgeklebten Codes mit ins Grab.
Future<void> fuehreZusammen(
  AppDatabase db, {
  required int behalten,
  required int aufgeben,
}) async {
  if (behalten == aufgeben) return;
  await db.transaction(() async {
    // ⚠️ `learning_progress` hat UNIQUE(equipment_id) — Umhängen liefe in
    // einen Constraint-Bruch, sobald beide Geräte schon abgefragt wurden.
    // Die Zählerstände gehören ohnehin addiert: Es war immer dasselbe Gerät.
    await db.customStatement(
      'UPDATE learning_progress SET '
      'correct_count = correct_count + '
      '  COALESCE((SELECT correct_count FROM learning_progress '
      '            WHERE equipment_id = ?2), 0), '
      'wrong_count = wrong_count + '
      '  COALESCE((SELECT wrong_count FROM learning_progress '
      '            WHERE equipment_id = ?2), 0) '
      'WHERE equipment_id = ?1',
      [behalten, aufgeben],
    );
    await db.customStatement(
      'UPDATE learning_progress SET equipment_id = ?1 WHERE equipment_id = ?2 '
      'AND NOT EXISTS (SELECT 1 FROM learning_progress WHERE equipment_id = ?1)',
      [behalten, aufgeben],
    );
    await db.customStatement(
      'DELETE FROM learning_progress WHERE equipment_id = ?',
      [aufgeben],
    );

    // Gelernte Schreibweisen sind bare Münze: Wer „CSA Anzug" getippt hat,
    // soll danach das behaltene Gerät treffen. `alias` ist eindeutig, also
    // fällt weg, was es schon gibt.
    await db.customStatement(
      'UPDATE OR IGNORE user_aliases SET equipment_id = ?1 '
      'WHERE equipment_id = ?2',
      [behalten, aufgeben],
    );

    await db.customStatement(
      'UPDATE equipment_instances SET equipment_id = ?1, dirty = 1 '
      'WHERE equipment_id = ?2',
      [behalten, aufgeben],
    );

    await db.customStatement(
      'UPDATE equipment_assignments SET equipment_id = ?1, dirty = 1 '
      'WHERE equipment_id = ?2',
      [behalten, aufgeben],
    );
    // Lagen beide im selben Fach, stehen dort jetzt zwei Zeilen für
    // dasselbe Gerät. Die Stückzahlen addieren sich — es waren zwei
    // getrennt gezählte Hälften derselben Beladung.
    await db.customStatement(
      'UPDATE equipment_assignments SET quantity = ('
      '  SELECT SUM(quantity) FROM equipment_assignments z '
      '  WHERE z.compartment_id = equipment_assignments.compartment_id '
      '    AND z.equipment_id = equipment_assignments.equipment_id) '
      'WHERE equipment_id = ?1 AND id = ('
      '  SELECT MIN(id) FROM equipment_assignments z '
      '  WHERE z.compartment_id = equipment_assignments.compartment_id '
      '    AND z.equipment_id = equipment_assignments.equipment_id)',
      [behalten],
    );
    await db.customStatement(
      'DELETE FROM equipment_assignments WHERE equipment_id = ?1 AND id NOT IN ('
      '  SELECT MIN(id) FROM equipment_assignments '
      '  WHERE equipment_id = ?1 GROUP BY compartment_id)',
      [behalten],
    );

    await (db.delete(db.equipmentItems)
      ..where((t) => t.id.equals(aufgeben))).go();
    // Der überlebende Eintrag steht so noch nicht oben — er trägt jetzt
    // die Beladung von zweien.
    await (db.update(db.equipmentItems)..where(
      (t) => t.id.equals(behalten),
    )).write(const EquipmentItemsCompanion(dirty: Value(true)));
  });
}

/// Führt mehrere Paare nacheinander zusammen.
///
/// ⚠️ **Ketten auflösen.** Drei Schreibweisen desselben Geräts ergeben zwei
/// Paare, und das zweite nennt womöglich eine ID, die das erste schon
/// gelöscht hat. Ohne diese Umleitung liefe es ins Leere — oder schlimmer,
/// auf eine ID, die inzwischen einem anderen Gerät gehört.
Future<void> fuehreAlleZusammen(
  AppDatabase db,
  List<({int behalten, int aufgeben})> paare,
) async {
  final ersetztDurch = <int, int>{};
  int aufgeloest(int id) {
    var aktuell = id;
    // Der Pfad ist so lang wie die Kette; die Schleife endet, weil jede
    // Umleitung auf eine Zeile zeigt, die vorher schon aufgelöst war.
    while (ersetztDurch.containsKey(aktuell)) {
      aktuell = ersetztDurch[aktuell]!;
    }
    return aktuell;
  }

  for (final paar in paare) {
    final behalten = aufgeloest(paar.behalten);
    final aufgeben = aufgeloest(paar.aufgeben);
    if (behalten == aufgeben) continue;
    await fuehreZusammen(db, behalten: behalten, aufgeben: aufgeben);
    ersetztDurch[aufgeben] = behalten;
  }
}
