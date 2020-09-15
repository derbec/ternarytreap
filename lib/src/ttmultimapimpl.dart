import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';

import 'global.dart';
import 'iterator.dart';
import 'key_mapping.dart';
import 'node.dart';
import 'pool.dart';
import 'ttiterable.dart';
import 'ttmultimap.dart';
import 'utility.dart';

const _JSONKEY_NODES = 'a';
const _JSONKEY_KEYMAPPING = 'b';

/// The result of an add operation.
class _AddResult<V> {
  /// [rootNode] is the potentially new root node of treap after add.
  /// [targetNode] is the node created or affected by the add.
  /// [newKey] is true if a new key was created by this add.
  /// [valueChanged] is true if value of key is changed by this add.
  _AddResult(this.rootNode, this.targetNode, this.newKey, this.valueChanged)
      : assert(!identical(rootNode, null)),
        assert(!identical(targetNode, null));
  final Node<V> rootNode;
  final Node<V> targetNode;
  final bool newKey;
  final bool valueChanged;
}

/// Defines equality between [TTMultiMap] instance.
class _TTMultiMapEquality<V> {
  final _keyEquality = IterableEquality<String>();
  final _hasher = ListEquality<int>();

  bool equals(TTMultiMap<V> e1, TTMultiMap<V> e2,
      Equality<Iterable<V>> valueEquality, bool strict) {
    ArgumentError.checkNotNull(strict);
    if (identical(e1, e2)) {
      return true;
    }

    if (e1 is _TTMultiMapImpl<V> && e2 is _TTMultiMapImpl<V>) {
      if (e1.length != e2.length) {
        // must be same length
        return false;
      }

      if (e1.isEmpty) {
        // two empty collections are the same
        return true;
      }

      if (strict) {
        // Compare everything exactly
        return nodeEquality(e1._root, e2._root);
      } else {
        // Only compare keys, values and node marking
        final keyItr1 = e1.keys.iterator as InOrderKeyIterator<V>;
        final keyItr2 = e2.keys.iterator as InOrderKeyIterator<V>;
        while (keyItr1.moveNext() && keyItr2.moveNext()) {
          if (keyItr1.currentKey != keyItr2.currentKey ||
              keyItr1.isMarked != keyItr2.isMarked ||
              !valueEquality.equals(
                  keyItr1.currentValue, keyItr2.currentValue)) {
            return false;
          }
        }
        return true;
      }
    }

    return false;
  }

  int hash(TTMultiMap<V> e, Equality<Iterable<V>> valueEquality) =>
      identical(e, null)
          ? null.hashCode
          : _hasher
              .hash([_keyEquality.hash(e.keys), valueEquality.hash(e.values)]);
}

/// An equality between [TTMultiMapSetEquality] instances.
class TTMultiMapSetEquality<V> implements Equality<TTMultiMapSet<V>> {
  final _ttMultiMapEquality = _TTMultiMapEquality<V>();
  final _valueEquality = UnorderedIterableEquality<V>();

  /// If [strict] is true then compares exact structure.
  /// If [strict] is false then compares keys, values and node marking.
  ///
  /// [strict] == 'false' should suffice for almost all cases.
  @override
  bool equals(TTMultiMapSet<V> e1, TTMultiMapSet<V> e2,
          {bool strict = false}) =>
      _ttMultiMapEquality.equals(e1, e2, _valueEquality, strict);

  @override
  int hash(TTMultiMapSet<V> e) => _ttMultiMapEquality.hash(e, _valueEquality);

  @override
  bool isValidKey(Object o) => o is TTMultiMapSet<V>;
}

/// An equality between [TTMultiMapListEquality] instances.
class TTMultiMapListEquality<V> implements Equality<TTMultiMapList<V>> {
  final _ttMultiMapEquality = _TTMultiMapEquality<V>();
  final _valueEquality = IterableEquality<V>();

  /// If [strict] is true then compares exact structure.
  /// If [strict] is false then compares keys, values and node marking.
  ///
  /// [strict] == 'false' should suffice for almost all cases.
  @override
  bool equals(TTMultiMapList<V> e1, TTMultiMapList<V> e2,
          {bool strict = false}) =>
      _ttMultiMapEquality.equals(e1, e2, _valueEquality, strict);

  @override
  int hash(TTMultiMapList<V> e) => _ttMultiMapEquality.hash(e, _valueEquality);

  @override
  bool isValidKey(Object o) => o is TTMultiMapSet<V>;
}

/// Return a [TTMultiMap] that stores values in a [Set]
///
/// Returned [TTMultiMap] is a function:
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
class TTMultiMapSet<V> extends _TTMultiMapImpl<V> implements TTMultiMap<V> {
  /// Construct a new [TTMultiMapSet] with an optional [keyMapping]
  TTMultiMapSet({KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping ?? identity);

  /// Create a [TTMultiMapSet] from a [TTMultiMap].
  ///
  /// Values are stored as Set collections, thus if [other] stores values in list
  /// then result will not be an exact copy.
  /// Create a [TTMultiMapList] from a [TTMultiMap].
  TTMultiMapSet.from(TTMultiMap<V> other)
      : super.from(other as _TTMultiMapImpl<V>) {
    final impl = (other as _TTMultiMapImpl<V>);
    if (!identical(impl._root, null)) {
      _root = NodeSet.from(impl._root, null, _runePool);
    }
  }

  /// Create a [TTMultiMapSet] from Iterables of [keys] and [values].
  ///
  /// Throws Error if [keys] and [values] are not of same length.
  ///
  /// Throws Error if any key in [keys] is empty after [KeyMapping] applied.
  TTMultiMapSet.fromIterables(Iterable<String> keys, Iterable<V> values,
      {KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping ?? identity) {
    _setFromIterables(keys, values);
  }

  /// Construct a [TTMultiMapSet] from the given Json
  TTMultiMapSet.fromJson(Map<String, dynamic> json,
      {KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping ?? identity) {
    _setFromJson(
        (List<dynamic> json, Random priorityGenerator, Node<V> parent,
                HashSet<RunePoolEntry> _runePool) =>
            NodeSet.fromJson(json, priorityGenerator, parent, _runePool),
        json);
  }

  /// Create a [TTMultiMapSet] from a [Map].
  TTMultiMapSet.fromMap(Map<String, Iterable<V>> map,
      {KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping ?? identity) {
    for (final key in map.keys) {
      addValues(key, map[key]);
    }
  }

  @override
  Set<V> operator [](String key) => super[key] as Set<V>;

  @override
  Map<String, Set<V>> asMap() => {
        for (final key in keys) key: this[key],
      };

  @override
  Iterable<MapEntry<String, Set<V>>> get entries =>
      InOrderMapEntryIterableSet<V>(_root, _version);

  @override
  TTIterable<MapEntry<String, Set<V>>> entriesByKeyPrefix(String prefix,
      {int maxPrefixEditDistance = 0}) {
    final key = _mapKey(prefix);
    return (key.isEmpty)
        ? InOrderMapEntryIterableSet<V>(null, _version)
        : InOrderMapEntryIterableSet<V>(_root, _version,
            prefixSearchResult: identical(_root, null)
                ? null
                : _root.getClosestPrefixDescendant(key.runes.toList()),
            maxPrefixEditDistance: maxPrefixEditDistance);
  }

  @override
  void forEachKey(void Function(String key, Set<V> values) f) {
    ArgumentError.checkNotNull(f, 'f');
    final keyItr = keys.iterator as InOrderKeyIterator<V>;
    while (keyItr.moveNext()) {
      f(keyItr.currentKey, keyItr.currentValue as Set<V>);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Set<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    ArgumentError.checkNotNull(f, 'f');
    final itr =
        keysByPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderKeyIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue as Set<V>);
    }
  }

  @override
  Set<V> removeValues(String key) => super.removeValues(key) as Set<V>;

  @override
  Set<V> removeKey(String key) => super.removeKey(key) as Set<V>;
}

/// Return a [TTMultiMap] that stores values in a [List]
///
/// Returned [TTMultiMap] is a function:
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
class TTMultiMapList<V> extends _TTMultiMapImpl<V> implements TTMultiMap<V> {
  /// Construct a new [TTMultiMapList] with an optional [keyMapping]
  TTMultiMapList({KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    final HashSet<RunePoolEntry> _runePool) =>
                NodeList<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping);

  /// Create a [TTMultiMapList] from a [TTMultiMap].
  TTMultiMapList.from(TTMultiMap<V> other)
      : super.from(other as _TTMultiMapImpl<V>) {
    final impl = (other as _TTMultiMapImpl<V>);
    if (!identical(impl._root, null)) {
      _root = NodeList.from(impl._root, null, _runePool);
    }
  }

  /// Create a [TTMultiMapList] from Iterables of [keys] and [values].
  ///
  /// Throws Error if [keys] and [values] are not of same length.
  ///
  /// Throws Error if any key in [keys] is empty after [KeyMapping] applied.
  TTMultiMapList.fromIterables(Iterable<String> keys, Iterable<V> values,
      {KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeList<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    _setFromIterables(keys, values);
  }

  /// Create a [TTMultiMapList] from a [Map].
  TTMultiMapList.fromMap(Map<String, Iterable<V>> map,
      {KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeList<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    for (final key in map.keys) {
      addValues(key, map[key]);
    }
  }

  /// Construct a NodeList from the given Json
  TTMultiMapList.fromJson(Map<String, dynamic> json,
      {KeyMapping keyMapping = identity})
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeList<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    _setFromJson(
        (List<dynamic> json, Random priorityGenerator, Node<V> parent,
                HashSet<RunePoolEntry> _runePool) =>
            NodeList.fromJson(json, priorityGenerator, parent, _runePool),
        json);
  }

  @override
  List<V> operator [](String key) => super[key] as List<V>;

  @override
  Map<String, List<V>> asMap() => {
        for (final key in keys) key: this[key],
      };

  @override
  Iterable<MapEntry<String, List<V>>> get entries =>
      InOrderMapEntryIterableList<V>(_root, _version);

  @override
  TTIterable<MapEntry<String, List<V>>> entriesByKeyPrefix(String prefix,
      {int maxPrefixEditDistance = 0}) {
    final key = _mapKey(prefix);
    return (key.isEmpty)
        ? InOrderMapEntryIterableList<V>(null, _version)
        : InOrderMapEntryIterableList<V>(_root, _version,
            prefixSearchResult: identical(_root, null)
                ? null
                : _root.getClosestPrefixDescendant(key.runes.toList()),
            maxPrefixEditDistance: maxPrefixEditDistance);
  }

  @override
  void forEachKey(void Function(String key, List<V> values) f) {
    ArgumentError.checkNotNull(f, 'f');
    final keyItr = keys.iterator as InOrderKeyIterator<V>;
    while (keyItr.moveNext()) {
      f(keyItr.currentKey, keyItr.currentValue as List<V>);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, List<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    ArgumentError.checkNotNull(f, 'f');
    final itr =
        keysByPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderKeyIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue as List<V>);
    }
  }

  @override
  List<V> removeValues(String key) => super.removeValues(key) as List<V>;

  @override
  List<V> removeKey(String key) => super.removeKey(key) as List<V>;
}

/// TernaryTreap implementation
class _TTMultiMapImpl<V> implements TTMultiMap<V> {
  /// Constructs a new [TTMultiMap].
  ///
  /// The [keyMapping] argument supplies an optional instance of
  /// [KeyMapping] to be applied to all keys processed by this [TTMultiMap].
  _TTMultiMapImpl(this._nodeFactory, KeyMapping keyMapping)
      : _keyMapping = keyMapping ?? identity,
        _version = ByRef(Version(0, 0));

  _TTMultiMapImpl.from(_TTMultiMapImpl<V> other)
      : _nodeFactory = other._nodeFactory,
        _keyMapping = other._keyMapping,
        _version = ByRef(Version(0, 0));

  /// The [KeyMapping] in use by this [TTMultiMap]
  ///
  /// See: [KeyMapping].
  final KeyMapping _keyMapping;

  final Random _random = Random();

  /// Factory used to create new nodes
  final NodeFactory<V> _nodeFactory;

  /// Pool runes sequences among nodes to reduce memory usage
  final _runePool = createPool();

  /// Allows tracking of modifications
  /// ByRef so as to allow sharing with Iterators
  final ByRef<Version> _version;

  /// Entry point into [Node] tree.
  Node<V> _root;

  @override
  Iterable<V> operator [](String key) =>
      _root?.getKeyNode(_mapKeyNonEmpty(key))?.values;

  @override
  void operator []=(String key, Iterable<V> values) {
    ArgumentError.checkNotNull(values, 'values');

    final addResult = _add(_root, _mapKeyNonEmpty(key).runes.toList(), null);

    _root = addResult.rootNode;

    addResult.targetNode.setValues(values);

    if (addResult.newKey) {
      _version.value.incKeysVersion();
    }

    _version.value.incValuesVersion();
  }

  @override
  bool add(String key, V value) {
    ArgumentError.checkNotNull(value, 'value');
    final addResult = _add(_root, _mapKeyNonEmpty(key).runes.toList(), value);

    _root = addResult.rootNode;

    // Operation may change keys, values, both, or nothing
    if (addResult.newKey) {
      _version.value.incKeysVersion();
    }
    if (addResult.valueChanged) {
      _version.value.incValuesVersion();
    }

    return addResult.newKey || addResult.valueChanged;
  }

  @override
  void addAll(TTMultiMap<V> other) {
    ArgumentError.checkNotNull(other, 'other');
    final keyItr = other.keys.iterator as InOrderKeyIterator<V>;

    var newKey = false;
    while (keyItr.moveNext()) {
      final key = _mapKey(keyItr.currentKey);
      // Keys from other may not map usefully to key domain of this.
      if (key.isNotEmpty) {
        newKey |= _addIterable(key.runes.toList(), keyItr.currentValue);
      }
    }

    if (newKey) {
      _version.value.incKeysVersion();
    }

    // Lot of work to determine if value change has occured so just assume it has
    _version.value.incValuesVersion();
  }

  @override
  void addEntries(Iterable<MapEntry<String, Iterable<V>>> entries) {
    ArgumentError.checkNotNull(entries, 'entries');
    var newKey = false;
    entries.forEach((final entry) {
      final key = _mapKey(entry.key);
      if (key.isNotEmpty) {
        newKey |= _addIterable(key.runes.toList(), entry.value);
      }
    });

    if (newKey) {
      _version.value.incKeysVersion();
    }

    // Lot of work to determine if value change has occured so just assume it has
    _version.value.incValuesVersion();
  }

  @override
  bool addKey(String key) {
    final addResult = _add(_root, _mapKeyNonEmpty(key).runes.toList(), null);

    _root = addResult.rootNode;

    // Change only occurs if key is new
    if (addResult.newKey) {
      _version.value.incKeysVersion();
    }

    return addResult.newKey;
  }

  @override
  void addKeys(Iterable<String> keys) => keys.forEach((final key) {
        addKey(key);
      });

  @override
  void addValues(String key, Iterable<V> values) {
    ArgumentError.checkNotNull(values, 'values');
    if (_addIterable(_mapKeyNonEmpty(key).runes.toList(), values)) {
      _version.value.incKeysVersion();
    }

    // Lot of work to determine if value change has occured so just assume it has
    _version.value.incValuesVersion();
  }

  @override
  Map<String, Iterable<V>> asMap() => {
        for (final key in keys) key: this[key],
      };

  @override
  void clear() {
    _version.value.incVersions();
    _root = null;
  }

  @override
  bool contains(String key, V value) {
    final keyNode = _root?.getKeyNode(_mapKey(key));

    // Does the key map to anything?
    if (identical(keyNode, null)) {
      return false;
    }

    return keyNode.values.contains(value);
  }

  @override
  bool containsKey(String key) => !identical(this[key], null);

  @override
  bool containsValue(V value) => values.contains(value);

  @override
  Iterable<MapEntry<String, Iterable<V>>> get entries =>
      InOrderMapEntryIterable<V>(_root, _version);

  @override
  TTIterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(String prefix,
      {int maxPrefixEditDistance = 0}) {
    final key = _mapKey(prefix);
    return (key.isEmpty)
        ? InOrderMapEntryIterable<V>(null, _version)
        : InOrderMapEntryIterable<V>(_root, _version,
            prefixSearchResult: identical(_root, null)
                ? null
                : _root.getClosestPrefixDescendant(key.runes.toList()),
            maxPrefixEditDistance: maxPrefixEditDistance);
  }

  @override
  void forEach(void Function(String key, V value) f) {
    ArgumentError.checkNotNull(f, 'f');
    final keyItr = keys.iterator as InOrderKeyIterator<V>;

    while (keyItr.moveNext()) {
      for (final value in keyItr.currentValue) {
        f(keyItr.currentKey, value);
      }
    }
  }

  @override
  void forEachKey(void Function(String key, Iterable<V> values) f) {
    ArgumentError.checkNotNull(f, 'f');
    final keyItr = keys.iterator as InOrderKeyIterator<V>;
    while (keyItr.moveNext()) {
      f(keyItr.currentKey, keyItr.currentValue);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    ArgumentError.checkNotNull(f, 'f');
    final itr =
        keysByPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderKeyIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue);
    }
  }

  @override
  bool get isEmpty => identical(_root, null);

  @override
  bool get isNotEmpty => !identical(_root, null);

  @override
  TTIterable<String> get keys => InOrderKeyIterable<V>(_root, _version);

  @override
  TTIterable<String> keysByPrefix(String prefix,
      {int maxPrefixEditDistance = 0}) {
    final key = _mapKey(prefix);
    return (key.isEmpty)
        ? InOrderKeyIterable<V>(null, _version)
        : InOrderKeyIterable<V>(_root, _version,
            prefixSearchResult: identical(_root, null)
                ? null
                : _root.getClosestPrefixDescendant(key.runes.toList()),
            maxPrefixEditDistance: maxPrefixEditDistance);
  }

  @override
  KeyMapping get keyMapping => _keyMapping;

  @override
  int get length => identical(_root, null) ? 0 : _root.sizeDFSTree;

  @override
  V lookup(String key, V value) =>
      _root?.getKeyNode(_mapKey(key))?.lookupValue(value);

  @override
  bool remove(String key, V value) {
    final keyNode = _root?.getKeyNode(_mapKey(key));

    if (!identical(keyNode, null) && keyNode.removeValue(value)) {
      _version.value.incVersions();
      return true;
    }

    return false;
  }

  @override
  Iterable<V> removeKey(String key) {
    if (identical(_root, null)) {
      return null;
    }

    final mappedKey = _mapKey(key);
    if (mappedKey.isEmpty) {
      return null;
    }

    final values = _remove(_root, mappedKey.runes.toList());
    if (identical(values, null)) {
      return null;
    }

    _version.value.incVersions();
    return values;
  }

  @override
  Iterable<V> removeValues(String key) {
    final keyNode = _root?.getKeyNode(_mapKey(key));

    if (identical(keyNode, null)) {
      return null;
    }

    _version.value.incVersions();
    return keyNode.removeValues();
  }

  @override
  int sizeOf([int valueSizeInBytes = 0]) {
    if (identical(_root, null)) {
      return 0;
    }

    // String pool size
    var poolSize = sizeOfPool(_runePool);

    // get tree size
    return (4 * SIZE_OF_REF) + poolSize + _sizeOfTree(_root, valueSizeInBytes);
  }

  int _sizeOfTree(Node<V> p, int valueSizeInBytes) {
    if (identical(p, null)) {
      return 0;
    }

    final sizeThisNode = ((2 * SIZE_OF_INT) + (6 * SIZE_OF_REF)) +
        (p.isKeyEnd ? (p.values.length * (SIZE_OF_REF + valueSizeInBytes)) : 0);

    return sizeThisNode +
        _sizeOfTree(p.left, valueSizeInBytes) +
        _sizeOfTree(p.mid, valueSizeInBytes) +
        _sizeOfTree(p.right, valueSizeInBytes);
  }

  @override
  String toString({String paddingChar = '-'}) {
    final buffer = StringBuffer();
    _toString(_root, paddingChar, '', buffer);
    return buffer.toString();
  }

  void _toString(
      Node<V> node, String paddingChar, String padding, StringBuffer buffer) {
    if (identical(node, null)) {
      return;
    }
    buffer.write(padding + String.fromCharCodes(node.runes));
    if (node.isKeyEnd) {
      buffer.write(node.values.toString());
    }
    buffer.writeln();
    _toString(node.mid, paddingChar, padding + paddingChar, buffer);
    _toString(node.left, paddingChar, padding + paddingChar, buffer);
    _toString(node.right, paddingChar, padding + paddingChar, buffer);
  }

  @override
  Map<String, dynamic> toJson(
      {bool includeValues = true, dynamic Function(V value) valueToEncodable}) {
    ArgumentError.checkNotNull(includeValues, 'includeValues');

    // Default value transform
    valueToEncodable ??= (V e) => e;

    final map = <String, dynamic>{};
    final nodes = <List<dynamic>>[];
    _toJson(_root, nodes, includeValues, valueToEncodable);
    map[_JSONKEY_NODES] = nodes;
    map[_JSONKEY_KEYMAPPING] = keyMapping(null);
    return map;
  }

  void _toJson(Node<V> node, List<dynamic> nodes, bool includeValues,
      dynamic Function(V value) toEncodable) {
    if (identical(node, null)) {
      // Empty list as placeholder for null node
      nodes.add([]);
      return;
    }
    nodes.add(node.toJson(includeValues, toEncodable));

    _toJson(node.left, nodes, includeValues, toEncodable);
    _toJson(node.mid, nodes, includeValues, toEncodable);
    _toJson(node.right, nodes, includeValues, toEncodable);
  }

  @override
  Iterable<V> get values => InOrderValuesIterable<V>(_root, _version);

  @override
  TTIterable<V> valuesByKeyPrefix(String prefix,
      {int maxPrefixEditDistance = 0}) {
    final key = _mapKey(prefix);
    return (key.isEmpty)
        ? InOrderValuesIterable<V>(null, _version)
        : InOrderValuesIterable<V>(_root, _version,
            prefixSearchResult: identical(_root, null)
                ? null
                : _root.getClosestPrefixDescendant(key.runes.toList()),
            maxPrefixEditDistance: maxPrefixEditDistance);
  }

  /// Add or update node for [keyRunesNotEmpty] starting from [searchRoot] and attach [value].
  ///
  /// Assumes [keyRunesNotEmpty] is not empty.
  ///
  /// Return a [_AddResult] with:
  /// * [_AddResult.rootNode]: New root node which may not be the same as [searchRoot] due
  /// to possible rotation.
  /// * [_AddResult.addedNode]: The new or existing end node corresponding to [keyRunesNotEmpty]
  /// * [_AddResult.newKey]: True if [keyRunesNotEmpty] was new to this [TernaryTreap].
  ///
  ///_AddResult(this.rootNode, this.addedNode, this.newKey);
  /// Iterative version: More complicated than recursive
  /// but 4 times as fast.
  _AddResult<V> _add(Node<V> rootNode, List<int> keyRunesNotEmpty, V value) {
    var keyRuneIdx = 0;
    var _rootNode = rootNode;

    // Create new root node if needed
    if (identical(_rootNode, null)) {
      _rootNode = _nodeFactory(keyRunesNotEmpty, _random, null, _runePool);
      keyRuneIdx = keyRunesNotEmpty.length;
    }

    var currentNode = _rootNode;

    // Create a path down to key node, rotating as we go.
    while (keyRuneIdx < keyRunesNotEmpty.length) {
      final keyRune = keyRunesNotEmpty[keyRuneIdx];
      if (keyRune < currentNode.runes[0]) {
        // create left path as end node if able
        if (identical(currentNode.left, null)) {
          currentNode.left = _nodeFactory(
              keyRunesNotEmpty.getRange(keyRuneIdx, keyRunesNotEmpty.length),
              _random,
              currentNode,
              _runePool);

          keyRuneIdx = keyRunesNotEmpty.length;
        }
        currentNode = currentNode.left;
      } else if (keyRune > currentNode.runes[0]) {
        // Create right path if needed
        if (identical(currentNode.right, null)) {
          currentNode.right = _nodeFactory(
              keyRunesNotEmpty.getRange(keyRuneIdx, keyRunesNotEmpty.length),
              _random,
              currentNode,
              _runePool);
          keyRuneIdx = keyRunesNotEmpty.length;
        }
        currentNode = currentNode.right;
      } else {
        // Move onto next key rune
        keyRuneIdx++;

        // We know that the first rune matches now try and match
        // the rest
        var nodeCodeIdx = 1;

        // Match node runes as far as possible
        while (keyRuneIdx < keyRunesNotEmpty.length &&
            nodeCodeIdx < currentNode.runes.length &&
            currentNode.runes[nodeCodeIdx] == keyRunesNotEmpty[keyRuneIdx]) {
          nodeCodeIdx++;
          keyRuneIdx++;
        }

        // If key was not consumed entirely
        if (keyRuneIdx < keyRunesNotEmpty.length) {
          if (nodeCodeIdx < currentNode.runes.length) {
            // if neither node or key were consumed then split and
            // continue on from new child
            _split(currentNode, nodeCodeIdx, _runePool);
          } else {
            // If key was not consumed but node was then grow down
            // and continue from new child
            if (identical(currentNode.mid, null)) {
              currentNode.mid = _nodeFactory(
                  keyRunesNotEmpty.getRange(
                      keyRuneIdx, keyRunesNotEmpty.length),
                  _random,
                  currentNode,
                  _runePool);
              keyRuneIdx = keyRunesNotEmpty.length;
            }
          }
        } else {
          // Key was consumed entirely
          // if both key and node were consumed this is the target
          if (nodeCodeIdx == currentNode.runes.length) {
            break;
          }
          // if key was consumed but node was not then split and
          // return current as target
          if (nodeCodeIdx < currentNode.runes.length) {
            _split(currentNode, nodeCodeIdx, _runePool);
            break;
          }
        }

        currentNode = currentNode.mid;
      }
    }

    final newKey = currentNode.setAsKeyEnd();
    if (newKey) {
      // If new node was inserted reverse back up to root node

      var reverseNode = currentNode;
      while (!identical(reverseNode, _rootNode.parent)) {
        // Merge any ophaned mid children on our way back
        reverseNode.mergeMid(_runePool);

        // Rebalance
        reverseNode.rotateChildren();

        reverseNode.updateDescendantCounts();

        reverseNode = reverseNode.parent;
      }
    }

    return _AddResult<V>(_rootNode, currentNode, newKey,
        identical(value, null) ? false : currentNode.addValue(value));
  }

  /// Add Iterable of values to key.
  ///
  /// Equivilent to [_add]`(`value`)` for all [values].
  ///
  /// Returns `true` if new key was created.
  bool _addIterable(List<int> keyRunes, Iterable<V> values) {
    // map key alone for case where no data is associated with key
    final addResult = _add(_root, keyRunes, null);
    _root = addResult.rootNode;

    addResult.targetNode.addValues(values);
    return addResult.newKey;
  }

  /// Map [key] and return empty Iterable if result is empty
  String _mapKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value('key is empty');
    }
    final mappedKey = keyMapping(key);
    if (mappedKey.isEmpty) {
      Iterable<String>.empty();
    }
    return mappedKey;
  }

  /// Map [key] and throw Error if result empty.
  String _mapKeyNonEmpty(String key) {
    final mappedKey = _mapKey(key);
    if (mappedKey.isEmpty) {
      throw ArgumentError.value(key, 'Key mapped to empty string');
    }
    return mappedKey;
  }

  /// Delete node for [keyRunes] starting from [rootNode] and return values
  /// or null if key does not exist.
  Iterable<V> _remove(Node<V> rootNode, List<int> keyRunes) {
    assert(!identical(rootNode, null));

    var keyCodeIdx = 0;

    var currentNode = rootNode;

    // Explore path down to key node
    while (keyCodeIdx < keyRunes.length) {
      if (identical(currentNode, null)) {
        // Key doesnt exist
        return null;
      }

      final keyRune = keyRunes[keyCodeIdx];
      if (keyRune < currentNode.runes[0]) {
        currentNode = currentNode.left;
      } else if (keyRune > currentNode.runes[0]) {
        currentNode = currentNode.right;
      } else {
        // Move onto next key rune
        keyCodeIdx++;

        // We know that the first rune matches now try and match
        // the rest
        var nodeCodeIdx = 1;

        // Match node runes as far as possible
        while (keyCodeIdx < keyRunes.length &&
            nodeCodeIdx < currentNode.runes.length) {
          if (currentNode.runes[nodeCodeIdx] != keyRunes[keyCodeIdx]) {
            return null;
          }
          nodeCodeIdx++;
          keyCodeIdx++;
        }

        // If both key and node are exhausted then this is a potential winner
        if (keyCodeIdx == keyRunes.length &&
            nodeCodeIdx == currentNode.runes.length) {
          break;
        }

        // If node is exhausted but key still has runes then explore mid
        if (keyCodeIdx < keyRunes.length &&
            nodeCodeIdx == currentNode.runes.length) {
          currentNode = currentNode.mid;
          continue;
        }

        return null;
      }
    }

    Iterable<V> values;

    if (currentNode.isKeyEnd) {
      values = currentNode.values;

      // If node has no key descendants we can eliminate it and all its children!
      if (!identical(currentNode, _root) &&
          currentNode.numDFSDescendants == 0) {
        // Delete from parent
        currentNode.parent.deleteChild(currentNode, _runePool);
      } else {
        // Otherwise sinply remove its key end and marked status
        currentNode.clearKeyEnd();
      }

      // reverse back up to root node to update node counts
      while (!identical(currentNode, rootNode.parent)) {
        // Merge any ophaned mid children on our way back
        currentNode.mergeMid(_runePool);

        // Rebalance
        currentNode.rotateChildren();

        currentNode.updateDescendantCounts();

        currentNode = currentNode.parent;
      }
    }

    if (_root.sizeDFSTree == 0) {
      /// There are no end nodes left in tree so delete root
      _root.destroy(_runePool);
      _root = null;
      assert(_runePool.isEmpty);
    }
    return values;
  }

  /// Inserts new split child under [node].mid.
  ///
  /// Split node at [runeIdx] such that:
  /// * node.runes becomes node.runes[0...runeIdx-1]
  /// * Created child [Node] has remainder runes
  /// * Created child inherits node mid child.
  /// * If node is an end node then child is instead.
  /// * Created child [Node] is attached to node.mid.
  void _split(
      Node<V> node, int runeIdx, final HashSet<RunePoolEntry> runePool) {
    if (node.runes.length < 2) {
      // Nothing to split
      throw ArgumentError();
    }

    if (runeIdx >= node.runes.length) {
      // Both parent and child must have at least 1 rune
      throw ArgumentError(runeIdx);
    }

    final child = _nodeFactory(node.runes.getRange(runeIdx, node.runes.length),
        _random, node, runePool);

    child.mid = node.mid;

    // Update child counts and grandchildren if any
    if (!identical(child.mid, null)) {
      child.numDFSDescendants = child.mid.sizeDFSTree;
      child.mid.parent = child;
    }

    node.setRunes(node.runes.getRange(0, runeIdx), runePool);

    // Insert child under node
    node.mid = child;

    // If node was a keyend then it transfers this to child
    if (node.isKeyEnd) {
      // Child inherits values and keyend/marked status
      child.takeKeyEndMarked(node);

      // and thus gains a key descendant
      node.numDFSDescendants++;
    }
  }

  void _setFromIterables(Iterable<String> keys, Iterable<V> values) {
    ArgumentError.checkNotNull(keys, 'keys');
    ArgumentError.checkNotNull(values, 'values');
    if (keys.length != values.length) {
      throw ArgumentError('keys.length != values.length');
    }
    final keyItr = keys.iterator;
    final valItr = values.iterator;
    while (keyItr.moveNext() && valItr.moveNext()) {
      add(keyItr.current, valItr.current);
    }
  }

  void _setFromJson(
      JsonNodeFactory<V> jsonNodeFactory, Map<String, dynamic> json) {
    // Insist on same keymapping
    final jsonKeymapping = json[_JSONKEY_KEYMAPPING];
    final expectedKeymapping = keyMapping(null);
    if (jsonKeymapping != expectedKeymapping) {
      throw ArgumentError.value(json,
          'Expected keymapping:$expectedKeymapping, got keymapping:$jsonKeymapping');
    }

    final nodes = json[_JSONKEY_NODES];

    if (nodes is List<dynamic>) {
      final nodeIdx = ByRef<int>(0);
      _root = _nodeTreeFromJson(jsonNodeFactory, nodes, nodeIdx, null);
      if (nodeIdx.value != nodes.length) {
        throw ArgumentError.value(json,
            'nodeIdx.value (${nodeIdx.value}) != nodes.length (${nodes.length})');
      }
    } else {
      throw ArgumentError.value(json);
    }
  }

  Node<V> _nodeTreeFromJson(JsonNodeFactory<V> jsonNodeFactory,
      List<dynamic> nodesJson, ByRef<int> nodesIdx, Node<V> parent) {
    if (nodesIdx.value < nodesJson.length) {
      parent = jsonNodeFactory(nodesJson[nodesIdx.value++] as List<dynamic>,
          _random, parent, _runePool);
      if (!identical(parent, null)) {
        parent
          ..left =
              _nodeTreeFromJson(jsonNodeFactory, nodesJson, nodesIdx, parent)
          ..adjustPrioritiesForChild(parent.left)
          ..mid =
              _nodeTreeFromJson(jsonNodeFactory, nodesJson, nodesIdx, parent)
          ..adjustPrioritiesForChild(parent.mid)
          ..right =
              _nodeTreeFromJson(jsonNodeFactory, nodesJson, nodesIdx, parent)
          ..adjustPrioritiesForChild(parent.right)
          ..updateDescendantCounts();
        return parent;
      }
    }
    return null;
  }
}
