import 'dart:io';

import 'package:ternarytreap/ternarytreap.dart';

import 'words.dart';

const int numRepeats = 1000;

void main(List<String> args) {
  final List<String> keys = <String>[
    ...words,
    ...words
        .map((String word) => String.fromCharCodes(word.codeUnits.reversed)),
    ...words.map((String word) => word.toUpperCase()),
    ...words.map((String word) => '$word $word'),
    ...words.map((String word) => '***$word**$word**$word**'),
  ];

  stdout.writeln('Number of keys = ${keys.length}');

  final Map<String, List<String>> map = <String, List<String>>{};
  final TernaryTreap<String> tt = TernaryTreapList<String>();

  final Stopwatch timer = Stopwatch()..start();

  for (int i = 0; i < numRepeats; i++) {
    for (final String key in keys) {
      map[key] = <String>[key];
    }
  }
  timer.stop();
  stdout.writeln('Map[key] = [key] for all keys: ${timer.elapsedMicroseconds}');

  timer
    ..reset()
    ..start();

  for (int i = 0; i < numRepeats; i++) {
    for (final String key in keys) {
      tt[key] = <String>[key];
    }
  }
  timer.stop();
  stdout.writeln('TernaryTreap[key] = [key] for all keys: '
      '${timer.elapsedMicroseconds} -- ${tt.depth}');

  timer
    ..reset()
    ..start();

  for (int i = 0; i < numRepeats; i++) {
    for (final String key in keys) {
      if (!map.containsKey(key)) {
        throw Error();
      }
    }
  }
  timer.stop();
  stdout.writeln('Map: containsKey for all keys: ${timer.elapsedMicroseconds}');

  timer
    ..reset()
    ..start();

  for (int i = 0; i < numRepeats; i++) {
    for (final String key in keys) {
      if (!tt.containsKey(key)) {
        throw Error();
      }
    }
  }
  timer.stop();
  stdout.writeln(
      'TernaryTreap containsKey for all keys: ${timer.elapsedMicroseconds}');
}
