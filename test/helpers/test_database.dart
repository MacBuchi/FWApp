/// test_database.dart – Creates an isolated in-memory AppDatabase for unit tests.
/// Use [createTestDatabase] in setUp(); call [db.close()] in tearDown().
library;
import 'package:drift/native.dart';
import 'package:fwapp/core/database/app_database.dart';

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());
