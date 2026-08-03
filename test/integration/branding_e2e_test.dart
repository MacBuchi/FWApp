/// branding_e2e_test.dart – Kopfbereich der Gesamtwehr (#57 P5) gegen den
/// LOKALEN Supabase-Stack (`supabase start`). Überspringt sich selbst, wenn er
/// nicht läuft.
///
/// Bewiesen wird hier, was kein Widget-Test beweisen kann: dass die Grenze
/// wirklich beim Feuerwehrkommandanten liegt und nicht beim Gerätewart, dass
/// eine fremde Wehr ihren Kopfbereich nicht herausgibt, und dass die Tabelle
/// keinen Weg am geprüften RPC vorbei hat.
///
/// Braucht die lokalen Testkonten aus tool/setup_local_supabase.sh:
///   admin@fw.local / geraetewart@fw.local / member@fw.local, pw test1234
library;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

/// Derselbe öffentlich dokumentierte Demo-Key wie in sync_e2e_test.dart —
/// in jedem lokalen Stack identisch, kein Geheimnis.
final _serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

Future<bool> _stackAvailable() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse('$_url/auth/v1/health'));
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return response.statusCode < 500;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  if (!await _stackAvailable()) {
    test('branding e2e', () {},
        skip: 'Lokaler Supabase-Stack läuft nicht (supabase start).');
    return;
  }

  late SupabaseClient kommandantClient;
  late SupabaseClient gwClient;
  late SupabaseClient memberClient;

  Future<T> asService<T>(Future<T> Function(SupabaseClient) body) async {
    final service = SupabaseClient(_url, _serviceRoleKey);
    try {
      return await body(service);
    } finally {
      await service.dispose();
    }
  }

  late String gesamtwehrId;
  late String fremdeGesamtwehrId;

  /// Eigene Abteilung in der eigenen Gesamtwehr.
  ///
  /// ⚠️ Bewusst NICHT die Spiegel-Abteilung: `flutter test` lässt Testdateien
  /// nebenläufig laufen, und sync_e2e_test hängt dieselbe Spiegel-Abteilung an
  /// seine eigene Gesamtwehr und löst sie danach wieder. Wer sich hier
  /// daranhängt, verliert seine Leserechte mitten im Lauf — je nach
  /// Reihenfolge, also sporadisch. Dieser Test fasst nur an, was er selbst
  /// angelegt hat.
  late String abteilungId;

  setUpAll(() async {
    kommandantClient = SupabaseClient(_url, _anonKey);
    gwClient = SupabaseClient(_url, _anonKey);
    memberClient = SupabaseClient(_url, _anonKey);
    await kommandantClient.auth
        .signInWithPassword(email: 'admin@fw.local', password: 'test1234');
    await gwClient.auth.signInWithPassword(
        email: 'geraetewart@fw.local', password: 'test1234');
    await memberClient.auth
        .signInWithPassword(email: 'member@fw.local', password: 'test1234');

    await asService((s) async {
      final gw = await s
          .from('gesamtwehren')
          .insert({'name': 'GW Branding', 'slug': 'gw-branding'})
          .select('id')
          .single();
      gesamtwehrId = gw['id'] as String;

      // Eine zweite Wehr, zu der KEINES der Testkonten gehört — an ihr zeigt
      // sich, ob RLS wirklich je Wehr trennt.
      final fremd = await s
          .from('gesamtwehren')
          .insert({'name': 'GW Fremd', 'slug': 'gw-fremd'})
          .select('id')
          .single();
      fremdeGesamtwehrId = fremd['id'] as String;

      final abt = await s
          .from('abteilungen')
          .insert({
            'name': 'Abteilung Branding',
            'slug': 'abteilung-branding',
            'status': 'active',
            'gesamtwehr_id': gesamtwehrId,
          })
          .select('id')
          .single();
      abteilungId = abt['id'] as String;

      // Gerätewart und Mitglied gehören zur Wehr — darüber greift
      // `can_read_gesamtwehr`. Der Gerätewart hat damit dieselbe Schreibrolle
      // am geteilten Gerätebestand wie in Stufe ②, und trotzdem darf er den
      // Kopfbereich nicht anfassen: genau das ist hier zu zeigen.
      await s.from('memberships').upsert([
        {
          'user_id': gwClient.auth.currentUser!.id,
          'abteilung_id': abteilungId,
          'role': 'geraetewart',
        },
        {
          'user_id': memberClient.auth.currentUser!.id,
          'abteilung_id': abteilungId,
          'role': 'member',
        },
      ]);

      // admin@fw.local wird Feuerwehrkommandant — der Gerätewart bewusst
      // NICHT, das ist der ganze Punkt dieses Tests.
      await s.from('gesamtwehr_kommandanten').upsert({
        'user_id': kommandantClient.auth.currentUser!.id,
        'gesamtwehr_id': gesamtwehrId,
      });
    });
  });

  tearDownAll(() async {
    await asService((s) async {
      await s.from('gesamtwehr_branding').delete().inFilter(
          'gesamtwehr_id', [gesamtwehrId, fremdeGesamtwehrId]);
      await s.from('memberships').delete().eq('abteilung_id', abteilungId);
      await s.from('abteilungen').delete().eq('id', abteilungId);
      await s
          .from('gesamtwehren')
          .delete()
          .inFilter('id', [gesamtwehrId, fremdeGesamtwehrId]);
    });
    await kommandantClient.dispose();
    await gwClient.dispose();
    await memberClient.dispose();
  });

  test('der Feuerwehrkommandant pflegt den Kopfbereich', () async {
    final zeile = await kommandantClient.rpc('set_gesamtwehr_branding', params: {
      'gw': gesamtwehrId,
      'neuer_titel': 'Freiwillige Feuerwehr Musterstadt',
      'neuer_text': 'Übung am Dienstag, 19 Uhr.',
      'neues_bild': 'supabase://gesamtwehr-branding/$gesamtwehrId/1700.jpg',
    });
    expect(zeile['title'], 'Freiwillige Feuerwehr Musterstadt');
    expect(zeile['welcome_text'], 'Übung am Dienstag, 19 Uhr.');
    expect(zeile['image_path'],
        'supabase://gesamtwehr-branding/$gesamtwehrId/1700.jpg');
  });

  test('der Gerätewart derselben Wehr darf NICHT — er pflegt Geräte, nicht '
      'den Auftritt', () async {
    // Gegenprobe zur Stufe ②: Denselben geteilten Gerätebestand DARF er
    // schreiben. Die Grenze verläuft hier bewusst anders.
    await expectLater(
      gwClient.rpc('set_gesamtwehr_branding', params: {
        'gw': gesamtwehrId,
        'neuer_titel': 'Übernommen',
        'neuer_text': null,
        'neues_bild': null,
      }),
      throwsA(isA<PostgrestException>().having((e) => e.message, 'message',
          contains('feuerwehrkommandant'))),
    );

    // Und der Bestand steht unverändert.
    final zeile = await kommandantClient
        .from('gesamtwehr_branding')
        .select('title')
        .eq('gesamtwehr_id', gesamtwehrId)
        .single();
    expect(zeile['title'], 'Freiwillige Feuerwehr Musterstadt');
  });

  test('jedes Mitglied der Wehr liest den Kopfbereich', () async {
    final zeile = await memberClient
        .from('gesamtwehr_branding')
        .select('title, welcome_text')
        .eq('gesamtwehr_id', gesamtwehrId)
        .maybeSingle();
    expect(zeile, isNotNull);
    expect(zeile!['welcome_text'], 'Übung am Dienstag, 19 Uhr.');
  });

  test('der Kopfbereich einer fremden Wehr bleibt unsichtbar', () async {
    await asService((s) => s.from('gesamtwehr_branding').insert({
          'gesamtwehr_id': fremdeGesamtwehrId,
          'title': 'Geheime Nachbarwehr',
        }));

    // Weder der Kommandant der eigenen Wehr noch das Mitglied sehen sie.
    for (final client in [kommandantClient, memberClient]) {
      final zeilen =
          await client.from('gesamtwehr_branding').select('gesamtwehr_id');
      expect(
        zeilen.map((r) => r['gesamtwehr_id']),
        isNot(contains(fremdeGesamtwehrId)),
      );
    }
  });

  test('an der RPC vorbei geht nichts — die Tabelle hat keine Schreib-Policy',
      () async {
    // Auch der Kommandant kommt nur über die geprüfte Funktion hinein. Ohne
    // Policy liefert PostgREST für den Insert einen 42501.
    await expectLater(
      kommandantClient.from('gesamtwehr_branding').insert({
        'gesamtwehr_id': gesamtwehrId,
        'title': 'Direkt geschrieben',
      }),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      kommandantClient
          .from('gesamtwehr_branding')
          .update({'title': 'Direkt geändert'}).eq(
              'gesamtwehr_id', gesamtwehrId),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('NULL heißt gelöscht, nicht unverändert', () async {
    // Die Nutzlast trägt immer den vollen Datensatz. Wer nur den Titel ändert,
    // schickt Text und Bild mit — sonst stünde hier plötzlich das alte Bild
    // wieder, obwohl der Kommandant es entfernt hat.
    final zeile = await kommandantClient.rpc('set_gesamtwehr_branding', params: {
      'gw': gesamtwehrId,
      'neuer_titel': 'Nur noch der Titel',
      'neuer_text': null,
      'neues_bild': null,
    });
    expect(zeile['title'], 'Nur noch der Titel');
    expect(zeile['welcome_text'], isNull);
    expect(zeile['image_path'], isNull);
  });

  test('leere Eingaben werden zu NULL, nicht zu leeren Zeichenketten',
      () async {
    // Sonst hielte die App einen Kopf für gepflegt, der nur aus Leerzeichen
    // besteht — und reservierte auf jeder Startseite Platz dafür.
    final zeile = await kommandantClient.rpc('set_gesamtwehr_branding', params: {
      'gw': gesamtwehrId,
      'neuer_titel': '   ',
      'neuer_text': '',
      'neues_bild': null,
    });
    expect(zeile['title'], isNull);
    expect(zeile['welcome_text'], isNull);
  });

  group('Bucket gesamtwehr-branding', () {
    // Ein winziges, gültiges JPEG-Gerüst reicht — geprüft wird die Policy,
    // nicht der Bildinhalt.
    final bytes = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, //
      ...List<int>.filled(64, 0x08),
      0xFF, 0xD9,
    ]);

    test('der Kommandant lädt in den Ordner seiner Wehr', () async {
      final objekt = '$gesamtwehrId/e2e.jpg';
      await kommandantClient.storage.from('gesamtwehr-branding').uploadBinary(
            objekt,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      addTearDown(() => asService((s) =>
          s.storage.from('gesamtwehr-branding').remove([objekt])));

      // Und jedes Mitglied der Wehr darf es sehen.
      final geladen = await memberClient.storage
          .from('gesamtwehr-branding')
          .download(objekt);
      expect(geladen, isNotEmpty);
    });

    test('der Gerätewart darf nicht in den Branding-Bucket', () async {
      await expectLater(
        gwClient.storage.from('gesamtwehr-branding').uploadBinary(
              '$gesamtwehrId/verboten.jpg',
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            ),
        throwsA(isA<StorageException>()),
      );
    });

    test('auch der Kommandant kommt nicht in den Ordner einer fremden Wehr',
        () async {
      await expectLater(
        kommandantClient.storage.from('gesamtwehr-branding').uploadBinary(
              '$fremdeGesamtwehrId/uebernahme.jpg',
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            ),
        throwsA(isA<StorageException>()),
      );
    });

    test('ein Ordnername ohne UUID kommt nicht in den Bucket', () async {
      await expectLater(
        kommandantClient.storage.from('gesamtwehr-branding').uploadBinary(
              'kein-ordner-mit-uuid/x.jpg',
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            ),
        throwsA(isA<StorageException>()),
      );
    });

    test('die Gerätefotos bleiben lesbar — die Branding-Policy stolpert nicht '
        'über deren Objektnamen', () async {
      // Regressionswache für den zweiten Bucket: Der Branding-Bucket kommt in
      // dieselbe Tabelle storage.objects, und seine Policies werden beim Lesen
      // mit ausgewertet. Dieser Test hält fest, dass die Gerätefotos davon
      // unberührt bleiben.
      //
      // ⚠️ Er ist ausdrücklich KEIN Beweis dafür, dass der Cast in
      // `branding_objekt_gesamtwehr` ein Auffangnetz braucht: Mit rohem Cast
      // lief er ebenfalls grün, weil Postgres `bucket_id` zuerst auswertete.
      // Warum das Netz trotzdem drinbleibt, steht in der Migration.
      const objekt = 'eq_99999_e2e.jpg';
      await kommandantClient.storage.from('equipment-images').uploadBinary(
            objekt,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      addTearDown(() =>
          asService((s) => s.storage.from('equipment-images').remove([objekt])));

      final geladen =
          await memberClient.storage.from('equipment-images').download(objekt);
      expect(geladen, isNotEmpty);

      final liste = await memberClient.storage.from('equipment-images').list();
      expect(liste.map((f) => f.name), contains(objekt));
    });
  });

  test('eine Wehr, deren Kommandant man nicht ist, bleibt unbeschreibbar',
      () async {
    await expectLater(
      kommandantClient.rpc('set_gesamtwehr_branding', params: {
        'gw': fremdeGesamtwehrId,
        'neuer_titel': 'Übernahme',
        'neuer_text': null,
        'neues_bild': null,
      }),
      throwsA(isA<PostgrestException>().having((e) => e.message, 'message',
          contains('feuerwehrkommandant'))),
    );
  });
}
