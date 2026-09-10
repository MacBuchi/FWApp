/// hinweis_weg_test.dart – Wohin ein Hinweis geht (Issue #194).
///
/// **Warum dafür ein eigener Test.** Die Weiche entscheidet zwischen einem
/// öffentlichen GitHub-Issue und dem Briefkasten des eigenen Gerätewarts.
/// Ein Fehler in die eine Richtung ist ein Datenschutzunfall: Der Hinweis
/// „Die Frage von Meier ist falsch, der hat auch den Schlauch nicht
/// gefunden" stünde im öffentlichen Repo. Ein Fehler in die andere Richtung
/// ist bloß unbequem — der Hinweis auf eine mitgelieferte Frage erreicht die
/// Entwicklung nie und wird zwölfmal gemeldet.
///
/// Beide Richtungen stehen deshalb hier, mit dem Grund daneben.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fwapp/core/database/app_database.dart';
import 'package:fwapp/features/knowledge/domain/wissensfrage.dart';
import 'package:fwapp/features/knowledge/presentation/providers/wissen_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<WissensfrageData> frage({
    required Fragenherkunft herkunft,
    String? remoteId,
  }) async {
    final id = await db.wissenDao.insertFrage(WissensfragenCompanion.insert(
      gebiet: 'funk',
      frage: 'Welcher Kanal ist der Anrufkanal?',
      antwortenJson: const Value('["a","b"]'),
      richtigeJson: const Value('[0]'),
      herkunft: Value(herkunft.schluessel),
      stand: const Value('freigegeben'),
      remoteId: Value(remoteId),
    ));
    return (await db.wissenDao.getById(id))!;
  }

  test('mitgelieferte Frage geht an den Bot — sie ist in jeder Wehr dieselbe',
      () async {
    final f = await frage(
        herkunft: Fragenherkunft.mitgeliefert, remoteId: null);
    expect(hinweisWegFuer(f, hatWehr: true), Hinweisweg.bot);
  });

  test('mitgeliefert schlägt alles andere — auch ohne Wehr', () async {
    // Eine mitgelieferte Frage hat auf dem Server nie eine Zeile (siehe
    // wissen_sync.dart: sie wird bewusst nicht hochgeladen). Der Bot-Weg darf
    // deshalb NICHT davon abhängen, ob eine Wehr da ist — sonst fiele der
    // Hinweis im Lokalbetrieb still unter den Tisch.
    final f = await frage(herkunft: Fragenherkunft.mitgeliefert);
    expect(hinweisWegFuer(f, hatWehr: false), Hinweisweg.bot);
  });

  test('eigene Frage der Wehr geht an den Gerätewart, NIE an den Bot',
      () async {
    final f = await frage(
        herkunft: Fragenherkunft.eigen, remoteId: 'abc-123');
    final weg = hinweisWegFuer(f, hatWehr: true);
    expect(weg, Hinweisweg.geraetewart);
    expect(weg, isNot(Hinweisweg.bot),
        reason: 'Ein Hinweis auf eine eigene Frage der Wehr hat in einem '
            'öffentlichen Issue nichts verloren.');
  });

  test('eigene Frage ohne Serverzeile ist nur lokal — es gibt keinen '
      'Empfänger', () async {
    // Noch nie hochgeladen: Der Gerätewart kann sie gar nicht sehen, und
    // ein Hinweis mit `frage_id = null` wäre kein Hinweis, sondern ein
    // Fehlschlag beim Senden.
    final f = await frage(herkunft: Fragenherkunft.eigen, remoteId: null);
    expect(hinweisWegFuer(f, hatWehr: true), Hinweisweg.nurLokal);
  });

  test('eigene Frage ohne Gesamtwehr ist nur lokal', () async {
    final f = await frage(
        herkunft: Fragenherkunft.eigen, remoteId: 'abc-123');
    expect(hinweisWegFuer(f, hatWehr: false), Hinweisweg.nurLokal);
  });
}
