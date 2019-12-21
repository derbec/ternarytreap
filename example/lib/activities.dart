import 'package:ternarytreap/ternarytreap.dart';
import 'package:meta/meta.dart';
import 'package:quiver_hashcode/hashcode.dart';

/// An example of a data object, a dictionary entry that takes a [word] and
/// [definition], and adds a timestamp.
@immutable
class DictEntry {
  /// Constructor for [DictEntry]
  DictEntry(this.word, this.definition)
      : timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  /// Title - will be set to original input string pre KeyMapping
  final String word;

  /// Description
  final String definition;

  /// Timestamp
  final String timestamp;

  @override
  bool operator ==(dynamic other) =>
      other is DictEntry &&
      word == other.word &&
      definition == other.definition &&
      timestamp == other.timestamp;

  @override
  int get hashCode => hash3(word, definition, timestamp);

  /// Return String value.
  ///
  /// @returns String repesenting object.
  @override
  String toString() => <String, dynamic>{
        'word': word,
        'definition': definition,
        'timestamp': timestamp,
      }.toString();
}

/// An activity manager
abstract class Activity {
  /// Process a single line of data from client.
  /// If empty title entered then session over and
  /// no more data expected.
  ///
  /// @returns true if more data expected, false otherwise
  bool processLine(String line);

  /// Display prompt for next action
  String get prompt;

  /// Return the underlying [TernaryTreap]
  TernaryTreap<DictEntry> get ternaryTreap;

  /// Return string representing current [TernaryTreap] state
  String treeString() {
    final StringBuffer result = StringBuffer();

    if (ternaryTreap.isEmpty) {
      result..writeln()..writeln('*** TernaryTreap is empty')..writeln();
    } else {
      result
        ..writeln()
        ..writeln('*** Current TernaryTreap state showing'
            ' depth, keys and data')
        ..write(ternaryTreap.toString())
        ..writeln('****')
        ..writeln();
    }
    return result.toString();
  }
}

/// Manage input round
class InputActivity extends Activity {
  /// Constructor for [InputActivity]
  InputActivity({KeyMapping keyMapping, List<String> preload})
      : _ternaryTreap = keyMapping == null
            ? TernaryTreapSet<DictEntry>()
            : TernaryTreapSet<DictEntry>(keyMapping) {
    if (preload.isNotEmpty) {
      for (final String word in preload) {
        // fabricate dict entry
        _ternaryTreap.add(word, DictEntry(word, 'meaning of $word'));
      }
    }
  }

  /// [TernaryTreap] with key transform determined by client
  final TernaryTreap<DictEntry> _ternaryTreap;

  @override
  TernaryTreap<DictEntry> get ternaryTreap => _ternaryTreap;

  /// Word currently being inserted
  String word;

  /// Process a single line of data from client.
  /// If empty title entered then session over and
  /// no more data expected.
  ///
  /// @returns true if more data expected, false otherwise
  @override
  bool processLine(String line) {
    if (word == null) {
      // we are expecting a key
      if (line.isEmpty) {
        // End of session, signal client
        return false;
      } else {
        word = line;
        return true;
      }
    } else {
      // store input as value
      _ternaryTreap.add(word, DictEntry(word, line));

      // Reset for next round
      word = null;
      return true;
    }
  }

  @override
  String get prompt {
    final String prefix = 'Entry # ${ternaryTreap.length.toString()}';
    if (word == null) {
      return '${treeString()}'
          '$prefix Enter word for insertion (or Enter to quit)';
    } else {
      return '$prefix Enter optional definition to associate with word';
    }
  }
}

/// Manage query round
class QueryActivity extends Activity {
  /// Constructor for [QueryActivity]
  QueryActivity(this._inputSession);

  final InputActivity _inputSession;

  @override
  TernaryTreap<DictEntry> get ternaryTreap => _inputSession.ternaryTreap;

  String _query;

  /// Process a single line of data from client.
  /// If empty title entered then session over and
  /// no more data expected.
  ///
  /// @returns true if more data expected, false otherwise
  @override
  bool processLine(String line) {
    if (line.isEmpty) {
      // End of session, signal client
      return false;
    }
    _query = line;
    return true;
  }

  @override
  String get prompt {
    final StringBuffer result = StringBuffer();
    if (_query != null) {
      result.writeln(ternaryTreap.valuesByKeyPrefix(_query));
    }
    result
      ..writeln()
      ..writeln('Enter word prefix to search for'
          ' (or Enter to quit)');
    return result.toString();
  }
}
