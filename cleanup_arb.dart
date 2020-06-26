import 'dart:io';
import 'dart:convert';
import 'dart:async';

const ARB_LOCATION = './lib/l10n';
const ARB_TEMPLATE = 'intl_messages.arb';

// from https://stackoverflow.com/questions/14268967/how-do-i-list-the-contents-of-a-directory-with-dart
Future<List<FileSystemEntity>> dirContents(Directory dir) {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen ( 
      (file) => files.add(file),
      // should also register onError
      onDone:   () => completer.complete(files)
      );
  return completer.future;
}

void main() async {
  final rawTemplateData = await File('$ARB_LOCATION/$ARB_TEMPLATE').readAsString();
  final templateData = json.decode(rawTemplateData);
  final translationKeys = templateData.keys.where((k) => !k.startsWith('@'));
  final allFiles = await dirContents(Directory(ARB_LOCATION));
  for (final file in allFiles) {
    final filename = file.path.split('/').last;
    if (!filename.endsWith('.arb') || !filename.startsWith('intl_')) {
      continue;
    }
    final lang = filename.replaceAll('.arb', '').replaceAll('intl_', '');
    if (lang == 'messages') {
      continue; // we don't want / need our template
    }
    print('Processing language $lang...');
    final rawTranslationData = await File(file.path).readAsString();
    final translationData = json.decode(rawTranslationData);
    var modified = false;
    for (final translationKey in translationKeys) {
      if (translationData.containsKey(translationKey)) {
        continue;
      }
      print('Missing translation "$translationKey", copying...');
      translationData[translationKey] = templateData[translationKey];
      translationData['@$translationKey'] = templateData['@$translationKey'];
      modified = true;
    }
    if (modified) {
      translationData['@@last_modified'] = DateTime.now().toString();
    }
    // sort it
    final entries = translationData.entries.toList();
    entries.sort((e1, e2) {
      if (e1.key.startsWith('@@') && !e2.key.startsWith('@@')) {
        return -1;
      }
      if (!e1.key.startsWith('@@') && e2.key.startsWith('@@')) {
        return 1;
      }
      String a = e1.key.replaceAll(RegExp(r'^[^a-zA-Z]*'), '');
      String b = e2.key.replaceAll(RegExp(r'^[^a-zA-Z]*'), '');
      if (a == b) {
        return e2.key[0] == '@' ? -1 : 1;
      }
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    final outputTranslationData = Map.fromEntries(entries);
    // and write it
    final writer = await File(file.path).open(mode: FileMode.write);
    final encoder = JsonEncoder.withIndent('  ');
    await writer.writeFrom(utf8.encode(encoder.convert(outputTranslationData)));
    await writer.close();
  }
}
