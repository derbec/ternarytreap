import 'dart:io';
import 'package:ternarytreap/ternarytreap.dart' as ternarytreap;

/// Mapping from word to frequency
class WordFrequency {
  WordFrequency(this.word, {this.frequency = 1});

  /// Word to keep track of
  final String word;

  /// Number of times word has been encountered
  int frequency;

  /// Compare based only upon word
  @override
  bool operator ==(Object other) =>
      other is WordFrequency && word == other.word;

  /// Hash only on word
  @override
  int get hashCode => word.hashCode;

  @override
  String toString() => '[Word($word), Frequency($frequency)]';
}

/// Mapping from code to word frequencies
final codeTowordFrequency = ternarytreap.TTMultiMapSet<WordFrequency>();

void main(List<String> args) {
  // map numbers to words, keeping track of counts
  mapNumberToWord('1111', 'cat');
  mapNumberToWord('1111', 'dog');
  mapNumberToWord('1111', 'bird');
  mapNumberToWord('1111', 'dog');

  mapNumberToWord('2222', 'bird');
  mapNumberToWord('2222', 'bee');
  mapNumberToWord('2222', 'cat');
  mapNumberToWord('2222', 'ant');
  mapNumberToWord('2222', 'cat');

  mapNumberToWord('3333', 'rat');
  mapNumberToWord('3333', 'bee');
  mapNumberToWord('3333', 'rat');
  mapNumberToWord('3333', 'dog');
  mapNumberToWord('3333', 'rat');

  /// Get each set
  final set1111 = codeTowordFrequency['1111'];
  final set2222 = codeTowordFrequency['2222'];
  final set3333 = codeTowordFrequency['3333'];

  // View each set
  stdout.writeln('Number 1111');
  stdout.writeln(set1111);
  stdout.writeln('Number 2222');
  stdout.writeln(set2222);
  stdout.writeln('Number 3333');
  stdout.writeln(set3333);
}

/// Associate word to number, counting frequency
void mapNumberToWord(String numberStr, String word) {
  // Create a search object
  final lookupWordFreq = WordFrequency(word);

  // Retrieve any existing object from set
  final existingWordFreq =
      codeTowordFrequency.lookup(numberStr, lookupWordFreq);

  if (identical(existingWordFreq, null)) {
    // If word not already known then add with zero count
    codeTowordFrequency.add(numberStr, lookupWordFreq);
  } else {
    // Otherwise update count
    existingWordFreq.frequency++;
  }
}
