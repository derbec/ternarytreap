import 'dart:convert';

import 'package:ternarytreap/ternarytreap.dart';
import 'package:test/test.dart';

import 'words.dart';

void main() {
  group('PrefixMatcher', () {
    //Test output
    final Map<String, List<String>> collator = <String, List<String>>{};
    for (final String x in words) {
      if (collator.containsKey(x.toString())) {
        if (!collator[x.toString()].contains(x)) {
          collator[x.toString()].add(x);
        }
      } else {
        collator[x.toString()] = <String>[x];
      }
    }

    final List<String> sortedKeys = collator.keys.toList()..sort();

    final PrefixMatcher matcher = PrefixMatcher(TernaryTreap.lowerCollapse)
      ..addAll(words);
    test('matchPrefix', () {
      for (final String key in sortedKeys) {
        //for each character in prefix compare prefix return to ternarytreap
        for (int i = 0; i < key.length; i++) {
          final String prefix = key.substring(0, i + 1);

          final List<String> expectedOutput = <String>[
            for (String word in sortedKeys) if (word.startsWith(prefix)) word
          ];

          expect(json.encode(matcher.match(prefix).toList()),
              equals(json.encode(expectedOutput)));
        }
      }
    });

    test('iterator', () {
      final List<String> expectedOutput = <String>[];

      for (final String word in sortedKeys) {
        expectedOutput.addAll(collator[word]);
      }
      expect(
          json.encode(matcher.toList()), equals(json.encode(expectedOutput)));
    });

    test('[]', () {
      for (final String word in sortedKeys) {
        expect(json.encode(matcher[word]), equals(json.encode(collator[word])));
      }
    });
  });
}
