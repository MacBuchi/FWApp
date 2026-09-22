/// inventory_providers.dart – Inventurassistent: Session anlegen (mit Soll-
/// Snapshot je Zuweisung), Prüfstatus setzen, Session abschließen.
/// Schichtung: bewusst ohne data/domain-Schicht, direkter DAO-Zugriff —
/// Inventurdaten sind rein lokal und werden nicht synchronisiert
/// (siehe CONTRIBUTING.md „Schichtung je Feature").
library;
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/features/inventory/data/inventory_export.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/inventory/data/tag_code.dart';
import 'package:fwapp/features/vehicle/presentation/providers/vehicle_providers.dart';

/// Live checks of a session (stream).
final inventoryChecksProvider =
    StreamProvider.family<List<InventoryCheckData>, int>((ref, sessionId) =>
        ref.watch(inventoryDaoProvider).watchChecks(sessionId));

/// Aggregated progress/result for a session.
class InventorySummary {
  final int total;
  final int checked; // status != open
  final int ok;
  final int missing;
  final int damaged;
  final int repair;

  const InventorySummary({
    required this.total,
    required this.checked,
    required this.ok,
    required this.missing,
    required this.damaged,
    required this.repair,
  });

  factory InventorySummary.from(List<InventoryCheckData> checks) {
    var ok = 0, missing = 0, damaged = 0, repair = 0, checked = 0;
    for (final c in checks) {
      if (c.status == InventoryChecks.statusOpen) continue;
      checked++;
      switch (c.status) {
        case InventoryChecks.statusOk:
          ok++;
        case InventoryChecks.statusMissing:
          missing++;
        case InventoryChecks.statusDamaged:
          damaged++;
        case InventoryChecks.statusRepair:
          repair++;
      }
    }
    return InventorySummary(
        total: checks.length,
        checked: checked,
        ok: ok,
        missing: missing,
        damaged: damaged,
        repair: repair);
  }

  bool get complete => total > 0 && checked == total;

  /// Zählt „in Reparatur" bewusst MIT: Der Gerätewart muss auch das
  /// nachhalten, und im Fach liegt das Gerät so wenig wie ein fehlendes.
  bool get hasIssues => missing > 0 || damaged > 0 || repair > 0;

  /// Die Zustände, die im Bericht als Abweichung erscheinen.
  static const abweichendeStatus = {
    InventoryChecks.statusMissing,
    InventoryChecks.statusDamaged,
    InventoryChecks.statusRepair,
  };
}

/// Kopfdaten des Berichts — alles, was nicht in den Prüfzeilen steht.
class InventurBerichtKopf {
  final String fahrzeug;

  /// Der Zeitpunkt, der im Bericht steht: der Abschluss, solange es einen
  /// gibt, sonst der Beginn. Der Bericht lässt sich teilen, BEVOR die
  /// Inventur abgeschlossen ist — dann ist das Startdatum die einzige
  /// ehrliche Angabe.
  final DateTime zeitpunkt;

  const InventurBerichtKopf({required this.fahrzeug, required this.zeitpunkt});
}

/// Die geführten Einheiten je Prüfzeile, für den Bericht (Issue #178).
///
/// Nur die Einheiten, die im Fach DIESER Zeile liegen: Dasselbe Gerät kann
/// in zwei Fächern stehen, und dann gehört jede Einheit in genau eine
/// Zeile — dieselbe Regel wie beim Abhaken.
///
/// Drei Abfragen für den ganzen Bericht, nicht eine je Zeile: Ein
/// Fahrzeugbericht hat gut hundert Zeilen.
final inventurEinheitenProvider =
    FutureProvider.family<Map<int, List<InventurEinheit>>, int>(
        (ref, sessionId) async {
  final db = ref.watch(appDatabaseProvider);
  final checks = await db.inventoryDao.getChecks(sessionId);
  final alleEinheiten = await db.inspectionDao.getAllInstances();

  final codes = <int, List<String>>{};
  for (final t in await db.tagDao.alleTags()) {
    (codes[t.instanceId] ??= []).add(t.code);
  }

  return {
    for (final c in checks)
      c.id: [
        for (final e in alleEinheiten)
          if (e.equipmentId == c.equipmentId &&
              e.compartmentId == c.compartmentId)
            InventurEinheit(
              id: e.id,
              kennung: e.identifier,
              codes: codes[e.id] ?? const [],
            ),
      ],
  };
});

final inventurBerichtKopfProvider =
    FutureProvider.family<InventurBerichtKopf, int>((ref, sessionId) async {
  final session = await ref.watch(inventoryDaoProvider).getSession(sessionId);
  if (session == null) {
    return InventurBerichtKopf(fahrzeug: '', zeitpunkt: DateTime.now());
  }
  final fahrzeug =
      await ref.watch(vehicleDetailProvider(session.vehicleId).future);
  return InventurBerichtKopf(
    fahrzeug: fahrzeug?.name ?? 'Fahrzeug ${session.vehicleId}',
    zeitpunkt: session.finishedAt ?? session.startedAt,
  );
});

/// Was beim Abhaken per Code herauskam.
sealed class AbhakErgebnis {
  const AbhakErgebnis();
}

/// Abgehakt — mit dem, was der Nutzer zur Bestätigung sehen will.
class Abgehakt extends AbhakErgebnis {
  final String geraet;
  final String fach;

  /// Wie viele Stück jetzt gezählt sind, und wie viele es sein sollen.
  final int ist;
  final int soll;
  const Abgehakt(this.geraet, this.fach, this.ist, this.soll);
}

/// Diese Einheit war schon gezählt — derselbe Aufkleber ein zweites Mal.
///
/// Kein Fehler, sondern der Normalfall beim Scannen: Die Kamera liest
/// denselben Code, solange er im Bild ist.
class SchonGezaehlt extends AbhakErgebnis {
  final String geraet;
  final String fach;
  final int ist;
  final int soll;
  const SchonGezaehlt(this.geraet, this.fach, this.ist, this.soll);
}

/// Der Code ist an keiner Einheit hinterlegt.
class CodeUnbekannt extends AbhakErgebnis {
  const CodeUnbekannt();
}

/// Der Code gehört zu einem Gerät, das in dieser Inventur nicht vorkommt —
/// anderes Fahrzeug, oder seit dem Start der Sitzung umgeräumt.
class CodeNichtInDieserInventur extends AbhakErgebnis {
  final String geraet;
  const CodeNichtInDieserInventur(this.geraet);
}

/// Es stand nichts Verwertbares da.
class CodeLeer extends AbhakErgebnis {
  const CodeLeer();
}

/// Was nach einem abgehakten Code über dem Bild steht.
///
/// Steht hier und nicht dreimal in den Bildschirmen: Kamera, Tastatur und
/// NFC (#176) liefern denselben Code auf drei Wegen, und die Meldung darf
/// nicht davon abhängen, welchen jemand genommen hat. Vor der dritten
/// Fassung war es zweimal derselbe `switch` — AGENTS.md, „Zweitverwendung =
/// Extraktion".
String abhakMeldung(AbhakErgebnis ergebnis) => switch (ergebnis) {
      Abgehakt(:final geraet, :final fach, :final ist, :final soll) =>
        '$geraet · $fach — $ist von $soll',
      SchonGezaehlt(:final geraet, :final ist, :final soll) =>
        '$geraet war schon gezählt — weiterhin $ist von $soll',
      CodeUnbekannt() => 'Dieser Code klebt auf keinem erfassten Gerät.',
      CodeNichtInDieserInventur(:final geraet) =>
        '$geraet gehört nicht zu diesem Fahrzeug.',
      CodeLeer() => 'Da stand kein Code.',
    };

class InventoryService {
  final AppDatabase db;
  InventoryService(this.db);

  /// Resumes an open session for [vehicleId] or creates a new one, snapshotting
  /// the current Soll-Beladung (label, equipment name, target quantity).
  Future<int> startOrResume(int vehicleId) async {
    final open = await db.inventoryDao.getOpenSession(vehicleId);
    if (open != null) return open.id;

    final sessionId = await db.inventoryDao.createSession(
        InventorySessionsCompanion.insert(vehicleId: vehicleId));

    final compartments = await db.compartmentDao.getByVehicle(vehicleId);
    final checks = <InventoryChecksCompanion>[];
    for (final c in compartments) {
      final assignments = await db.assignmentDao.getByCompartment(c.id);
      for (final a in assignments) {
        final eq = await db.equipmentDao.getById(a.equipmentId);
        checks.add(InventoryChecksCompanion.insert(
          sessionId: sessionId,
          equipmentId: Value(a.equipmentId),
          compartmentId: Value(c.id),
          equipmentName: eq?.name ?? 'Gerät ${a.equipmentId}',
          compartmentLabel: c.label,
          targetQuantity: Value(a.quantity),
        ));
      }
    }
    if (checks.isNotEmpty) await db.inventoryDao.insertChecks(checks);
    return sessionId;
  }

  Future<void> setStatus(int checkId, String status,
          {int? actualQuantity, String? note}) =>
      db.inventoryDao.updateCheck(
        checkId,
        InventoryChecksCompanion(
          status: Value(status),
          actualQuantity: Value(actualQuantity),
          note: note == null ? const Value.absent() : Value(note),
        ),
      );

  /// Hakt das Gerät ab, auf dem [roh] klebt (Issues #177/#179).
  ///
  /// **Zählt hoch statt zu setzen.** Bei „Soll 4" wird viermal gescannt, und
  /// jeder Scan ist ein gefundenes Stück. Auf „vollständig" springt die Zeile
  /// erst, wenn das Soll erreicht ist — vorher bleibt sie offen, sonst
  /// meldete der erste von vier Pressluftatmern das Fach als fertig.
  ///
  /// Das Zählen läuft über die EINHEIT, nicht über die Zeile: Zweimal
  /// denselben Aufkleber zu scannen erhöht nichts, weil dieselbe Einheit
  /// nicht zweimal daliegt.
  /// Hakt ab, was von einem NFC-Tag kam (Issue #176).
  ///
  /// **Warum mehrere Kandidaten.** Ein Tag trägt bis zu zwei Schlüssel: den
  /// Text, den wir daraufgeschrieben haben, und seine unveränderliche
  /// Seriennummer. Welcher davon verknüpft ist, hängt daran, ob sich das Tag
  /// beschreiben ließ — schreibgeschützte Aufkleber und Prüfplaketten hängen
  /// an der Seriennummer, die übrigen am Text.
  ///
  /// Nur den ersten zu probieren wäre der stille Fehler: Ein Tag, das schon
  /// eine fremde Aufschrift trägt und über seine Seriennummer verknüpft ist,
  /// meldete dann „klebt auf keinem erfassten Gerät" — obwohl es klebt.
  ///
  /// Der erste Kandidat, der irgendwo hinzeigt, gewinnt. Zeigt keiner
  /// hin, kommt die Antwort zum ersten zurück, damit die Meldung nicht von
  /// der Reihenfolge abhängt.
  Future<AbhakErgebnis> hakeKandidatenAb(
      int sessionId, List<String> kandidaten) async {
    AbhakErgebnis? erste;
    for (final kandidat in kandidaten) {
      final ergebnis = await hakeCodeAb(sessionId, kandidat);
      if (ergebnis is! CodeUnbekannt && ergebnis is! CodeLeer) return ergebnis;
      erste ??= ergebnis;
    }
    return erste ?? const CodeLeer();
  }

  Future<AbhakErgebnis> hakeCodeAb(int sessionId, String roh) async {
    final code = normalisiereTagCode(roh);
    if (code == null) return const CodeLeer();

    final tag = await db.tagDao.findByCode(code);
    if (tag == null) return const CodeUnbekannt();
    final einheit = await db.tagDao.getInstanceById(tag.instanceId);
    if (einheit == null) return const CodeUnbekannt();
    final geraetename =
        (await db.equipmentDao.getById(einheit.equipmentId))?.name ??
            'Gerät ${einheit.equipmentId}';

    final checks = await db.inventoryDao.getChecks(sessionId);
    final passend = checks.where((c) => c.equipmentId == einheit.equipmentId);
    if (passend.isEmpty) return CodeNichtInDieserInventur(geraetename);

    // Das Fach der Einheit gewinnt, wenn es eines gibt — dasselbe Gerät kann
    // in zwei Fächern liegen, und dann ist die Einheit die genauere Angabe.
    final check = passend.firstWhere(
      (c) => c.compartmentId == einheit.compartmentId,
      orElse: () => passend.first,
    );

    // Die Menge der schon gezählten Einheiten ist die Wahrheit, nicht die
    // Zahl daneben: Nur so ist derselbe Aufkleber zweimal derselbe.
    final gezaehlt = _leseEinheiten(check.countedInstancesJson);
    if (gezaehlt.contains(einheit.id)) {
      return SchonGezaehlt(geraetename, check.compartmentLabel,
          gezaehlt.length, check.targetQuantity);
    }
    gezaehlt.add(einheit.id);

    final ist = gezaehlt.length;
    final vollstaendig = ist >= check.targetQuantity;
    await db.inventoryDao.updateCheck(
      check.id,
      InventoryChecksCompanion(
        status: Value(vollstaendig
            ? InventoryChecks.statusOk
            : InventoryChecks.statusOpen),
        actualQuantity: Value(ist),
        countedInstancesJson: Value(jsonEncode(gezaehlt.toList()..sort())),
      ),
    );
    return Abgehakt(
        geraetename, check.compartmentLabel, ist, check.targetQuantity);
  }

  /// Liest die Einheiten-Menge. Ein kaputter oder leerer Wert ist eine leere
  /// Menge, kein Absturz mitten in einer Inventur.
  Set<int> _leseEinheiten(String json) {
    try {
      final roh = jsonDecode(json);
      if (roh is! List) return <int>{};
      return roh.whereType<int>().toSet();
    } catch (e) {
      appLog.w('Gezählte Einheiten unlesbar, beginne leer', error: e);
      return <int>{};
    }
  }

  Future<void> finish(int sessionId, {String doneBy = ''}) =>
      db.inventoryDao.finishSession(sessionId, doneBy: doneBy);

  Future<void> discard(int sessionId) =>
      db.inventoryDao.deleteSession(sessionId);
}

final inventoryServiceProvider = Provider<InventoryService>(
    (ref) => InventoryService(ref.watch(appDatabaseProvider)));
