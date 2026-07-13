/// connection.dart – Platform-conditional database connection.
library;
export 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
