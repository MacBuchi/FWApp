/// release_workflow_test.dart – Die Riegel der Release-Kanäle festhalten.
///
/// Alles, was hier geprüft wird, sind einzelne Zeilen YAML. Geht eine davon
/// verloren, kompiliert weiterhin alles, jede CI bleibt grün — und der
/// Ausfall zeigt sich erst im Feld: Die Wehr bekommt wieder an jedem
/// Arbeitstag Update-Hinweise, oder eine Beförderung veröffentlicht
/// Release-Notizen, in denen die halbe Arbeit fehlt. Solche Fehler fängt nur
/// ein Konfigurations-Regressionstest.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Der YAML-Inhalt ohne Kommentarzeilen.
///
/// ⚠️ Ohne das prüft dieser Test Prosa statt Verhalten: Beide Workflows
/// beschreiben in ihren Köpfen ausführlich, was sie bewusst NICHT tun — und
/// jede Verneinung hier („der Web-Deploy steht nicht in der Beförderung")
/// wäre schon an der Erklärung gescheitert, warum er dort nicht steht. Beim
/// ersten Lauf ist genau das passiert, an zwei von fünf Prüfungen.
String ohneKommentare(String yaml) => yaml
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

void main() {
  final release =
      ohneKommentare(File('.github/workflows/release.yml').readAsStringSync());
  final promote =
      ohneKommentare(File('.github/workflows/promote.yml').readAsStringSync());

  group('Release-Kanäle (#154)', () {
    test('jeder Merge veröffentlicht als Prerelease, nie als latest', () {
      expect(
        release,
        contains('prerelease: true'),
        reason:
            'Ohne die Markierung erscheint jeder Merge in /releases/latest — '
            'genau der Zustand, den #154 abgestellt hat.',
      );
      expect(
        release,
        contains('make_latest: false'),
        reason:
            'GitHub markiert das neueste Release sonst TROTZ Prerelease-Flag '
            'als „latest". Die beiden Zeilen gehören zusammen; eine allein '
            'genügt nicht.',
      );
    });

    test('die Beförderung schaltet stabil UND sammelt die Notizen', () {
      expect(promote, contains('--prerelease=false'));
      expect(
        promote,
        contains('--latest'),
        reason:
            'Ohne --latest bliebe das Release zwar kein Prerelease mehr, '
            'aber /releases/latest zeigte weiter auf den alten Stand.',
      );
      expect(
        promote,
        contains('--notes-file release-body.md'),
        reason:
            'Sonst bliebe der automatisch erzeugte Text des einen Merges '
            'stehen, statt der Sammlung seit dem letzten stabilen Stand.',
      );
    });

    test('die Notizen-Sammlung schließt den beförderten Stand aus', () {
      // Ohne diese Bedingung findet ein wiederholter Lauf sich selbst als
      // „letzten stabilen Stand" und sammelt zwischen einer Version und
      // derselben — also nichts. In MitFahrBar genau so passiert.
      expect(
        promote,
        contains(r'if [ "$candidate" != "$TAG" ]'),
        reason:
            'Der zu befördernde Tag muss beim Suchen des letzten stabilen '
            'Standes übersprungen werden, sonst sind die Notizen beim '
            'zweiten Lauf leer.',
      );
    });

    test('die Beförderung prüft ihr Ergebnis dort nach, wo die App fragt', () {
      expect(
        promote,
        contains('releases/latest'),
        reason:
            'Der Lauf muss gegen denselben Endpunkt gegenprüfen, den '
            'update_check.dart abfragt — sonst meldet er Erfolg, während '
            'die Geräte weiter den alten Stand sehen.',
      );
      expect(
        promote,
        isNot(contains('--json isLatest')),
        reason:
            'Das Feld gibt es in neueren gh-Fassungen nicht mehr; in '
            'MitFahrBar riss der Lauf daran ab, NACH dem Umschalten.',
      );
    });

    test('der Web-Deploy bleibt bewusst beim Merge, nicht bei der Beförderung',
        () {
      // Die bewusste Abweichung von MitFahrBar (dort deployt die Beförderung
      // GitHub Pages). FWApp liefert das Web über den web-dist-Branch aus,
      // und im Web gibt es keine Update-Hinweise — die Kanaltrennung löst
      // ein Android-Problem. Der Test steht hier, damit die Abweichung als
      // Entscheidung erkennbar bleibt und niemand sie als Versehen
      // „nachzieht".
      expect(
        release,
        contains('git push --force origin web-dist'),
        reason:
            'Das Web-Bündel gehört weiterhin in den Merge-Lauf: Die PWA hat '
            'keinen Update-Hinweis, den man bündeln müsste, und der '
            'Autodeploy der VM zieht es vom web-dist-Branch.',
      );
      expect(
        promote,
        isNot(contains('web-dist')),
        reason:
            'Wandert der Web-Deploy in die Beförderung, steht zwischen zwei '
            'Beförderungen der alte Stand im Browser — entschieden am '
            '2026-08-21 dagegen.',
      );
    });
  });
}
