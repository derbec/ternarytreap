import 'package:ternarytreap/src/ternarytreap_base.dart'; 

/// Defines a 1 to n relation between Prefixes and Input strings
/// Use for prefix matching in autocompletion tasks etc.
class PrefixMatcher {
  /// Constructs a new [PrefixMatcher].
  ///
  /// @param [keyMapping] Optional instance of [KeyMapping] to be
  /// applied to all keys processed by this [PrefixMatcher].
  /// @returns New [PrefixMatcher].
  /// @see [TernaryTreap()]
  PrefixMatcher([KeyMapping keyMapping])
      : _ternaryTreap = TernaryTreap<String>(keyMapping);

  final TernaryTreap<String> _ternaryTreap;

  /// Return all keys in [PrefixMatcher]
  Iterable<String> get keys => _ternaryTreap.keys;

  /// Return all data in [PrefixMatcher]
  ///
  /// Returned in key order
  Iterable<List<String>> get values => _ternaryTreap.values;

  /// Add a key and store input string as data attached to the key.
  /// If key allready exists then string is added to existing key.
  ///
  /// @param [str] A unique sequence of characters to be stored for retrieval.
  /// @throws [ArgumentError] if key is empty.
  /// @see [TernaryTreap.add]
  void add(String str) => _ternaryTreap.add(str, str);

  /// Add all strings from [iterable] to the [PrefixMatcher]
  /// 
  /// @param An iterable generating strings
  void addAll(Iterable<String> iterable){
    iterable.forEach(add);
  }

  /// Return a list of previously added strings that start with [prefix].
  ///
  /// Returned strings are ordered by key (i.e. grouped by [KeyMapping]),
  /// and then by order of insertion.
  /// If [maxNumberOfMatches] is specified then only that number of matches
  /// will be returned useful in mobile environments where presenting 100's
  /// of matches is impractical and a waste of time.
  List<String> matchPrefix(String prefix, [int maxNumberOfMatches = 0]) {
    if (maxNumberOfMatches < 0) {
      throw ArgumentError();
    }

    final List<String> result = <String>[];

    forEachPrefixedBy(prefix, (String key, List<String> data) {
      result.addAll(data);
      return result.length < maxNumberOfMatches;
    });

    //trim result if needed
    return (maxNumberOfMatches > 0 && result.length > maxNumberOfMatches)
        ? result.sublist(0, maxNumberOfMatches)
        : result;
  }

  /// Applies [f] to each key/value pair of the [PrefixMatcher]
  ///
  /// Calling [f] must not add or remove keys from the [PrefixMatcher]
  void forEach(void Function(String key, List<String> data) f) {
    _ternaryTreap.forEach(f);
  }

  /// Applies [f] to each key/value pair of the [PrefixMatcher]
  /// where key is prefixed by [prefix].
  ///
  /// Calling [f] must not add or remove keys from the [PrefixMatcher]
  /// The return value of [f] is used for early stopping.
  /// This is useful when only a subset of the entire resultset is required.
  /// When [f] returns true iteration continues.
  /// When [f] returns false iteration stops.
  void forEachPrefixedBy(
      String prefix, bool Function(String key, List<String> value) f) {
    _ternaryTreap.forEachPrefixedBy(prefix, f);
  }

  /// Does specified [key] exist?.
  ///
  /// @param [key] The key to check.
  /// @returns true if key exists, false otherwise.
  /// @see [TernaryTreap.containsKey]
  bool containsKey(String key) => _ternaryTreap.containsKey(key);

  /// Return data for specified [key].
  ///
  /// @param [key] The key to get.
  /// @returns List of [String] objects corresponding to [key].
  /// If no data associated with key then return empty [List].
  /// If key found then return null.
  List<String> operator [](String key) => _ternaryTreap[key];

  /// Generate a string representation of this [PrefixMatcher].
  ///
  /// @returns String representation of objects in order of traversal
  /// formated as:
  /// key -> data (json encoded)
  /// @see [TernaryTreap.toString]
  @override
  String toString([String paddingChar = '-']) => _ternaryTreap.toString();
}
