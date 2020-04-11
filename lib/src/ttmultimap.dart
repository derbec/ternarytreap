import 'prefixeditdistanceiterable.dart';
import 'key_mapping.dart';
/// A self balancing Ternary search tree Multimap
///
/// # Usage
///
/// ## Most basic case
///
/// Insert keys and later return those starting with a given prefix.
///
/// ```dart
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
/// [TTMultiMapSet] and [TTMultiMapList] are multimaps:
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
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  void operator []=(String key, Iterable<V> values);

  /// Insert a [key] and optional [value].
  ///
  /// [key] is a string to be transformed via [KeyMapping] into a key.
  ///
  /// An optional [value] may be supplied to associate with this key.
  ///
  /// Return true if (key, value) pair did not already exist, false otherwise.
  ///
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  bool add(String key, [V value]);

  /// Adds all associations contained in [entries] to this [TTMultiMap].
  ///
  /// Is equivilent to calling [addValues] for each entry.
  ///
  /// [mapKey] is applied to all incoming keys so
  /// keys may be altered during copying from [entries].
  ///
  /// Throws [ArgumentError] if [mapKey]`(key)` is empty for any
  /// incoming keys of [entries].
  void addEntries(Iterable<MapEntry<String, Iterable<V>>> entries);

  /// Call [add](key) for each key in [keys].
  void addKeys(Iterable<String> keys);

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

  /// Returns [Iterable] collection of each key of the [TTMultiMap]
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
  PrefixEditDistanceIterable<String> keysByPrefix(String prefix,
      {int maxPrefixEditDistance = 0});

  /// The number of keys in the [TTMultiMap].
  int get length;

  /// Prioritise [key] such that future prefix searches will return [key]
  /// closer to beginning of search result. Subsequent calls will increase this
  /// effect.
  void likeKey(String key);

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
  Iterable<V> removeAll(String key);

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

  /// Return a single suggested prefix expansion for [key].
  String suggestKey(String key);

  /// Generate a string representation of this [TTMultiMap].
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
  PrefixEditDistanceIterable<V> valuesByKeyPrefix(String prefix,
      {int maxPrefixEditDistance = 0});
}