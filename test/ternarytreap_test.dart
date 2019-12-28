import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';

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
  const numUniqueKeys = 10;
  // Total number of keys taking into account overlap and special keys
  final numKeys = (numUniqueKeys * 1.5).round() + 3;
  const startVal = 17;
  List<String> sortedKeys;
  Map<String, List<int>> collator;
  TernaryTreap<int> tst;

  setUp(() {
    //Test data
    //Create increasing keys with overlap - worst case scenario for tree
    final Iterable<int> testKeys = <int>[
      (numUniqueKeys * 3 + startVal + 1),
      for (int i = 0; i < numUniqueKeys; i++) startVal + i,
      for (int i = 0; i < numUniqueKeys; i++)
        (startVal + (numUniqueKeys / 2).round()) + i,
      // Special keys for mapping to empty data
      (numUniqueKeys * 3 + startVal + 2),
      (numUniqueKeys * 3 + startVal + 3),
    ];

    //Test output
    collator = <String, List<int>>{};
    for (final x in testKeys) {
      if (collator.containsKey(x.toString())) {
        if (!collator[x.toString()].contains(x)) {
          collator[x.toString()].add(x);
        }
      } else {
        // Map special keys to empty data
        if (x > (numUniqueKeys * 3 + startVal)) {
          collator[x.toString()] = <int>[];
        } else {
          collator[x.toString()] = <int>[x];
        }
      }
    }

    sortedKeys = collator.keys.toList()..sort();

    tst = TernaryTreapSet<int>();
    for (final x in testKeys) {
      // Special keys are added with no data
      if (x > (numUniqueKeys * 3 + startVal)) {
        tst.add(x.toString());
      } else {
        tst.add(x.toString(), x);
      }
    }
  });
  group('TernaryTreap', () {
    test('forEach', () {
      final expectedOutput = <MapEntry<String, int>>[
        for (String word in sortedKeys)
          for (int x in collator[word]) MapEntry<String, int>(word, x)
      ];

      final result = <MapEntry<String, int>>[];
      tst.forEach((String key, int data) {
        result.add(MapEntry<String, int>(key, data));
      });

      expect(json.encode(result, toEncodable: toEncodable),
          equals(json.encode(expectedOutput, toEncodable: toEncodable)));
    });

    test('forEachKey', () {
      final expectedOutput = <MapEntry<String, Iterable<int>>>[
        for (String word in sortedKeys)
          MapEntry<String, Iterable<int>>(word, collator[word])
      ];

      final result = <MapEntry<String, Iterable<int>>>[];
      tst.forEachKey((String key, Iterable<int> data) {
        result.add(MapEntry<String, Iterable<int>>(key, data));
      });

      expect(json.encode(result, toEncodable: toEncodable),
          equals(json.encode(expectedOutput, toEncodable: toEncodable)));
    });

    test('forEachKeyPrefixedBy', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <MapEntry<String, List<int>>>[
          for (String word in sortedKeys)
            if (word.startsWith(prefix))
              MapEntry<String, List<int>>(word, collator[word])
        ];

        final result = <MapEntry<String, Iterable<int>>>[];
        tst.forEachKeyPrefixedBy(prefix, (String key, Iterable<int> data) {
          result.add(MapEntry<String, Iterable<int>>(key, data));
        });

        expect(json.encode(result, toEncodable: toEncodable),
            equals(json.encode(expectedOutput, toEncodable: toEncodable)));

        // Check that subtree length is maintained correctly while here
        final subTreeLength = tst.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
    });

    test('one key', () {
      final TernaryTreap<int> oneKey = TernaryTreapSet<int>()..add('a');
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
      expect(tst.keys.toList(), equals(sortedKeys));
    });

    test('values', () {
      //Filter out empty lists
      final expectedOutput = <int>[
        for (String word in sortedKeys)
          if (collator[word].isNotEmpty) ...collator[word]
      ];
      expect(tst.values.toList(), equals(expectedOutput));
    });
    test('entries', () {
      final expectedOutput = <MapEntry<String, Iterable<int>>>[
        for (String word in sortedKeys)
          MapEntry<String, Iterable<int>>(word, collator[word])
      ];
      expect(json.encode(tst.entries.toList(), toEncodable: toEncodable),
          equals(json.encode(expectedOutput, toEncodable: toEncodable)));
    });

    test('entriesByKeyPrefix', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <MapEntry<String, Iterable<int>>>[
          for (String word in sortedKeys)
            if (word.startsWith(prefix))
              MapEntry<String, Iterable<int>>(word, collator[word])
        ];

        expect(
            json.encode(tst.entriesByKeyPrefix(prefix).toList(),
                toEncodable: toEncodable),
            equals(json.encode(expectedOutput, toEncodable: toEncodable)));

        // Check that subtree length is maintained correctly while here
        expect(tst.entriesByKeyPrefix(prefix).length, equals(expectedOutput.length));
      }

      expect(tst.entriesByKeyPrefix('NOT PRESENT').isEmpty,equals(true));
    });

    test('keysByPrefix', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <String>[
          for (String word in sortedKeys) if (word.startsWith(prefix)) word
        ];

        expect(tst.keysByPrefix(prefix).toList(), equals(expectedOutput));

        // Check that subtree length is maintained correctly while here
        final subTreeLength = tst.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
      expect(tst.keysByPrefix('NOT PRESENT').isEmpty,equals(true));
    });

    test('valuesByKeyPrefix', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (var i = 0; i < key.length; i++) {
        final prefix = key.substring(0, i + 1);

        final expectedOutput = <int>[
          for (String word in sortedKeys)
            if (word.startsWith(prefix)) ...collator[word]
        ];

        expect(tst.valuesByKeyPrefix(prefix).toList(), equals(expectedOutput));

        // Check that subtree length is maintained correctly while here
        final subTreeLength = tst.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
      expect(tst.valuesByKeyPrefix('NOT PRESENT').isEmpty,equals(true));
    });

    test('[]', () {
      //Use key from middle of range
      final key = (startVal + (numUniqueKeys / 2).round()).toString();

      expect(tst[key], equals(collator[key]));

      expect(tst['NOT FOUND'], equals(null));

      expect(tst['1'], equals(null));
    });

    test('[]=', () {
      final TernaryTreap<int> tree =
          TernaryTreapSet<int>(TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree['At'], equals(<int>[1]));

      tree['at'] = <int>[2, 3];

      expect(tree['AT'], equals(<int>[2, 3]));
    });

    test('contains', () {
      for (final key in sortedKeys) {
        for (final val in collator[key]) {
          expect(tst.contains(key, val), equals(true));
          expect(tst.contains(key, -val), equals(false));
        }
      }

      expect(tst.contains('NOT FOUND', 5), equals(false));
    });

    test('containsKey', () {
      for (final key in sortedKeys) {
        expect(tst.containsKey(key), equals(true));
      }

      expect(tst.containsKey('NOT FOUND'), equals(false));
    });

    test('containsValue', () {
      for (final key in sortedKeys) {
        for (final val in collator[key]) {
          expect(tst.containsValue(val), equals(true));
          expect(tst.containsValue(-val), equals(false));
        }
      }
    });

    test('length', () {
      expect(tst.length, equals(numKeys));
    });

    test('KeyMapping', () {
      TernaryTreap<int> tree = TernaryTreapSet<int>(TernaryTreap.lowercase)
        ..add('TeStInG', 1);

      expect(tree['fake'], equals(null));

      expect(tree['tEsTiNg'], equals(<int>[1]));

      expect(tree['testing'], equals(<int>[1]));

      expect(tree.keys.first, equals('testing'));

      testIdempotence(tree, 'DSAF DF SD FSDRTE ');

      tree = TernaryTreapSet<int>(TernaryTreap.uppercase)..add('TeStInG', 1);

      expect(tree['fake'], equals(null));

      expect(tree['tEsTiNg'], equals(<int>[1]));

      expect(tree['testing'], equals(<int>[1]));

      expect(tree.keys.first, equals('TESTING'));

      testIdempotence(tree, 'asdas KJHGJGH fsdfsdf ');

      tree = TernaryTreapSet<int>(TernaryTreap.collapseWhitespace)
        ..add(' t es   ti     ng  ', 1);
      expect(
          tree['t             '
              'es ti ng     '],
          equals(<int>[1]));

      expect(tree.keys.first, equals('t es ti ng'));

      testIdempotence(tree, '   asdas          KJHG  JGH fsdf  sdf   ');

      tree = TernaryTreapSet<int>(TernaryTreap.lowerCollapse)
        ..add(' T eS   KK     Bg  ', 1);
      expect(
          tree['       t es'
              ' kk bg'],
          equals(<int>[1]));

      expect(tree.keys.first, equals('t es kk bg'));

      testIdempotence(tree, '   asdas          KJHG  JGH fsdf  sdf   ');

      tree = TernaryTreapSet<int>(TernaryTreap.nonLetterToSpace)
        ..add('*T_eS  -KK  ,  Bg )\n\t', 1);
      expect(tree[' T eS  ^KK %* ^Bg ;  '], <int>[1]);

      expect(tree.keys.first, equals(' T eS   KK     Bg    '));

      testIdempotence(tree, ' %  asd+=as   & & ^J%@HG  J(GH f`sdf  s*df   )!');

      tree = TernaryTreapSet<int>(TernaryTreap.joinSingleLetters)
        ..add('    a     b .  ab.cd a  b abcd a        b', 1);

      expect(tree['ab .  ab.cd ab abcd ab'], equals(<int>[1]));

      expect(tree.keys.first, equals('ab . ab.cd ab abcd ab'));

      testIdempotence(tree, '    a     b .  ab.cd a  b abcd a        b v');
    });

    test('remove', () {
      for (final key in sortedKeys) {
        for (final val in collator[key]) {
          expect(tst.remove(key, val), equals(true));
          expect(tst.remove(key, -val), equals(false));
        }
      }

      expect(tst.remove('NOT FOUND', 5), equals(false));
    });

    test('removeValues', () {
      final TernaryTreap<int> tree =
          TernaryTreapSet<int>(TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree.removeValues('At'), equals(<int>[1]));

      expect(tree['At'], equals(<int>[]));

      tree['be'] = <int>[2, 3];

      expect(tree.removeValues('CAT'), equals(<int>[]));

      expect(tree.removeValues('BE'), equals(<int>[2, 3]));
      expect(tree['Be'], equals(<int>[]));
    });

    test('removeKey', () {
      final TernaryTreap<int> tree =
          TernaryTreapSet<int>(TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(tree.removeKey('At'), equals(<int>[1]));

      tree['be'] = <int>[2, 3];

      expect(tree.removeKey('CAT'), equals(<int>[]));

      expect(tree.removeKey('BE'), equals(<int>[2, 3]));

      collator.keys.toList().forEach(tst.removeKey);

      expect(tst.length, equals(0));
      expect(tst.isEmpty, equals(true));
      expect(tst.isNotEmpty, equals(false));
    });

    test('addAll', () {
      final TernaryTreap<int> tree = TernaryTreapSet<int>();

      tree['At'] = <int>[1];

      tree['be'] = <int>[2, 3];

      tree.addAll(tst);

      expect(tree.length, equals(tst.length + 2));

      // Original mappings should still be there
      expect(tree['At'], equals(<int>[1]));
      expect(tree['be'], equals(<int>[2, 3]));

      // All mappings from tst should be there as well
      for (final key in tst.keys) {
        expect(tree[key], equals(tst[key]));
      }

      // Check set behaviour by adding again
      tree.addAll(tst);
      // All mappings from tst should be the same
      for (final key in tst.keys) {
        expect(tree[key], equals(tst[key]));
      }
    });

    test('addValues', () {
      final TernaryTreap<int> tree = TernaryTreapSet<int>();

      tree['At'] = <int>[1];

      tree['be'] = <int>[2, 3];

      for (final key in tst.keys) {
        tree.addValues(key, tst[key]);
      }

      expect(tree.length, equals(tst.length + 2));

      // Original mappings should still be there
      expect(tree['At'], equals(<int>[1]));
      expect(tree['be'], equals(<int>[2, 3]));

      // All mappings from tst should be there as well
      for (final key in tst.keys) {
        expect(tree[key], equals(tst[key]));
      }

      // Check set behaviour by adding again
      for (final key in tst.keys) {
        tree.addValues(key, tst[key]);
      }

      // All mappings from tst should be the same
      for (final key in tst.keys) {
        expect(tree[key], equals(tst[key]));
      }
    });

    test('asMap', () {
      expect(tst.asMap(), equals(collator));
    });

    test('asImmutable', () {
      expect(tst.asImmutable().asMap(), equals(collator));
    });
  });
}
