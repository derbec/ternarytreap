import 'dart:collection';

import 'package:ternarytreap/src/ternarytreap_base.dart';

/// Defines a 1 to n relation between Prefixes and Input strings
/// Use for prefix matching in autocompletion tasks etc.
/// Iterating [PrefixMatcher] will return all input strings ordered
/// first by [KeyMapping] result then by insertion order.
class PrefixMatcher with IterableMixin<String> {
  /// Constructs a new [PrefixMatcher].
  ///
  /// @param [keyMapping] Optional instance of [KeyMapping] to be
  /// applied to all keys processed by this [PrefixMatcher].
  /// @returns New [PrefixMatcher].
  /// @see [TernaryTreap()]
  PrefixMatcher([KeyMapping keyMapping])
      : ternaryTreap = TernaryTreap<String>(keyMapping:keyMapping);

  /// Underlying [TernaryTreap]
  final TernaryTreap<String> ternaryTreap;

  /// Add a key and store input string as data attached to the key.
  /// If key allready exists then string is added to existing key.
  ///
  /// @param [str] A unique sequence of characters to be stored for retrieval.
  /// @throws [ArgumentError] if key is empty.
  /// @see [TernaryTreap.add]
  void add(String str) => ternaryTreap.add(str, str);

  /// Add all strings from [iterable] to the [PrefixMatcher]
  ///
  /// @param An iterable generating strings
  void addAll(Iterable<String> iterable) => iterable.forEach(add);

  /// Return an Iterable of previously added strings that start with [prefix].
  ///
  /// Returned strings are ordered by key (i.e. grouped by [KeyMapping]),
  /// and then by order of insertion.
  Iterable<String> match(String prefix) => ternaryTreap
      .valuesByKeyPrefix(prefix).flattened;

  /// Return data for specified [key].
  ///
  /// @param [key] The key to get.
  /// @returns List of [String] objects corresponding to [key].
  /// If no data associated with key then return empty [List].
  /// If key found then return null.
  List<String> operator [](String key) => ternaryTreap[key];

  /// Remove specified string [key] and return list of strings that
  /// were associated with [key]
  List<String> remove(String key) => ternaryTreap.remove(key);

  /// Does specified [key] exist?.
  ///
  /// @param [key] The key to check.
  /// @returns true if key exists, false otherwise.
  /// @see [TernaryTreap.containsKey]
  @override
  bool contains(Object key) => ternaryTreap.containsKey(key);

  @override
  Iterator<String> get iterator => ternaryTreap.values.flattened.iterator;

  @override
  int get length => ternaryTreap.length;
}
