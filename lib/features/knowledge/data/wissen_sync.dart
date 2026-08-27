/// wissen_sync.dart – Der zeilenweise Abgleich der Wissensdatenbank
/// (Issue #174).
///
/// **Warum nicht im Snapshot.** Der Bestands-Sync veröffentlicht die ganze
/// Abteilung auf einmal und ist Einzelschreiber. Die Fragen gehören aber der
/// GESAMTWEHR — zwei Gerätewarte, die veröffentlichen, würden einander
/// überschreiben. Derselbe eigene Weg wie bei den Gerätetypen (Issue #99).
///
/// **Warum ein voller Zug statt eines Cursors.** Eine Wehr hat Dutzende bis
/// wenige hundert Fragen, keine Hunderttausende. Ein inkrementeller Pull
/// spart hier nichts Messbares, kostet aber eine weitere Spalte in
/// `sync_meta` und die Sorte Fehler, die man erst bemerkt, wenn ein Gerät
/// eine Woche offline war.
///
/// **Was NIE hochgeladen wird: mitgelieferte Fragen.** Die stehen auf jedem
/// Gerät im Asset. Sie zu übertragen hieße, denselben Grundstock für jede
/// Wehr ein zweites Mal zu speichern — und beim nächsten App-Update lägen
/// zwei Fassungen nebeneinander.
library;

import 'package:drift/drift.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WissenSync {
  final AppDatabase db;
  final SupabaseClient? client;

  const WissenSync({required this.db, this.client});

  /// Holt die Fragen der Gesamtwehr in den lokalen Bestand.
  ///
  /// Gibt zurück, wie viele Zeilen der Server geliefert hat.
  Future<int> ziehe(String gesamtwehrId) async {
    final c = client;
    if (c == null) return 0;

    final zeilen = List<Map<String, dynamic>>.from(await c
        .from('quiz_questions')
        .select()
        .eq('gesamtwehr_id', gesamtwehrId));

    for (final r in zeilen) {
      final remoteId = r['id'] as String;
      final vorhanden = await db.wissenDao.getByRemoteId(remoteId);

      // Archiviert heißt: hier weg. `deleted_at` gibt es, weil ein Pull
      // harte Löschungen nicht sehen könnte.
      if (r['deleted_at'] != null) {
        if (vorhanden != null) await db.wissenDao.deleteFrage(vorhanden.id);
        continue;
      }

      // ⚠️ Eine lokal geänderte Frage NICHT überschreiben — sie wartet noch
      // aufs Hochladen. Sonst verliert der Einreichende seinen Text, sobald
      // er zwischendurch synchronisiert.
      if (vorhanden != null && vorhanden.dirty) continue;

      await db.wissenDao.upsert(WissensfragenCompanion(
        id: vorhanden == null ? const Value.absent() : Value(vorhanden.id),
        gebiet: Value(r['gebiet'] as String),
        frage: Value(r['frage'] as String),
        antwortenJson: Value(r['antworten_json'] as String),
        richtig: Value((r['richtig'] as num).toInt()),
        erklaerung: Value(r['erklaerung'] as String?),
        herkunft: Value(r['herkunft'] as String),
        stand: Value(r['stand'] as String),
        eingereichtVon: Value(r['eingereicht_von'] as String?),
        remoteId: Value(remoteId),
        remoteUpdatedAt: Value(DateTime.tryParse(r['updated_at'] as String)),
        dirty: const Value(false),
      ));
    }
    return zeilen.length;
  }

  /// Schiebt, was hier entstanden oder geändert wurde.
  ///
  /// Eine neue Frage geht IMMER als `eingereicht` hinaus — die Insert-Policy
  /// lässt nichts anderes zu, und das ist Absicht: Niemand gibt seine eigene
  /// Frage frei. Wer freigeben darf, tut es im zweiten Schritt über das
  /// Update, das die Policy an den Gerätewart bindet.
  Future<int> schiebe(String gesamtwehrId, {String? anzeigename}) async {
    final c = client;
    final nutzer = c?.auth.currentUser;
    if (c == null || nutzer == null) return 0;

    var geschoben = 0;
    for (final f in await db.wissenDao.getAll()) {
      if (!f.dirty) continue;
      // Mitgeliefertes bleibt lokal, siehe Kopf.
      if (f.herkunft == Fragenherkunft.mitgeliefert.schluessel) {
        await db.wissenDao
            .aendere(f.id, const WissensfragenCompanion(dirty: Value(false)));
        continue;
      }

      try {
        if (f.remoteId == null) {
          final angelegt = await c
              .from('quiz_questions')
              .insert({
                'gesamtwehr_id': gesamtwehrId,
                'gebiet': f.gebiet,
                'frage': f.frage,
                'antworten_json': f.antwortenJson,
                'richtig': f.richtig,
                'erklaerung': f.erklaerung,
                'herkunft': f.herkunft,
                'stand': Fragenstand.eingereicht.schluessel,
                'eingereicht_von': anzeigename ?? f.eingereichtVon,
                'created_by': nutzer.id,
              })
              .select()
              .single();

          await db.wissenDao.aendere(
            f.id,
            WissensfragenCompanion(
              remoteId: Value(angelegt['id'] as String),
              remoteUpdatedAt:
                  Value(DateTime.tryParse(angelegt['updated_at'] as String)),
              // Der Server hat das letzte Wort über den Stand.
              stand: Value(angelegt['stand'] as String),
              dirty: const Value(false),
            ),
          );
          // Ein Gerätewart, der die Frage sofort freigeben wollte, tut das
          // im zweiten Zug — das Insert darf es nicht.
          if (f.stand == Fragenstand.freigegeben.schluessel) {
            await _standSetzen(c, angelegt['id'] as String, f.stand, f.id);
          }
        } else {
          await _standSetzen(c, f.remoteId!, f.stand, f.id, ganzeZeile: f);
        }
        geschoben++;
      } catch (e) {
        // Nicht abbrechen: Eine Frage, die der Server ablehnt (fehlendes
        // Recht, kaputte Zeile), darf die übrigen nicht aufhalten. Sie
        // bleibt `dirty` und wird beim nächsten Mal erneut versucht.
        appLog.w('Wissensfrage ${f.id} nicht übertragbar', error: e);
      }
    }
    return geschoben;
  }

  Future<void> _standSetzen(
    SupabaseClient c,
    String remoteId,
    String stand,
    int lokalId, {
    WissensfrageData? ganzeZeile,
  }) async {
    final nutzlast = <String, dynamic>{'stand': stand};
    if (ganzeZeile != null) {
      nutzlast.addAll({
        'gebiet': ganzeZeile.gebiet,
        'frage': ganzeZeile.frage,
        'antworten_json': ganzeZeile.antwortenJson,
        'richtig': ganzeZeile.richtig,
        'erklaerung': ganzeZeile.erklaerung,
      });
    }
    final aktualisiert = await c
        .from('quiz_questions')
        .update(nutzlast)
        .eq('id', remoteId)
        .select()
        .maybeSingle();

    await db.wissenDao.aendere(
      lokalId,
      WissensfragenCompanion(
        remoteId: Value(remoteId),
        remoteUpdatedAt: aktualisiert == null
            ? const Value.absent()
            : Value(DateTime.tryParse(aktualisiert['updated_at'] as String)),
        dirty: const Value(false),
      ),
    );
  }

  /// Archiviert statt zu löschen — siehe Kopf.
  Future<void> archiviere(WissensfrageData f, String gesamtwehrId) async {
    final c = client;
    if (c != null && f.remoteId != null) {
      try {
        await c
            .from('quiz_questions')
            .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', f.remoteId!);
      } catch (e) {
        appLog.w('Wissensfrage ${f.id} nicht archivierbar', error: e);
      }
    }
    await db.wissenDao.deleteFrage(f.id);
  }
}
