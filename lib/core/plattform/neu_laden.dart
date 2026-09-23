/// neu_laden.dart – Die App neu starten, wo das geht (Issue #238).
///
/// Die Serververbindung wird beim Start einmal aufgebaut
/// (`Supabase.initialize` in main.dart); eine neue Adresse wirkt deshalb erst
/// nach einem Neustart. Im Browser ist das ein Neuladen der Seite, in der
/// Android-App gibt es keinen sauberen Weg — dort sagt die Oberfläche, dass
/// man die App schließen und neu öffnen soll.
library;

export 'neu_laden_stub.dart' if (dart.library.js_interop) 'neu_laden_web.dart';
