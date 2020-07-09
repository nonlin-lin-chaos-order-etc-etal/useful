import 'dart:io';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:moor/moor.dart';
import 'cipher_db.dart' as cipher;

bool _inited = false;

Database constructDb(
    {bool logStatements = false,
    String filename = 'database.sqlite',
    String password = ''}) {
  if (!_inited) {
    cipher.init();
    _inited = true;
  }
  debugPrint('[Moor] using encrypted moor');
  return Database(LazyDatabase(() async {
    final dbFolder = await getDatabasesPath();
    final file = File(p.join(dbFolder, filename));
    return cipher.VmDatabaseEncrypted(file,
        password: password, logStatements: logStatements);
  }));
}

Future<String> getLocalstorage(String key) async {
  return null;
}
