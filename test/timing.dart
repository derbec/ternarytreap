import 'dart:io';

import 'package:ternarytreap/ternarytreap.dart';

import 'emails.dart';

const int numRepeats = 15;

void main(List<String> args) {
  final keys = emails;

  stdout.writeln('Number of keys = ${keys.length}');

  //final map = <String, List<String>>{};
  final tt = TernaryTreapList<String>();

  final timer = Stopwatch()..start();
/*
  for (var i = 0; i < numRepeats; i++) {
    for (final key in keys) {
      map[key] = <String>[key];
    }
  }
  timer.stop();
  stdout.writeln('Map[key] = [key] for all keys: ${timer.elapsedMicroseconds}');
*/
  timer
    ..reset()
    ..start();

  //for (var i = 0; i < numRepeats; i++) {
    for (final key in keys) {
      tt[key] = <String>[key];
    }
  //}
  timer.stop();
  stdout.writeln('TernaryTreap[key] = [key] for all keys: '
      '${timer.elapsedMicroseconds} ');
/*
  timer
    ..reset()
    ..start();

  for (var i = 0; i < numRepeats; i++) {
    for (final key in keys) {
      if (!map.containsKey(key)) {
        throw Error();
      }
    }
  }
  timer.stop();
  stdout.writeln('Map: containsKey for all keys: ${timer.elapsedMicroseconds}');
*/


for(var fuzzInt = 0;fuzzInt<11;fuzzInt++){
  final fuzzDouble = (fuzzInt/10);
  timer
    ..reset()
    ..start();

  //for (var i = 0; i < numRepeats; i++) {
    /*
    for (final key in keys) {
      if (!tt.containsKey(key)) {
        throw Error();
      }
    }*/
    print(tt.entriesByKeyPrefix('pryefuimx', fuzzDouble).length.toString());
  //}

  timer.stop();
  stdout.writeln(
      'TernaryTreap containsKey for all keys using fuzz: ${fuzzDouble.toString()} was ${timer.elapsedMicroseconds}');
}


/*
  var entries = TernaryTreap.codeUnitPool.toList();

  entries.sort((a, b) => a.count.compareTo(b.count));

  var memTotal = 0;
  var memPooled = 0;

  for (final entry in entries) {
    final length = entry.codeUnits.length;
    memTotal += (entry.count * length);
    memPooled += length;

    //print('${String.fromCharCodes(entry.codeUnits)}  -->  ${entry.count}');
  }

  print('$memTotal  -->  $memPooled');
  */
}
