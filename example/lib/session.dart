import 'package:ternarytreap/ternarytreap.dart';
import 'package:meta/meta.dart';
import 'package:quiver_hashcode/hashcode.dart';

/// An example of a data object, takes a title and
/// description, and adds a timestamp.
@immutable
class Metadata {
  /// Constructor for [Metadata]
  Metadata(this.title, this.description)
      : timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  /// Title - will be set to original input string pre KeyMapping
  final String title;

  /// Description
  final String description;

  /// Timestamp
  final String timestamp;

  @override
  bool operator ==(dynamic other) =>
      other is Metadata &&
      title == other.title &&
      description == other.description &&
      timestamp == other.timestamp;

  @override
  int get hashCode => hash3(title, description, timestamp);

  /// Return String value.
  ///
  /// @returns String repesenting object.
  @override
  String toString() => <String, dynamic>{
        'title': title,
        'description': description,
        'timestamp': timestamp,
      }.toString();
}

/// Single round of example session
class Session {
  /// Constructor for [Session]
  Session([KeyMapping keyMapping])
      : ternaryTreap = keyMapping == null
            ? TernaryTreap<Metadata>()
            : TernaryTreap<Metadata>(keyMapping);

  /// [TernaryTreap] with key transform determined by client
  final TernaryTreap<Metadata> ternaryTreap;

  /// Title currently being inserted
  String title;

  /// Process a single line of data from client.
  /// If empty title entered then session over and
  /// no more data expected.
  ///
  /// @returns true if more data expected, false otherwise
  bool processLine(String line) {
    if (title == null) {
      // we are expecting a key
      if (line.isEmpty) {
        // End of session, signal client
        return false;
      } else {
        title = line;
        return true;
      }
    } else {
      // we are expecting a description
      if (line.isEmpty) {
        // no description given
        // add key without data
        ternaryTreap.add(title);
      } else {
        // store original input string as title
        ternaryTreap.add(title, Metadata(title, line));
      }
      // Reset for next round
      title = null;
      return true;
    }
  }
}
