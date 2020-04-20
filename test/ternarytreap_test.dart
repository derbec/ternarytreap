import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart' as ternarytreap;
import 'package:test/test.dart';
import 'words.dart';

dynamic toEncodable(dynamic obj) {
  if (obj is Iterable<String>) {
    return obj.toList();
  }
  if (obj is Set) {
    return obj.toList();
  }
  if (obj is MapEntry<String, Iterable<int>>) {
    return <String, dynamic>{'key': obj.key, 'val': obj.value.toList()};
  }
  if (obj is MapEntry<String, Iterable<String>>) {
    return <String, dynamic>{'key': obj.key, 'val': obj.value.toList()};
  }
  if (obj is MapEntry<String, int>) {
    return <String, dynamic>{'key': obj.key, 'val': obj.value};
  }

  return null;
}

void testIdempotence(ternarytreap.TTMultiMap<int> tree, String key) {
  // map key and then ensure that subsequent mappings do not change
  // mapped value
  var mappedKey = tree.keyMapping(key);

  expect(mappedKey, equals(tree.keyMapping(mappedKey)));

  mappedKey = tree.keyMapping(mappedKey);

  expect(mappedKey, equals(tree.keyMapping(mappedKey)));

  mappedKey = tree.keyMapping(mappedKey);

  expect(mappedKey, equals(tree.keyMapping(mappedKey)));
}

class _TestObject {
  _TestObject(this._name);
  final _name;
  @override
  bool operator ==(final dynamic other) =>
      identical(this, other) || _name == other._name;

  @override
  int get hashCode => _name.hashCode;
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
  ternarytreap.TTMultiMap<int> numberTST;
  ternarytreap.TTMultiMap<String> wordTST;

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

    numberTST = ternarytreap.TTMultiMapSet<int>();
    for (final x in numberKeys) {
      // Special keys are added with no data
      if (x > (numUniqueKeys * 3 + startVal)) {
        numberTST.addKey(x.toString());
      } else {
        numberTST.add(x.toString(), x);
      }
    }

    wordTST = ternarytreap.TTMultiMapSet<String>();
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
      final oneKey = ternarytreap.TTMultiMapSet<int>()..addKey('a');
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
      expect(wordTST.keys.toList(), equals(sortedWordKeys));
    });

    test('values', () {
      //Filter out empty lists
      final expectedNumberOutput = <int>[
        for (String word in sortedNumberKeys)
          if (numberMap[word].isNotEmpty) ...numberMap[word]
      ];

      final expectedWordOutput = <String>[
        for (String word in sortedWordKeys)
          if (wordMap[word].isNotEmpty) ...wordMap[word]
      ];

      expect(numberTST.values.toList(), equals(expectedNumberOutput));
      expect(wordTST.values.toList(), equals(expectedWordOutput));
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

    test('keysByNonExistentPrefix', () {
      //Find a prefix that uis not present
      var prefix = wordTST.keys.first;
      prefix = '^' + prefix.substring(0, prefix.length - 1) + '^';
      expect(wordTST.keysByPrefix(prefix).isEmpty, equals(true));
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
      final tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.lowercase);

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

    test('lookupValue', () {
      final original = _TestObject('I am an object');
      final copy = _TestObject('I am an object');

      var treeSet =
          ternarytreap.TTMultiMapSet<_TestObject>(ternarytreap.lowercase);
      var treeList =
          ternarytreap.TTMultiMapList<_TestObject>(ternarytreap.lowercase);

      treeSet.add('this is a key', original);
      treeList.add('this is a key', original);

      // Searching for value should return reference to original
      expect(identical(treeSet.lookup('this is a key', copy), original),
          equals(true));

      expect(identical(treeList.lookup('this is a key', copy), original),
          equals(true));
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
      var tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.lowercase)
        ..add('TeStInG', 1);

      expect(tree['fake'], equals(null));

      expect(tree['tEsTiNg'], equals(<int>[1]));

      expect(tree['testing'], equals(<int>[1]));

      expect(tree.keys.first, equals('testing'));

      testIdempotence(tree, 'DSAF DF SD FSDRTE ');

      tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.uppercase)
        ..add('TeStInG', 1);

      expect(tree['fake'], equals(null));

      expect(tree['tEsTiNg'], equals(<int>[1]));

      expect(tree['testing'], equals(<int>[1]));

      expect(tree.keys.first, equals('TESTING'));

      testIdempotence(tree, 'asdas KJHGJGH fsdfsdf ');

      tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.collapseWhitespace)
        ..add(' t es   ti     ng  ', 1);
      expect(
          tree['t             '
              'es ti ng     '],
          equals(<int>[1]));

      expect(tree.keys.first, equals('t es ti ng'));

      testIdempotence(tree, '   asdas          KJHG  JGH fsdf  sdf   ');

      tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.lowerCollapse)
        ..add(' T eS   KK     Bg  ', 1);
      expect(
          tree['       t es'
              ' kk bg'],
          equals(<int>[1]));

      expect(tree.keys.first, equals('t es kk bg'));

      testIdempotence(tree, '   asdas          KJHG  JGH fsdf  sdf   ');

      tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.nonLetterToSpace)
        ..add('*T_eS  -KK  ,  Bg )\n\t', 1);
      expect(tree[' T eS  ^KK %* ^Bg ;  '], <int>[1]);

      expect(tree.keys.first, equals(' T eS KK Bg '));

      testIdempotence(tree, ' %  asd+=as   & & ^J%@HG  J(GH f`sdf  s*df   )!');

      tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.joinSingleLetters)
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
      final tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree.removeValues('At'), equals(<int>[1]));

      expect(tree['At'], equals(<int>[]));

      tree['be'] = <int>[2, 3];

      expect(tree.removeValues('CAT'), equals(null));

      expect(tree.removeValues('BE'), equals(<int>[2, 3]));
      expect(tree['Be'], equals(<int>[]));
    });

    test('removeKey', () {
      final tree = ternarytreap.TTMultiMapSet<int>(ternarytreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree.removeAll('At'), equals(<int>[1]));

      tree['be'] = <int>[2, 3];

      expect(tree.length, equals(1));

      // Returns null if key not mapped
      expect(tree.removeAll('CAT'), equals(null));

      expect(tree.length, equals(1));

      expect(tree.removeAll('BE'), equals(<int>[2, 3]));

      numberMap.keys.toList().forEach(numberTST.removeAll);

      expect(numberTST.length, equals(0));
      expect(numberTST.isEmpty, equals(true));
      expect(numberTST.isNotEmpty, equals(false));
    });

    test('addEntries', () {
      final tree = ternarytreap.TTMultiMapSet<int>();

      tree['At'] = <int>[1];

      tree['be'] = <int>[2, 3];

      tree.addEntries(numberTST.entries);

      expect(tree.length, equals(numberTST.length + 2));

      // Original mappings should still be there
      expect(tree['At'], equals(<int>[1]));
      expect(tree['be'], equals(<int>[2, 3]));

      // All mappings from tst should be there as well
      for (final key in numberTST.keys) {
        expect(tree[key], equals(numberTST[key]));
      }

      // Check set behaviour by adding again
      tree.addEntries(numberTST.entries);
      // All mappings from tst should be the same
      for (final key in numberTST.keys) {
        expect(tree[key], equals(numberTST[key]));
      }
    });

    test('addValues', () {
      final tree = ternarytreap.TTMultiMapSet<int>();

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

    test('valuesByKeyPrefixDistance', () {
      final maxPrefixEditDistance = 2;
      for (final key in sortedWordKeys) {
        if (key.length > maxPrefixEditDistance) {
          // Reverse keys to mix it up
          final prefix = String.fromCharCodes(key.codeUnits.reversed);

          var checker = <List<String>>[];
          for (final key in sortedWordKeys) {
            final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
            if (distance > -1 && distance <= maxPrefixEditDistance) {
              checker.add(wordMap[key]);
            }
          }

          var flatChecker =
              checker.expand((Iterable<String> values) => values).toList();
          flatChecker.sort();

          var result = wordTST
              .valuesByKeyPrefix(prefix,
                  maxPrefixEditDistance: maxPrefixEditDistance)
              .toList();
          result.sort();

          expect(result, equals(flatChecker));
        }
      }
    });

    test('keysByPrefixDistance', () {
      final maxPrefixEditDistance = 100;
      for (final key in sortedWordKeys) {
        if (key.length > maxPrefixEditDistance) {
          // Reverse keys to mix it up
          final prefix = String.fromCharCodes(key.codeUnits.reversed);

          var checker = <String>[];
          for (final key in sortedWordKeys) {
            final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
            if (distance > -1 && distance <= maxPrefixEditDistance) {
              checker.add(key);
            }
          }

          var result = wordTST
              .keysByPrefix(prefix,
                  maxPrefixEditDistance: maxPrefixEditDistance)
              .toList();

          result.sort();
          checker.sort();
          expect(result, equals(checker));
        }
      }
    });

    test('PrefixDistanceIterator', () {
      final maxPrefixEditDistance = 3;
      for (final key in sortedWordKeys) {
        if (key.length > maxPrefixEditDistance) {
          final prefix = String.fromCharCodes(key.codeUnits.reversed);

          var keyItr = wordTST
              .keysByPrefix(prefix,
                  maxPrefixEditDistance: maxPrefixEditDistance)
              .iterator;
          while (keyItr.moveNext()) {
            expect(
                keyItr.prefixEditDistance,
                equals(prefixDistance(
                    prefix.codeUnits, keyItr.current.codeUnits)));
          }

          var entryItr = wordTST
              .entriesByKeyPrefix(prefix,
                  maxPrefixEditDistance: maxPrefixEditDistance)
              .iterator;
          while (entryItr.moveNext()) {
            expect(
                entryItr.prefixEditDistance,
                equals(prefixDistance(
                    prefix.codeUnits, entryItr.current.key.codeUnits)));
          }
        }
      }
    });

    test('entriesByPrefixDistance', () {
      final maxPrefixEditDistance = 2;
      for (final key in sortedWordKeys) {
        if (key.length > maxPrefixEditDistance) {
          final prefix = String.fromCharCodes(key.codeUnits.reversed);

          var checker = <MapEntry<String, Iterable<String>>>[];
          for (final key in sortedWordKeys) {
            final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
            if (distance > -1 && distance <= maxPrefixEditDistance) {
              checker
                  .add(MapEntry<String, Iterable<String>>(key, wordMap[key]));
            }
          }

          var result = wordTST
              .entriesByKeyPrefix(prefix,
                  maxPrefixEditDistance: maxPrefixEditDistance)
              .toList();

          result.sort((a, b) => a.key.compareTo(b.key));
          checker.sort((a, b) => a.key.compareTo(b.key));

          expect(json.encode(result, toEncodable: toEncodable),
              equals(json.encode(checker, toEncodable: toEncodable)));
        }
      }
    });

    test('forEachKeyPrefixedByDistance', () {
      final maxPrefixEditDistance = 4;
      for (final key in sortedWordKeys) {
        if (key.length > maxPrefixEditDistance) {
          final prefix = String.fromCharCodes(key.codeUnits.reversed);

          var checker = <MapEntry<String, Iterable<String>>>[];
          for (final key in sortedWordKeys) {
            final distance = prefixDistance(prefix.codeUnits, key.codeUnits);
            if (distance > -1 && distance <= maxPrefixEditDistance) {
              checker
                  .add(MapEntry<String, Iterable<String>>(key, wordMap[key]));
            }
          }

          var result = <MapEntry<String, Iterable<String>>>[];

          wordTST.forEachKeyPrefixedBy(prefix,
              (String key, Iterable<String> data) {
            result.add(MapEntry<String, Iterable<String>>(key, data));
          }, maxPrefixEditDistance: maxPrefixEditDistance);

          result.sort((a, b) => a.key.compareTo(b.key));
          checker.sort((a, b) => a.key.compareTo(b.key));

          expect(json.encode(result, toEncodable: toEncodable),
              equals(json.encode(checker, toEncodable: toEncodable)));
        }
      }
    });

    test('suggestKey', () {
      final wordTSTKeys = wordTST.keys.toList();
      final anKeys = wordTST.keysByPrefix('an').toList();

      // Prioritise the last key
      wordTST.markKey(anKeys.last);

      // Now suggest should return promoted key
      expect(wordTST.lastMarkedKeyByPrefix('an'), equals(anKeys.last));

      expect(wordTST.lastMarkedKeyByPrefix('a'), equals(anKeys.last));

      //Repeat with another key
      final cKeys = wordTST.keysByPrefix('c').toList();

      // Prioritise the last key
      wordTST.markKey(cKeys.last);

      // Now suggest should return prioritised key
      expect(wordTST.lastMarkedKeyByPrefix('c'), equals(cKeys.last));

      // Check that tree remembers original promotion
      expect(wordTST.lastMarkedKeyByPrefix('an'), equals(anKeys.last));

      expect(wordTST.lastMarkedKeyByPrefix('c'), equals(cKeys.last));

      expect(wordTST.keys.toList(), equals(wordTSTKeys));

      final ttSet = ternarytreap.TTSet.fromIterable(
          ['grab', 'angry', 'camel', 'axe', 'animal', 'bike', 'announced']);

      final ttSetKeys = ttSet.toList();

      ttSet.promoteKey('announced');

      expect(ttSet.toList(), equals(ttSetKeys));
    });
  });
}

int prefixDistance(final List<int> prefix, final List<int> key) {
  if (key.length < prefix.length) {
    // cannot compute hamming distance here as
    return -1;
  }

  // Assume worst case and improve if possible
  var distance = prefix.length;

  // Improve if possible
  for (var i = 0; i < prefix.length; i++) {
    if (prefix[i] == key[i]) {
      distance--;
    }
  }

  return distance;
}
