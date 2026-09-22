/// zeilen_sync.dart – Die Tabellen, die NEBEN dem Snapshot laufen, an einer
/// Stelle (Issues #182/#177).
///
/// **Warum es diese Datei gibt.** „Den Bestand aktualisieren" stand an drei
/// Stellen ausgeschrieben — beim Start (`main.dart`), hinter „Jetzt
/// aktualisieren" (`settings_screen.dart`) und beim Abteilungswechsel
/// (`abteilung_providers.dart`). Zwei davon zogen die Unterlagen und die
/// Codes, die dritte nicht. Gemerkt hat das niemand: Der Gerätewart schaltet
/// auf eine Schwester-Abteilung, öffnet dort die Inventur und scannt ins
/// Leere — die Fahrzeuge sind da, die Codes nicht.
///
/// Drei Kopien einer Liste sind zwei zu viel. Diese hier ist **die** Liste:
/// Wer einen weiteren zeilenweisen Weg baut, trägt ihn hier ein und ist
/// fertig.
///
/// **Warum nicht einfach alles in den Snapshot.** ⚠️ Weil
/// `publish_snapshot` die Zeilen der Abteilung ersetzt und ein Alt-Client,
/// der eine Tabelle nicht kennt, sie damit leeren würde — bei den Unterlagen
/// wären das hochgeladene Dokumente, bei den Codes jeder aufgeklebte
/// Aufkleber. Die lange Fassung steht im Kopf von `sync_service.dart`.
///
/// **Warum die Dienste als Parameter und nicht über `ref`.** Aufgerufen wird
/// das aus einem Provider (`Ref`), aus einem Widget (`WidgetRef`) und aus dem
/// Umschalter — und die beiden Ref-Arten sind in Riverpod 3 keine gemeinsame
/// Schnittstelle mehr. Dieselbe Bauform wie vorher `anhaengeSynchronisieren`.
///
/// ⚠️ **Immer NACH dem Snapshot aufrufen.** Ein Code zeigt auf eine
/// Geräte-Einheit, und die kommt von dort. Andersherum findet der Zug die
/// Einheit nicht und lässt den Code liegen (`tag_sync.dart`).
library;

import 'package:fwapp/features/inventory/data/tag_sync.dart';
import 'package:fwapp/features/vehicle/data/anhang_speicher.dart';

/// Holt alles, was neben dem Snapshot läuft, für [abteilung].
///
/// Ohne Abteilung ein No-op — die App läuft lokal weiter.
Future<void> zeilenweiseSynchronisieren({
  required AnhangSpeicher anhaenge,
  required TagSync tags,
  required String? abteilung,
}) async {
  if (abteilung == null) return;

  // Unterlagen am Fahrzeug (#182): ziehen, dann nachreichen, was offline
  // entstanden ist.
  await anhaenge.zieheAnhaenge(abteilung);
  await anhaenge.nachreichen(abteilungId: abteilung);

  // Codes an den Geräten (#177): erst schieben, dann ziehen — sonst
  // überschreibt der Zug einen Code, der hier gerade erst vergeben wurde.
  await tags.schiebe(abteilung);
  await tags.ziehe(abteilung);
}
