/// app_version.dart – Die installierte App-Version als App-weiter Startwert.
///
/// `PackageInfo.fromPlatform()` ist asynchron, wird aber an Stellen gebraucht,
/// die synchron aufgebaut werden (z. B. `syncServiceProvider`). main.dart
/// ermittelt den Wert einmal beim Start und legt ihn hier ab — dasselbe
/// Muster, das `supabaseStorageBaseUrl` schon verwendet.
///
/// Bleibt `null`, solange nichts gesetzt wurde. Aufrufer müssen das aushalten:
/// Beim Mindestversions-Gate (Issue #35) heisst „Version unbekannt" auf dem
/// Server ausdrücklich nicht „durchlassen", sondern wird wie ein zu alter
/// Client behandelt — deshalb darf hier nichts geraten werden.
library;

String? currentAppVersion;
