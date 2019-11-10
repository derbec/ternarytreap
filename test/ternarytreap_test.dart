import 'dart:convert';
import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';

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
      tst.insert(x.toString(), x);
    }
    test('Traversal', () {
      final List<TernaryTreapResult<int>> expectedOutput =
          <TernaryTreapResult<int>>[
        for (final String word in sortedKeys)
          TernaryTreapResult<int>(word, collator[word])
      ];

      final List<TernaryTreapResult<int>> output = tst.searchPrefix('');

      expect(json.encode(output), equals(json.encode(expectedOutput)));
    });

    test('Prefix', () {
      //Use key from middle of range
      final String key = (startVal + (numKeys / 2).round()).toString();

      //for each character in prefix compare prefix return to ternarytreap
      for (int i = 0; i < key.length; i++) {
        final String prefix = key.substring(0, i + 1);

        final List<TernaryTreapResult<int>> expectedOutput =
            <TernaryTreapResult<int>>[
          for (String word in sortedKeys)
            if (word.startsWith(prefix))
              TernaryTreapResult<int>(word, collator[word])
        ];

        expect(json.encode(tst.searchPrefix(prefix)),
            equals(json.encode(expectedOutput)));
      }
    });

    test('Search', () {
      //Use key from middle of range
      final String key = (startVal + (numKeys / 2).round()).toString();

      expect(json.encode(tst.search(key)),
          equals(json.encode(TernaryTreapResult<int>(key, collator[key]))));
    });

    test('Stats', () {
      final Map<String, int> stats = tst.stats();
      expect(stats[TernaryTreap.keyCount], equals((numKeys * 1.5).round()));
    });

    test('FormatTree', () {
      final List<String> lines = tst.formattedTree('-');
      expect(lines.length, equals((numKeys * 1.5).round()));
    });

    test('KeyTransforms', () {
      TernaryTreap<int> tree = TernaryTreap<int>(TernaryTreap.lowerCase)
        ..insert('TeStInG');
      expect(json.encode(tree.search('tEsTiNg')),
          equals(json.encode(TernaryTreapResult<int>('testing', <int>[]))));

      expect(
          json.encode(tree.searchPrefix('T')),
          equals(json.encode(<TernaryTreapResult<int>>[
            TernaryTreapResult<int>('testing', <int>[])
          ])));

      tree = TernaryTreap<int>(TernaryTreap.collapseWhitespace)
        ..insert(' t es   ti     ng  ');
      expect(json.encode(tree.search('t es ti ng')),
          equals(json.encode(TernaryTreapResult<int>('t es ti ng', <int>[]))));

      expect(
          json.encode(tree.searchPrefix('t es ti')),
          equals(json.encode(<TernaryTreapResult<int>>[
            TernaryTreapResult<int>('t es ti ng', <int>[])
          ])));

      tree = TernaryTreap<int>(TernaryTreap.lowerCollapse)
        ..insert(' T eS   KK     Bg  ');
      expect(
          json.encode(tree.search('t es kk bg')),
          equals(
              json.encode(TernaryTreapResult<int>('t es kk bg', <int>[]))));

      expect(
          json.encode(tree.searchPrefix('t es kk')),
          equals(json.encode(<TernaryTreapResult<int>>[
            TernaryTreapResult<int>('t es kk bg', <int>[])
          ])));
    });
  });
}
