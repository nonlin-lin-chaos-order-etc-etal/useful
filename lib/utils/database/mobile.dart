import 'package:famedlysdk/famedlysdk.dart';
import 'package:moor/moor.dart';
import 'package:encrypted_moor/encrypted_moor.dart';

Database constructDb({bool logStatements = false, String filename = 'database.sqlite', String password = ''}) {
  print('[Moor] using encrypted moor');
  return Database(EncryptedExecutor(path: filename, password: password, logStatements: logStatements));
}

Future<String> getLocalstorage(String key) async {
  return null;
}
