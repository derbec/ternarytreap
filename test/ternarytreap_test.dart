import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';

Map<String, dynamic> mapEntryToJson(MapEntry<String, List<int>> mapEntry) =>
    <String, dynamic>{'key': mapEntry.key, 'val': mapEntry.value};

void main() {
  group('TernaryTreap', () {
    const int numUniqueKeys = 10753;
    const int startVal = 17;

    //Test data
    //Create increasing keys with overlap - worst case scenario for tree
    final List<int> testInput = <int>[
      for (int i = 0; i < numUniqueKeys; i++) startVal + i,
      for (int i = 0; i < numUniqueKeys; i++)
        (startVal + (numUniqueKeys / 2).round()) + i
    ];

    //Test output
    final Map<String, List<int>> collator = <String, List<int>>{};
    for (final int x in testInput) {
      if (collator.containsKey(x.toString())) {
        if (!collator[x.toString()].contains(x)) {
          collator[x.toString()].add(x);
        }
      } else {
        collator[x.toString()] = <int>[x];
      }
    }

    final List<String> sortedKeys = collator.keys.toList()..sort();

    final TernaryTreap<int> tst = TernaryTreap<int>();
    for (final int x in testInput) {
      tst.add(x.toString(), x);
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
          return true;
        });

        expect(json.encode(result), equals(json.encode(expectedOutput)));
      }
    });

    test('keys', () {
      expect(json.encode(tst.keys.toList()), equals(json.encode(sortedKeys)));
    });

    test('values', () {
      final List<List<int>> expectedOutput = <List<int>>[
        for (String word in sortedKeys) collator[word]
      ];
      expect(json.encode(tst.values.toList()),
          equals(json.encode(expectedOutput)));
    });
test('entries', () {
    final List<Map<String, dynamic>> expectedOutput =
          <Map<String,dynamic>>[
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
    });

    test('containsKey', () {
      //Use key from middle of range
      final String key = (startVal + (numUniqueKeys / 2).round()).toString();

      expect(json.encode(tst.containsKey(key)), equals(json.encode(true)));

      expect(json.encode(tst.containsKey('NOT FOUND')),
          equals(json.encode(false)));
    });

    test('stats', () {
      final int numKeys = (numUniqueKeys * 1.5).round();
      final Map<String, int> stats = tst.stats();
      expect(stats[TernaryTreap.keyCount], equals(numKeys));
    });

    test('length', () {
      final int numKeys = (numUniqueKeys * 1.5).round();
      expect(tst.length, equals(numKeys));
      expect(tst.length2, equals(numKeys));
    });

    test('KeyMappings', () {
      TernaryTreap<int> tree = TernaryTreap<int>(TernaryTreap.lowercase)
        ..add('TeStInG', 1);

      expect(json.encode(tree['fake']), equals(json.encode(null)));

      expect(json.encode(tree['tEsTiNg']), equals(json.encode(<int>[1])));

      expect(json.encode(tree['testing']), equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(TernaryTreap.collapseWhitespace)
        ..add(' t es   ti     ng  ', 1);
      expect(json.encode(tree['t es ti ng']), equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(TernaryTreap.lowerCollapse)
        ..add(' T eS   KK     Bg  ', 1);
      expect(json.encode(tree['t es kk bg']), equals(json.encode(<int>[1])));
    });
  });
}
