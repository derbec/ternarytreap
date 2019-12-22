import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';
import 'words.dart';

void main() {
  group('PrefixMatcher', () {
    //Test output
    final collator = <String, List<String>>{};
    for (final x in words) {
      if (collator.containsKey(x.toString())) {
        if (!collator[x.toString()].contains(x)) {
          collator[x.toString()].add(x);
        }
      } else {
        collator[x.toString()] = <String>[x];
      }
    }

    final sortedKeys = collator.keys.toList()..sort();

    final matcher = PrefixMatcher(TernaryTreap.lowerCollapse)..addAll(words);
    test('matchPrefix', () {
      for (final key in sortedKeys) {
        //for each character in prefix compare prefix return to ternarytreap
        for (var i = 0; i < key.length; i++) {
          final prefix = key.substring(0, i + 1);

          final expectedOutput = <String>[
            for (String word in sortedKeys) if (word.startsWith(prefix)) word
          ];

          expect(matcher.match(prefix).toList(), equals(expectedOutput));
        }
      }
    });

    test('iterator', () {
      final expectedOutput = <String>[];

      for (final word in sortedKeys) {
        expectedOutput.addAll(collator[word]);
      }
      expect(matcher.toList(), equals(expectedOutput));
    });

    test('[]', () {
      for (final word in sortedKeys) {
        expect(matcher[word], equals(collator[word]));
      }
    });

    test('Remove', () {
      final tree = PrefixMatcher(TernaryTreap.lowercase)..add('at');

      expect(tree.remove('at'), equals(<String>['at']));

      tree.add('be');

      expect(tree.remove('CAT'), equals(const Iterable<String>.empty()));

      expect(tree.remove('BE'), equals(<String>['be']));

      collator.keys.toList().forEach(tree.remove);

      expect(tree.length, equals(0));
      expect(tree.isEmpty, equals(true));
    });
  });
}
