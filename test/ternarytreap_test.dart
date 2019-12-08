import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';

Map<String, dynamic> mapEntryToJson(MapEntry<String, List<int>> mapEntry) =>
    <String, dynamic>{'key': mapEntry.key, 'val': mapEntry.value};

void main() {
  group('TernaryTreap', () {
    const int numUniqueKeys = 10;
    // Total number of keys taking into account overlap and special keys
    final int numKeys = (numUniqueKeys * 1.5).round() + 3;
    const int startVal = 17;

    //Test data
    //Create increasing keys with overlap - worst case scenario for tree
    final List<int> testKeys = <int>[
      (numUniqueKeys * 3 + startVal + 1),
      for (int i = 0; i < numUniqueKeys; i++) startVal + i,
      for (int i = 0; i < numUniqueKeys; i++)
        (startVal + (numUniqueKeys / 2).round()) + i,
      // Special keys for mapping to empty data
      (numUniqueKeys * 3 + startVal + 2),
      (numUniqueKeys * 3 + startVal + 3),
    ];

    //Test output
    final Map<String, List<int>> collator = <String, List<int>>{};
    for (final int x in testKeys) {
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

    final List<String> sortedKeys = collator.keys.toList()..sort();

    final TernaryTreap<int> tst = TernaryTreap<int>();
    for (final int x in testKeys) {
      // Special keys are added with no data
      if (x > (numUniqueKeys * 3 + startVal)) {
        tst.add(x.toString());
      } else {
        tst.add(x.toString(), x);
      }
    }

    test('forEach', () {
      final List<Map<String, dynamic>> expectedOutput = <Map<String, dynamic>>[
        for (String word in sortedKeys)
          mapEntryToJson(MapEntry<String, List<int>>(word, collator[word]))
      ];

      final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
      tst.forEach((String key, List<int> data) {
        result.add(mapEntryToJson(MapEntry<String, List<int>>(key, data)));
      });

      expect(json.encode(result), equals(json.encode(expectedOutput)));
    });

    test('forEachPrefixedBy', () {
      //Use key from middle of range
      final String key = (startVal + (numUniqueKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (int i = 0; i < key.length; i++) {
        final String prefix = key.substring(0, i + 1);

        final List<Map<String, dynamic>> expectedOutput =
            <Map<String, dynamic>>[
          for (String word in sortedKeys)
            if (word.startsWith(prefix))
              mapEntryToJson(MapEntry<String, List<int>>(word, collator[word]))
        ];

        final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
        tst.forEachPrefixedBy(prefix, (String key, List<int> data) {
          result.add(mapEntryToJson(MapEntry<String, List<int>>(key, data)));
        });

        expect(json.encode(result), equals(json.encode(expectedOutput)));

        // Check that subtree length is maintained correctly while here
        final int subTreeLength = tst.entriesByKeyPrefix(prefix).length;

        expect(subTreeLength, equals(expectedOutput.length));
      }
    });

    test('one key', () {
      final TernaryTreap<int> oneKey = TernaryTreap<int>()..add('a');
      expect(oneKey.length, equals(1));
      expect(oneKey.entries.length, equals(1));
      expect(oneKey.entriesByKeyPrefix('a').length, equals(1));
      expect(oneKey.entriesByKeyPrefix('b').length, equals(0));

      expect(
          json.encode(
              oneKey.entriesByKeyPrefix('b').map(mapEntryToJson).toList()),
          equals(json.encode(<MapEntry<String, List<int>>>[])));

      expect(
          json.encode(
              oneKey.entriesByKeyPrefix('a').map(mapEntryToJson).toList()),
          equals(json.encode(<Map<String, dynamic>>[
            mapEntryToJson(const MapEntry<String, List<int>>('a', <int>[]))
          ])));
    });

    test('keys', () {
      expect(json.encode(tst.keys.toList()), equals(json.encode(sortedKeys)));
    });

    test('values', () {
      //Filter out empty lists
      final List<List<int>> expectedOutput = <List<int>>[
        for (String word in sortedKeys)
          if (collator[word].isNotEmpty) collator[word]
      ];
      expect(json.encode(tst.values.toList()),
          equals(json.encode(expectedOutput)));
    });
    test('entries', () {
      final List<Map<String, dynamic>> expectedOutput = <Map<String, dynamic>>[
        for (String word in sortedKeys)
          mapEntryToJson(MapEntry<String, List<int>>(word, collator[word]))
      ];
      expect(json.encode(tst.entries.map(mapEntryToJson).toList()),
          equals(json.encode(expectedOutput)));
    });

    test('[]', () {
      //Use key from middle of range
      final String key = (startVal + (numUniqueKeys / 2).round()).toString();

      expect(json.encode(tst[key]), equals(json.encode(collator[key])));

      expect(json.encode(tst['NOT FOUND']), equals(json.encode(null)));

      expect(json.encode(tst['1']), equals(json.encode(null)));
    });

    test('[]=', () {
      final TernaryTreap<int> tree =
          TernaryTreap<int>(keyMapping: TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(json.encode(tree['At']), equals(json.encode(<int>[1])));

      tree['at'] = <int>[2, 3];

      expect(json.encode(tree['AT']), equals(json.encode(<int>[2, 3])));
    });

    test('containsKey', () {
      //Use key from middle of range
      final String key = (startVal + (numUniqueKeys / 2).round()).toString();

      expect(json.encode(tst.containsKey(key)), equals(json.encode(true)));

      expect(json.encode(tst.containsKey('NOT FOUND')),
          equals(json.encode(false)));
    });

    test('length', () {
      expect(tst.length, equals(numKeys));
    });

    test('KeyMappings', () {
      TernaryTreap<int> tree =
          TernaryTreap<int>(keyMapping: TernaryTreap.lowercase)
            ..add('TeStInG', 1);

      expect(json.encode(tree['fake']), equals(json.encode(null)));

      expect(json.encode(tree['tEsTiNg']), equals(json.encode(<int>[1])));

      expect(json.encode(tree['testing']), equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(keyMapping: TernaryTreap.collapseWhitespace)
        ..add(' t es   ti     ng  ', 1);
      expect(
          json.encode(tree['t             '
              'es ti ng     ']),
          equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(keyMapping: TernaryTreap.lowerCollapse)
        ..add(' T eS   KK     Bg  ', 1);
      expect(
          json.encode(tree['       t es'
              ' kk bg']),
          equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(keyMapping: TernaryTreap.nonLetterToSpace)
        ..add('*T_eS  -KK  ,  Bg )\n\t', 1);
      expect(json.encode(tree[' T eS  ^KK %* ^Bg ;  ']),
          equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(keyMapping: TernaryTreap.joinSingleLetters)
        ..add('    a b .  ab.cd a b abcd a        b', 1);

      expect(json.encode(tree['ab .  ab.cd ab abcd ab']),
          equals(json.encode(<int>[1])));
    });

    test('Remove', () {
      final TernaryTreap<int> tree =
          TernaryTreap<int>(keyMapping: TernaryTreap.lowercase);

      tree['At'] = <int>[1];

      expect(json.encode(tree.remove('At')), equals(json.encode(<int>[1])));

      tree['be'] = <int>[2, 3];

      expect(json.encode(tree.remove('CAT')), equals(json.encode(null)));

      expect(json.encode(tree.remove('BE')), equals(json.encode(<int>[2, 3])));

      collator.keys.toList().forEach(tst.remove);

      expect(tst.length, equals(0));
      expect(tst.isEmpty, equals(true));
    });
  });
}
