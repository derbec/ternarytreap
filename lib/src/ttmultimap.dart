import 'package:ternarytreap/ternarytreap.dart';

import 'prefixeditdistanceiterable.dart';
import 'key_mapping.dart';

/// A Multimap with prefix and near neighbour searching capability
/// across keys.
///
/// ## Usage
///
/// Use as a generic multimap of arbitrary type.
/// Key->Values relations are stored as either Set or List as below.
/// ```dart
/// final ttMultimapList = ternarytreap.TTMultiMapList<int>()
///   ..add('zebra')
///   ..addValues('zebra', [])
///   ..add('zebra', 23)
///   ..addValues('cat', [1, 2])
///   ..addValues('canary', [3, 4])
///   ..addValues('dog', [5, 6, 7, 9])
///   ..addValues('cow', [4])
///   ..addValues('donkey', [7, 5, 1])
///   ..addValues('donkey', [6, 8, 3])
///   ..add('goat', 7)
///   ..add('pig', 3)
///   ..addValues('horse', [9, 5, 8])
///   ..add('rabbit')
///   ..addValues('rat', [2, 3])
///   ..add('sheep', 7)
///   ..addValues('ape', [5, 6, 7])
///   ..add('zonkey') // Yes it's a thing!
///   ..add('dingo', 5)
///   ..addValues('kangaroo', [4, 5, 7])
///   ..add('chicken')
///   ..add('hawk')
///   ..add('crocodile', 5)
///   ..addValues('cow', [3])
///   ..addValues('zebra', [23, 24, 24, 25]);
/// ```
/// Entries with keys starting with 'z'
///
/// ```dart
/// print(ttMultimapList.keysByPrefix('z'));
/// print(ttMultimapList.entriesByKeyPrefix('z'));
/// print(ttMultimapList.valuesByKeyPrefix('z'));
/// ```
/// ```shell
/// (zebra, zonkey)
/// (MapEntry(zebra: [23, 23, 24, 24, 25]), MapEntry(zonkey: []))
/// (23, 23, 24, 24, 25)
/// ```
///
/// Same data using Set for value storage. Repeated values are removed.
/// ```dart
/// final ttMultimapSet =
///          ternarytreap.TTMultiMapSet<int>.from(ttMultimapList);
/// ```
/// Entries with keys starting with 'z' with values.
/// ```dart
/// print(ttMultimapSet.entriesByKeyPrefix('z'));
/// ```
/// ```shell
/// (MapEntry(zebra: {23, 24, 25}), MapEntry(zonkey: {}))
/// ```
///
/// ## Near neighbour searching
///
/// [TTMultiMap] supports near neighbour searching.
/// Keys starting with 'cow' and maxPrefixEditDistance of 2.
/// i.e.:
/// <mark>cow</mark>, <mark>c</mark>hicken, <mark>c</mark>rocodile,
/// <mark>c</mark>anary, <mark>c</mark>at, d<mark>o</mark>g,
/// d<mark>o</mark>nkey, g<mark>o</mark>at, ha<mark>w</mark>k,
/// h<mark>o</mark>rse, z<mark>o</mark>nkey
/// ```dart
/// print(ttMultimapSet.keysByPrefix('cow', maxPrefixEditDistance: 2).join(', '));
/// ```
/// ```shell
/// cow, chicken, crocodile, canary, cat, dog, donkey, goat, hawk, horse, zonkey
///
/// ```
///
/// ## Case sensitivity and other key transformations
///
/// Use key mappings to specify key transforms during all operations.
///
/// ```dart
/// final ttMultiMap = ternarytreap.TTMultiMapSet<String>(ternarytreap.lowercase)
///   ..addKeys(['TeStInG', 'Cat', 'cAt', 'testinG', 'DOG', 'dog']);
/// print(ttMultiMap.keys);
/// ```
/// ```shell
/// (cat, dog, testing)
/// ```
///
/// Depending on the [KeyMapping] this may result in 1 to many relationships
/// between input string and key.
///
/// For example case insensitivity can be achieved by applying a lowercase
/// mapping to all keys. If original strings are required than these must
/// be stored as values.
///
/// ```dart
/// final keyValue = ternarytreap.TTMultiMapSet<String>(ternarytreap.lowercase)
///   ..addKeyValues(['TeStInG', 'Cat', 'cAt', 'testinG', 'DOG', 'dog']);
/// print(keyValue.entries);
/// print(keyValue.valuesByKeyPrefix('CA'));
/// ```
/// ```shell
/// (MapEntry(cat: {Cat, cAt}), MapEntry(dog: {DOG, dog}), MapEntry(testing: {TeStInG, testinG}))
/// (Cat, cAt)
/// ```
///
/// ## Implementation
///
/// A [TTMultiMap] is a tree of Nodes.
///
/// ```
///                +---+   Graph with 3 keys,
///                | C |   each associated with
///                +-+-+   different number of
///                  |     value objects:
///                  |
///                +-+-+   CAN: no value
///   +------------+U 5|   CUP: 2 value objects
///   |            +-+-+   CUT: 1 value object
/// +-+-+            |
/// |A 3|            |     * Numbers represent priorities.
/// |N  |          +-+-+   * Middle children are collapsed
/// +-+-+          |P 8+-------------+
///                +-+-+             |
///                  |             +-+-+
///                  |             |T 2|
///          +------+++------+     +-+-+
///          | Value | Value |       |
///          +------+-+------+       |
///                              +---+---+
///                              | Value |
///                              +-------+
/// ```
/// Each Node stores:
///
/// * A list of characters `Node.runes` such that Ternary Tree invarient
/// is maintained:
/// `Node.runes.left.first < Node.runes.first` &
/// `Node.runes.right.first > Node.runes.first`
/// * An integer priority value `Node.priority` such that Treap invarient:
/// ```
/// (Node.left.priority < Node.priority) &&
/// (Node.right.priority < Node.priority)
/// ```
/// is maintained.
///
/// Note: Key nodes with empty Value collections all share a common empty collection object.
abstract class TTMultiMap<V> {
  /// Return [Iterable] of values for specified [key].
  ///
  /// If no value associated with key then returns empty [Iterable].
  /// If key not found then returns null.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  Iterable<V> operator [](String key);

  /// Set [Iterable] of values corresponding to [key].
  ///
  /// Any existing [values] of [key] are replaced.
  ///
  /// Throws [ArgumentError] if [keyMapping]`(`[key]`)` is empty.
  void operator []=(String key, Iterable<V> values);

  /// Insert a [key] and [value] association.
  ///
  /// [key] is a string to be transformed via [KeyMapping] into a key.
  ///
  /// Return true if (key, value) pair did not already exist, false otherwise.
  ///
  /// Throws [ArgumentError] if [keyMapping]`(`[key]`)` is empty.
  bool add(String key, V value);

  /// Add all key/value pairs from [other].
  void addAll(TTMultiMap<V> other);

  /// Adds all associations contained in [entries] to this [TTMultiMap].
  ///
  /// Is equivilent to calling [addValues] for each entry.
  ///
  /// [keyMapping] is applied to all incoming keys so
  /// keys may be altered during copying from [entries].
  ///
  /// Throws [ArgumentError] if [keyMapping]`(key)` is empty for any
  /// incoming keys of [entries].
  void addEntries(Iterable<MapEntry<String, Iterable<V>>> entries);

  /// Add [key] to collection.
  ///
  /// If a key does not allready exists then it is mapped to an empty
  /// value collection, otherwise no change occurs.
  void addKey(String key);

  /// Call [addKey](key) for each key in [keys].
  ///
  /// If a key does not allready exists then it is mapped to an empty
  /// value collection, otherwise no change occurs.
  void addKeys(Iterable<String> keys);

  /// Convenience method for cases where key and value are the same object.
  ///
  /// Equivilent to calling [add]([keyValue].toString(), [keyValue] as V)
  void addKeyValue(V keyValue);

  /// Equivilent to calling [addKeyValue] for all [keyValues].
  void addKeyValues(Iterable<V> keyValues);

  /// Add all [values] to specified key
  ///
  /// Is equivilent to calling [add]`(`[key]`, value)` for all [values].
  ///
  /// Note: if [values] is empty [key] will still be added and mapped to an
  /// empty [Iterable].
  ///
  /// See [add].
  ///
  /// Throws [ArgumentError] if [keyMapping]`(`[key]`)` is empty.
  void addValues(String key, Iterable<V> values);

  /// Return a view of this [TTMultiMap] as a [Map]
  Map<String, Iterable<V>> asMap();

  /// Removes all data from the [TTMultiMap].
  void clear();

  /// Returns whether this [TTMultiMap] contains an
  /// association between [key[] and [value].
  bool contains(String key, V value);

  /// Returns whether this [TTMultiMap] contains [key].
  bool containsKey(String key);

  /// Returns whether this [TTMultiMap] contains [value]
  /// at least once.
  bool containsValue(V value);

  /// Iterates through [TTMultiMap] as [MapEntry] objects.
  ///
  /// Each [MapEntry] contains a key (after [KeyMapping] applied)
  /// and its associated values.
  Iterable<MapEntry<String, Iterable<V>>> get entries;

  /// Iterates through [TTMultiMap] as [MapEntry] objects such
  /// that only keys prefixed by [keyMapping]`(`[prefix]`)` are included.
  ///
  /// Each [MapEntry] contains a key and its associated values.
  ///
  /// See [keysByPrefix] for more information on result ordering,
  /// near neighbour search etc.
  ///
  /// Throws ArgumentError if [prefix] is empty.
  PrefixEditDistanceIterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(
      String prefix,
      {int maxPrefixEditDistance = 0});

  /// Applies [f] to each key/value pair of the [TTMultiMap]
  ///
  /// Calling [f] must not add or remove keys from the [TTMultiMap].
  void forEach(void Function(String key, V value) f);

  /// Applies [f] to each key/value pair of the [TTMultiMap] where
  /// key matches specified key.
  ///
  /// Calling [f] must not add or remove keys from the [TTMultiMap]
  void forEachKey(void Function(String key, Iterable<V> values) f);

  /// Applies [f] to each key/value pair of the [TTMultiMap]
  /// where key is prefixed by [prefix] (after [KeyMapping] applied).
  ///
  /// Calling [f] must not add or remove keys from the [TTMultiMap]
  ///
  /// Throws ArgumentError if [prefix] is empty
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f,
      {int maxPrefixEditDistance = 0});

  /// Returns true if there are no keys in the [TTMultiMap].
  bool get isEmpty;

  /// Returns true if there is at least one key in the [TTMultiMap].
  bool get isNotEmpty;

  /// The [KeyMapping] in use by this [TTMultiMap]
  ///
  /// See: [KeyMapping].
  KeyMapping get keyMapping;

  /// The node depth of [key].
  ///
  /// Used for diagnostic/testing purposes.
  int keyDepth(String key);

  /// Return [Iterable] view of keys
  Iterable<String> get keys;

  /// Iterates through [TTMultiMap] keys such
  /// that only keys prefixed by [keyMapping]`(`[prefix]`)` are included.
  ///
  /// * If [keyMapping]`(`[prefix]`)` is empty then returns empty [Iterable].
  /// * If [maxPrefixEditDistance] > 0 then search will expand to all keys
  /// whose prefix is within a [Hamming edit distance](https://en.wikipedia.org/wiki/Hamming_distance)
  /// of [maxPrefixEditDistance] or less. For example searching for prefix
  /// 'cow' with [maxPrefixEditDistance] = 2 may give:
  /// <mark>cow</mark>,<mark>cow</mark>boy, <mark>c</mark>hicken, <mark>c</mark>rocodile,
  /// <mark>c</mark>anary, <mark>c</mark>at, d<mark>o</mark>g,
  /// d<mark>o</mark>nkey, g<mark>o</mark>at, ha<mark>w</mark>k,
  /// h<mark>o</mark>rse, z<mark>o</mark>nkey
  ///
  /// Results are ordered by key as:
  ///
  /// 1. Results where key is prefixed by [prefix] ordered lexicographically.
  /// 2. Results of increasing edit distance ordered lexographically.
  ///
  /// Throws ArgumentError if [prefix] is empty.
  PrefixEditDistanceIterable<String> keysByPrefix(String prefix,
      {int maxPrefixEditDistance = 0});

  /// The number of keys in the [TTMultiMap].
  int get length;

  /// Mark a key such that it can be refered to in future. For example via the `filterMarked`
  /// parameter of [keysByPrefix].
  ///
  /// Although this uses no extra memory it rearranges the tree such that the newly
  /// marked key is moved toward root, enabling later identification of the last marked key
  /// with a given prefix.
  ///
  /// see: [lastMarkedKeyForPrefix], [keysByPrefix]
  void markKey(String key);

  /// If [TTMultiMap] contains specified ([key], [value]) pair
  /// then return stored value.
  ///
  /// Returned value may not be the same as [value] if element type
  /// equality does not include identity.
  ///
  ///
  /// If key is mapped to multiple elements satisfying equality
  /// to [value] then only the first will be returned
  ///
  /// If ([key], [value]) pair is not present then returns null.
  V lookup(String key, V value);

  /// Removes the association between the given [key] and [value].
  ///
  /// Returns `true` if the association existed, `false` otherwise
  bool remove(String key, V value);

  /// Removes [key] and all associated values.
  ///
  /// Returns the collection of values associated with key,
  /// or null if key was unmapped.
  Iterable<V> removeKey(String key);

  /// Removes all values associated with [key].
  /// The key remains present, mapped to an empty iterable.
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  Iterable<V> removeValues(String key);

  /// Return approximate size of tree in bytes
  ///
  /// Not exact but provides useful comparison between different
  /// instances of [TTMultiMap].
  ///
  /// If size of value type should be included in calculation then
  /// specify size via [valueSizeInBytes].
  int sizeOf([int valueSizeInBytes = 0]);

  /// Attempt to return the most recently marked key with a specified [prefix].
  ///
  /// For example:
  ///
  /// ```dart
  /// final ttSet = ternarytreap.TTSet.fromIterable(
  ///     ['grab', 'angry', 'camel', 'axe', 'animal', 'bike', 'announced']);
  ///
  /// // Mark key 'announced'.
  /// ttSet.markKey('announced');
  ///
  /// // Retrieve the last marked key for the prefix 'an'.
  /// // The result should be 'announced'.
  /// print(ttSet.lastMarkedKeyByPrefix('an'));
  /// ```
  /// ```shell
  /// announced
  /// ```
  ///
  /// Ordering of key marking is not stored explicitly but instead a result of
  /// tree reordering by [markKey]. Thus the correctness of [lastMarkedKeyForPrefix]
  /// is not guaranteed to survive beyond the next operation that modifies the [TTMultiMap].
  ///
  /// If no marked key is found for [prefix] then returns null.
  ///
  /// see: [markKey]
  String lastMarkedKeyForPrefix(String prefix);

  /// Generate a string representation of this [TTMultiMap].
  ///
  /// Optional left [paddingChar] to indicate tree depth.
  /// Default = '-', use '' for no depth.
  ///
  /// Key nodes will be distinguishable by a values collection appended
  /// to the key.
  @override
  String toString([String paddingChar = '-']);

  /// Return Json representation of [TTMultiMap].
  ///
  /// Simply storing the key->value pairs and rebuilding on deserialisation
  /// would lose the [markKey], [lastMarkedKeyForPrefix] functionality thus
  /// tree structure is maintained during serialisation.
  ///
  /// Node tree stored as preorder traversal.
  ///
  /// If [includeValues] is true then values are included and must be
  /// Json serialisable in their own right.
  Map<String, dynamic> toJson([bool includeValues = true]);

  /// Return [Iterable] view of values
  ///
  /// Combines individual Key->Values relations into a single flat ordering.
  ///
  /// `[['Card', 'card'],['Cat', 'cat', 'CAT']]` ->
  /// `['Card', 'card','Cat', 'cat', 'CAT']`.
  Iterable<V> get values;

  /// Iterates through [TTMultiMap] values for each key such
  /// that only keys prefixed by [keyMapping]`(`[prefix]`)` are included.
  ///
  /// See [keysByPrefix] for more information on result ordering,
  /// near neighbour search etc.
  ///
  /// Combines individual Key->Values relations into a single flat ordering.
  ///
  /// `[['Card', 'card'],['Cat', 'cat', 'CAT']]` ->
  /// `['Card', 'card','Cat', 'cat', 'CAT']`.
  ///
  /// Throws ArgumentError if [prefix] is empty.
  PrefixEditDistanceIterable<V> valuesByKeyPrefix(String prefix,
      {int maxPrefixEditDistance = 0});
}
