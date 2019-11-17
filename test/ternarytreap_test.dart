import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';

// Wraps search results of search for testing
//
// A single [key] can be inserted multiple times with different
// data thus [data] is a list to handle one to many relation.
class _KeyData<V> {
  // Constructs a new [KeyData].
  //
  // @param [key] The unique key for this result
  // @param [data] The data for this result
  // @throws [ArgumentError] If passed null data.
  _KeyData(this.key, this.data) {
    if (key == null) {
      throw ArgumentError.notNull('key');
    }
    if (data == null) {
      throw ArgumentError.notNull('data');
    }
  }

  static const String _key = 'key';
  static const String _data = 'data';

  // The unique key for this result.
  final String key;

  // A list of user supplied data objects.
  //
  // Because user may insert the same key multiple times with different
  // data this is a list. Will never be null.
  final List<V> data;

  // Return String value.
  //
  // @returns String repesenting object.
  @override
  String toString() => toJson().toString();

  // Return [Map] for json encoding.
  //
  // @returns String repesenting object.
  Map<String, dynamic> toJson() => <String, dynamic>{_key: key, _data: data};
}

void main() {
  group('TernaryTreap', () {
    const int numKeys = 1000;
    const int startVal = 123456798887;

    //Test data
    //Create increasing keys with overlap - worst case scenario for tree
    final List<int> testInput = <int>[
      for (int i = 0; i < numKeys; i++) startVal + i,
      for (int i = 0; i < numKeys; i++) (startVal + (numKeys / 2).round()) + i
    ];

    //Test output
    final Map<String, List<int>> collator = <String, List<int>>{};
    for (final int x in testInput) {
      if (collator.containsKey(x.toString())) {
        collator[x.toString()].add(x);
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
      final List<_KeyData<int>> expectedOutput = <_KeyData<int>>[
        for (String word in sortedKeys) _KeyData<int>(word, collator[word])
      ];

      final List<_KeyData<int>> result = <_KeyData<int>>[];
      tst.forEach((String key, List<int> data) {
        result.add(_KeyData<int>(key, data));
      });

      expect(json.encode(result), equals(json.encode(expectedOutput)));
    });

    test('forEachPrefixedBy', () {
      //Use key from middle of range
      final String key = (startVal + (numKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (int i = 0; i < key.length; i++) {
        final String prefix = key.substring(0, i + 1);

        final List<_KeyData<int>> expectedOutput = <_KeyData<int>>[
          for (String word in sortedKeys)
            if (word.startsWith(prefix)) _KeyData<int>(word, collator[word])
        ];

        final List<_KeyData<int>> result = <_KeyData<int>>[];
        tst.forEachPrefixedBy(prefix, (String key, List<int> data) {
          result.add(_KeyData<int>(key, data));
          return true;
        });

        expect(json.encode(result), equals(json.encode(expectedOutput)));
      }
    });

    test('keys', () {
      expect(json.encode(tst.keys), equals(json.encode(sortedKeys)));
    });

    test('[]', () {
      //Use key from middle of range
      final String key = (startVal + (numKeys / 2).round()).toString();

      expect(json.encode(tst[key]), equals(json.encode(collator[key])));

      expect(json.encode(tst['NOT FOUND']), equals(json.encode(null)));
    });

    test('containsKey', () {
      //Use key from middle of range
      final String key = (startVal + (numKeys / 2).round()).toString();

      expect(json.encode(tst.containsKey(key)), equals(json.encode(true)));

      expect(json.encode(tst.containsKey('NOT FOUND')),
          equals(json.encode(false)));
    });

    test('Stats', () {
      final Map<String, int> stats = tst.stats();
      expect(stats[TernaryTreap.keyCount], equals((numKeys * 1.5).round()));
    });

    test('Length', () {
      expect(tst.length, equals((numKeys * 1.5).round()));
    });

    test('KeyMappings', () {
      TernaryTreap<int> tree = TernaryTreap<int>(TernaryTreap.lowercase)
        ..add('TeStInG', 1);

      expect(json.encode(tree['fake']), equals(json.encode(null)));

      expect(json.encode(tree['tEsTiNg']), equals(json.encode(<int>[1])));

      expect(
          json.encode(tree['testing']),
          equals(
              json.encode(<int>[1])));

      tree = TernaryTreap<int>(TernaryTreap.collapseWhitespace)
        ..add(' t es   ti     ng  ', 1);
      expect(json.encode(tree['t es ti ng']), equals(json.encode(<int>[1])));

      tree = TernaryTreap<int>(TernaryTreap.lowerCollapse)
        ..add(' T eS   KK     Bg  ', 1);
      expect(json.encode(tree['t es kk bg']), equals(json.encode(<int>[1])));
    });
  });
}
