import 'dart:collection';

import 'key_mapping.dart';
import 'prefixeditdistanceiterable.dart';
import 'ttmultimapimpl.dart';

/// A Set based around TernaryTreap
class TTSet extends SetBase<String> {
  /// Construct a new TernaryTreapSet
  TTSet([KeyMapping keyMapping])
      : _ternaryTreap = TTMultiMapList(keyMapping);

  final TTMultiMapList _ternaryTreap;

  @override
  bool add(String value) => _ternaryTreap.add(value);

  @override
  bool contains(Object element) =>
      (element is String) && _ternaryTreap.containsKey(element);

  @override
  Iterator<String> get iterator => _ternaryTreap.keys.iterator;

  @override
  int get length => _ternaryTreap.length;

  @override
  String lookup(Object element) =>
      (element is String && _ternaryTreap.containsKey(element))
          ? element
          : null;

  /// Returns [Iterable] collection of each element of the [TTSet]
  /// where key is prefixed by [mapKey]`(`[prefix]`)`.
  ///
  /// If [mapKey]`(`[prefix]`)` is empty then returns empty [Iterable].
  ///
  /// If [fuzzy] is true then search will expand to all keys within
  /// a [Hamming edit distance](https://en.wikipedia.org/wiki/Hamming_distance)
  /// corresponding to length of transformed prefix.
  ///
  /// Results are ordered by key as:
  ///
  /// 1. Results where key is prefixed by [prefix]
  /// 2. Results of increasing edit distance ordered by lexographic similarity to [prefix].
  ///
  /// Throws ArgumentError if [prefix] is empty.
  PrefixEditDistanceIterable<String> lookupByPrefix(String prefix,
          {int maxPrefixEditDistance = 0}) =>
      _ternaryTreap.keysByPrefix(prefix,
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  bool remove(Object value) =>
      value is String && _ternaryTreap.removeAll(value) != null;

  @override
  Set<String> toSet() => Set<String>.from(_ternaryTreap.keys);
}
