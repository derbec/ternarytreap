import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';
import 'package:quiver/collection.dart';

// 2^53-1
const int _MAX_SAFE_INTEGER = 9007199254740991;

const int _INVALID_DISTANCE = -1;

const int _INVALID_CODE_UNIT = -1;

// Unicode categories rock!
final RegExp _matchLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _matchNonLetter = RegExp(r'\P{L}', unicode: true);
final RegExp _matchSeperators = RegExp(r'\p{Z}+', unicode: true);

/// Often it is desirable to define equivalences between Key
/// strings, for example for case insensitivity.
///
/// This is achieved via the surjection:
///
/// * <i>m</i> : <i>K</i>&twoheadrightarrow; <i>L  &sube; K</i>
///
/// such that:
///
/// * <i>m</i>(<i>m</i>(x)) = <i>m</i>(x), i.e. <i>m</i> must be
/// [idempotent](https://en.wikipedia.org/wiki/Idempotence),
/// repeated applications do not change the result.
///
/// For example:
///
/// * <i>m</i>(x) = lowercase(x).
///
/// [KeyMapping] is optionally specified during construction and
/// applied to keys during all operations.
///
/// If no [KeyMapping] is supplied then the default identity function is used.
///
/// * <i>m</i>(x) = x.
///
/// Predefined mappings include:
///
/// * [TernaryTreap.lowercase]
/// * [TernaryTreap.uppercase]
/// * [TernaryTreap.collapseWhitespace]
/// * [TernaryTreap.nonLetterToSpace]
/// * [TernaryTreap.lowerCollapse]
/// * [TernaryTreap.joinSingleLetters]
///
/// See [TernaryTreap.lowerCollapse] for example of combining multiple
/// [KeyMapping] functions.
typedef KeyMapping = String Function(String str);

/// A self balancing Ternary search tree implementing quiver Multimap interface.
///
/// # Usage
///
/// ## Most basic case
///
/// Insert keys and later return those starting with a given prefix.
///
/// ```dart
/// void  main(List<String> args) {
///
/// final  TernaryTreap<String> ternaryTreap = TernaryTreapSet<String>()
/// ..add('cat')
/// ..add('Canary')
/// ..add('dog')
/// ..add('zebr
/// ..add('CAT');
///
/// print(ternaryTreap.keys);
/// ```
/// ```
/// (CAT, Canary, cat, dog, zebra)
/// ```
/// ```dart
/// print(ternaryTreap.keysByPrefix('ca'));
/// // for near neighbour (fuzzy) search: print(ternaryTreap.keysByPrefix('ca', true));
/// ```
/// ```shell
/// (cat)
/// ```
/// ```dart
/// print(ternaryTreap.toString());
/// ```
/// ```shell
/// -CAT
/// Canary
/// cat
/// dog
/// zebra
/// ```
///
/// ## Case insensitivity and other key mappings
///
/// The above example matches strings exactly,
/// i.e. `keysByPrefix('ca')` returns 'cat' but not 'CAT'.
/// This is because the default identity [KeyMapping]: <i>m</i>(x) = x is used.
/// This can be overridden by specifying a KeyMapping during construction.
/// For example to achieve case insensitivity:
///
/// ```dart
/// import  'package:ternarytreap/ternarytreap.dart';
/// void  main(List<String> args) {
/// final  TernaryTreap<String> ternaryTreap =
/// TernaryTreapSet<String>(TernaryTreap.lowercase)
/// ..add('cat')
/// ..add('Canary')
/// ..add('dog')
/// ..add('zebra')
/// ..add('CAT');
/// }
///
/// print(ternaryTreap.keys);
/// ```
///
/// ```
/// (canary, cat, dog, zebra)
/// ```
///
/// ```dart
/// print(ternaryTreap.keysByPrefix('ca'));
/// ```
///
/// ```shell
/// (canary, cat)
/// ```
///
/// ```dart
/// print(ternaryTreap.toString());
/// ```
///
/// ```shell
/// canary
/// cat
/// dog
/// zebra
/// ```
/// ## Attaching String Data to Retain Key->Input Mapping
///
/// When a [KeyMapping] such as [lowercase]
/// maps multiple inputs to the same key the original input strings are lost.
/// In the example below this results in input
/// strings 'CAT' and 'Cat' being lost.
///
/// ```dart
/// final  TernaryTreap<String> ternaryTreap =
/// TernaryTreapSet<String>(TernaryTreap.lowercase)
/// ..add('cat')
/// ..add('Cat')
/// ..add('CAT');
/// print(ternaryTreap.keysByPrefix('ca'));
/// ```
///
/// ```shell
/// (cat)
/// ```
/// To retain the original string you may attach it as a Value during insertion.
/// These strings may now be recovered during subsequent queries.
/// ```dart
/// import  'package:ternarytreap/ternarytreap.dart';
/// void  main(List<String> args) {
/// final  TernaryTreap<String> ternaryTreap =
/// TernaryTreap<String>(TernaryTreap.lowercase)
/// ..add('cat', 'cat')
/// ..add('Cat', 'Cat')
/// ..add('CAT', 'CAT')
/// ..add('CanaRy', 'CanaRy')
/// ..add('CANARY', 'CANARY');
/// }
/// ```
/// ```dart
/// print(ternaryTreap.keys);
/// ```
/// ```shell
/// (canary, cat)
/// ```
/// ```dart
/// print(ternaryTreap.keysByPrefix('ca'));
/// ```
/// ```shell
/// (canary, cat)
/// ```
/// ```dart
/// print(ternaryTreap.values);
/// ```
/// ```shell
/// (canary, CanaRy, CANARY, cat, Cat, CAT)
/// ```
/// ```dart
/// print(ternaryTreap.valuesByKeyPrefix('cat'));
/// ```
/// ```shell
/// (cat, Cat, CAT)
/// ```
/// ```dart
/// print(ternaryTreap.toString());
/// ```
/// ```shell
/// canary
/// CanaRy
/// CANARY
/// cat
/// cat
/// Cat
/// CAT
/// ```
/// ## Attaching Complex data Types
/// Sometimes it is useful to associate input strings
/// with more complex datatypes.
/// For example the following datatype stores an 'Animal'
/// with name, description and a timestamp
///
/// ```dart
/// import  'package:ternarytreap/ternarytreap.dart';
///
/// // An example of a data object, takes a name and description,
/// // and adds a timestamp.
/// class  Animal {
/// Animal(this.name, this.description)
/// : timestamp = DateTime.now().millisecondsSinceEpoch.toString();
///
/// // name - will be set to original input string pre KeyMapping
/// final  String name;
///
/// final  String description;
///
/// final  String timestamp;
///
/// Return String value.
///
/// @returns String repesenting object.
/// @override
/// String  toString() => <String, dynamic>{
/// 'name': name,
/// 'description': description,
/// 'timestamp': timestamp,
/// }.toString();
/// }
///
/// void  main(List<String> args) {
/// final  TernaryTreap<Animal> ternaryTreap =
/// TernaryTreap<Animal>(TernaryTreap.lowerCollapse)
/// ..add('Cat', Animal('Cat', 'Purrs'))
/// ..add('Canary', Animal('Canary', 'Yellow'))
/// ..add('Dog', Animal('Dog', 'Friend'))
/// ..add('Zebra', Animal('Zebra', 'Stripes'))
/// ..add('CAT', Animal('CAT', 'Scan'));
/// ```
///
/// ```dart
/// print(ternaryTreap.keys);
/// ```
///
/// ```shell
/// (canary, cat, dog, zebra)
/// ```
///
/// ```dart
/// print(ternaryTreap.keysByPrefix('ca'));
/// ```
///
/// ```shell
/// (canary, cat)
/// ```
///
/// ```dart
/// print(ternaryTreap.values);
/// ```
///
/// ```shell
/// ({name: Canary, description: Yellow, timestamp: 1574730578753},
/// {name: Cat, description: Purrs, timestamp: 1574730578735},
/// {name: CAT, description: Scan, timestamp: 1574730578754},
/// {name: Dog, description: Friend, timestamp: 1574730578754},
/// {name: Zebra, description: Stripes, timestamp: 1574730578754})
/// ```
///
/// ```dart
/// print(ternaryTreap.valuesByKeyPrefix('ca'));
/// ```
///
/// ```shell
/// ({name: Canary, description: Yellow, timestamp: 1574730578753},
/// {name: Cat, description: Purrs, timestamp: 1574730578735},
/// {name: CAT, description: Scan, timestamp: 1574730578754})
/// ```
///
/// ```dart
/// print(ternaryTreap.toString());
/// ```
///
/// ```shell
/// canary
/// {name: Canary, description: Yellow, timestamp: 1574730578753}
/// cat
/// {name: Cat, description: Purrs, timestamp: 1574730578735}
/// {name: CAT, description: Scan, timestamp: 1574730578754}
/// dog
/// {name: Dog, description: Friend, timestamp: 1574730578754}
/// zebra
/// {name: Zebra, description: Stripes, timestamp: 1574730578754}
/// ```
///
/// # Specification
///
/// [TernaryTreapSet] and [TernaryTreapList] are multimaps:
///
/// * <i>f</i> :  <i>K</i> &mapsto; &weierp; (<i>V</i>)
/// * <i>g</i> :  <i>K</i> &mapsto; <i>V</i><sup>&#8469;</sup> &cup; V<sup>&emptyset;</sup>
///
/// such that
///
/// * K is the set of all Keys
/// * V is the set of all Values
/// * &#8469; is the set of Natural numbers
/// * &weierp; (<i>V</i>) is the powerset of V
/// * <i>V</i><sup>&#8469;</sup> is the set of all functions &#8469; &mapsto; <i>V</i>
/// * <i>V</i><sup>&emptyset;</sup> contains the empty function &emptyset; &mapsto; <i>V</i>
///
/// The codomain of <i>f</i> and <i>g</i> include the empty set and empty sequence respectively.
/// This allows Keys to be stored without Values, useful when
/// you require only a set of Keys for prefix searching purposes.
///
/// Often it is desirable to define equivalences between Key strings,
/// for example case insensitivity.
///
/// For example the key 'it' may map to 'IT', 'It' or 'it'.
///
/// This is achieved via a [KeyMapping](https://pub.dev/documentation/ternarytreap/latest/ternarytreap/KeyMapping.html), defined as the surjection:
///
///* <i>m</i> : <i>K</i>&twoheadrightarrow; <i>L  &sube; K</i>
///
/// such that:
///
/// * <i>m</i>(<i>m</i>(x)) = <i>m</i>(x), i.e. <i>m</i> must be [idempotent](https://en.wikipedia.org/wiki/Idempotence), repeated applications do not change the result.
///
/// For example:
///
/// * <i>m</i>(x) = x : Default identity function, preserve all input keys.
/// * <i>m</i>(x) = lowercase(x) : Convert keys to lowercase.
///
/// TernaryTreap Multimaps are composite functions with KeyMapping parameter <i>m</i>.
///
/// * TernaryTreapSet<sub><i>m</i></sub>(x) = <i>f</i> &#8728; <i>m</i>(x)
/// * TernaryTreapList<sub><i>m</i></sub>(x) = <i>g</i> &#8728; <i>m</i>(x)
///
/// # Structure
///
/// A [TernaryTreap] is a tree of Nodes.
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
/// * A list of characters `Node.codeUnits` such that Ternary Tree invarient
/// is maintained:
/// `Node.codeUnits.left.first < Node.codeUnits.first` &
/// `Node.codeUnits.right.first > Node.codeUnits.first`
/// * An integer priority value `Node.priority` such that Treap invarient:
/// ```
/// (Node.left.priority < Node.priority) &&
/// (Node.right.priority < Node.priority)
/// ```
/// is maintained.
abstract class TernaryTreap<V> extends _CommonInterface<V> implements Multimap<String, V>{
  /// Transform [str] such that all characters are lowercase.
  ///
  /// When passed to [TernaryTreap()] this [KeyMapping] will be applied
  /// to all key arguments passed by client
  static String lowercase(String str) => str.toLowerCase();

  /// Transform [str] such that all characters are uppercase.
  ///
  /// When passed to [TernaryTreap()] this [KeyMapping] will be applied
  /// to all key arguments passed by client
  static String uppercase(String str) => str.toUpperCase();

  /// Transform [str] such that each non letter character is
  /// replaced by a space character.
  ///
  /// When passed to [TernaryTreap()] this [KeyMapping] will be applied
  /// to all key arguments passed by client
  static String nonLetterToSpace(String str) =>
      str.replaceAll(_matchNonLetter, ' ');

  /// Transform [str] such that adjacent single Letters separated by
  /// whitespace are joined together. For example:
  ///
  /// '    a b   a   b  abcd a b' -> 'ab   ab  abcd ab'
  ///
  /// When used after [nonLetterToSpace] this ensures that 'U.S.A' and 'USA'
  /// are equivilent after [KeyMapping] applied.
  ///
  /// Note: This transform trims and collapses whitespace during operation
  /// and is thus equivilent also to performing [collapseWhitespace].
  ///
  /// When passed to [TernaryTreap()] this [KeyMapping] will be applied
  /// to all key arguments passed by client
  static String joinSingleLetters(String str) {
    final chunks = str.trim().split(_matchSeperators);

    final res = <String>[];
    //join all adjacent chunks with size 1
    final newChunk = StringBuffer();

    for (final chunk in chunks) {
      // if chuck is single Letter
      if (chunk.length == 1 && _matchLetter.matchAsPrefix(chunk) != null) {
        newChunk.write(chunk);
      } else {
        if (newChunk.isNotEmpty) {
          res.add(newChunk.toString());
          newChunk.clear();
        }
        res.add(chunk);
      }
    }
    if (newChunk.isNotEmpty) {
      res.add(newChunk.toString());
    }
    return res.join(' ');
  }

  /// Transform [str] such that:
  ///
  /// * Whitespace is trimmed from start and end
  /// * Runs of multiple whitespace characters are collapsed into a single ' '.
  ///
  /// When passed to [TernaryTreap()] this [KeyMapping] will be applied
  /// to all key arguments passed by client.
  static String collapseWhitespace(String str) =>
      str.trim().replaceAll(_matchSeperators, ' ');

  /// Transform [str] with both [lowercase] and [collapseWhitespace].
  ///
  /// When passed to [TernaryTreap()] this [KeyMapping] will be applied
  /// to all key arguments passed by client
  static String lowerCollapse(String str) =>
      collapseWhitespace(str).toLowerCase();

  /// Set [Iterable] of values corresponding to [key].
  ///
  /// Any existing [values] of [key] are replaced.
  ///
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  void operator []=(String key, Iterable<V> values);

  /// Insert a [key] and optional [value].
  ///
  /// [key] is a string to be transformed via [KeyMapping] into a key.
  ///
  /// An optional [value] may be supplied to associate with this key.
  ///
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  @override
  void add(String key, [V value]);

  /// Adds all associations of other to this [TernaryTreap].
  ///
  /// Is equivilent to calling [addValues]`(key, other[key])`
  /// for all `other.`[keys].
  ///
  /// [mapKey] is applied to all incoming keys so
  /// keys may be altered during copying from [other] to `this`
  /// if they are using different [KeyMapping] functions.
  ///
  /// Throws [ArgumentError] if [mapKey]`(key)` is empty for any
  /// incoming keys of [other].
  @override
  void addAll(Multimap<String, V> other);

  /// Add all [values] to specified key
  ///
  /// Is equivilent to calling [add]`(`[key]`, value)` for all [values].
  ///
  /// Note: if [values] is empty [key] will still be added and mapped to an
  /// empty [Iterable].
  ///
  /// See [add].
  ///
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  @override
  void addValues(String key, Iterable<V> values);

  /// Return a view of this [TernaryTreap] as a [ImmutableTernaryTreap]
  ImmutableTernaryTreap<V> asImmutable();

  /// Removes all data from the [TernaryTreap].
  @override
  void clear();

  /// Prioritise [key] such that future prefix searches will return [key]
  /// closer to beginning of search result. Subsequent calls will increase this
  /// effect.
  void likeKey(String key);

  /// Removes the association between the given [key] and [value].
  ///
  /// Returns `true` if the association existed, `false` otherwise
  @override
  bool remove(Object key, V value);

  /// Removes [key] and all associated values.
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  @override
  Iterable<V> removeAll(Object key);

  /// Removes all values associated with [key].
  /// The key remains present, mapped to an empty iterable.
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  Iterable<V> removeValues(String key);
}

/// Return a [TernaryTreap] that stores values in a [List]
///
/// Returned [TernaryTreap] is a function:
///
/// * <i>f</i> :  <i>K</i> &mapsto; <i>V</i><sup>&#8469;</sup> &cup; V<sup>&emptyset;</sup>
///
/// such that
///
/// * K is the set of all Keys
/// * V is the set of all Values
/// * &#8469; is the set of Natural numbers
/// * <i>V</i><sup>&#8469;</sup> is the set of all functions &#8469; &mapsto; <i>V</i>
/// * <i>V</i><sup>&emptyset;</sup> contains the empty function &emptyset; &mapsto; <i>V</i>
///
/// By definition the Values sequence may feature the same Value multiple times.
/// It is ordered by insertion.
///
/// The codomain of <i>f</i> includes the empty sequence.
/// This allows Keys to be stored without Values, useful when
/// you require only a set of Keys for searching purposes.
class TernaryTreapList<V> extends _MutableTernaryTreap<V> {
  /// Construct a new [TernaryTreapList] with an optional [keyMapping]
  TernaryTreapList([KeyMapping keyMapping])
      : super(
            (List<int> codeUnit, int priority, _Node<V> parent,
                    Iterable<V> emptyValues) =>
                _NodeList<V>(codeUnit, priority, parent, emptyValues),
            keyMapping);
}

/// Return a [TernaryTreap] that stores values in a [Set]
///
/// Returned [TernaryTreap] is a function:
///
/// * <i>f</i> :  <i>K</i> &mapsto; &weierp; (<i>V</i>)
///
/// such that:
///
/// * K is the set of all Keys
/// * V is the set of all Values
/// * &weierp; (<i>V</i>) is the powerset of V
///
/// By definition the Values set may feature the same Value only once.
///
/// The codomain of <i>f</i> includes the empty set.
/// This allows Keys to be stored without Values, useful when
/// you require only a set of Keys for searching purposes.
class TernaryTreapSet<V> extends _MutableTernaryTreap<V> {
  /// Construct a new [TernaryTreapSet] with an optional [keyMapping]
  TernaryTreapSet([KeyMapping keyMapping])
      : super(
            (List<int> codeUnit, int priority, _Node<V> parent,
                    Iterable<V> emptyValues) =>
                _NodeSet<V>(codeUnit, priority, parent, emptyValues),
            keyMapping);
}

/// A view of a [TernaryTreap] without mutators.
abstract class ImmutableTernaryTreap<V> extends _CommonInterface<V> {}

/// An iterable over a [TernaryTreap] that returns
/// [TernaryTreapIterator].
abstract class _TernaryTreapIterable<V> extends Iterable<V> {
  @override
  TernaryTreapIterator<V> get iterator;
}

/// An iterator that returns items that fall within an edit
/// distance of search query.
abstract class TernaryTreapIterator<V> implements Iterator<V> {
  /// the key edit distance associated with current iterator value.
  int get keyDistance;
}

/// Exists so that [ImmutableTernaryTreap] and [TernaryTreap] may share interface spec but
/// avoid inheritence issue discussed at:
/// https://blog.codefx.org/java/immutable-collections-in-java/#What8217s-An-Immutable-Collection
abstract class _CommonInterface<V> {
  /// Return [Iterable] of values for specified [key].
  ///
  /// If no value associated with key then returns empty [Iterable].
  /// If key not found then returns null.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  Iterable<V> operator [](Object key);

  /// Return a view of this [TernaryTreap] as a [Map]
  Map<String, Iterable<V>> asMap();

  /// Returns whether this [TernaryTreap] contains an
  /// association between [key[] and [value].
  bool contains(Object key, Object value);

  /// Returns whether this [TernaryTreap] contains [key].
  bool containsKey(Object key);

  /// Returns whether this [TernaryTreap] contains [value]
  /// at least once.
  bool containsValue(Object value);

  /// Iterates through [TernaryTreap] as [MapEntry] objects.
  ///
  /// Each [MapEntry] contains a key (after [KeyMapping] applied)
  /// and its associated values.
  Iterable<MapEntry<String, Iterable<V>>> get entries;

  /// Iterates through [TernaryTreap] as [MapEntry] objects such
  /// that only keys prefixed by [mapKey]`(`[prefix]`)` are included.
  ///
  /// Each [MapEntry] contains a key and its associated values.
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
  _TernaryTreapIterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(
      String prefix,
      [bool fuzzy = false]);

  /// Return a single suggested prefix expansion for [key].
  String suggestKey(String key);

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap].
  void forEach(void Function(String key, V value) f);

  /// Applies [f] to each key/value pair of the [TernaryTreap] where
  /// key matches specified key.
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  void forEachKey(void Function(String key, Iterable<V> values) f);

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  /// where key is prefixed by [prefix] (after [KeyMapping] applied).
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  ///
  /// Throws ArgumentError if [prefix] is empty
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f,
      [bool fuzzy = false]);

  /// Returns true if there are no keys in the [TernaryTreap].
  bool get isEmpty;

  /// Returns true if there is at least one key in the [TernaryTreap].
  bool get isNotEmpty;

  /// The node nepth of [key].
  ///
  /// Used for diagnostic/testing purposes.
  int keyDepth(String key);

  /// Return [Iterable] view of keys
  Iterable<String> get keys;

  /// Returns [Iterable] collection of each key of the [TernaryTreap]
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
  _TernaryTreapIterable<String> keysByPrefix(String prefix,
      [bool fuzzy = false]);

  /// The number of keys in the [TernaryTreap].
  int get length;

  /// Return key transformed by any [KeyMapping] specified
  /// during construction.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  String mapKey(String key);

  /// Return [ImmutableTernaryTreap] view of tree
  ImmutableTernaryTreap<V> toImmutable();

  /// Generate a string representation of this [TernaryTreap].
  /// Requires that values be json encodable.
  ///
  /// Optional left [paddingChar] to indicate tree depth.
  /// Default = '-', use '' for no depth.
  /// Returns String representation of objects in order of traversal
  /// formated as:
  /// key
  /// value (value type must have valid [toString] method)
  @override
  String toString([String paddingChar = '-']);

  /// Return [Iterable] view of values
  ///
  /// Return an iterable that combines individual Key->Values
  /// relations into a single flat ordering.
  ///
  /// `[['Card', 'card'],['Cat', 'cat', 'CAT']]` ->
  /// `['Card', 'card','Cat', 'cat', 'CAT']`.
  Iterable<V> get values;

  /// Return [Iterable] view of values where key
  /// is prefixed by [mapKey]`(`[prefix]`)`.
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
  _TernaryTreapIterable<V> valuesByKeyPrefix(String prefix,
      [bool fuzzy = false]);
}

/// Non mutating portion of [TernaryTreap]
class _ImmutableTernaryTreap<V> implements ImmutableTernaryTreap<V> {
  /// Constructs a new [_ImmutableTernaryTreap].
  ///
  /// The [_keyMapping] argument supplies an optional instance of
  /// [KeyMapping] to be applied to all keys processed by this [TernaryTreap].
  _ImmutableTernaryTreap(
      [_ByRef<_Node<V>> _root, _ByRef<int> _version, this._keyMapping])
      : _version = _version ?? _ByRef<int>(0),
        _root = _root ?? _ByRef<_Node<V>>(null);

  /// The [KeyMapping] in use by this [TernaryTreap]
  ///
  /// See: [KeyMapping].
  final KeyMapping _keyMapping;

  /// Allows tracking of modifications
  /// ByRef so as to allow sharing with Immutable views
  final _ByRef<int> _version;

  /// Entry point into [_Node] tree.
  /// Because rotations can change this it is stored as
  /// a reference
  final _ByRef<_Node<V>> _root;

  /// A placeholder for empty node values
  final _emptyValues = Iterable<V>.empty();

  @override
  Iterable<V> operator [](Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final keyNode = _root.value?.getKeyNode(_mapKeyErrorOnEmpty(key as String));

    if (keyNode == null) {
      return null;
    }

    return keyNode.values;
  }

  @override
  Map<String, Iterable<V>> asMap() =>
      Map<String, Iterable<V>>.fromEntries(entries);

  /// Map key and throw error if result is empty
  String _mapKeyErrorOnEmpty(String key) {
    final mappedKey = mapKey(key);
    if (mappedKey.isEmpty) {
      throw ArgumentError('key $key is empty after KeyMapping applied');
    }
    return mappedKey;
  }

  @override
  bool contains(Object key, Object value) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final keyNode = _root.value?.getKeyNode(_mapKeyErrorOnEmpty(key as String));

    // Does the key map to anything?
    if (keyNode == null) {
      return false;
    }

    return keyNode.values.contains(value);
  }

  @override
  bool containsKey(Object key) => this[key] != null;

  @override
  bool containsValue(Object value) => values.contains(value);

  @override
  Iterable<MapEntry<String, Iterable<V>>> get entries =>
      _InOrderMapEntryIterable<V>(this, _root.value);

  @override
  _TernaryTreapIterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(
          String prefix,
          [bool fuzzy = false]) =>
      _InOrderMapEntryIterable<V>(this, _root.value,
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits, fuzzy: fuzzy);

  @override
  String suggestKey(String key) {
    final prefix = mapKey(key).codeUnits;
    final searchResult = _root.value?.getClosestPrefixDescendant(prefix);

    if (searchResult == null || !searchResult.isPrefixMatch) {
      return key;
    }

    // Can we find a suggestion by expanding the node itself
    var expansion = searchResult.expandPrefix(prefix);

    // Concatenate mid descendants until key is found
    var midNode = searchResult.node.mid;
    while (midNode != null) {
      expansion += midNode.codeUnits;
      if (midNode.isKeyEnd) {
        break;
      } else {
        midNode = midNode.mid;
      }
    }

    return String.fromCharCodes(expansion);
  }

  @override
  void forEach(void Function(String key, V value) f) {
    final entryItr = entries.iterator as _InOrderMapEntryIterator<V>;

    while (entryItr.moveNext()) {
      for (final value in entryItr.currentValue) {
        f(entryItr.currentKey, value);
      }
    }
  }

  @override
  void forEachKey(void Function(String key, Iterable<V> values) f) {
    final entryItr = entries.iterator as _InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f,
      [bool fuzzy = false]) {
    final itr = entriesByKeyPrefix(prefix, fuzzy).iterator
        as _InOrderMapEntryIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue);
    }
  }

  @override
  bool get isEmpty => _root.value == null;

  @override
  bool get isNotEmpty => _root.value != null;

  @override
  int keyDepth(String key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    if (_root.value == null) {
      return -1;
    }

    final prefixDescendant = _root.value
        .getClosestPrefixDescendant(_mapKeyErrorOnEmpty(key).codeUnits);

    // The node must represent only this key
    if (!prefixDescendant.isPrefixMatch ||
        prefixDescendant.nodeCodeunitIdx !=
            prefixDescendant.node.codeUnits.length - 1 ||
        !prefixDescendant.node.isKeyEnd) {
      throw ArgumentError('key: $key not found');
    }
    return prefixDescendant.depth;
  }

  @override
  Iterable<String> get keys => _InOrderKeyIterable<V>(this, _root.value);

  @override
  _TernaryTreapIterable<String> keysByPrefix(String prefix,
          [bool fuzzy = false]) =>
      _InOrderKeyIterable<V>(this, _root.value,
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits, fuzzy: fuzzy);

  @override
  int get length => _root.value == null ? 0 : _root.value.sizeDFSTree;

  @override
  String mapKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError('key is empty');
    }

    return _keyMapping == null ? key : _keyMapping(key);
  }

  @override
  ImmutableTernaryTreap<V> toImmutable() =>
      _ImmutableTernaryTreap<V>(_root, _version, _keyMapping);

  @override
  _TernaryTreapIterable<V> get values =>
      _InOrderValuesIterable<V>(this, _root.value);

  @override
  _TernaryTreapIterable<V> valuesByKeyPrefix(String prefix,
          [bool fuzzy = false]) =>
      _InOrderValuesIterable<V>(this, _root.value,
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits, fuzzy: fuzzy);

  @override
  String toString([String paddingChar = '-']) {
    final lines = StringBuffer();
    final itr = entries.iterator as _InOrderMapEntryIterator<V>;

    // We can avoid an object creation per key by not accessing the
    // 'current' getter of itr.
    while (itr.moveNext()) {
      final currentDepth = itr.stack.length;

      final keyPadding =
          ''.padLeft(currentDepth + 1 - itr.currentKey.length, paddingChar);

      final valuePadding = ''.padLeft(keyPadding.length, ' ');
      lines.writeln(keyPadding + itr.currentKey);
      // There is not always a value associated with a key
      for (final datum in itr.currentValue) {
        lines.writeln(valuePadding + datum.toString());
      }
    }
    return lines.toString();
  }
}

/// TernaryTreap mutators
class _MutableTernaryTreap<V> extends _ImmutableTernaryTreap<V> 
    implements TernaryTreap<V>, Multimap<String, V> {
  /// Constructs a new [TernaryTreap].
  ///
  /// The [_keyMapping] argument supplies an optional instance of
  /// [KeyMapping] to be applied to all keys processed by this [TernaryTreap].
  _MutableTernaryTreap(this._nodeFactory, KeyMapping keyMapping)
      : super(null, _ByRef<int>(0), keyMapping);

  final Random _random = Random();

  /// Factory used to create new nodes
  final _Node<V> Function(List<int> codeUnit, int priority, _Node<V> parent,
      Iterable<V> emptyValues) _nodeFactory;

  @override
  void add(String key, [V value]) {
    _root.value = _add(_root.value, _mapKeyErrorOnEmpty(key), value).a;

    _incVersion();
  }

  @override
  void addAll(Multimap<String, V> other) {
    other.forEachKey((String key, Iterable<V> data) {
      final mappedKey = _mapKeyErrorOnEmpty(key);

      // map key alone for case where no data is associated with key
      final tuple = _add(_root.value, mappedKey, null);
      _root.value = tuple.a;

      // copy data over
      for (final value in data) {
        tuple.b.addValue(value);
      }
    });

    _incVersion();
  }

  @override
  void addValues(String key, Iterable<V> values) {
    final mappedKey = _mapKeyErrorOnEmpty(key);

    // map key alone for case where no data is associated with key
    final tuple = _add(_root.value, mappedKey, null);
    _root.value = tuple.a;

    for (final value in values) {
      tuple.b.addValue(value);
    }

    _incVersion();
  }

  @override
  ImmutableTernaryTreap<V> asImmutable() =>
      _ImmutableTernaryTreap<V>(_root, _version, _keyMapping);

  @override
  void operator []=(String key, Iterable<V> values) {
    final keyMapped = _mapKeyErrorOnEmpty(key);

    final addResult = _add(_root.value, keyMapped, null);
    _root.value = addResult.a;
    var keyNode = addResult.b;

    if (keyNode == null) {
      throw Error();
    }

    // Update values with shallow copy
    keyNode.setValues(values);

    _incVersion();
  }

  @override
  void clear() {
    _incVersion();
    _root.value = null;
  }

  @override
  void likeKey(String key) {
    var keyNode = _root.value?.getKeyNode(_mapKeyErrorOnEmpty(key));

    if (keyNode == null) {
      throw ArgumentError('key: $key not found');
    }

    var changed = false;

    while (true) {
      // Find next non mid child ancestor and its parent
      var parent = keyNode.parent;
      if (parent != null) {
        while (keyNode == parent.mid) {
          if (parent.parent == null) {
            // Can't go any higher
            break;
          }
          keyNode = parent;
          parent = keyNode.parent;
        }

        final parentIsRoot = parent == _root.value;

        // Also need granparent to swap parent child relationship.
        // Or if at root then assign rotated node as new root.
        final grandparent = parent.parent;
        if (grandparent != null || parentIsRoot) {
          // Swap priority with parent if it is higher
          if (parent.priority > keyNode.priority) {
            final parentPriority = parent.priority;
            parent.priority = keyNode.priority;
            keyNode.priority = parentPriority;
          }

          // Rotate parent node such that it's position is swapped with node.
          if (keyNode == parent.left) {
            if (parentIsRoot) {
              _root.value = parent.rotateRight();
            } else {
              grandparent.updateChild(parent, parent.rotateRight());
            }
          } else {
            if (parentIsRoot) {
              _root.value = parent.rotateLeft();
            } else {
              grandparent.updateChild(parent, parent.rotateLeft());
            }
          }
          changed = true;
          // Final run
          if (parentIsRoot) {
            break;
          }
        } else {
          break;
        }
      }
    }
    if (changed) {
      _incVersion();
    }
  }

  @override
  bool remove(Object key, V value) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final keyNode = _root.value?.getKeyNode(_mapKeyErrorOnEmpty(key as String));

    // Does the key map to anything?
    if (keyNode == null) {
      return false;
    }

    // Try to remove
    if (keyNode.removeValue(value)) {
      _incVersion();
      return true;
    }
    return false;
  }

  @override
  Iterable<V> removeValues(Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final keyNode = _root.value?.getKeyNode(_mapKeyErrorOnEmpty(key as String));

    // Return empty Iterable when unmapped
    if (keyNode == null) {
      return Iterable<V>.empty();
    }

    _incVersion();

    return keyNode.removeValues();
  }

  @override
  Iterable<V> removeAll(Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final transformedKey = _mapKeyErrorOnEmpty(key as String);

    Iterable<V> values;
    if (_root.value != null) {
      values = _remove(_root.value, transformedKey);
      if (_root.value.sizeDFSTree == 0) {
        /// There are no end nodes left in tree so delete root
        _root.value = null;
      }
    }
    // Return empty Iterable when unmapped
    if (values == null) {
      return Iterable<V>.empty();
    }
    _incVersion();
    return values;
  }

  /// Increment modification version.
  /// Wrap backto 0 when [_MAX_SAFE_INTEGER] exceeded
  void _incVersion() {
    _version.value =
        (_version.value >= _MAX_SAFE_INTEGER) ? 0 : _version.value + 1;
  }

  /// Add or update node for [key] starting from [searchRoot] and attach [value].
  ///
  /// Return a [_Tuple2] containing:
  /// * a: New root node which may not be the same as [searchRoot] due
  /// to possible rotation.
  /// * b: The new or existing end node corresponding to [key]
  ///
  /// Iterative version: More complicated than recursive
  /// but 4 times as fast.
  _Tuple2<_Node<V>, _Node<V>> _add(_Node<V> rootNode, String key, V value) {
    final keyCodeUnits = key.codeUnits;

    var keyCodeIdx = 0;
    var _rootNode = rootNode;

    // Create new root node if needed
    if (_rootNode == null) {
      _rootNode = _nodeFactory(
          keyCodeUnits, _random.nextInt(1 << 32), null, _emptyValues);
      keyCodeIdx = keyCodeUnits.length;
    }

    var currentNode = _rootNode;

    // Create a path down to key node, rotating as we go.
    while (keyCodeIdx < keyCodeUnits.length) {
      final keyCodeUnit = keyCodeUnits[keyCodeIdx];
      if (keyCodeUnit < currentNode.codeUnits[0]) {
        // create left path as end node if able
        if (currentNode.left == null) {
          currentNode.left = _nodeFactory(keyCodeUnits.sublist(keyCodeIdx),
              _random.nextInt(1 << 32), currentNode, _emptyValues);

          keyCodeIdx = keyCodeUnits.length;
        }
        currentNode = currentNode.left;
      } else if (keyCodeUnit > currentNode.codeUnits[0]) {
        // Create right path if needed
        if (currentNode.right == null) {
          currentNode.right = _nodeFactory(keyCodeUnits.sublist(keyCodeIdx),
              _random.nextInt(1 << 32), currentNode, _emptyValues);
          keyCodeIdx = keyCodeUnits.length;
        }
        currentNode = currentNode.right;
      } else {
        // Move onto next key code unit
        keyCodeIdx++;

        // We know that the first code unit matches now try and match
        // the rest
        var nodeCodeIdx = 1;

        // Match node code units as far as possible
        while (keyCodeIdx < keyCodeUnits.length &&
            nodeCodeIdx < currentNode.codeUnits.length &&
            currentNode.codeUnits[nodeCodeIdx] == keyCodeUnits[keyCodeIdx]) {
          nodeCodeIdx++;
          keyCodeIdx++;
        }

        // If key was not consumed entirely
        if (keyCodeIdx < keyCodeUnits.length) {
          if (nodeCodeIdx < currentNode.codeUnits.length) {
            // if neither node or key were consumed then split and
            // continue on from new child
            _split(currentNode, nodeCodeIdx);
          } else {
            // If key was not consumed but node was then grow down
            // and continue from new child
            if (currentNode.mid == null) {
              currentNode.mid = _nodeFactory(keyCodeUnits.sublist(keyCodeIdx),
                  _random.nextInt(1 << 32), currentNode, _emptyValues);
              keyCodeIdx = keyCodeUnits.length;
            }
          }
        } else {
          // Key was consumed entirely
          // if both key and node were consumed this is the target
          if (nodeCodeIdx == currentNode.codeUnits.length) {
            break;
          }
          // if key was consumed but node was not then split and
          // return current as target
          if (nodeCodeIdx < currentNode.codeUnits.length) {
            _split(currentNode, nodeCodeIdx);
            break;
          }
        }

        currentNode = currentNode.mid;
      }
    }

    if (currentNode.setAsKeyEnd()) {
      // If new node was inserted reverse back up to root node
      // to update node counts
      var reverseNode = currentNode;
      while (reverseNode != _rootNode.parent) {
        // Merge any ophaned mid children on our way back
        // Probably only useful after multiple add and delete cycles
        reverseNode.mergeMid();

        // Rebalance
        reverseNode.rotateChildren();

        reverseNode.updateDescendantCounts();

        reverseNode = reverseNode.parent;
      }
    }

    if (value != null) {
      currentNode.addValue(value);
    }

    return _Tuple2<_Node<V>, _Node<V>>(_rootNode, currentNode);
  }

  /// Delete node for [transformedKey] starting from [rootNode] and return values
  /// of null if key does not exist.
  ///
  /// Assumes [transformedKey] has been transformed
  Iterable<V> _remove(_Node<V> rootNode, String transformedKey) {
    final keyCodeUnits = transformedKey.codeUnits;

    var keyCodeIdx = 0;
    var _rootNode = rootNode;

    if (_rootNode == null) {
      throw ArgumentError();
    }

    var currentNode = _rootNode;

    // Explore path down to key node
    while (keyCodeIdx < keyCodeUnits.length) {
      if (currentNode == null) {
        // Key doesnt exist
        return null;
      }

      final keyCodeUnit = keyCodeUnits[keyCodeIdx];
      if (keyCodeUnit < currentNode.codeUnits[0]) {
        currentNode = currentNode.left;
      } else if (keyCodeUnit > currentNode.codeUnits[0]) {
        currentNode = currentNode.right;
      } else {
        // Move onto next key code unit
        keyCodeIdx++;

        // We know that the first code unit matches now try and match
        // the rest
        var nodeCodeIdx = 1;

        // Match node code units as far as possible
        while (keyCodeIdx < keyCodeUnits.length &&
            nodeCodeIdx < currentNode.codeUnits.length) {
          if (currentNode.codeUnits[nodeCodeIdx] != keyCodeUnits[keyCodeIdx]) {
            return null;
          }
          nodeCodeIdx++;
          keyCodeIdx++;
        }

        // If both key and node are exhausted then this is a potential winner
        if (keyCodeIdx == keyCodeUnits.length &&
            nodeCodeIdx == currentNode.codeUnits.length) {
          break;
        }

        // If node is exhausted but key still has code units then explore mid
        if (keyCodeIdx < keyCodeUnits.length &&
            nodeCodeIdx == currentNode.codeUnits.length) {
          currentNode = currentNode.mid;
          continue;
        }

        return null;
      }
    }

    if (currentNode.isKeyEnd) {
      var values = currentNode.values;

      // If node has no key descendants we can eliminate it and all its children!
      if (currentNode.parent != null && currentNode.numDFSDescendants == 0) {
        // Delete from parent
        currentNode.parent.updateChild(currentNode, null);
      } else {
        // Otherwise sinply remove its key end status
        currentNode.values = null;
      }

      // reverse back up to root node to update node counts
      while (currentNode != _root.value.parent) {
        // Merge any ophaned mid children on our way back
        currentNode.mergeMid();

        // Rebalance
        currentNode.rotateChildren();

        currentNode.updateDescendantCounts();

        currentNode = currentNode.parent;
      }
      return values;
    } else {
      return null;
    }
  }

  /// Inserts new split child under [node].mid.
  ///
  /// Split node at [codeUnitIdx] such that:
  /// * node.codeUnits becomes node.codeUnits[0...codeUnitIdx-1]
  /// * Created child [_Node] has remainder codeUnits
  /// * Created child inherits node mid child.
  /// * If node is an end node then child is instead.
  /// * Created child [_Node] is attached to node.mid.
  void _split(_Node<V> node, int codeUnitIdx) {
    if (node.codeUnits.length < 2) {
      // Nothing to split
      throw ArgumentError();
    }

    if (codeUnitIdx >= node.codeUnits.length) {
      // Both parent and child must have at least 1 codeunit
      throw ArgumentError(codeUnitIdx);
    }

    final child = _nodeFactory(node.codeUnits.sublist(codeUnitIdx),
        _random.nextInt(1 << 32), node, _emptyValues);

    child.mid = node.mid;

    // Update child counts and grandchildren if any
    if (child.mid != null) {
      child.numDFSDescendants = child.mid.sizeDFSTree;
      child.mid.parent = child;
    }

    node.setCodeUnits(node.codeUnits.sublist(0, codeUnitIdx));

    // Insert child under node
    node.mid = child;

    // If node was a keyend then it transfers this to child
    if (node.isKeyEnd) {
      // Child inherits values and keyend status
      child.values = node.values;
      node.values = null;
      // and thus gains a key descendant
      node.numDFSDescendants++;
    }
  }
}

/// Base for all node types
abstract class _Node<V> {
  _Node(Iterable<int> codeUnits, this.priority, this.parent, this._emptyValues)
      : codeUnits = List<int>.unmodifiable(codeUnits);

  /// Fixed size array of unicode code units
  List<int> codeUnits;

  /// Randomly generated value for balancing
  /// May be changed later when reducing node proximity to root.
  int priority;

  /// Number of end nodes below this node if a DFS was performed.
  /// Allows fast calculation of subtree size
  int numDFSDescendants = 0;

  /// A single node may map to multiple values.
  /// How this is managed depends on Node sub class.
  /// If null then is not end node
  Iterable<V> values;

  _Node<V> left;
  _Node<V> mid;
  _Node<V> right;

  /// Costs space but much faster than maintaining explicit stack.
  /// during add operation. Maybe can use for near neighbour or something.
  _Node<V> parent;

  /// An empty values placeholder shared between all nodes of a
  /// particular TernaryTreap. Avoids the need for an empty valued [_Node]
  /// to incur space overhead of empty container which is presumably greater
  /// in memory usage than a reference to this shared iterator.
  final Iterable<V> _emptyValues;

  /// Remove all values from this node and return said values.
  Iterable<V> removeValues();

  /// If node is not already key End then set as key end
  bool setAsKeyEnd() {
    if (values == null) {
      values = _emptyValues;
      return true;
    } else {
      return false;
    }
  }

  /// Set to shallow copy of [values]
  void setValues(Iterable<V> values);

  void addValue(V value);

  bool removeValue(V value);

  /// Does this node represent the final character of a key?
  bool get isKeyEnd => values != null;
  // return number of end nodes in subtree with this node as root
  int get sizeDFSTree =>
      values == null ? numDFSDescendants : numDFSDescendants + 1;

  /// return number of end nodes in subtree with this node as prefix root
  int get sizePrefixTree {
    var size = values == null ? 0 : 1;
    if (mid != null) {
      size += mid.sizeDFSTree;
    }

    return size;
  }

  /// Set codeunits to fixed size array
  /// Faster and less memory than growable
  void setCodeUnits(Iterable<int> codeUnits) {
    this.codeUnits = List<int>.unmodifiable(codeUnits);
  }

  /// Return _Node descendant corresponding to a transformed key.
  /// Returns null if key does not map to a node.
  /// Assumes key has already been transformed by KeyMapping
  _Node<V> getKeyNode(String transformedKey) {
    if (transformedKey.isEmpty) {
      return null;
    }

    final prefixDescendant =
        getClosestPrefixDescendant(transformedKey.codeUnits);

    // The node must represent only this key
    if (!prefixDescendant.isPrefixMatch ||
        prefixDescendant.nodeCodeunitIdx !=
            prefixDescendant.node.codeUnits.length - 1 ||
        !prefixDescendant.node.isKeyEnd) {
      return null;
    }
    return prefixDescendant.node;
  }

  /// Find the node descendant that is parent to all keys starting with [prefix]
  ///
  /// Return [_PrefixSearchResult] where:
  ///
  /// * [_PrefixSearchResult.node] = Node containing end of prefix or closest to it. Equal to this node if no match found.
  /// * [_PrefixSearchResult.prefixCodeunitIdx] = The index of final matching prefix codeunit
  /// or [_INVALID_CODE_UNIT] if prefix not processed at all.
  /// * [_PrefixSearchResult.nodeCodeunitIdx] = The index of final matching node codeunit.
  /// * [_PrefixSearchResult.isPrefixMatch] = true if full match was found otherwise false.
  _PrefixSearchResult<V> getClosestPrefixDescendant(List<int> prefixCodeUnits) {
    _Node<V> closestNode;
    var nextNode = this;
    var prefixIdx = 0;
    var codeUnitIdx = 0;
    var depth = -1;

    while (true) {
      if (nextNode == null) {
        return _PrefixSearchResult<V>(
            closestNode, prefixIdx - 1, codeUnitIdx - 1, false, depth);
      }

      depth++;

      final codeUnits = nextNode.codeUnits;

      // Compare current prefix unit to first unit of new node
      // All nodes have at least one code unit so this wont go out of bounds
      if (prefixCodeUnits[prefixIdx] < codeUnits[0]) {
        nextNode = nextNode.left;
      } else if (prefixCodeUnits[prefixIdx] > codeUnits[0]) {
        nextNode = nextNode.right;
      } else {
        // There is a match between prefix unit and first code unit of this node
        // so this is the closest match node currently
        closestNode = nextNode;

        // Continue matching for this node
        codeUnitIdx = 1;
        prefixIdx++;
        nextNode = null;

        // The prefix may live in this node or its mid descendants
        // Match with this nodes code units
        while (prefixIdx < prefixCodeUnits.length &&
            codeUnitIdx < codeUnits.length &&
            codeUnits[codeUnitIdx] == prefixCodeUnits[prefixIdx]) {
          codeUnitIdx++;
          prefixIdx++;
        }

        if (prefixIdx == prefixCodeUnits.length) {
          // Found match in current node!
          return _PrefixSearchResult<V>(
              closestNode, prefixIdx - 1, codeUnitIdx - 1, true, depth);
        }

        if (codeUnitIdx == codeUnits.length) {
          // Made it to end of node codeunits.
          // Hunt for rest of prefix down mid child.
          nextNode = closestNode.mid;
        }
      }
    }
  }

  /// Accumulate prefix descendant counts and update own count
  void updateDescendantCounts() {
    numDFSDescendants = (left == null ? 0 : left.sizeDFSTree) +
        (mid == null ? 0 : mid.sizeDFSTree) +
        (right == null ? 0 : right.sizeDFSTree);
  }

  /// Update [oldChild] with [newChild]
  void updateChild(_Node<V> oldChild, _Node<V> newChild) {
    if (left == oldChild) {
      left = newChild;
    } else if (mid == oldChild) {
      mid = newChild;
    } else if (right == oldChild) {
      right = newChild;
    } else {
      throw Error();
    }
  }

  /// If children exist then rotate if needed.
  void rotateChildren() {
    if (left != null) {
      left = left.rotateIfNeeded();
    }

    if (right != null) {
      right = right.rotateIfNeeded();
    }
  }

  /// Rotate node tree if needed to maintain
  /// heap invarient:
  ///
  /// ([left.priority] < [priority]) &&
  /// ([right.priority] <[priority])
  ///
  /// Return possibly new root of rotated node tree
  _Node<V> rotateIfNeeded() {
    if (left != null && left.priority > priority) {
      return rotateRight();
    }

    if (right != null && right.priority > priority) {
      return rotateLeft();
    }
    return this;
  }

  /// ```
  ///     b              a
  ///    / \            / \
  ///   c   a    -->   b   e
  ///      / \        / \
  ///     d   e      c   d
  /// ```
  _Node<V> rotateLeft() {
    final b = this;
    final a = b.right;

    if (a == null) {
      return b;
    }

    final d = a.left;

    // Rotate
    a
      ..left = b
      ..parent = b.parent;

    b
      ..right = d
      ..parent = a;

    if (d != null) {
      d.parent = b;
    }

    // Adjust descendant counts from bottom up
    b.updateDescendantCounts();
    a.updateDescendantCounts();

    return a;
  }

  /// ```
  ///      a            b
  ///     / \          / \
  ///    b   e   -->  c   a
  ///   / \              / \
  ///  c   d            d   e
  /// ```
  _Node<V> rotateRight() {
    final a = this;
    final b = a.left;

    if (b == null) {
      // Nothing to rotate to.
      return a;
    }

    final d = b.right;

    // Rotate
    b
      ..right = a
      ..parent = a.parent;

    a
      ..left = d
      ..parent = b;

    if (d != null) {
      d.parent = a;
    }

    // Adjust descendant counts from bottom up
    a.updateDescendantCounts();
    b.updateDescendantCounts();

    return b;
  }

  /// Merge node and mid child such that:
  /// * codeUnits becomes codeUnits + mid.codeUnits.
  /// * node takes on all children of mid.
  /// * node takes on values children of mid.
  ///
  /// Operation only performed if:
  /// * mid is not null.
  /// * is not an end node.
  /// * child has no Left or Right children.
  void mergeMid() {
    if (mid == null) {
      // No child to merge
      return;
    }

    if (isKeyEnd) {
      // Would result in lost key/values for
      // Node and child need to be kept separated.
      return;
    }

    final child = mid;

    if (child.left != null || child.right != null) {
      // Would disrupt tree ordering
      return;
    }

    setCodeUnits(codeUnits + child.codeUnits);

    // Take on mid grandchild
    mid = child.mid;

    // Node takes on child values/keyend status
    // If child was a key node then node has 1 less descendant
    if (child.isKeyEnd) {
      values = child.values;
      // Child has been absorbed so 1 less descendant
      numDFSDescendants--;
    }

    if (mid != null) {
      mid.parent = this;
    }
  }

  @override
  String toString() => '${String.fromCharCodes(codeUnits)}';
}

/// A Node that stores values in [Set].
class _NodeSet<V> extends _Node<V> {
  _NodeSet(Iterable<int> codeUnits, int priority, _Node<V> parent,
      Iterable<V> emptyValues)
      : super(codeUnits, priority, parent, emptyValues);

  @override
  void setValues(Iterable<V> values) {
    this.values = Set<V>.from(values);
  }

  @override
  bool removeValue(V value) =>
      (values == _emptyValues) ? false : (values as Set<V>).remove(value);

  @override
  Iterable<V> removeValues() {
    final ret = values;
    values = _emptyValues;
    return ret;
  }

  @override
  void addValue(V value) {
    if (values == _emptyValues) {
      setValues([value]);
    } else {
      (values as Set<V>).add(value);
    }
  }
}

/// A Node that stores values in [List].
class _NodeList<V> extends _Node<V> {
  _NodeList(Iterable<int> codeUnit, int priority, _Node<V> parent,
      Iterable<V> emptyValues)
      : super(codeUnit, priority, parent, emptyValues);

  @override
  void setValues(Iterable<V> values) {
    this.values = List<V>.from(values);
  }

  @override
  bool removeValue(V value) =>
      (values == _emptyValues) ? false : (values as Set<V>).remove(value);

  @override
  Iterable<V> removeValues() {
    final ret = values;
    values = _emptyValues;
    return ret;
  }

  @override
  void addValue(V value) {
    if (values == _emptyValues) {
      setValues([value]);
    } else {
      (values as List<V>).add(value);
    }
  }
}

/// No way to pass primitives by ref in Dart so need to wrap in object
class _ByRef<T> {
  _ByRef(this.value);
  T value;
}

class _Tuple2<A, B> {
  _Tuple2(this.a, this.b);
  A a;
  B b;
}

/// Stores result of prefix search.
@immutable
class _PrefixSearchResult<V> {
  _PrefixSearchResult(this.node, this.prefixCodeunitIdx, this.nodeCodeunitIdx,
      this.isPrefixMatch, this.depth);

  /// Node at which search terminated.
  final _Node<V> node;

  /// The final matching codeunit index in prefix.
  final int prefixCodeunitIdx;

  /// The final matching codeunit index in [node].
  final int nodeCodeunitIdx;

  /// Is true then the prefix was fully matched.
  final bool isPrefixMatch;

  /// Depth of node from search root
  final int depth;

  /// Trim any code units at end of [prefix] that are contained in [node].
  ///
  /// The returned value can be be prepended to [node] to form [prefix].
  List<int> trimPrefix(List<int> prefix) =>
      prefix.sublist(0, prefixCodeunitIdx - nodeCodeunitIdx);

  /// Expand prefix using remaining code units of this node
  List<int> expandPrefix(List<int> prefix) =>
      prefix.sublist(0, prefixCodeunitIdx) +
      node.codeUnits.sublist(nodeCodeunitIdx);

  @override
  String toString() =>
      'Node: $node, prefixCodeunitIdx: $prefixCodeunitIdx, nodeCodeunitIdx: $nodeCodeunitIdx, isPrefixMatch:$isPrefixMatch';
}

/// Simple stack implementation based upon dynamic list.
/// Designed for scenarios where frequency of push/pop operation is
/// greater concern than depth of stack.
class _FastStack<E> {
  _FastStack(int initialSize) : stack = List<E>(initialSize);
  List<E> stack;
  int ptrTop = -1;

  int get length => ptrTop + 1;

  bool get isEmpty => ptrTop == -1;
  bool get isNotEmpty => ptrTop > -1;

  void push(E value) {
    if (++ptrTop >= stack.length) {
      //simplest growth strategy - double current size
      final newStack = List<E>(stack.length * 2);
      for (var i = 0; i < stack.length; i++) {
        newStack[i] = stack[i];
      }
      stack = newStack;
    }
    stack[ptrTop] = value;
  }

  E pop() => stack[ptrTop--];

  E top() => stack[ptrTop];

  E bottom() => stack[0];

  void reverse() {
    if (ptrTop < 1) {
      // cant reverse if less then 2 elements
      return;
    }

    for (var mid = (ptrTop / 2).floor(), left = 0, right = ptrTop;
        left <= mid;
        left++, right--) {
      final tmp = stack[left];
      stack[left] = stack[right];
      stack[right] = tmp;
    }
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.writeln('------');

    //show top down
    for (var i = ptrTop; i > -1; i--) {
      buffer.writeln(stack[i]);
    }

    buffer.writeln('------');
    return buffer.toString();
  }
}

/// Base class for in order iterables
/// Reusable until owner changes version.
abstract class _InOrderIterableBase<V, I> extends IterableMixin<I>
    implements _TernaryTreapIterable<I> {
  _InOrderIterableBase(this.owner, this.root,
      {List<int> prefix, this.fuzzy = false})
      : validVersion = owner._version.value,
        prefix = prefix ?? <int>[],
        prefixRoot = root == null
            ? null
            : prefix == null ? null : root.getClosestPrefixDescendant(prefix) {
    // Distance with no prefix doesnt make sense
    if (this.prefix.isEmpty && fuzzy) {
      throw ArgumentError('prefix.isEmpty && fuzzy');
    }
  }

  final _ImmutableTernaryTreap<V> owner;
  // Store root as base for near neighbour searches
  final _Node<V> root;
  final _PrefixSearchResult<V> prefixRoot;
  final List<int> prefix;
  final bool fuzzy;
  final int validVersion;

  @override
  int get length {
    if (owner._version.value != validVersion) {
      throw ConcurrentModificationError(owner);
    }

    if (root == null) {
      return 0;
    }

    // No shortcut to calulate length for distance queries
    if (fuzzy) {
      return super.length;
    }

    // No query, traversing entire tree
    if (prefixRoot == null) {
      return root.sizeDFSTree;
    }

    // Prefix found
    if (prefixRoot.isPrefixMatch) {
      return prefixRoot.node.sizePrefixTree;
    }

    // Prefix not found
    return 0;
  }

  @override
  bool get isEmpty => length == 0;
}

class _InOrderKeyIterable<V> extends _InOrderIterableBase<V, String> {
  _InOrderKeyIterable(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      {List<int> prefix, bool fuzzy = false})
      : super(owner, root, prefix: prefix, fuzzy: fuzzy);

  @override
  TernaryTreapIterator<String> get iterator =>
      _InOrderKeyIterator<V>._(owner, validVersion, root, prefixRoot,
          prefix: prefix, fuzzy: fuzzy);
}

/// Iterates through values of the [TernaryTreap].
///
/// Values are ordered first by key and then by insertion order.
/// Due to the 1 to n relationship between key and values
/// (necessary for key mapping) each element returned will be an [Iterable]
/// containing 1 or more elemets that are associated with a key.
///
/// If a key maps to an empty values [Iterable] then it is skipped, no
/// empty [Iterable] is returned.
class _InOrderValuesIterable<V> extends _InOrderIterableBase<V, V> {
  /// Constructs a TernaryTreeValuesIterable
  _InOrderValuesIterable(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      {List<int> prefix, bool fuzzy = false})
      : super(owner, root, prefix: prefix, fuzzy: fuzzy);

  @override
  TernaryTreapIterator<V> get iterator =>
      _InOrderValuesIterator<V>(owner, validVersion, root, prefixRoot,
          prefix: prefix, fuzzy: fuzzy);
}

class _InOrderMapEntryIterable<V>
    extends _InOrderIterableBase<V, MapEntry<String, Iterable<V>>> {
  _InOrderMapEntryIterable(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      {List<int> prefix, bool fuzzy = false})
      : super(owner, root, prefix: prefix, fuzzy: fuzzy);

  @override
  TernaryTreapIterator<MapEntry<String, Iterable<V>>> get iterator =>
      _InOrderMapEntryIterator<V>(owner, validVersion, root, prefixRoot,
          prefix: prefix, fuzzy: fuzzy);
}

// store call stack data for iterators
@immutable
class _StackFrame<V> {
  _StackFrame(this.node, this.prefix,
      {this.distance = _INVALID_DISTANCE, this.ignoreChild}) {
    if (node == null) {
      throw ArgumentError.notNull('node');
    }
  }
  final _Node<V> node;
  final List<int> prefix;
  final int distance;
  final _Node<V> ignoreChild;

  @override
  String toString() =>
      '${String.fromCharCodes(prefix)} : $node : ignoreChild -> $ignoreChild -> $distance';

  _StackFrame<V> copyWith(
          {_Node<V> node,
          List<int> prefix,
          int distance,
          _Node<V> ignoreChild,
          bool ignoreThis}) =>
      _StackFrame<V>(node ?? this.node, prefix ?? this.prefix,
          distance: distance ?? this.distance,
          ignoreChild: ignoreChild ?? this.ignoreChild);
}

enum _FuzzyState { FUZZY_INIT, FUZZY_WORKING, NON_FUZZY }

/// Base class for in order [TernaryTreap] iterators.
abstract class _InOrderIteratorBase<V> {
  /// Construct new [_InOrderIteratorBase] to start from
  /// [prefixSearchResult] node which belongs to [owner]. Is result of prefix search, may be exact or only closest lexicographic match
  /// If [prefix] is specified then it is prefixed to all returned keys.
  /// If [distance]>0 then after initial exploration from [prefixSearchResult] back to [root] further
  /// explorations from [root] are performed, each with increasing hamming distance
  /// until [distance] is reached.
  ///
  /// Note:
  /// * Distance ordering is based on the assumption that first
  /// prefix characters are more likely to be correct than later characters.
  /// * Additional work for fuzzy searches is defered until absolutely neccessary.
  /// This means that initial matches are returned rapidly and cost no more than
  /// non fuzzy matching.
  _InOrderIteratorBase(this.owner, this.validVersion, this.root,
      _PrefixSearchResult<V> prefixSearchResult,
      {this.prefix, bool fuzzy = false})
      : stack = _FastStack<_StackFrame<V>>(owner.length),
        fuzzyState = fuzzy ? _FuzzyState.FUZZY_INIT : _FuzzyState.NON_FUZZY {
    if (root != null) {
      // Was a search requested?
      if (prefixSearchResult == null) {
        // Simple DFS traversal requested
        if (fuzzyState == _FuzzyState.FUZZY_INIT) {
          throw ArgumentError('prefixRoot == null && fuzzy');
        }

        pushLeft(stack, _StackFrame<V>(root, []));
        return;
      }

      // A search was requested, what sort of match was found?
      // Set up intial stack frame parameters
      if (prefixSearchResult.prefixCodeunitIdx == _INVALID_CODE_UNIT) {
        // No match at all was found
        // All we know is that minimum possible distance is 1
        currentDistance = 1;

        // Search entire tree from root
        prefixFrame = _StackFrame<V>(root, []);

        // There is no initial subtree intialisation to dodge around
        fuzzyState = _FuzzyState.FUZZY_WORKING;

        pushLeft(stack, prefixFrame);
      } else {
        int matchDistance;

        // What distance is intial match?
        if (prefixSearchResult.isPrefixMatch) {
          // A distance 0 match has been found
          matchDistance = 0;
        } else {
          // Prefix was only partially matched so trim accordingly and
          // add any remainding code units of match node
          final closestMatch = prefixSearchResult.expandPrefix(prefix);

          // Calculate distance of this partial match
          matchDistance = prefixDistance(prefix, closestMatch);

          // Given no exact match present, minimum possible search distance is 1
          currentDistance = 1;
        }

        // Set the start frame for prefix query.
        // Because the moveNext method constructs keys as:
        // prefix + codeUnits we need to remove matched codeUnits from
        // the prefix.
        prefixFrame = _StackFrame<V>(
            prefixSearchResult.node, prefixSearchResult.trimPrefix(prefix),
            distance: matchDistance);

        // Ensure that only mid child explored for initial run
        // by instructing moveNext() to ignore right child
        stack.push(
            prefixFrame.copyWith(ignoreChild: prefixSearchResult.node.right));
      }
    }
  }

  final _FastStack<_StackFrame<V>> stack;

  final _ImmutableTernaryTreap<V> owner;

  final int validVersion;

  /// Entry point for distance searching
  final _Node<V> root;

  final List<int> prefix;

  /// Current state of fuzzy search
  _FuzzyState fuzzyState;

  /// The startying frame for each search distance
  _StackFrame<V> prefixFrame;

  /// Distance currently being explored
  int currentDistance = 0;

  String currentKey;
  Iterable<V> currentValue;

  /// Moves to the next element.
  ///
  /// Returns true if current contains the next element.
  /// Returns false if no elements are left.
  /// It is safe to invoke moveNext even when the
  /// iterator is already positioned after the last element.
  /// In this case moveNext returns false again and has no effect.
  /// A call to moveNext may throw [ConcurrentModificationError] if
  /// iteration has been broken by changing the underlying collection.
  bool moveNext() {
    if (owner._version.value != validVersion) {
      throw ConcurrentModificationError(owner);
    }
    if (root != null) {
      // Max distance is when all but one prefix code units are altered
      final maxDistance =
          fuzzyState == _FuzzyState.NON_FUZZY ? 0 : prefix.length - 1;

      while (currentDistance <= maxDistance) {
        while (stack.isNotEmpty) {
          final context = stack.pop();

          final nodeCodeUnits = context.prefix + context.node.codeUnits;

          // Avoid recalculating if possible
          final nodeDistance = prefix.isEmpty
              ? 0
              : context.distance == _INVALID_DISTANCE
                  ? prefixDistance(prefix, nodeCodeUnits)
                  : context.distance;

          // Push right and mid for later consumption
          // Exclude initial path root
          if (context.node.right != null &&
              context.node.right != context.ignoreChild) {
            pushLeft(stack, _StackFrame<V>(context.node.right, context.prefix));
          }

          if (context.node.mid != null &&
              context.node.mid != context.ignoreChild) {
            // Only follow if within current distance or
            // not computable
            if (nodeDistance <= currentDistance) {
              pushLeft(
                  stack,
                  _StackFrame<V>(context.node.mid, nodeCodeUnits,
                      distance: nodeDistance),
                  nodeDistance);
            }
          }

          //Only return keys of current distance
          if (context.node.isKeyEnd && nodeDistance == currentDistance) {
            currentKey = String.fromCharCodes(nodeCodeUnits);

            currentValue = context.node.values;

            return true;
          }
        }

        // Prepare stack for next round if needed
        switch (fuzzyState) {
          case _FuzzyState.FUZZY_INIT:
            // Only need to partially init here as it has already
            // been started by constructor
            pushExplorePath(false);
            fuzzyState = _FuzzyState.FUZZY_WORKING;
            break;
          case _FuzzyState.FUZZY_WORKING:
            // Fully re-init stack
            pushExplorePath(true);
            currentDistance++;
            break;
          case _FuzzyState.NON_FUZZY:
            currentDistance++;
            break;
        }
      }
    }
    return false;
  }

  /// Set up empty stack for backtracking
  // For distance searching we want to traverse in this order:
  // * prefixRoot -> descendants
  // * prefixRoot -> root
  // * root -> rest of tree
  //
  // This gives preference to strings lexiographically similar to prefix.
  void pushExplorePath(bool includePrefixMid) {
    assert(stack.isEmpty);

    var prefixNode = prefixFrame.node;
    var currentPrefix = prefixFrame.prefix;

    if (includePrefixMid) {
      pushLeft(stack, prefixFrame);
    } else {
      // prefixNode and prefixNode->mid have already been explored so explore left and right only
      if (prefixNode.left != null) {
        pushLeft(stack, _StackFrame<V>(prefixNode.left, currentPrefix));
      }

      if (prefixNode.right != null) {
        pushLeft(stack, _StackFrame<V>(prefixNode.right, currentPrefix));
      }
    }

    while (prefixNode != root) {
      var parentNode = prefixNode.parent;
      assert(parentNode != null);
      // Parent node prefix depends upon child position.
      // If mid child then need to remove parent code units.
      if (prefixNode == parentNode.mid) {
        currentPrefix = currentPrefix.sublist(
            0, currentPrefix.length - parentNode.codeUnits.length);
      }

      // DFS from parent if last node is not left child
      if (parentNode.left != prefixNode) {
        pushLeft(stack,
            _StackFrame<V>(parentNode, currentPrefix, ignoreChild: prefixNode));
      } else {
        stack.push(
            _StackFrame<V>(parentNode, currentPrefix, ignoreChild: prefixNode));
      }

      prefixNode = parentNode;
    }

    stack.reverse();
  }

  /// Calculate distance from [prefix] to [compare]
  ///
  /// Cannot calculate distance if [compare] is shorter than [prefix]
  /// so return [_INVALID_DISTANCE] in this case.
  ///
  /// Return distance as number of edits between [prefix] and
  /// first [prefix].length code unti of  [compare].
  ///
  int prefixDistance(final List<int> prefix, final List<int> compare) {
    if (compare.length < prefix.length) {
      // cannot compute hamming distance here as
      return _INVALID_DISTANCE;
    }

    // Assume worst case and improve if possible
    var distance = prefix.length;

    // Improve if possible
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] == compare[i]) {
        distance--;
      }
    }

    return distance;
  }

  /// Add [context] to [stack] and then follow left children down.
  /// Child inherit prefix
  void pushLeft(_FastStack<_StackFrame<V>> stack, _StackFrame<V> context,
      [int distance = _INVALID_DISTANCE]) {
    // add current frame to stack and drill down the left

    stack.push(context);

    var node = context.node;
    while (node.left != null) {
      node = node.left;
      stack.push(_StackFrame<V>(node, context.prefix, distance: distance));
    }
  }
}

/// Iterate through keys
class _InOrderKeyIterator<V> extends _InOrderIteratorBase<V>
    implements TernaryTreapIterator<String> {
  /// Construct new [_InOrderKeyIterator]
  _InOrderKeyIterator._(_ImmutableTernaryTreap<V> owner, int validVersion,
      _Node<V> root, _PrefixSearchResult<V> prefixRoot,
      {List<int> prefix, bool fuzzy = false})
      : super(owner, validVersion, root, prefixRoot,
            prefix: prefix, fuzzy: fuzzy);

  @override
  String get current => currentKey;

  @override
  int get keyDistance => currentDistance;
}

/// Iterate through values
class _InOrderValuesIterator<V> extends _InOrderIteratorBase<V>
    implements TernaryTreapIterator<V> {
  /// Construct new [_InOrderKeyIterator]
  _InOrderValuesIterator(_ImmutableTernaryTreap<V> owner, int validVersion,
      _Node<V> root, _PrefixSearchResult<V> prefixRoot,
      {List<int> prefix, bool fuzzy = false})
      : super(owner, validVersion, root, prefixRoot,
            prefix: prefix, fuzzy: fuzzy);

  Iterator<V> _currentItr;

  @override
  bool moveNext() {
    // Flatten out value collections into single iterable
    var next = false;

    // First time round
    if (_currentItr == null) {
      next = super.moveNext();
      //  Skip empty collections
      while (next && currentValue.isEmpty) {
        next = super.moveNext();
      }
      if (next) {
        _currentItr = currentValue.iterator;
        return _currentItr.moveNext();
      }
      return false;
    }

    // Check current iterator
    next = _currentItr.moveNext();
    if (next) {
      return true;
    }

    // Move to next iterator
    next = super.moveNext();
    // skip empty value lists
    while (next && currentValue.isEmpty) {
      next = super.moveNext();
    }
    if (next) {
      _currentItr = currentValue.iterator;
      return _currentItr.moveNext();
    }
    return false;
  }

  @override
  V get current => _currentItr.current;

  @override
  int get keyDistance => currentDistance;
}

/// Iterate through keys
class _InOrderMapEntryIterator<V> extends _InOrderIteratorBase<V>
    implements TernaryTreapIterator<MapEntry<String, Iterable<V>>> {
  /// Construct new [_InOrderKeyIterator]
  _InOrderMapEntryIterator(_ImmutableTernaryTreap<V> owner, int validVersion,
      _Node<V> root, _PrefixSearchResult<V> prefixRoot,
      {List<int> prefix, bool fuzzy = false})
      : super(owner, validVersion, root, prefixRoot,
            prefix: prefix, fuzzy: fuzzy);

  @override
  MapEntry<String, Iterable<V>> get current =>
      MapEntry<String, Iterable<V>>(currentKey, currentValue);

  @override
  int get keyDistance => currentDistance;
}
