import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:example/session.dart';

Session _session;
StreamSubscription<String> _subscription;

void main(List<String> args) {
  if (args.isEmpty) {
    _displayHeader();
    _displayHelp();
    return;
  }
  _displayHeader();
  switch (args[0]) {
    case '0':
      _session = Session();
      stdout.writeln('Using no Keymapping');
      break;
    case '1':
      _session = Session(TernaryTreap.lowercase);
      stdout.writeln('Using lowercase KeyMapping');
      break;
    case '2':
      _session = Session(TernaryTreap.collapseWhitespace);
      stdout.writeln('Using collapseWhitespace KeyMapping');
      break;
    case '3':
      _session = Session(TernaryTreap.lowerCollapse);
      stdout.writeln('Using lowerCollapse KeyMapping');
      break;
    default:
      stderr.writeln('*** Invalid KeyMapping Argument! ***');
      _displayHelp();
      return;
  }
  _displayPrompt();
  _subscription = readLine().listen(processLine);
}

Stream<String> readLine() =>
    stdin.transform(utf8.decoder).transform(const LineSplitter());

void processLine(String line) {
  if (!_session.processLine(line)) {
    _subscription.cancel();
    stdout.writeln('Finished');
    _displayTree();
  } else {
    _displayPrompt();
  }
}

void _displayPrompt() {
  if (_session.title == null) {
    _displayTree();
    stdout.writeln('Enter title for insertion (Enter empty title to quit)');
  } else {
    stdout.writeln('Enter optional description to add as data');
  }
}

void _displayHeader() {
  stdout
    ..writeln('*** TernaryTreap example ***')
    ..writeln('Demonstrates the key -> '
        'data relationship using different KeyMappings.')
    ..writeln('A custom data object is used containing title, description'
        ' and timestamp.')
    ..writeln('At each round the current TernaryTreap state is shown.')
    ..writeln('***************************');
}

void _displayHelp() {
  stdout
    ..writeln()
    ..writeln('Usage:')
    ..writeln('dart main.dart <KeyMapping>')
    ..writeln()
    ..writeln('KeyMapping Indexes:')
    ..writeln('0 - No key transform')
    ..writeln('1 - Lowercase key transform')
    ..writeln('2 - Collapse whitespace key transform')
    ..writeln('3 - Lowercase and Collapse whitespace key transform')
    ..writeln()
    ..writeln('Examples:')
    ..writeln('dart main.dart 0')
    ..writeln('dart main.dart 1')
    ..writeln('dart main.dart 2');
}

void _displayTree() {
  final String state = _session.ternaryTreap.toString();
  if (state.isEmpty) {
    stdout..writeln()..writeln('*** TernaryTreap is empty')..writeln();
  } else {
    stdout
      ..writeln()
      ..writeln('*** Current TernaryTreap state showing'
          ' depth, keys and data')
      ..write(state)
      ..writeln('****')
      ..writeln();
  }
}
