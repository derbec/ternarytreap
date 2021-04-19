import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ternarytreap/ternarytreap.dart' as ternarytreap;
import 'package:example/activities.dart';
import '../../../ternarytreap/test/words.dart';

late Activity _session;
late StreamSubscription<String> _subscription;

void main(List<String> args) {
  if (args.isEmpty) {
    _displayHeader();
    _displayHelp();
    return;
  }
  _displayHeader();

  var _words = <String>[];

  if (args.length > 1) {
    if (args[1] == 'preload') {
      _words = words;
    } else {
      stderr
        ..writeln('*** Invalid 2nd Argument! ***')
        ..writeln('*** 2nd argument must be either "preload"'
            ' or empty! ***');
      return;
    }
  }

  switch (args[0]) {
    case '0':
      _session = InputActivity();
      stdout.writeln('Using no Keymapping');
      break;
    case '1':
      _session =
          InputActivity(keyMapping: ternarytreap.lowercase, preload: _words);
      stdout.writeln('Using lowercase KeyMapping');
      break;
    case '2':
      _session = InputActivity(
          keyMapping: ternarytreap.collapseWhitespace, preload: _words);
      stdout.writeln('Using collapseWhitespace KeyMapping');
      break;
    case '3':
      _session = InputActivity(
          keyMapping: ternarytreap.lowerCollapse, preload: _words);
      stdout.writeln('Using lowerCollapse KeyMapping');
      break;
    default:
      stderr.writeln('*** Invalid KeyMapping Argument! ***');
      _displayHelp();
      return;
  }

  stdout.writeln(_session.prompt);
  _subscription = readLine().listen(processLine);
}

Stream<String> readLine() =>
    stdin.transform(utf8.decoder).transform(const LineSplitter());

void processLine(String line) {
  if (!_session.processLine(line)) {
    if (_session is QueryActivity) {
      _subscription.cancel();

      stdout..writeln('Finished')..writeln(_session.treeString());
      return;
    }
    _session = QueryActivity(_session as InputActivity);
  }
  stdout.writeln(_session.prompt);
}

void _displayHeader() {
  stdout
    ..writeln('*** TernaryTreap example ***')
    ..writeln('Demonstrates the key -> '
        'data relationship using different KeyMappings.')
    ..writeln('A dictionary is created via custom data object'
        ' containing word, definition and timestamp.')
    ..write('Try entering different versions/capitalisations (e.g: Cat/CAT/cat)'
        ' to view one to many relationship between key and values')
    ..writeln('At each round the current TernaryTreap state is shown.')
    ..writeln('***************************');
}

void _displayHelp() {
  stdout
    ..writeln()
    ..writeln('Usage:')
    ..writeln('dart main.dart <KeyMapping> <preload>')
    ..writeln()
    ..writeln('KeyMappings:')
    ..writeln('0 - No key transform')
    ..writeln('1 - Lowercase key transform')
    ..writeln('2 - Collapse whitespace key transform')
    ..writeln('3 - Lowercase and Collapse whitespace key transform')
    ..writeln()
    ..writeln('preload argument will insert prexisting word list if desired')
    ..writeln()
    ..writeln('Examples:')
    ..writeln('dart main.dart 0')
    ..writeln('dart main.dart 1')
    ..writeln('dart main.dart 2')
    ..writeln('dart main.dart 3 preload')
    ..writeln('dart main.dart 2 preload');
}
