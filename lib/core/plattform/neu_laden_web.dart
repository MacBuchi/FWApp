/// neu_laden_web.dart – Neuladen der Seite im Browser.
library;

import 'dart:js_interop';

@JS('window.location.reload')
external void _neuLaden();

/// `true`: Die Seite lädt neu, die App startet mit der neuen Adresse.
bool seiteNeuLaden() {
  _neuLaden();
  return true;
}
