/// zugang_teilen.dart – Die Nachrichten, mit denen ein Zugang weitergegeben
/// wird (Issue #165).
///
/// Reiner Text, bewusst ohne Widget: Was in einem WhatsApp-Verlauf landet,
/// gehört an EINE testbare Stelle. Zwei Wege, und der Unterschied zwischen
/// ihnen ist der ganze Punkt:
///
/// - **Persönlicher Zugang.** Das Initialpasswort vom Zugangszettel ist ein
///   Einmal-Schlüssel: Der Router erzwingt beim ersten Anmelden einen
///   eigenen (`must_change_password`, nicht umgehbar), danach ist die
///   Nachricht wertlos. Genau deshalb darf sie überhaupt durch einen Chat
///   wandern.
/// - **Demo-Zugang.** Ein festes, lesendes Konto in der erfundenen Wehr
///   „Feuerwehr Freiwilligen". Beliebig oft teilbar, weil dahinter kein
///   einziges echtes Wehrdatum liegt.
///
/// ⚠️ **Kein geteiltes Gastkonto in der echten Wehr.** Das wäre die einzige
/// Variante, die den Pflichtwechsel abschalten müsste — dann läge ein
/// dauerhaft gültiger Zugang zum echten Bestand in einem Chatverlauf,
/// Weiterleiten sieht man nicht, und Widerrufen träfe alle gleichzeitig.
/// Entschieden am 2026-08-21, Begründung im Issue.
library;

/// Öffentliche Adresse der Web-App, zur Build-Zeit gesetzt
/// (`--dart-define=FWAPP_WEB_URL=…`, im Release-Workflow aus der
/// Repo-Variablen `FWAPP_WEB_URL`).
///
/// Leer, wenn nichts gesetzt ist — und dann steht in der Nachricht auch
/// keine Adresse. Eine nachnutzende Wehr soll nicht den Link auf unsere
/// Instanz erben, nur weil sie den Quelltext übernimmt.
const kWebAppUrl = String.fromEnvironment('FWAPP_WEB_URL', defaultValue: '');

/// Das lesende Konto der Demo-Wehr.
///
/// ⚠️ **Dieses Passwort ist mit Absicht öffentlich.** Es steckt in jedem
/// verteilten Build und ist damit aus einem APK lesbar — deshalb gehört es
/// ausschließlich diesem Konto, das nur liest und nie veröffentlicht. Die
/// drei arbeitenden Demo-Konten (Kommandant, Abteilungskommandant,
/// Gerätewart) haben ein eigenes, geheimes Passwort aus `docs/private/`.
/// Beide Werte stehen in `tool/demo_wehr.py`; `zugang_teilen_test.dart`
/// hält die Sprachgrenze zusammen.
const kDemoNutzername = 'demo.mitglied';
const kDemoPasswort = 'demo-freiwilligen';

/// Die Wehr, in die der Demo-Zugang führt — der Name muss in der Nachricht
/// stehen, sonst hält der Empfänger die erfundenen Fahrzeuge für echte.
const kDemoWehrName = 'Feuerwehr Freiwilligen';

/// Nachricht für einen persönlichen Zugang (Zugangszettel).
String zugangsNachricht({
  required String nutzername,
  required String passwort,
  String webUrl = kWebAppUrl,
}) {
  final zeilen = <String>[
    'Dein Zugang zur Feuerwehr-Lernapp:',
    '',
    if (webUrl.isNotEmpty) ...[webUrl, ''],
    'Nutzername: $nutzername',
    'Passwort: $passwort',
    '',
    // Der Hinweis ist kein Beiwerk: Ohne ihn wirkt der erzwungene Wechsel
    // beim ersten Anmelden wie ein Fehler, und genau dort steigen Leute aus.
    'Beim ersten Anmelden wählst du ein eigenes Passwort — dieses hier gilt '
        'dann nicht mehr.',
  ];
  return zeilen.join('\n');
}

/// Nachricht für den Demo-Zugang.
String demoNachricht({String webUrl = kWebAppUrl}) {
  final zeilen = <String>[
    'Schau dir die Feuerwehr-Lernapp an:',
    '',
    if (webUrl.isNotEmpty) ...[webUrl, ''],
    'Zum Reinschauen, ohne einen eigenen Zugang zu brauchen:',
    'Nutzername: $kDemoNutzername',
    'Passwort: $kDemoPasswort',
    '',
    'Das ist die erfundene Wehr „$kDemoWehrName" — keine echten Daten, und '
        'nur zum Lesen.',
  ];
  return zeilen.join('\n');
}
