/// wissen_providers.dart – Zugriff auf die Wissensdatenbank (Issue #174).
///
/// ⚠️ **Ohne Codegen**, wie `anhang_providers.dart` und
/// `dashboard_providers.dart`: `riverpod_generator` bricht mit
/// `InvalidTypeException` ab, sobald ein Provider eine Drift-Datenklasse
/// zurückgibt — die liegt in einer `part`-Datei.
library;

import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/core/database/database_providers.dart';
import 'package:fwapp/core/sync/abteilung_providers.dart';
import 'package:fwapp/core/sync/sync_providers.dart';
import 'package:fwapp/features/knowledge/data/wissen_sync.dart';
import 'package:fwapp/core/utils/json_utils.dart';
import 'package:fwapp/features/game/party/domain/party_frage.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';

final wissenSyncProvider = Provider<WissenSync>((ref) => WissenSync(
      db: ref.watch(appDatabaseProvider),
      client: ref.watch(supabaseClientProvider),
    ));

/// Die Gesamtwehr, der die Fragen gehören. `null` = Lokalbetrieb oder eine
/// Abteilung ohne Wehr — dann bleibt alles auf diesem Gerät, und das ist ein
/// gültiger Zustand, kein Fehler.
///
/// Abgeleitet aus der gerade gezeigten Abteilung, nicht aus der eigenen:
/// Wer über die Quer-Sicht in einer Schwester-Abteilung steht, gehört
/// derselben Wehr an — die Fragen sind dieselben.
final wissenGesamtwehrProvider = Provider<String?>((ref) {
  final abteilungen = ref.watch(abteilungenProvider).value ?? const [];
  if (abteilungen.isEmpty) return null;
  final gewaehlt = ref.watch(selectedAbteilungIdProvider) ??
      ref.watch(myAbteilungIdProvider).value;
  for (final a in abteilungen) {
    if (a.id == gewaehlt) return a.gesamtwehrId;
  }
  return abteilungen.first.gesamtwehrId;
});

/// Alle Fragen, live. Auch die noch nicht freigegebenen — die Übersicht soll
/// zeigen, was aussteht, sonst merkt niemand, dass etwas auf ihn wartet.
final wissensfragenProvider =
    StreamProvider<List<WissensfrageData>>((ref) =>
        ref.watch(wissenDaoProvider).watchAll());

/// Was auf Freigabe wartet — Grundlage des Hinweises für den Gerätewart.
final offeneFragenProvider =
    StreamProvider<List<WissensfrageData>>((ref) =>
        ref.watch(wissenDaoProvider).watchOffen());

/// Nur, was gestellt werden darf.
///
/// ⚠️ Ein StreamProvider, KEIN `FutureProvider`, der den Strom beobachtet:
/// Letzterer wird bei der ersten Emission verworfen, und ein `await` auf
/// sein `.future` kehrt nie zurück. Der Party-Start hing genau daran.
final spielbareFragenProvider =
    StreamProvider<List<WissensfrageData>>((ref) =>
        ref.watch(wissenDaoProvider).watchSpielbare());

/// Wie viele freigegebene Fragen je Gebiet — aus demselben Strom gerechnet,
/// nicht mit einer zweiten Abfrage.
final fragenJeGebietProvider = Provider<Map<String, int>>((ref) {
  final fragen = ref.watch(spielbareFragenProvider).value ?? const [];
  final zaehlung = <String, int>{};
  for (final f in fragen) {
    zaehlung[f.gebiet] = (zaehlung[f.gebiet] ?? 0) + 1;
  }
  return zaehlung;
});

/// Übersetzt eine Datenbankzeile in das Modell der Oberfläche.
Wissensfrage zuWissensfrage(WissensfrageData z) => Wissensfrage(
      id: z.id,
      gebiet: Wissensgebiet.ausSchluessel(z.gebiet) ??
          Wissensgebiet.rechtUndOrganisation,
      frage: z.frage,
      antworten: jsonToStringList(z.antwortenJson),
      richtig: z.richtig,
      erklaerung: z.erklaerung,
      herkunft: Fragenherkunft.ausSchluessel(z.herkunft),
      stand: Fragenstand.ausSchluessel(z.stand),
      eingereichtVon: z.eingereichtVon,
    );

/// Macht aus einer Wissensfrage eine Spielfrage des Party-Modus.
///
/// ⚠️ **Die Antworten werden gemischt, und das ist Pflicht.** `mischePartie`
/// mischt die Reihenfolge der FRAGEN, nicht die Antworten innerhalb einer
/// Frage. Ohne das Mischen hier stünde die richtige Antwort immer an
/// derselben Stelle wie in der Datenbank — wer die Wissensdatenbank einmal
/// durchgeblättert hat, bräuchte danach kein Feuerwehrwissen mehr, nur ein
/// gutes Gedächtnis für Positionen. Die Regel stand schon am Asset-Weg
/// (`UnerwarteteFrage.zuPartyFrage`) und ist beim Umzug beinahe verloren
/// gegangen.
PartyFrage wissensfrageAlsPartyFrage(WissensfrageData z, Random zufall) {
  final antworten = jsonToStringList(z.antwortenJson);
  if (antworten.isEmpty) {
    return PartyFrage(
      art: PartyFrageArt.unerwartet,
      text: z.frage,
      antworten: const [PartyAntwort('—')],
      richtig: 0,
      erklaerung: z.erklaerung,
    );
  }
  final richtigerText = antworten[z.richtig.clamp(0, antworten.length - 1)];
  final gemischt = [...antworten]..shuffle(zufall);
  return PartyFrage(
    art: PartyFrageArt.unerwartet,
    text: z.frage,
    antworten: gemischt.map(PartyAntwort.new).toList(),
    richtig: gemischt.indexOf(richtigerText),
    erklaerung: z.erklaerung,
  );
}

/// Reicht eine Frage ein. Jeder mit Konto darf das — freigegeben wird sie
/// erst vom Gerätewart (Issue #174).
///
/// Sie wird lokal angelegt und als `dirty` markiert; der Abgleich schiebt
/// sie nach. Damit funktioniert Einreichen auch im Funkloch, und das ist
/// kein Zufall: Die App muss ohne Netz vollständig laufen.
Future<int> reicheFrageEin(
  WidgetRef ref, {
  required Wissensgebiet gebiet,
  required String frage,
  required List<String> antworten,
  required int richtig,
  String? erklaerung,
  String? eingereichtVon,
  bool sofortFreigeben = false,
}) async {
  final id = await ref.read(wissenDaoProvider).insertFrage(
        WissensfragenCompanion.insert(
          gebiet: gebiet.schluessel,
          frage: frage.trim(),
          antwortenJson:
              Value(stringListToJson(antworten.map((a) => a.trim()).toList())),
          richtig: Value(richtig),
          erklaerung: Value(erklaerung?.trim().isEmpty ?? true
              ? null
              : erklaerung!.trim()),
          herkunft: Value(Fragenherkunft.eigen.schluessel),
          stand: Value(sofortFreigeben
              ? Fragenstand.freigegeben.schluessel
              : Fragenstand.eingereicht.schluessel),
          eingereichtVon: Value(eingereichtVon),
          dirty: const Value(true),
        ),
      );
  await _abgleichen(ref);
  return id;
}

/// Setzt den Stand einer Frage — freigeben oder ablehnen.
Future<void> setzeStand(
    WidgetRef ref, WissensfrageData f, Fragenstand stand) async {
  await ref.read(wissenDaoProvider).aendere(
        f.id,
        WissensfragenCompanion(
          stand: Value(stand.schluessel),
          dirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
  await _abgleichen(ref);
}

/// Entfernt eine Frage. Mitgeliefertes ist davon ausgenommen — das käme
/// beim nächsten Start ohnehin wieder.
Future<void> entferneFrage(WidgetRef ref, WissensfrageData f) async {
  final wehr = ref.read(wissenGesamtwehrProvider);
  if (wehr == null) {
    await ref.read(wissenDaoProvider).deleteFrage(f.id);
    return;
  }
  await ref.read(wissenSyncProvider).archiviere(f, wehr);
}

/// Schiebt und zieht, soweit es geht. Ohne Gesamtwehr ein No-op.
Future<void> _abgleichen(WidgetRef ref) async {
  final wehr = ref.read(wissenGesamtwehrProvider);
  if (wehr == null) return;
  final sync = ref.read(wissenSyncProvider);
  try {
    await sync.schiebe(wehr);
    await sync.ziehe(wehr);
  } catch (_) {
    // Offline ist kein Fehler: Die Frage steht lokal und ist `dirty`, der
    // nächste Abgleich holt sie nach.
  }
}
