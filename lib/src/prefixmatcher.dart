import 'dart:collection';

import 'package:ternarytreap/src/ternarytreap_base.dart';

/// A [TernaryTreap] specialised for [String] values.
///
/// Use for prefix matching in autocompletion tasks etc.
///
/// A single Key can map to multiple Input strings.
/// This relationship is formed by specified [KeyMapping].
///
/// Iterating [PrefixMatcher] will return all input strings ordered
/// first by Key then by insertion order.
///
///
/// [PrefixMatcher] is the function:
///
/// * <i>f</i> : <i>K</i> &mapsto; &weierp; (<i>I</i>) &setminus; &emptyset;
///
/// such that:
///
/// * K is the set of all Key strings
/// * I is the set of all Input strings
/// * &weierp; (<i>I</i>) &setminus; &emptyset; is the powerset of I exluding the empty set
///
/// ```dart
///
/// final  PrefixMatcher matcher = PrefixMatcher(TernaryTreap.lowerCollapse)
///
/// ..addAll(['cat', 'Cat', 'CAT', 'CanaRy', 'CANARY']);
///
/// ```
///
/// ```dart
///
/// print(matcher.match('can'));
///
/// ```
///
/// ```shell
///
/// (CanaRy, CANARY)
///
/// ```
class PrefixMatcher with IterableMixin<String> {
  /// Constructs a new [PrefixMatcher].
  ///
  /// Argument [keyMapping] is an optional instance of [KeyMapping] to be
  /// applied to all keys processed by this [PrefixMatcher].
  /// see [TernaryTreap()].
  PrefixMatcher([KeyMapping keyMapping])
      : ternaryTreap = TernaryTreapSet<String>(keyMapping);

  /// Underlying [TernaryTreap]
  final TernaryTreap<String> ternaryTreap;

  /// Insert an input string for later querying.
  ///
  /// [str] is a string to be converted via [KeyMapping] into a key.
  ///
  /// Throws [ArgumentError] if key is empty.
  /// @see [TernaryTreap.add]
  void add(String str) => ternaryTreap.add(str, str);

  /// Add all strings from [iterable] to the [PrefixMatcher].
  ///
  void addAll(Iterable<String> iterable) => iterable.forEach(add);

  /// Return an Iterable of previously added strings that start with [prefix].
  ///
  /// Returned strings are ordered by key (i.e. grouped by [KeyMapping]),
  /// and then by order of insertion.
  Iterable<String> match(String prefix) =>
      ternaryTreap.valuesByKeyPrefix(prefix);

  /// @returns [Iterable] of [String] objects corresponding to [key].
  ///
  /// If no data associated with key then return empty [List].
  /// If key found then return null.
  Iterable<String> operator [](String key) => ternaryTreap[key];

  /// Remove specified string [key] and return list of strings that
  /// were associated with [key]
  /// See [TernaryTreap.remove]
  Iterable<String> remove(String key) => ternaryTreap.removeKey(key);

  /// Does specified [key] exist?.
  ///
  /// Returns true if key exists, false otherwise.
  /// See [TernaryTreap.containsKey]
  @override
  bool contains(Object key) => ternaryTreap.containsKey(key);

  @override
  Iterator<String> get iterator => ternaryTreap.values.iterator;

  @override
  int get length => ternaryTreap.length;
}
