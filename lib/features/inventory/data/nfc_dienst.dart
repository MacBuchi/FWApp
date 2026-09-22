/// nfc_dienst.dart – NFC-Tags lesen und beschreiben (Issue #176).
///
/// **Wozu, wenn es QR schon gibt.** Ein QR-Aufkleber muss angepeilt werden:
/// Kamera drauf, Abstand, Licht. Ein NFC-Tag genügt es zu berühren — im
/// Geräteraum, halb im Dunkeln, mit Handschuhen. Das war der Wunsch hinter
/// #176: mit dem Handy am Gerät entlang statt fünfzehnmal zielen.
///
/// **Was hier NICHT passiert: entscheiden, was ein Code bedeutet.** Wie der
/// Kamera-Bildschirm liefert dieser Dienst nur Zeichenketten. Verknüpfen und
/// Abhaken nehmen danach denselben Weg wie eine Tastatureingabe, durch
/// `normalisiereTagCode`. Eine zweite Auswertung hier hätte zwei Wahrheiten
/// darüber erzeugt, was ein gültiger Code ist.
///
/// **Zwei Kandidaten, in dieser Reihenfolge.** Ein Tag kann beides tragen:
/// einen Text, den wir geschrieben haben, und seine unveränderliche
/// Seriennummer. Billige Aufkleber und Prüfplaketten sind oft
/// schreibgeschützt — dann ist die Seriennummer der Code. Wer nur den Text
/// läse, fände so ein Tag später nie wieder; wer nur die Seriennummer läse,
/// verlöre die beschriebenen. Deshalb kommen beide zurück, und der Aufrufer
/// probiert der Reihe nach.
///
/// ⚠️ **`NfcManager.instance` WIRFT auf jeder anderen Plattform** —
/// `UnsupportedError` schon beim Zugriff auf die Eigenschaft, nicht erst beim
/// Aufruf. Im Web-Build risse das die Seite auf, sobald irgendwo NFC
/// angefasst wird. Genau die Falle aus #210: Ein Plattform-Zweig, den kein
/// Test erreicht. Deshalb geht **jeder** Weg hier zuerst durch
/// [NfcDienst.unterstuetzt], und der fragt `kIsWeb` und die Zielplattform,
/// bevor das Plugin überhaupt berührt wird.
///
/// ⚠️ **Geprüft ist hier nichts außer dem Textformat** (`nfc_text.dart`).
/// NFC gibt es weder im Browser noch im Emulator — was unter dieser Zeile
/// steht, beweist erst ein Gerät. AGENTS.md hält fest, dass die
/// v1.6.0-Abstürze im Gerätepfad saßen.
library;

import 'package:flutter/foundation.dart';
import 'package:fwapp/core/logging/app_logger.dart';
import 'package:fwapp/features/inventory/data/nfc_text.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// Woran es liegt, wenn NFC gerade nicht geht — jeder Fall bekommt einen
/// eigenen Satz, weil „geht nicht" den Gerätewart nicht weiterbringt.
enum NfcLage {
  /// Antenne da und eingeschaltet.
  bereit,

  /// Das Gerät kann es, aber es ist in den Einstellungen aus.
  ausgeschaltet,

  /// Kein NFC in diesem Gerät.
  keineHardware,

  /// Web oder eine Plattform ohne Umsetzung. Kein Fehler, nur kein Weg.
  hierNicht,
}

/// Was von einem Tag gelesen wurde.
class NfcFund {
  /// Das Tag selbst — für [NfcDienst.schreibe].
  ///
  /// ⚠️ Nur gültig, solange die Sitzung läuft und das Tag anliegt. Es
  /// aufzuheben und später zu beschreiben geht ins Leere; deshalb passiert
  /// beides im selben Rückruf.
  final NfcTag tag;

  /// Der Textdatensatz, falls einer drauf steht.
  final String? text;

  /// Die Seriennummer als Code (`NFC-…`), falls das Gerät sie herausgibt.
  final String? seriennummer;

  const NfcFund({required this.tag, this.text, this.seriennummer});

  /// Was als Code in Frage kommt, in der Reihenfolge, in der es probiert
  /// werden soll: erst das Beschriebene, dann die Seriennummer.
  List<String> get kandidaten =>
      [text, seriennummer].nonNulls.where((c) => c.trim().isNotEmpty).toList();
}

/// Wie das Beschreiben ausgegangen ist.
enum NfcSchreibLage {
  geschrieben,

  /// Das Tag lässt sich nicht beschreiben — schreibgeschützt oder kein NDEF.
  /// Kein Fehlschlag: Dann zählt die Seriennummer, und das Tag ist trotzdem
  /// brauchbar.
  schreibgeschuetzt,

  /// Der Code passt nicht in den Speicher des Tags.
  zuKlein,

  /// Abgerissen, zu früh weggezogen, unklar.
  misslungen,
}

class NfcDienst {
  const NfcDienst();

  /// Gibt es auf dieser Plattform überhaupt einen NFC-Weg?
  ///
  /// ⚠️ Muss VOR jedem Zugriff auf `NfcManager.instance` stehen, siehe Kopf.
  /// Nur Android: Die App wird als APK und als Web ausgeliefert, iOS baut
  /// niemand und könnte auch niemand prüfen. Einen ungeprüften zweiten
  /// Gerätepfad mitzuliefern wäre kein Entgegenkommen, sondern eine
  /// Behauptung.
  static bool get unterstuetzt =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<NfcLage> lage() async {
    if (!unterstuetzt) return NfcLage.hierNicht;
    try {
      return switch (await NfcManager.instance.checkAvailability()) {
        NfcAvailability.enabled => NfcLage.bereit,
        NfcAvailability.disabled => NfcLage.ausgeschaltet,
        NfcAvailability.unsupported => NfcLage.keineHardware,
      };
    } catch (e) {
      appLog.w('NFC-Verfügbarkeit nicht feststellbar', error: e);
      return NfcLage.hierNicht;
    }
  }

  /// Startet das Lauschen. [beiTag] läuft für jedes berührte Tag.
  Future<void> starte(void Function(NfcTag tag) beiTag) async {
    if (!unterstuetzt) return;
    await NfcManager.instance.startSession(
      // Alle drei Familien: Welche Sorte Tag jemand kauft, weiß die App
      // nicht, und ein Tag, das nicht einmal erkannt wird, sieht aus wie ein
      // kaputtes Handy.
      pollingOptions: NfcPollingOption.values.toSet(),
      onDiscovered: beiTag,
      // Ohne das piept das Gerät bei jedem Fund. Bei fünfzehn Geräten in
      // einem Fach ist das kein Hinweis mehr, sondern Lärm — die Meldung
      // steht auf dem Bildschirm.
      noPlatformSoundsAndroid: true,
    );
  }

  Future<void> stoppe() async {
    if (!unterstuetzt) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      // Eine Sitzung, die schon zu ist, ist kein Problem — nur beim
      // Verlassen des Bildschirms nicht der Rede wert.
      appLog.d('NFC-Sitzung ließ sich nicht schließen: $e');
    }
  }

  /// Liest Text und Seriennummer von [tag].
  Future<NfcFund> lies(NfcTag tag) async {
    final roh = NfcTagAndroid.from(tag);
    final seriennummer =
        (roh == null || roh.id.isEmpty) ? null : nfcSeriennummerCode(roh.id);

    String? text;
    final ndef = NdefAndroid.from(tag);
    if (ndef != null) {
      try {
        // Erst das frisch Gelesene, sonst das, was beim Erkennen anfiel —
        // ein Tag, das gerade wieder weg ist, liefert oben null.
        final nachricht =
            await ndef.getNdefMessage() ?? ndef.cachedNdefMessage;
        text = _ersterText(nachricht);
      } catch (e) {
        appLog.w('NDEF nicht lesbar', error: e);
      }
    }
    return NfcFund(tag: tag, text: text, seriennummer: seriennummer);
  }

  /// Schreibt [code] als Textdatensatz auf [tag].
  Future<NfcSchreibLage> schreibe(NfcTag tag, String code) async {
    final ndef = NdefAndroid.from(tag);
    if (ndef == null || !ndef.isWritable) {
      return NfcSchreibLage.schreibgeschuetzt;
    }
    final nachricht = NdefMessage(records: [
      NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList([0x54]), // 'T' — Textdatensatz
        identifier: Uint8List(0),
        payload: nfcTextNutzlast(code),
      ),
    ]);
    // Vorher messen statt hinterher scheitern: Ein zu großer Datensatz
    // bricht sonst mitten im Schreiben ab, und was dann auf dem Tag steht,
    // weiß niemand.
    if (nachricht.byteLength > ndef.maxSize) return NfcSchreibLage.zuKlein;
    try {
      await ndef.writeNdefMessage(nachricht);
      return NfcSchreibLage.geschrieben;
    } catch (e) {
      appLog.w('Tag nicht beschreibbar', error: e);
      return NfcSchreibLage.misslungen;
    }
  }

  /// Der erste Textdatensatz einer Nachricht.
  ///
  /// Ein Tag darf mehrere tragen; gemeint ist der erste, den wir verstehen.
  /// Alles andere (URLs, Hersteller-Daten) bleibt liegen — daraus einen Code
  /// zu machen hieße raten.
  static String? _ersterText(NdefMessage? nachricht) {
    for (final r in nachricht?.records ?? const <NdefRecord>[]) {
      if (r.typeNameFormat != TypeNameFormat.wellKnown) continue;
      if (r.type.length != 1 || r.type.first != 0x54) continue;
      final text = nfcTextAusNutzlast(r.payload);
      if (text != null) return text;
    }
    return null;
  }
}
