import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';
import 'words.dart';
import 'helper.dart';

void testIdempotence(TernaryTreap<int> tree, String key) {
  // map key and then ensure that subsequent mappings do not change
  // mapped value
  var mappedKey = tree.mapKey(key);

  expect(mappedKey, equals(tree.mapKey(mappedKey)));

  mappedKey = tree.mapKey(mappedKey);

  expect(mappedKey, equals(tree.mapKey(mappedKey)));

  mappedKey = tree.mapKey(mappedKey);

  expect(mappedKey, equals(tree.mapKey(mappedKey)));
}

void main() {
  const numUniqueKeys = 1000;
  // Total number of keys taking into account overlap and special keys
  final numKeys = (numUniqueKeys * 1.5).round() + 3;
  const startVal = 17;
  List<String> sortedNumberKeys;
  List<String> sortedWordKeys;
  Map<String, List<int>> numberMap;
  Map<String, List<String>> wordMap;
  TernaryTreap<int> numberTST;
  TernaryTreap<String> wordTST;

  setUp(() {
    //Test data
    //Create increasing keys with overlap - worst case scenario for tree
    final Iterable<int> numberKeys = <int>[
      (numUniqueKeys * 3 + startVal + 1),
      for (int i = 0; i < numUniqueKeys; i++) startVal + i,
      for (int i = 0; i < numUniqueKeys; i++)
        (startVal + (numUniqueKeys / 2).round()) + i,
      // Special keys for mapping to empty data
      (numUniqueKeys * 3 + startVal + 2),
      (numUniqueKeys * 3 + startVal + 3),
    ];

    //Test output
    numberMap = <String, List<int>>{};
    for (final x in numberKeys) {
      if (numberMap.containsKey(x.toString())) {
        if (!numberMap[x.toString()].contains(x)) {
          numberMap[x.toString()].add(x);
        }
      } else {
        // Map special keys to empty data
        if (x > (numUniqueKeys * 3 + startVal)) {
          numberMap[x.toString()] = <int>[];
        } else {
          numberMap[x.toString()] = <int>[x];
        }
      }
    }

    //Test output
    wordMap = <String, List<String>>{};

    for (final x in words) {
      // Add a few different variations of word

      wordMap[x.toLowerCase()] = [x.toLowerCase()];
      wordMap[x.toUpperCase()] = [x.toLowerCase()];
      wordMap[
          '*' + x + '-' + String.fromCharCodes(x.codeUnits.reversed) + '*'] = [
        '*' + x + '-' + String.fromCharCodes(x.codeUnits.reversed) + '*'
      ];
    }

    sortedNumberKeys = numberMap.keys.toList()..sort();
    sortedWordKeys = wordMap.keys.toList()..sort();

    numberTST = TernaryTreap<int>.Set();
    for (final x in numberKeys) {
      // Special keys are added with no data
      if (x > (numUniqueKeys * 3 + startVal)) {
        numberTST.add(x.toString());
      } else {
        numberTST.add(x.toString(), x);
      }
    }

    wordTST = TernaryTreap<String>.Set();
    for (final x in wordMap.keys) {
      wordTST[x] = wordMap[x];
    }
  });

  group('TernaryTreap', () {
    test('forEach', () {
      final expectedOutput = <MapEntry<String, int>>[
        for (String word in sortedNumberKeys)
          for (int x in numberMap[word]) MapEntry<String, int>(word, x)
      ];

      final result = <MapEntry<String, int>>[];
      numberTST.forEach((String key, int data) {
        result.add(MapEntry<String, int>(key, data));
      });

      expect(json.encode(result, toEncodable: toEncodable),
          equals(json.encode(expectedOutput, toEncodable: toEncodable)));
    });

    test('forEachKey', () {
      final expectedOutput = <MapEntry<String, Iterable<int>>>[
        for (String word in sortedNumberKeys)
          MapEntry<String, Iterable<int>>(word, numberMap[word])
      ];

      final result = <MapEntry<String, Iterable<int>>>[];
      numberTST.forEachKey((String key, Iterable<int> data) {
        result.add(MapEntry<String, Iterable<int>>(key, data));
      });

      expect(json.encode(result, toEncodable: toEncodable),
          equals(json.encode(expectedOutput, toEncodable: toEncodable)));
    });

    test('concurrentModificationError', () {
      expect(() {
        numberTST.forEachKey((String key, Iterable<int> data) {
          numberTST.add('NOT ALLOWED', 9);
        });
      }, throwsA(TypeMatcher<ConcurrentModificationError>()));
    });

    test('forEachKeyPrefixedBy', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <MapEntry<String, List<int>>>[
          for (String word in sortedNumberKeys)
            if (word.startsWith(prefix))
              MapEntry<String, List<int>>(word, numberMap[word])
        ];

        final result = <MapEntry<String, Iterable<int>>>[];
        numberTST.forEachKeyPrefixedBy(prefix,
            (String key, Iterable<int> data) {
          result.add(MapEntry<String, Iterable<int>>(key, data));
        });

        expect(json.encode(result, toEncodable: toEncodable),
            equals(json.encode(expectedOutput, toEncodable: toEncodable)));

        // Check that subtree length is maintained correctly while here
        final subTreeLength = numberTST.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
    });

    test('one key', () {
      final oneKey = TernaryTreap<int>.Set()..add('a');
      expect(oneKey.length, equals(1));
      expect(oneKey.entries.length, equals(1));
      expect(oneKey.entriesByKeyPrefix('a').length, equals(1));
      expect(oneKey.entriesByKeyPrefix('b').length, equals(0));

      expect(
          json.encode(oneKey.entriesByKeyPrefix('b').toList(),
              toEncodable: toEncodable),
          equals(json.encode(<MapEntry<String, Iterable<int>>>[],
              toEncodable: toEncodable)));

      expect(
          json.encode(oneKey.entriesByKeyPrefix('a').toList(),
              toEncodable: toEncodable),
          equals(json.encode(<MapEntry<String, Iterable<int>>>[
            const MapEntry<String, Iterable<int>>('a', <int>[])
          ], toEncodable: toEncodable)));
    });

    test('keys', () {
      expect(numberTST.keys.toList(), equals(sortedNumberKeys));
    });

    test('values', () {
      //Filter out empty lists
      final expectedOutput = <int>[
        for (String word in sortedNumberKeys)
          if (numberMap[word].isNotEmpty) ...numberMap[word]
      ];
      expect(numberTST.values.toList(), equals(expectedOutput));
    });
    test('entries', () {
      final expectedOutput = <MapEntry<String, Iterable<int>>>[
        for (String word in sortedNumberKeys)
          MapEntry<String, Iterable<int>>(word, numberMap[word])
      ];
      expect(json.encode(numberTST.entries.toList(), toEncodable: toEncodable),
          equals(json.encode(expectedOutput, toEncodable: toEncodable)));
    });

    test('entriesByKeyPrefix', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <MapEntry<String, Iterable<int>>>[
          for (String word in sortedNumberKeys)
            if (word.startsWith(prefix))
              MapEntry<String, Iterable<int>>(word, numberMap[word])
        ];

        expect(
            json.encode(numberTST.entriesByKeyPrefix(prefix).toList(),
                toEncodable: toEncodable),
            equals(json.encode(expectedOutput, toEncodable: toEncodable)));

        // Check that subtree length is maintained correctly while here
        expect(numberTST.entriesByKeyPrefix(prefix).length,
            equals(expectedOutput.length));
      }

      expect(numberTST.entriesByKeyPrefix('NOT PRESENT').isEmpty, equals(true));
    });

    test('keysByPrefix', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <String>[
          for (String word in sortedNumberKeys)
            if (word.startsWith(prefix)) word
        ];

        expect(numberTST.keysByPrefix(prefix).toList(), equals(expectedOutput));

        // Check that subtree length is maintained correctly while here
        final subTreeLength = numberTST.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
      expect(numberTST.keysByPrefix('NOT PRESENT').isEmpty, equals(true));
    });

    test('valuesByKeyPrefix', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <int>[
          for (String word in sortedNumberKeys)
            if (word.startsWith(prefix)) ...numberMap[word]
        ];

        expect(numberTST.valuesByKeyPrefix(prefix).toList(),
            equals(expectedOutput));

        // Check that subtree length is maintained correctly while here
        final subTreeLength = numberTST.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
      expect(numberTST.valuesByKeyPrefix('NOT PRESENT').isEmpty, equals(true));
    });

    test('[]', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      expect(numberTST[key], equals(numberMap[key]));

      expect(numberTST['NOT FOUND'], equals(null));

      expect(numberTST['1'], equals(null));
    });

    test('[]=', () {
      final tree = TernaryTreap<int>.Set(TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree['At'], equals(<int>[1]));

      tree['at'] = <int>[2, 3];

      expect(tree['AT'], equals(<int>[2, 3]));
    });

    test('contains', () {
      for (final key in sortedNumberKeys) {
        for (final val in numberMap[key]) {
          expect(numberTST.contains(key, val), equals(true));
          expect(numberTST.contains(key, -val), equals(false));
        }
      }

      expect(numberTST.contains('NOT FOUND', 5), equals(false));
    });

    test('containsKey', () {
      for (final key in sortedNumberKeys) {
        expect(numberTST.containsKey(key), equals(true));
      }

      expect(numberTST.containsKey('NOT FOUND'), equals(false));
    });

    test('containsValue', () {
      for (final key in sortedNumberKeys) {
        for (final val in numberMap[key]) {
          expect(numberTST.containsValue(val), equals(true));
          expect(numberTST.containsValue(-val), equals(false));
        }
      }
    });

    test('length', () {
      expect(numberTST.length, equals(numKeys));
    });

    test('KeyMapping', () {
      var tree = TernaryTreap<int>.Set(TernaryTreap.lowercase)
        ..add('TeStInG', 1);

      expect(tree['fake'], equals(null));

      expect(tree['tEsTiNg'], equals(<int>[1]));

      expect(tree['testing'], equals(<int>[1]));

      expect(tree.keys.first, equals('testing'));

      testIdempotence(tree, 'DSAF DF SD FSDRTE ');

      tree = TernaryTreap<int>.Set(TernaryTreap.uppercase)..add('TeStInG', 1);

      expect(tree['fake'], equals(null));

      expect(tree['tEsTiNg'], equals(<int>[1]));

      expect(tree['testing'], equals(<int>[1]));

      expect(tree.keys.first, equals('TESTING'));

      testIdempotence(tree, 'asdas KJHGJGH fsdfsdf ');

      tree = TernaryTreap<int>.Set(TernaryTreap.collapseWhitespace)
        ..add(' t es   ti     ng  ', 1);
      expect(
          tree['t             '
              'es ti ng     '],
          equals(<int>[1]));

      expect(tree.keys.first, equals('t es ti ng'));

      testIdempotence(tree, '   asdas          KJHG  JGH fsdf  sdf   ');

      tree = TernaryTreap<int>.Set(TernaryTreap.lowerCollapse)
        ..add(' T eS   KK     Bg  ', 1);
      expect(
          tree['       t es'
              ' kk bg'],
          equals(<int>[1]));

      expect(tree.keys.first, equals('t es kk bg'));

      testIdempotence(tree, '   asdas          KJHG  JGH fsdf  sdf   ');

      tree = TernaryTreap<int>.Set(TernaryTreap.nonLetterToSpace)
        ..add('*T_eS  -KK  ,  Bg )\n\t', 1);
      expect(tree[' T eS  ^KK %* ^Bg ;  '], <int>[1]);

      expect(tree.keys.first, equals(' T eS   KK     Bg    '));

      testIdempotence(tree, ' %  asd+=as   & & ^J%@HG  J(GH f`sdf  s*df   )!');

      tree = TernaryTreap<int>.Set(TernaryTreap.joinSingleLetters)
        ..add('    a     b .  ab.cd a  b abcd a        b', 1);

      expect(tree['ab .  ab.cd ab abcd ab'], equals(<int>[1]));

      expect(tree.keys.first, equals('ab . ab.cd ab abcd ab'));

      testIdempotence(tree, '    a     b .  ab.cd a  b abcd a        b v');
    });

    test('remove', () {
      for (final key in sortedNumberKeys) {
        for (final val in numberMap[key]) {
          expect(numberTST.remove(key, val), equals(true));
          expect(numberTST.remove(key, -val), equals(false));
        }
      }

      expect(numberTST.remove('NOT FOUND', 5), equals(false));
    });

    test('removeValues', () {
      final tree = TernaryTreap<int>.Set(TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree.removeValues('At'), equals(<int>[1]));

      expect(tree['At'], equals(<int>[]));

      tree['be'] = <int>[2, 3];

      expect(tree.removeValues('CAT'), equals(<int>[]));

      expect(tree.removeValues('BE'), equals(<int>[2, 3]));
      expect(tree['Be'], equals(<int>[]));
    });

    test('removeKey', () {
      final tree = TernaryTreap<int>.Set(TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree.removeKey('At'), equals(<int>[1]));

      tree['be'] = <int>[2, 3];

      expect(tree.length, equals(1));

      expect(tree.removeKey('CAT'), equals(<int>[]));

      expect(tree.length, equals(1));

      expect(tree.removeKey('BE'), equals(<int>[2, 3]));

      numberMap.keys.toList().forEach(numberTST.removeKey);

      expect(numberTST.length, equals(0));
      expect(numberTST.isEmpty, equals(true));
      expect(numberTST.isNotEmpty, equals(false));
    });

    test('addAll', () {
      final tree = TernaryTreap<int>.Set();

      tree['At'] = <int>[1];

      tree['be'] = <int>[2, 3];

      tree.addAll(numberTST);

      expect(tree.length, equals(numberTST.length + 2));

      // Original mappings should still be there
      expect(tree['At'], equals(<int>[1]));
      expect(tree['be'], equals(<int>[2, 3]));

      // All mappings from tst should be there as well
      for (final key in numberTST.keys) {
        expect(tree[key], equals(numberTST[key]));
      }

      // Check set behaviour by adding again
      tree.addAll(numberTST);
      // All mappings from tst should be the same
      for (final key in numberTST.keys) {
        expect(tree[key], equals(numberTST[key]));
      }
    });

    test('addValues', () {
      final tree = TernaryTreap<int>.Set();

      tree['At'] = <int>[1];

      tree['be'] = <int>[2, 3];

      for (final key in numberTST.keys) {
        tree.addValues(key, numberTST[key]);
      }

      expect(tree.length, equals(numberTST.length + 2));

      // Original mappings should still be there
      expect(tree['At'], equals(<int>[1]));
      expect(tree['be'], equals(<int>[2, 3]));

      // All mappings from tst should be there as well
      for (final key in numberTST.keys) {
        expect(tree[key], equals(numberTST[key]));
      }

      // Check set behaviour by adding again
      for (final key in numberTST.keys) {
        tree.addValues(key, numberTST[key]);
      }

      // All mappings from tst should be the same
      for (final key in numberTST.keys) {
        expect(tree[key], equals(numberTST[key]));
      }
    });

    test('asMap', () {
      expect(numberTST.asMap(), equals(numberMap));
    });

    test('asImmutable', () {
      expect(numberTST.asImmutable().asMap(), equals(numberMap));

      var immutable = numberTST.asImmutable();

      // Ensure that immutable view updates with original
      numberTST['new element'] = {6};

      expect(immutable.asMap(), equals(numberTST.asMap()));
      expect(immutable.length, equals(numberTST.length));

      numberTST.clear();

      expect(immutable.isEmpty, equals(numberTST.isEmpty));
    });

    test('valuesByKeyPrefixDistance', () {
      for (final key in sortedWordKeys) {
        // Reverse keys to mix it up
        final prefix = String.fromCharCodes(key.codeUnits.reversed);
        var checker = <List<String>>[];
        for (final key in sortedWordKeys) {
          final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
          if (distance > -1 && distance < prefix.length) {
            checker.add(wordMap[key]);
          }
        }

        var flatChecker =
            checker.expand((Iterable<String> values) => values).toList();
        flatChecker.sort();

        var result = wordTST.valuesByKeyPrefix(prefix, true).toList();
        result.sort();

        expect(result, equals(flatChecker));
      }
    });

    test('keysByPrefixDistance', () {
      for (final key in sortedWordKeys) {
        final prefix = String.fromCharCodes(key.codeUnits.reversed);
        var checker = <String>[];
        for (final key in sortedWordKeys) {
          final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
          if (distance > -1 && distance < prefix.length) {
            checker.add(key);
          }
        }

        var result = wordTST.keysByPrefix(prefix, true).toList();

        result.sort();
        checker.sort();

        expect(result, equals(checker));
      }
    });

    test('entriesByPrefixDistance', () {
      for (final key in sortedWordKeys) {
        final prefix = String.fromCharCodes(key.codeUnits.reversed);
        var checker = <MapEntry<String, Iterable<String>>>[];
        for (final key in sortedWordKeys) {
          final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
          if (distance > -1 && distance < prefix.length) {
            checker.add(MapEntry<String, Iterable<String>>(key, wordMap[key]));
          }
        }

        var result = wordTST.entriesByKeyPrefix(prefix, true).toList();

        result.sort((a, b) => a.key.compareTo(b.key));
        checker.sort((a, b) => a.key.compareTo(b.key));

        expect(json.encode(result, toEncodable: toEncodable),
            equals(json.encode(checker, toEncodable: toEncodable)));
      }
    });

    test('forEachKeyPrefixedByDistance', () {
      for (final key in sortedWordKeys) {
        final prefix = String.fromCharCodes(key.codeUnits.reversed);
        var checker = <MapEntry<String, Iterable<String>>>[];
        for (final key in sortedWordKeys) {
          final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
          if (distance > -1 && distance  < prefix.length) {
            checker.add(MapEntry<String, Iterable<String>>(key, wordMap[key]));
          }
        }

        var result = <MapEntry<String, Iterable<String>>>[];

        wordTST.forEachKeyPrefixedBy(prefix,
            (String key, Iterable<String> data) {
          result.add(MapEntry<String, Iterable<String>>(key, data));
        }, true);


        result.sort((a, b) => a.key.compareTo(b.key));
        checker.sort((a, b) => a.key.compareTo(b.key));

        expect(json.encode(result, toEncodable: toEncodable),
            equals(json.encode(checker, toEncodable: toEncodable)));
      }
    });
  });
}

int prefixDistance(final List<int> prefix, final List<int> compare) {
  if (compare.length < prefix.length) {
    // cannot compute hamming distance here as
    return -1;
  }

  // Assume worst case and improve if possible
  var distance = prefix.length;

  // Improve if possible
  for (var i = 0; i < prefix.length; i++) {
    if (prefix[i] == compare[i]) {
      distance--;
    }
  }

  return distance;
}
