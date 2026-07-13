/// connection_web.dart – Persistent WasmDatabase connection for the web build
/// (IndexedDB/OPFS backed). Requires web/sqlite3.wasm and web/drift_worker.js.
library;
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openConnection() =>
    DatabaseConnection.delayed(Future(() async {
      final result = await WasmDatabase.open(
        databaseName: 'fwapp',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return result.resolvedExecutor;
    }));
