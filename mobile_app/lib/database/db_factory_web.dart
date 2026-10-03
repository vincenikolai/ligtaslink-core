import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web builds run SQLite as WebAssembly (run `dart run sqflite_common_ffi_web:setup` once).
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
