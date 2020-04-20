import 'dart:collection';

import 'key_mapping.dart';
import 'prefixeditdistanceiterable.dart';
import 'ttmultimapimpl.dart';

/// A `Set<String>` with prefix and near neighbour searching capability
/// across elements.
///
/// ##Usage
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
/// Paa a [KeyMapping] during construction to specify key 
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
class TTSet extends SetBase<String> {
  /// Construct a new [TTSet]
  TTSet([KeyMapping keyMapping]) : _ttMultiMap = TTMultiMapList(keyMapping);

  /// Construct a new [TTSet] and fill with [elements].
  factory TTSet.fromIterable(Iterable<String> elements,
          [KeyMapping keyMapping]) =>
      TTSet(keyMapping)..addAll(elements);

  final TTMultiMapList _ttMultiMap;

  @override
  bool add(String value) => _ttMultiMap.addKey(value);

  @override
  bool contains(Object element) =>
      (element is String) && _ttMultiMap.containsKey(element);

  @override
  Iterator<String> get iterator => _ttMultiMap.keys.iterator;

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
  /// See: [TTMultiMap.keysByPrefix] for how results are ordered and usage
  /// of [maxPrefixEditDistance] parameter.
  /// 
  /// Throws ArgumentError if [prefix] is empty.
  PrefixEditDistanceIterable<String> lookupByPrefix(String prefix,
          {int maxPrefixEditDistance = 0, bool filterMarked = false}) =>
      _ttMultiMap.keysByPrefix(prefix,
          maxPrefixEditDistance: maxPrefixEditDistance, filterMarked:filterMarked);

  /// Promote [key] such that future calls to [suggestKey] will be
  /// more likely to return [key].
  ///
  /// see: [TTMultiMap.markKey]
  void promoteKey(String key) => _ttMultiMap.markKey(key);

  @override
  bool remove(Object value) =>
      value is String && _ttMultiMap.removeAll(value) != null;

  /// Return a single suggested key expansion for [prefix].
  ///
  /// see: [promoteKey]
  String suggestKey(String prefix) => _ttMultiMap.lastMarkedKeyByPrefix(prefix);

  @override
  Set<String> toSet() => Set<String>.from(_ttMultiMap.keys);
}
