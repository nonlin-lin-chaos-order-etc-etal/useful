import 'package:famedlysdk/famedlysdk.dart';
import 'package:moor/moor.dart';
import 'package:moor/moor_web.dart';

Database constructDb({bool logStatements = false, String filename = 'database.sqlite', String password = ''}) {
  print('[Moor] Using moor web');
  return Database(WebDatabase.withStorage(MoorWebStorage.indexedDbIfSupported(filename), logStatements: logStatements));
}
