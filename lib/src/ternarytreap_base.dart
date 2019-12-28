import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';

// 2^53-1
const int _MAX_SAFE_INTEGER = 9007199254740991;

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

/// A self balancing Ternary search tree.
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
/// This is because the default identity KeyMapping: <i>m</i>(x) = x is used.
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
/// |A 3|            |     *Numbers represent priorities.
/// +-+-+          +-+-+
///   |            |P 8+-------------+
/// +-+-+          +-+-+             |
/// | N |            |             +-+-+
/// +---+            |             |T 2|
///          +------+++------+     +-+-+
///          | Value | Value |       |
///          +------+-+------+       |
///                              +---+---+
///                              | Value |
///                              +-------+
/// ```
/// Each Node stores:
///
/// * A character `Node.codeUnit` such that Ternary Tree invarient
/// is maintained.
/// * An integer priority value `Node.priority` such that Treap invarient:
/// ```
/// (Node.left.priority > Node.priority) &&
/// (Node.right.priority > Node.priority)
/// ```
/// is maintained.
abstract class TernaryTreap<V> extends ImmutableTernaryTreap<V> {
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
  void addAll(TernaryTreap<V> other);

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
  void addValues(String key, Iterable<V> values);

  /// Return a view of this [TernaryTreap] as a [ImmutableTernaryTreap]
  ImmutableTernaryTreap<V> asImmutable();

  /// Removes all data from the [TernaryTreap].
  void clear();

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
      String prefix, void Function(String key, Iterable<V> values) f);

  /// Removes the association between the given [key] and [value].
  ///
  /// Returns `true` if the association existed, `false` otherwise
  bool remove(Object key, V value);

  /// Removes [key] and all associated values.
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  Iterable<V> removeKey(Object key);

  /// Removes all values associated with [key].
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  Iterable<V> removeValues(Object key);
}

/// A view of a [TernaryTreap] with no mutators
abstract class ImmutableTernaryTreap<V> {
  /// Return [Iterable] of values for specified [key].
  ///
  /// If no value associated with key then returns empty [Iterable].
  /// If key not found then returns null.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  Iterable<V> operator [](Object key);

  /// Return a view of this [TernaryTreap] as a [Map]
  Map<String, Iterable<V>> asMap();

  /// Return [ImmutableTernaryTreap] view of sub tree
  /// underneath final node of prefix [mapKey]`(`[prefix]`)`.
  ///
  /// If [mapKey]`(`[prefix]`)` is empty or no suffices exist then returns
  /// empty [ImmutableTernaryTreap]
  ///
  /// Throws ArgumentError if [prefix] is empty.
  ImmutableTernaryTreap<V> suffixTree(String prefix);

  /// Returns whether this [TernaryTreap] contains an
  /// association between [key[] and [value].
  bool contains(Object key, Object value);

  /// Returns whether this [TernaryTreap] contains [key].
  bool containsKey(Object key);

  /// Returns whether this [TernaryTreap] contains [value]
  /// at least once.
  bool containsValue(Object value);

  /// The maximum node depth of the [TernaryTreap].
  ///
  /// Returns
  int get depth;

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
  /// If [mapKey]`(`[prefix]`)` is empty then returns [Iterable.empty].
  ///
  /// Throws [ArgumentError] if [prefix] is empty.
  Iterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(String prefix);

  /// Returns true if there are no keys in the [TernaryTreap].
  bool get isEmpty;

  /// Returns true if there is at least one key in the [TernaryTreap].
  bool get isNotEmpty;

  /// Return [Iterable] view of keys
  Iterable<String> get keys;

  /// Returns [Iterable] collection of each key of the [TernaryTreap]
  /// where key is prefixed by [mapKey]`(`[prefix]`)`.
  ///
  /// If [mapKey]`(`[prefix]`)` is empty then returns [Iterable.empty].
  ///
  /// Throws [ArgumentError] if [prefix] is empty.
  Iterable<String> keysByPrefix(String prefix);

  /// The number of keys in the [TernaryTreap].
  int get length;

  /// Return key transformed by any [KeyMapping] specified
  /// during construction.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  String mapKey(String key);

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
  /// If [mapKey]`(`[prefix]`)` is empty then returns [Iterable.empty].
  ///
  /// Throws ArgumentError if [prefix] is empty.
  Iterable<V> valuesByKeyPrefix(String prefix);
}

/// A [TernaryTreap] that stores values in a [Set]
///
/// [TernaryTreapSet] is a function a Key to a set of Values:
///
/// * <i>f</i> :  <i>K</i> &mapsto; &weierp; (<i>V</i>)
///
/// such that
///
/// * K is the set of all Keys
/// * V is the set of all Values
/// * &weierp; (<i>V</i>) is the powerset of V
///
/// By definition the Values sequence may feature the same Value only once.
///
/// The codomain of <i>f</i> includes the empty set.
/// This allows Keys to be stored without Values, useful when
/// you require only a set of Keys for prefix searching purposes.

class TernaryTreapSet<V> extends _TernaryTreap<V> {
  /// Construct new [TernaryTreapSet]
  TernaryTreapSet([KeyMapping keyMapping])
      : super(
            (int codeUnit, int priority, _Node<V> parent) =>
                _NodeSet<V>(codeUnit, priority, parent),
            keyMapping);
}

/// A [TernaryTreap] that stores values in a [List]
///
/// [TernaryTreapList] is a function from a Key to a sequence of Values:
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
/// By definition the Values sequence may feature the same Value multiple times
/// and is ordered by insertion.
///
/// The codomain of <i>f</i> includes the empty sequence.
/// This allows Keys to be stored without Values, useful when
/// you require only a set of Keys for prefix searching purposes.
class TernaryTreapList<V> extends _TernaryTreap<V> {
  /// Construct new [TernaryTreapList]
  TernaryTreapList([KeyMapping keyMapping])
      : super(
            (int codeUnit, int priority, _Node<V> parent) =>
                _NodeList<V>(codeUnit, priority, parent),
            keyMapping);
}

class _ImmutableTernaryTreap<V> implements ImmutableTernaryTreap<V> {
  /// Constructs a new [TernaryTreap].
  ///
  /// The [_keyMapping] argument supplies an optional instance of
  /// [KeyMapping] to be applied to all keys processed by this [TernaryTreap].
  _ImmutableTernaryTreap([this._root, _ByRef<int> _version, this._keyMapping])
      : _version = _version ?? _ByRef<int>(0);

  /// The [KeyMapping] in use by this [TernaryTreap]
  ///
  /// See: [KeyMapping].
  final KeyMapping _keyMapping;

  /// Entry point into [_Node] tree.
  _Node<V> _root;

  /// Allows tracking of modifications
  /// ByRef so as to allow sharing with Immutable views
  final _ByRef<int> _version;

  @override
  Iterable<V> operator [](Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final keyMapped = mapKey(key as String);

    if (_root == null || keyMapped.isEmpty) {
      return null;
    }

    final keyNode = _root._getKeyNode(keyMapped);

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

    final transformedKey = mapKey(key as String);

    if (_root == null || transformedKey.isEmpty) {
      return false;
    }

    final keyNode = _root._getKeyNode(transformedKey);

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
  int get depth {
    final itr = entries.iterator as _MapEntryIterator<V>;
    var maxDepth = 0;
    while (itr.moveNext()) {
      final currentDepth = itr.stack.length;

      if (currentDepth > maxDepth) {
        maxDepth = currentDepth;
      }
    }
    return maxDepth;
  }

  @override
  Iterable<MapEntry<String, Iterable<V>>> get entries =>
      _MapEntryIterable<V>(this, _root);
  @override
  Iterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(String prefix) => _MapEntryIterable<V>(this, _root, mapKey(prefix));

  @override
  bool get isEmpty => _root == null;

  @override
  bool get isNotEmpty => _root != null;

  @override
  Iterable<String> get keys => _KeyIterable<V>(this, _root);

  @override
  Iterable<String> keysByPrefix(String prefix) => _KeyIterable<V>(this, _root, mapKey(prefix));

  @override
  int get length => _root == null ? 0 : _root.sizeDFSTree;

  @override
  String mapKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError();
    }

    return _keyMapping == null ? key : _keyMapping(key);
  }

  @override
  ImmutableTernaryTreap<V> suffixTree(String prefix) {
    final prefixMapped = mapKey(prefix);

    if (_root == null || prefixMapped.isEmpty) {
      return _ImmutableTernaryTreap<V>(null, _version, _keyMapping);
    }

    //Traverse from last node of prefix
    var suffixRoot = _root._getPrefixDescendant(prefixMapped);

    if (suffixRoot != null) {
      suffixRoot = suffixRoot.mid;
    }

    return _ImmutableTernaryTreap<V>(suffixRoot, _version, _keyMapping);
  }

  @override
  Iterable<V> get values =>
      _ValuesIterable<V>(this, _root).expand((Iterable<V> values) => values);

  @override
  Iterable<V> valuesByKeyPrefix(String prefix) => _ValuesIterable<V>(this, _root, mapKey(prefix))
        .expand((Iterable<V> values) => values);

  @override
  String toString([String paddingChar = '-']) {
    final lines = StringBuffer();
    final itr = entries.iterator as _MapEntryIterator<V>;

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

class _TernaryTreap<V> extends _ImmutableTernaryTreap<V>
    implements TernaryTreap<V> {
  /// Constructs a new [TernaryTreap].
  ///
  /// The [_keyMapping] argument supplies an optional instance of
  /// [KeyMapping] to be applied to all keys processed by this [TernaryTreap].
  _TernaryTreap(this._nodeFactory, KeyMapping keyMapping)
      : super(null, _ByRef<int>(0), keyMapping);

  final Random _random = Random();

  /// Factory used to create new nodes
  final _Node<V> Function(int codeUnit, int priority, _Node<V> parent)
      _nodeFactory;

  @override
  void add(String key, [V value]) {
    _root = _add(_root, _mapKeyErrorOnEmpty(key), value);

    _incVersion();
  }

  @override
  void addAll(TernaryTreap<V> other) {
    final  entryItr = other.entries.iterator as _MapEntryIterator<V>;
    while (entryItr.moveNext()) {
      final mappedKey = _mapKeyErrorOnEmpty(entryItr.currentKey);

      // map key alone for case where no data is associated with key
      _root = _add(_root, mappedKey, null);

      for (final value in entryItr.currentValue) {
        _root = _add(_root, mappedKey, value);
      }
    }

    _incVersion();
  }

  @override
  void addValues(String key, Iterable<V> values) {
    final mappedKey = _mapKeyErrorOnEmpty(key);

    // map key alone for case where no data is associated with key
    _root = _add(_root, mappedKey, null);

    for (final value in values) {
      _root = _add(_root, mappedKey, value);
    }

    _incVersion();
  }

  @override
  ImmutableTernaryTreap<V> asImmutable() => _ImmutableTernaryTreap(_root, _version, _keyMapping);

  @override
  void forEach(void Function(String key, V value) f) {
    final  entryItr = entries.iterator as _MapEntryIterator<V>;

    while (entryItr.moveNext()) {
      for (final value in entryItr.currentValue) {
        f(entryItr.currentKey, value);
      }
    }
  }

  @override
  void forEachKey(void Function(String key, Iterable<V> values) f) {
    final entryItr = entries.iterator as _MapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f) {
    final itr = entriesByKeyPrefix(prefix).iterator as _MapEntryIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue);
    }
  }

  @override
  void operator []=(String key, Iterable<V> values) {
    final keyMapped = _mapKeyErrorOnEmpty(key);
    var keyNode = _root?._getKeyNode(keyMapped);

    if (keyNode == null) {
      // Node does not exist so insert a new one
      add(key);
      // Get newly added now
      keyNode = _root._getKeyNode(keyMapped);

      if (keyNode == null) {
        throw Error();
      }
    }

    // Update values with shallow copy
    keyNode.setValues(values);

    _incVersion();
  }

  @override
  void clear() {
    _incVersion();
    _root = null;
  }

  @override
  bool remove(Object key, V value) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final keyNode = _root?._getKeyNode(mapKey(key as String));

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

    final keyNode = _root?._getKeyNode(mapKey(key as String));

    // Return empty Iterable when unmapped
    if (keyNode == null) {
      return Iterable<V>.empty();
    }

    _incVersion();

    return keyNode.removeValues();
  }

  @override
  Iterable<V> removeKey(Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }
    _incVersion();
    final transformedKey = mapKey(key as String);
    final values = _remove(_root, null, transformedKey.codeUnits, 0);
    if (_root != null && _root.numDFSDescendants == 0) {
      /// There are no end nodes left in tree so delete root
      _root = null;
    }

    // Return empty Iterable when unmapped
    if (values == null) {
      return Iterable<V>.empty();
    }
    return values;
  }

  /// Increment modification version.
  /// Wrap backto 0 when [_MAX_SAFE_INTEGER] exceeded
  void _incVersion() => _version.value =
      (_version.value >= _MAX_SAFE_INTEGER) ? 0 : _version.value + 1;

/*
  /// Add node if necessary and attach [value]
  /// Recursive version
  _Node<V> _add(_Node<V> thisNode, String key, int idx, V value) {
    final List<int> keyCodeUnits = key.codeUnits;
    _Node<V> _thisNode;
    if (thisNode == null) {
      _thisNode = _NodeSet<V>(keyCodeUnits[idx], _random.nextInt(1 << 32));
    } else {
      _thisNode = thisNode;
    }

    if (key[idx] < _thisNode.codeUnit) {
      _thisNode.left = _add(_thisNode.left, key, idx, value);
      if (_thisNode.left.priority > _thisNode.priority) {
        _thisNode = _rotateRight(_thisNode);
      }
    } else if (key[idx] > _thisNode.codeUnit) {
      _thisNode.right = _add(_thisNode.right, key, idx, value);
      if (_thisNode.right.priority > _thisNode.priority) {
        _thisNode = _rotateLeft(_thisNode);
      }
    } else {
      if (idx + 1 < key.length) {
        _thisNode.mid = _add(_thisNode.mid, key, idx + 1, value);
      } else {
        // Terminal node for this key
        //This is a new key
        _thisNode.setAsKeyEnd();

        // If a value has been specified then consider adding it to list
        if (value != null) {
          _thisNode.addValue(value);
        }
      }
    }

    return _updateDescendantCounts(_thisNode);
  }
*/

  /// Add node if necessary and attach [value].
  /// Iterative version: More complicated than recursive
  /// but 4 times as fast.
  _Node<V> _add(_Node<V> rootNode, String key, V value) {
    final keyCodeUnits = key.codeUnits;

    var currentIdx = 0;
    var _rootNode = rootNode;

    // Create new root node if needed
    var currentNode = _rootNode ??=
        _nodeFactory(keyCodeUnits[currentIdx], _random.nextInt(1 << 32), null)

          // stop marker for reverse iteration
          ..parent = null;

    // Create a path down to key node
    while (currentIdx < keyCodeUnits.length) {
      final keyCodeUnit = keyCodeUnits[currentIdx];
      if (keyCodeUnit < currentNode.codeUnit) {
        // create left path if needed
        currentNode.left ??=
            _nodeFactory(keyCodeUnit, _random.nextInt(1 << 32), currentNode);

        // rotate node and update parent if needed
        if (currentNode.left.priority > currentNode.priority) {
          final currentParent = currentNode.parent;
          final rotatedNode = _rotateRight(currentNode);
          if (currentParent == null) {
            _rootNode = rotatedNode;
          } else {
            // Update parent with new child
            if (currentNode == currentParent.left) {
              currentParent.left = rotatedNode;
            } else if (currentNode == currentParent.right) {
              currentParent.right = rotatedNode;
            } else {
              currentParent.mid = rotatedNode;
            }
          }
          currentNode = rotatedNode;
        } else {
          currentNode = currentNode.left;
        }
      } else if (keyCodeUnit > currentNode.codeUnit) {
        currentNode.right ??=
            _nodeFactory(keyCodeUnit, _random.nextInt(1 << 32), currentNode);

        if (currentNode.right.priority > currentNode.priority) {
          final currentParent = currentNode.parent;
          final rotatedNode = _rotateLeft(currentNode);
          if (currentParent == null) {
            // Set new root
            _rootNode = rotatedNode;
          } else {
            // Update parent with new child
            if (currentNode == currentParent.left) {
              currentParent.left = rotatedNode;
            } else if (currentNode == currentParent.right) {
              currentParent.right = rotatedNode;
            } else {
              currentParent.mid = rotatedNode;
            }
          }
          currentNode = rotatedNode;
        } else {
          currentNode = currentNode.right;
        }
      } else {
        currentIdx++;
        if (currentIdx < keyCodeUnits.length) {
          currentNode.mid ??= _nodeFactory(
              keyCodeUnits[currentIdx], _random.nextInt(1 << 32), currentNode);

          currentNode = currentNode.mid;
        }
      }
    }

    if (currentNode.setAsKeyEnd()) {
      // If new node was inserted reverse back up to root node
      // to update node counts
      var reverseNode = currentNode;
      while (reverseNode != null) {
        reverseNode.numDFSDescendants =
            (reverseNode.left == null ? 0 : reverseNode.left.sizeDFSTree) +
                (reverseNode.mid == null ? 0 : reverseNode.mid.sizeDFSTree) +
                (reverseNode.right == null ? 0 : reverseNode.right.sizeDFSTree);

        reverseNode = reverseNode.parent;
      }
    }

    if (value != null) {
      currentNode.addValue(value);
    }

    return _rootNode;
  }

  /// Accumulate prefix descendant counts and update own count
  _Node<V> _updateDescendantCounts(_Node<V> _thisNode) {
    if (_thisNode != null) {
      _thisNode.numDFSDescendants =
          (_thisNode.left == null ? 0 : _thisNode.left.sizeDFSTree) +
              (_thisNode.mid == null ? 0 : _thisNode.mid.sizeDFSTree) +
              (_thisNode.right == null ? 0 : _thisNode.right.sizeDFSTree);
    }
    return _thisNode;
  }

  /// Remove node corresponding to key for codeunits and return values
  /// or null if it doesn't exist.
  Iterable<V> _remove(
      _Node<V> thisNode, _Node<V> parentNode, List<int> codeUnits, int idx) {
    if (thisNode == null) {
      return null;
    }

    if (codeUnits[idx] < thisNode.codeUnit) {
      final values = _remove(thisNode.left, thisNode, codeUnits, idx);
      if (values != null) {
        _updateDescendantCounts(thisNode);
      }
      return values;
    } else {
      if (codeUnits[idx] > thisNode.codeUnit) {
        final values = _remove(thisNode.right, thisNode, codeUnits, idx);
        if (values != null) {
          _updateDescendantCounts(thisNode);
        }
        return values;
      } else {
        // This node represents word end for key
        if (idx == (codeUnits.length - 1)) {
          // First check if key exists
          if (!thisNode.isKeyEnd) {
            // Key doesnt exist
            return null;
          }
          // Node has no key descendants
          if (thisNode.numDFSDescendants == 0) {
            // Delete from parent and return
            if (parentNode != null) {
              parentNode.mid = null;
            }
          }
          // Remove end node status
          final values = thisNode.values;
          thisNode.values = null;
          return values;
        } else {
          final values = _remove(thisNode.mid, thisNode, codeUnits, idx + 1);
          if (values != null) {
            _updateDescendantCounts(thisNode);
          }
          return values;
        }
      }
    }
  }

  /// ```
  ///      a            b
  ///     / \          / \
  ///    b   e   -->  c   a
  ///   / \              / \
  ///  c   d            d   e ```
  _Node<V> _rotateRight(_Node<V> a) {
    final b = a.left;
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
    _updateDescendantCounts(a);
    _updateDescendantCounts(b);

    return b;
  }

  /// ```
  ///     b              a
  ///    / \            / \
  ///   c   a    -->   b   e
  ///      / \        / \
  ///     d   e      c   d ```
  _Node<V> _rotateLeft(_Node<V> b) {
    final a = b.right;
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
    _updateDescendantCounts(b);
    _updateDescendantCounts(a);

    return a;
  }
}

/// Base for all node types
abstract class _Node<V> {
  _Node(this.codeUnit, this.priority, this.parent);

  final int codeUnit;
  final int priority;

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

  // Used for backtracking info during iterative add.
  // Costs space but much faster than maintaining explicit stack.
  _Node<V> parent;

  Iterable<V> removeValues();

  /// If node is not already key End then set as key end
  bool setAsKeyEnd();

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
  int get _sizePrefixTree {
    var size = values == null ? 0 : 1;
    if (mid != null) {
      size += mid.sizeDFSTree;
    }
    return size;
  }

  /// Return _Node descendant corresponding to a transformed key.
  /// Returns null if key does not map to a node.
  /// Assumes key has already been transformed by KeyMapping
  _Node<V> _getKeyNode(String transformedKey) {
    if (transformedKey.isEmpty) {
      return null;
    }

    final lastPrefixNode = _getPrefixDescendant(transformedKey);

    if (lastPrefixNode == null || !lastPrefixNode.isKeyEnd) {
      return null;
    }
    return lastPrefixNode;
  }

  /// Return the node descendant that is parent to all keys starting with [prefix]
  _Node<V> _getPrefixDescendant(String prefix) {
    final prefixCodeUnits = prefix.codeUnits;
    _Node<V> currentNode, nextNode = this;
    var currentIdx = 0;

    while (currentIdx < (prefixCodeUnits.length)) {
      if (nextNode == null) {
        return null;
      }
      currentNode = nextNode;

      if (prefixCodeUnits[currentIdx] < currentNode.codeUnit) {
        nextNode = currentNode.left;
      } else if (prefixCodeUnits[currentIdx] > currentNode.codeUnit) {
        nextNode = currentNode.right;
      } else {
        currentIdx++;
        nextNode = currentNode.mid;
      }
    }
    return currentNode;
  }
}

/// A Node that stores values in [Set].
class _NodeSet<V> extends _Node<V> {
  _NodeSet(int codeUnit, int priority, _Node<V> parent)
      : super(codeUnit, priority, parent);

  @override
  void setValues(Iterable<V> values) {
    this.values = Set<V>.from(values);
  }

  @override
  bool removeValue(V value) => (values as Set<V>).remove(value);

  @override
  Iterable<V> removeValues() {
    final ret = values;
    values = <V>{};
    return ret;
  }

  @override
  void addValue(V value) {
    (values as Set<V>).add(value);
  }

  @override
  bool setAsKeyEnd() {
    if (values == null) {
      values = <V>{};
      return true;
    } else {
      return false;
    }
  }
}

/// A Node that stores values in [List].
class _NodeList<V> extends _Node<V> {
  _NodeList(int codeUnit, int priority, _Node<V> parent)
      : super(codeUnit, priority, parent);

  @override
  void setValues(Iterable<V> values) {
    this.values = List<V>.from(values);
  }

  @override
  bool removeValue(V value) => (values as Set<V>).remove(value);

  @override
  Iterable<V> removeValues() {
    final ret = values;
    values = <V>[];
    return ret;
  }

  @override
  void addValue(V value) {
    (values as List<V>).add(value);
  }

  @override
  bool setAsKeyEnd() {
    if (values == null) {
      values = <V>[];
      return true;
    } else {
      return false;
    }
  }
}

/// No way to pass primitives by ref in Dart so need to wrap in object
class _ByRef<T> {
  T value;
  _ByRef(this.value);
}

/// Simple stack implementation
class _Stack<E> {
  _Stack(int initialSize) : stack = List<E>(initialSize);
  List<E> stack;
  int ptrTop = -1;

  int get length => ptrTop + 1;

  bool get isNotEmpty => ptrTop > -1;
  void push(E value) {
    if (++ptrTop >= stack.length) {
      //simplest growth strategy
      final newStack = List<E>(stack.length * 2);
      for (var i = 0; i < stack.length; i++) {
        newStack[i] = stack[i];
      }
      stack = newStack;
    }
    stack[ptrTop] = value;
  }

  E pop() => stack[ptrTop--];
}

/// Base class for in order iterables
abstract class _IterableBase<V, I> extends IterableMixin<I> {
  _IterableBase(this.owner, _Node<V>root, this.prefix)
      : root = prefix.isEmpty ? root : root?._getPrefixDescendant(prefix);

  final _ImmutableTernaryTreap<V> owner;
  final _Node<V> root;
  final String prefix;

  @override
  int get length {
    if (root == null) {
      return 0;
    }

    return prefix.isEmpty ? root.sizeDFSTree : root._sizePrefixTree;
  }

  @override
  bool get isEmpty => root == null;
}

class _KeyIterable<V> extends _IterableBase<V, String> {
  _KeyIterable(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<String> get iterator => _KeyIterator<V>(owner, root, prefix);
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
class _ValuesIterable<V> extends _IterableBase<V, Iterable<V>> {
  /// Constructs a TernaryTreeValuesIterable
  _ValuesIterable(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<Iterable<V>> get iterator => _ValuesIterator<V>(owner, root, prefix);
}

class _MapEntryIterable<V>
    extends _IterableBase<V, MapEntry<String, Iterable<V>>> {
  _MapEntryIterable(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<MapEntry<String, Iterable<V>>> get iterator =>
      _MapEntryIterator<V>(owner, root, prefix);
}

// store call stack data for iterators
@immutable
class _StackFrame<V> {
  const _StackFrame(this.node, this.prefix);
  final _Node<V> node;
  final String prefix;
}

/// Base class for in order [TernaryTreap] iterators.
///
/// Accepts optional [prefix] that was apply to root.
abstract class _InOrderIteratorBase<V> {
  /// Construct new [_InOrderIteratorBase] to start from
  /// [root] node which belongs to [owner].
  _InOrderIteratorBase(this.owner, _Node<V> root, [String prefix = ''])
      : ownerStartingVersion = owner._version.value,
        stack = _Stack<_StackFrame<V>>(owner.length) {
    if (prefix == null) {
      throw ArgumentError.notNull('prefix');
    }

    if (root != null) {
      // If prefix was specified then our result tree is hanging
      // from _root.mid however current value must reflect _root
      // after first call of moveNext()
      if (prefix.isNotEmpty) {
        if (root != null) {
          if (root.isKeyEnd) {
            // If root represents a key end then ensure it is
            // returned ater first call.
            prefixFrame = _StackFrame<V>(root, prefix);
          }
          if (root.mid != null) {
            pushAllLeft(_StackFrame<V>(root.mid, prefix));
          }
        }
      } else {
        pushAllLeft(_StackFrame<V>(root, ''));
      }
    }
  }

  final _Stack<_StackFrame<V>> stack;

  final _ImmutableTernaryTreap<V> owner;

  final int ownerStartingVersion;

  _StackFrame<V> prefixFrame; // Handle prefix end node
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
    if (owner._version.value != ownerStartingVersion) {
      throw ConcurrentModificationError(owner);
    }

    // Handle one time case where root node represents final char of
    // prefix and should not be explored
    if (prefixFrame != null) {
      currentKey = prefixFrame.prefix;
      currentValue = prefixFrame.node.values;

      prefixFrame = null;
      return true;
    }

    while (stack.isNotEmpty) {
      final context = stack.pop();

      // push right and mid for later consumption
      if (context.node.right != null) {
        pushAllLeft(_StackFrame<V>(context.node.right, context.prefix));
      }

      if (context.node.mid != null) {
        pushAllLeft(_StackFrame<V>(context.node.mid,
            context.prefix + String.fromCharCode(context.node.codeUnit)));
      }

      if (context.node.isKeyEnd) {
        currentKey =
            context.prefix + String.fromCharCode(context.node.codeUnit);

        currentValue = context.node.values;

        return true;
      }
    }
    return false;
  }

  void pushAllLeft(_StackFrame<V> context) {
    var _context = context;
    // add frame to stack and drill down the left
    stack.push(_context);
    while (_context.node.left != null) {
      _context = _StackFrame<V>(_context.node.left, _context.prefix);
      stack.push(_context);
    }
  }
}

/// Iterate through keys
class _KeyIterator<V> extends _InOrderIteratorBase<V>
    implements Iterator<String> {
  /// Construct new [_KeyIterator]
  _KeyIterator(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  String get current => currentKey;
}

/// Iterate through values
class _ValuesIterator<V> extends _InOrderIteratorBase<V>
    implements Iterator<Iterable<V>> {
  /// Construct new [_KeyIterator]
  _ValuesIterator(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  bool moveNext() {
    var next = super.moveNext();
    // skip empty value lists
    while (next && currentValue.isEmpty) {
      next = super.moveNext();
    }
    return next;
  }

  @override
  Iterable<V> get current => currentValue;
}

/// Iterate through keys
class _MapEntryIterator<V> extends _InOrderIteratorBase<V>
    implements Iterator<MapEntry<String, Iterable<V>>> {
  /// Construct new [_KeyIterator]
  _MapEntryIterator(_ImmutableTernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  MapEntry<String, Iterable<V>> get current =>
      MapEntry<String, Iterable<V>>(currentKey, currentValue);
}
