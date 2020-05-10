import 'dart:collection';
import 'package:collection/collection.dart';
import 'key_mapping.dart';
import 'ttiterable.dart';
import 'ttmultimapimpl.dart';

/// An equality between [TTSetEquality] instances.
class TTSetEquality implements Equality<TTSet> {
  final _ttMultiMapEquality = TTMultiMapListEquality<dynamic>();

  @override
  bool equals(TTSet e1, TTSet e2, [bool strict]) =>
      (!identical(e1, null) && !identical(e2, null)) &&
      _ttMultiMapEquality.equals(e1._ttMultiMap, e2._ttMultiMap, strict);

  @override
  int hash(TTSet e) => identical(e, null)
      ? null.hashCode
      : _ttMultiMapEquality.hash(e._ttMultiMap);

  @override
  bool isValidKey(Object o) => o is TTSet;
}

/// A `Set<String>` with prefix and near neighbour searching capability
/// across elements.
///
/// ## Usage
///
/// ```dart
/// final ttSet = ternarytreap.TTSet()
///   ..addAll([
///     'zebra',
///     'canary',
///     'goat',
///     'cat',
///     'chicken',
///     'sheep',
///     'cow',
///     'crocodile',
///     'hawk',
///     'dingo',
///     'dog',
///     'donkey',
///     'horse',
///     'kangaroo',
///     'rabbit',
///     'pig',
///     'rat',
///     'ape',
///   ]);
///
/// print(ttSet.join(', '));
/// ```
/// ```shell
/// (ape, cat, chicken, cow, crocodile, dingo, dog, donkey, goat, hawk, horse, kangaroo, pig, rabbit, rat, sheep, zebra, canary)
/// ```
///
/// Strings that start with 'ra', e.g. <mark>ra</mark>bbit, <mark>ra</mark>t
/// ```dart
/// print(ttSet.lookupByPrefix('ra'));
/// ```
/// ```shell
/// (rabbit, rat)
/// ```
///
/// Strings that start with 'ra' given max edit distance of 1.
/// Eg: <mark>ra</mark>bbit, <mark>ra</mark>t, k<mark>a</mark>ngaroo, h<mark>a</mark>wk, c<mark>a</mark>t
/// ```dart
/// print(ttSet.lookupByPrefix('ra', maxPrefixEditDistance: 1));
/// ```
/// ```shell
/// (rabbit, rat, hawk, kangaroo, cat)
/// ```
/// Keys that start with 'din' given max edit distance of 2
/// Eg: <mark>din</mark>go, <mark>d</mark>o<mark>n</mark>key, <mark>d</mark>og, ka<mark>n</mark>garoo, p<mark>i</mark>g
/// ```dart
/// print(ttSet.lookupByPrefix('din', maxPrefixEditDistance: 2));
/// ```
/// ```shell
/// (dingo, donkey, dog, kangaroo, pig)
/// ```
/// ## Case sensitivity and other key transformations
///
/// Pass a [KeyMapping] during construction to specify key
/// transform to be performed before all operations.
///
/// ```dart
/// final ttSet = ternarytreap.TTSet(ternarytreap.lowercase)
///   ..addAll(['TeStInG', 'Cat', 'cAt', 'testinG', 'DOG', 'dog']);
/// print(ttSet);
/// ```
/// ```shell
/// (cat, dog, testing)
/// ```
class TTSet extends SetBase<String> implements TTIterable<String> {
  /// Construct a new [TTSet]
  TTSet([KeyMapping keyMapping]) : _ttMultiMap = TTMultiMapList(keyMapping);

  /// Construct a new [TTSet] and fill with [elements].
  TTSet.fromIterable(Iterable<String> elements, [KeyMapping keyMapping])
      : _ttMultiMap = TTMultiMapList(keyMapping) {
    ArgumentError.checkNotNull(elements, 'elements');
    addAll(elements);
  }

  /// Construct a new [TTSet] from [json].
  TTSet.fromJson(Map<String, dynamic> json, [KeyMapping keyMapping])
      : _ttMultiMap = TTMultiMapList.fromJson(json, keyMapping);

  final TTMultiMapList _ttMultiMap;

  @override
  bool add(String value) => _ttMultiMap.addKey(value);

  @override
  bool contains(Object element) =>
      (element is String) && _ttMultiMap.containsKey(element);

  @override
  TTIterator<String> get iterator => _ttMultiMap.keys.iterator;

  /// The [KeyMapping] in use by this [TTSet]
  ///
  /// See: [KeyMapping].
  KeyMapping get keyMapping => _ttMultiMap.keyMapping;

  @override
  int get length => _ttMultiMap.length;

  @override
  String lookup(Object element) =>
      (element is String && _ttMultiMap.containsKey(element)) ? element : null;

  /// Iterates through [TTSet] elements such
  /// that only elements prefixed by [keyMapping]`(`[prefix]`)` are included.
  ///
  /// If [keyMapping]`(`[prefix]`)` is empty then returns empty Iterable.
  ///
  /// See: [TTMultiMap.keysByPrefix] for how results are ordered and usage
  /// of [maxPrefixEditDistance] parameter.
  ///
  /// Throws ArgumentError if [prefix] is empty or null.
  TTIterable<String> lookupByPrefix(String prefix,
          {int maxPrefixEditDistance = 0, bool filterMarked = false}) =>
      _ttMultiMap.keysByPrefix(prefix,
          maxPrefixEditDistance: maxPrefixEditDistance);

  /// see: [TTMultiMap.markKey]
  bool markKey(String key) => _ttMultiMap.markKey(key);

  @override
  bool remove(Object value) =>
      value is String && !identical(_ttMultiMap.removeKey(value), null);

  /// Return structure for Json encoding
  ///
  /// see: [TTMultiMap.toJson]
  Map<String, dynamic> toJson() => _ttMultiMap.toJson(includeValues: false);

  @override
  Set<String> toSet() => Set<String>.from(_ttMultiMap.keys);

  @override
  TTIterable<String> get marked => _ttMultiMap.keys.marked;

  @override
  TTIterable<String> get unmarked => _ttMultiMap.keys.unmarked;
}
