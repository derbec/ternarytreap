import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:ternarytreap/ternarytreap.dart';

import 'key_mapping.dart';
import 'pool.dart';
import 'prefixeditdistanceiterable.dart';
import 'ttmultimap.dart';
import 'node.dart';
import 'iterator.dart';
import 'utility.dart';
import 'global.dart';

/// (2^53)-1 because javascript
const int _MAX_SAFE_INTEGER = 9007199254740991;
const _JSONKEY_NODES = 'nodes';
const _JSONKEY_KEYMAPPING = 'keymapping';

/// The result of an add operation.
class _AddResult<V> {
  /// [rootNode] is the potentially new root node of treap after add.
  /// [targetNode] is the node created or affected by the add.
  /// [newKeyValue] is true if a new key or value was created by this add.
  _AddResult(this.rootNode, this.targetNode, this.newKeyValue)
      : assert(!identical(rootNode, null)),
        assert(!identical(targetNode, null));
  final Node<V> rootNode;
  final Node<V> targetNode;
  final bool newKeyValue;
}

/// An equality over TTMultiMaps
///
/// Compares keys, values and structure.
class TTMultiMapEquality<V> implements Equality<TTMultiMap<V>> {
  final _keyEquality = IterableEquality<String>();
  final _valueEquality = IterableEquality<V>();
  final _hasher = ListEquality<int>();
  @override
  bool equals(TTMultiMap<V> e1, TTMultiMap<V> e2) {
    if (identical(e1, e2)) {
      return true;
    }

    if (e1 is _TTMultiMapImpl<V> && e2 is _TTMultiMapImpl<V>) {
      if (e1.isEmpty && e2.isEmpty) {
        // two empty collections are the same
        return true;
      }

      if (e1.length != e2.length) {
        return false;
      }
      if (!identical(e1._root, null)) {
        // To support [lastMarkedKeyForPrefix] structure needs to be the same
        return nodeEquality(e1._root, e2._root);
      }
    }

    return false;
  }

  @override
  int hash(TTMultiMap<V> e) => identical(e, null)
      ? null.hashCode
      : _hasher
          .hash([_keyEquality.hash(e.keys), _valueEquality.hash(e.values)]);

  @override
  bool isValidKey(Object o) => o is TTMultiMap<V>;
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
  TTMultiMapSet([KeyMapping keyMapping])
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping);

  /// Create a [TTMultiMapSet] from a [TTMultiMap].
  ///
  /// Values are stored as Set collections, thus if [other] stores values in list
  /// then result will not be an exact copy.
  ///
  /// ** CURRENTLY SLOW AS PIGGYBACKS ON JSON ROUTINE **
  TTMultiMapSet.from(TTMultiMap<V> other, [KeyMapping keyMapping])
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    ArgumentError.checkNotNull(other, 'other');
    _setFromJson(
        (List<dynamic> json, Random priorityGenerator, Node<V> parent,
                HashSet<RunePoolEntry> _runePool) =>
            NodeSet.fromJson(json, priorityGenerator, parent, _runePool),
        other.toJson());
  }

  /// Create a [TTMultiMapSet] from a [Map].
  TTMultiMapSet.fromMap(Map<String, Iterable<V>> map, [KeyMapping keyMapping])
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    for (final key in map.keys) {
      addValues(key, map[key]);
    }
  }

  /// Construct a [TTMultiMapSet] from the given Json
  TTMultiMapSet.fromJson(Map<String, dynamic> json, [KeyMapping keyMapping])
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeSet<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    _setFromJson(
        (List<dynamic> json, Random priorityGenerator, Node<V> parent,
                HashSet<RunePoolEntry> _runePool) =>
            NodeSet.fromJson(json, priorityGenerator, parent, _runePool),
        json);
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
  PrefixEditDistanceIterable<MapEntry<String, Set<V>>> entriesByKeyPrefix(
          String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderMapEntryIterableSet<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).runes.toList(),
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  void forEachKey(void Function(String key, Set<V> values) f) {
    ArgumentError.checkNotNull(f, 'f');
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue as Set<V>);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Set<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    ArgumentError.checkNotNull(f, 'f');
    final itr =
        entriesByKeyPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderMapEntryIterator<V>;

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
  TTMultiMapList([KeyMapping keyMapping])
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    final HashSet<RunePoolEntry> _runePool) =>
                NodeList<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping);

  /// Create a [TTMultiMapList] from a [TTMultiMap].
  ///
  /// Values are stored as List collections, thus if [other] stores values in list
  /// then result will not be an exact copy.
  TTMultiMapList.from(TTMultiMap<V> other, [KeyMapping keyMapping])
      : super(
            (Iterable<int> runes, Random priorityGenerator, Node<V> parent,
                    HashSet<RunePoolEntry> _runePool) =>
                NodeList<V>(runes, priorityGenerator, parent, _runePool),
            keyMapping) {
    ArgumentError.checkNotNull(other, 'other');
    _setFromJson(
        (List<dynamic> json, Random priorityGenerator, Node<V> parent,
                HashSet<RunePoolEntry> _runePool) =>
            NodeList.fromJson(json, priorityGenerator, parent, _runePool),
        other.toJson());
  }

  /// Create a [TTMultiMapList] from a [Map].
  TTMultiMapList.fromMap(Map<String, Iterable<V>> map, [KeyMapping keyMapping])
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
  TTMultiMapList.fromJson(Map<String, dynamic> json, [KeyMapping keyMapping])
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
  PrefixEditDistanceIterable<MapEntry<String, List<V>>> entriesByKeyPrefix(
          String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderMapEntryIterableList<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).runes.toList(),
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  void forEachKey(void Function(String key, List<V> values) f) {
    ArgumentError.checkNotNull(f, 'f');
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue as List<V>);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, List<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    ArgumentError.checkNotNull(f, 'f');
    final itr =
        entriesByKeyPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderMapEntryIterator<V>;

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
        _version = ByRef(0),
        _root = null;

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
  final ByRef<int> _version;

  /// Entry point into [Node] tree.
  Node<V> _root;

  @override
  Iterable<V> operator [](String key) =>
      _root?.getKeyNode(_mapKeyErrorOnEmpty(key))?.values;

  @override
  void operator []=(String key, Iterable<V> values) {
    ArgumentError.checkNotNull(values, 'values');
    final addResult =
        _add(_root, _mapKeyErrorOnEmpty(key).runes.toList(), null);

    _root = addResult.rootNode;

    addResult.targetNode.setValues(values);

    _incVersion();
  }

  @override
  bool add(String key, V value) {
    ArgumentError.checkNotNull(value, 'value');
    final addResult =
        _add(_root, _mapKeyErrorOnEmpty(key).runes.toList(), value);

    _root = addResult.rootNode;

    _incVersion();

    return addResult.newKeyValue;
  }

  @override
  void addAll(TTMultiMap<V> other) {
    ArgumentError.checkNotNull(other, 'other');
    final entryItr = other.entries.iterator as InOrderMapEntryIterator<V>;

    while (entryItr.moveNext()) {
      _addIterable(_mapKeyErrorOnEmpty(entryItr.currentKey).runes.toList(),
          entryItr.currentValue);
    }

    _incVersion();
  }

  @override
  void addEntries(Iterable<MapEntry<String, Iterable<V>>> entries) {
    ArgumentError.checkNotNull(entries, 'entries');
    entries.forEach((final entry) {
      _addIterable(_mapKeyErrorOnEmpty(entry.key).runes.toList(), entry.value);
    });

    _incVersion();
  }

  @override
  bool addKey(String key) {
    final addResult =
        _add(_root, _mapKeyErrorOnEmpty(key).runes.toList(), null);

    _root = addResult.rootNode;

    _incVersion();

    return addResult.newKeyValue;
  }

  @override
  void addKeys(Iterable<String> keys) => keys.forEach((final key) {
        addKey(key);
      });

  @override
  void addKeyValue(V keyValue) {
    add(keyValue.toString(), keyValue);
  }

  @override
  void addKeyValues(Iterable<V> keyValues) =>
      keyValues.forEach((final keyValue) {
        addKeyValue(keyValue);
      });

  @override
  void addValues(String key, Iterable<V> values) {
    ArgumentError.checkNotNull(values, 'values');
    _addIterable(_mapKeyErrorOnEmpty(key).runes.toList(), values);

    _incVersion();
  }

  @override
  Map<String, Iterable<V>> asMap() => {
        for (final key in keys) key: this[key],
      };

  @override
  void clear() {
    _incVersion();
    _root = null;
  }

  @override
  bool contains(String key, V value) {
    final keyNode = _root?.getKeyNode(_mapKeyErrorOnEmpty(key));

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
  PrefixEditDistanceIterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(
          String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderMapEntryIterable<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).runes.toList(),
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  void forEach(void Function(String key, V value) f) {
    ArgumentError.checkNotNull(f, 'f');
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;

    while (entryItr.moveNext()) {
      for (final value in entryItr.currentValue) {
        f(entryItr.currentKey, value);
      }
    }
  }

  @override
  void forEachKey(void Function(String key, Iterable<V> values) f) {
    ArgumentError.checkNotNull(f, 'f');
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    ArgumentError.checkNotNull(f, 'f');
    final itr =
        entriesByKeyPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderMapEntryIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue);
    }
  }

  @override
  bool get isEmpty => identical(_root, null);

  @override
  bool get isNotEmpty => !identical(_root, null);

  @override
  Iterable<String> get keys => InOrderKeyIterable<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<String> keysByPrefix(String prefix,
          {int maxPrefixEditDistance = 0, bool filterMarked = false}) =>
      InOrderKeyIterable<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).runes.toList(),
          maxPrefixEditDistance: maxPrefixEditDistance,
          filterMarked: filterMarked);

  @override
  int keyDepth(String key) {
    if (identical(_root, null)) {
      return -1;
    }

    final prefixDescendant = _root
        .getClosestPrefixDescendant(_mapKeyErrorOnEmpty(key).runes.toList());

    // The node must represent only this key
    if (!prefixDescendant.isPrefixMatch ||
        prefixDescendant.nodeRuneIdx !=
            prefixDescendant.node.runes.length - 1 ||
        !prefixDescendant.node.isKeyEnd) {
      throw ArgumentError('key: $key not found');
    }
    return prefixDescendant.depth;
  }

  @override
  KeyMapping get keyMapping => _keyMapping;

  @override
  int get length => identical(_root, null) ? 0 : _root.sizeDFSTree;

  @override
  void markKey(String key) {
    var keyNode = _root?.getKeyNode(_mapKeyErrorOnEmpty(key));

    if (identical(keyNode, null)) {
      throw ArgumentError('key: $key not found');
    }

    // Promote node priority
    keyNode.mark();

    var changed = false;

    while (true) {
      // Find next non mid child ancestor and its parent
      var parent = keyNode.parent;
      if (!identical(parent, null)) {
        while (keyNode == parent.mid) {
          if (identical( parent.parent, null)) {
            // Can't go any higher
            break;
          }
          keyNode = parent;
          parent = keyNode.parent;
        }

        final parentIsRoot = parent == _root;

        // Also need grandparent to swap parent child relationship.
        // Or if at root then assign rotated node as new root.
        final grandparent = parent.parent;
        if (!identical(grandparent, null) || parentIsRoot) {
          // Swap priority with parent if it is higher
          if (parent.priority > keyNode.priority) {
            final parentPriority = parent.priority;
            parent.priority = keyNode.priority;
            keyNode.priority = parentPriority;
          }

          // Rotate parent node such that it's position is swapped with node.
          if (keyNode == parent.left) {
            if (parentIsRoot) {
              _root = parent.rotateRight();
            } else {
              grandparent.updateChild(parent, parent.rotateRight());
            }
          } else {
            if (parentIsRoot) {
              _root = parent.rotateLeft();
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
  V lookup(String key, V value) =>
      _root?.getKeyNode(_mapKeyErrorOnEmpty(key))?.lookupValue(value);

  @override
  bool remove(String key, V value) {
    final keyNode = _root?.getKeyNode(_mapKeyErrorOnEmpty(key));

    if (!identical(keyNode, null) && keyNode.removeValue(value)) {
      _incVersion();
      return true;
    }

    return false;
  }

  @override
  Iterable<V> removeValues(String key) {
    final keyNode = _root?.getKeyNode(_mapKeyErrorOnEmpty(key));

    if (!identical(keyNode, null)) {
      _incVersion();
      return keyNode.removeValues();
    }
    return null;
  }

  @override
  Iterable<V> removeKey(String key) {
    Iterable<V> values;
    if (!identical(_root, null)) {
      values = _remove(_root, _mapKeyErrorOnEmpty(key).runes.toList());
      if (!identical(values, null)) {
        _incVersion();
      }
    }
    return values;
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
  String lastMarkedKeyForPrefix(String key) {
    final prefix = _mapKeyErrorOnEmpty(key).runes.toList();
    final searchResult = _root?.getClosestPrefixDescendant(prefix);

    if (identical(searchResult, null) || !searchResult.isPrefixMatch) {
      return null;
    }

    // Expand prefix with remaining node runes
    var expansion = [
      ...prefix.getRange(0, searchResult.prefixRuneIdx),
      ...searchResult.node.runes
          .getRange(searchResult.nodeRuneIdx, searchResult.node.runes.length)
    ];

    // Concatenate mid descendants until key is found
    var suggestionNode = searchResult.node;

    while (!suggestionNode.isMarked && !identical(suggestionNode.mid, null)) {
      suggestionNode = suggestionNode.mid;
      expansion += suggestionNode.runes;
    }

    return suggestionNode.isMarked ? String.fromCharCodes(expansion) : null;
  }

  @override
  String toString([String paddingChar = '-']) {
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
  Map<String, dynamic> toJson([bool includeValues = true]) {
    ArgumentError.checkNotNull(includeValues, 'includeValues');
    final map = <String, dynamic>{};
    final nodes = <List<dynamic>>[];
    _toJson(_root, nodes, includeValues);
    map[_JSONKEY_NODES] = nodes;
    map[_JSONKEY_KEYMAPPING] = keyMapping(null);
    return map;
  }

  void _toJson(Node<V> node, List<dynamic> nodes, bool includeValues) {
    if (identical(node, null)) {
      // Empty list as placeholder for null node
      nodes.add([]);
      return;
    }
    nodes.add(node.toJson(includeValues));

    _toJson(node.left, nodes, includeValues);
    _toJson(node.mid, nodes, includeValues);
    _toJson(node.right, nodes, includeValues);
  }

  @override
  Iterable<V> get values => InOrderValuesIterable<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<V> valuesByKeyPrefix(String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderValuesIterable<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).runes.toList(),
          maxPrefixEditDistance: maxPrefixEditDistance);

  /// Increment modification _version.
  /// Wrap backto 0 when [_MAX_SAFE_INTEGER] exceeded
  void _incVersion() {
    _version.value =
        (_version.value >= _MAX_SAFE_INTEGER) ? 1 : _version.value + 1;
  }

  /// Add or update node for [key] starting from [searchRoot] and attach [value].
  ///
  /// Return a [_AddResult] with:
  /// * [_AddResult.rootNode]: New root node which may not be the same as [searchRoot] due
  /// to possible rotation.
  /// * [_AddResult.addedNode]: The new or existing end node corresponding to [key]
  /// * [_AddResult.newKey]: True if [key] was new to this [TernaryTreap].
  ///
  ///_AddResult(this.rootNode, this.addedNode, this.newKey);
  /// Iterative version: More complicated than recursive
  /// but 4 times as fast.
  _AddResult<V> _add(Node<V> rootNode, List<int> keyRunes, V value) {
    var keyRuneIdx = 0;
    var _rootNode = rootNode;

    // Create new root node if needed
    if (identical(_rootNode, null)) {
      _rootNode = _nodeFactory(keyRunes, _random, null, _runePool);
      keyRuneIdx = keyRunes.length;
    }

    var currentNode = _rootNode;

    // Create a path down to key node, rotating as we go.
    while (keyRuneIdx < keyRunes.length) {
      final keyRune = keyRunes[keyRuneIdx];
      if (keyRune < currentNode.runes[0]) {
        // create left path as end node if able
        if (identical(currentNode.left, null)) {
          currentNode.left = _nodeFactory(
              keyRunes.getRange(keyRuneIdx, keyRunes.length),
              _random,
              currentNode,
              _runePool);

          keyRuneIdx = keyRunes.length;
        }
        currentNode = currentNode.left;
      } else if (keyRune > currentNode.runes[0]) {
        // Create right path if needed
        if (identical(currentNode.right, null)) {
          currentNode.right = _nodeFactory(
              keyRunes.getRange(keyRuneIdx, keyRunes.length),
              _random,
              currentNode,
              _runePool);
          keyRuneIdx = keyRunes.length;
        }
        currentNode = currentNode.right;
      } else {
        // Move onto next key rune
        keyRuneIdx++;

        // We know that the first rune matches now try and match
        // the rest
        var nodeCodeIdx = 1;

        // Match node runes as far as possible
        while (keyRuneIdx < keyRunes.length &&
            nodeCodeIdx < currentNode.runes.length &&
            currentNode.runes[nodeCodeIdx] == keyRunes[keyRuneIdx]) {
          nodeCodeIdx++;
          keyRuneIdx++;
        }

        // If key was not consumed entirely
        if (keyRuneIdx < keyRunes.length) {
          if (nodeCodeIdx < currentNode.runes.length) {
            // if neither node or key were consumed then split and
            // continue on from new child
            _split(currentNode, nodeCodeIdx, _runePool);
          } else {
            // If key was not consumed but node was then grow down
            // and continue from new child
            if (identical(currentNode.mid, null)) {
              currentNode.mid = _nodeFactory(
                  keyRunes.getRange(keyRuneIdx, keyRunes.length),
                  _random,
                  currentNode,
                  _runePool);
              keyRuneIdx = keyRunes.length;
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

    bool newKeyValue;
    if (newKeyValue = currentNode.setAsKeyEnd()) {
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

    if (!identical(value, null)) {
      newKeyValue = currentNode.addValue(value) || newKeyValue;
    }

    return _AddResult<V>(_rootNode, currentNode, newKeyValue);
  }

  void _addIterable(List<int> keyRunes, Iterable<V> values) {
    // map key alone for case where no data is associated with key
    final tuple = _add(_root, keyRunes, null);
    _root = tuple.rootNode;

    tuple.targetNode.addValues(values);
  }

  /// Map key and throw error if result is empty
  String _mapKeyErrorOnEmpty(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value('key is empty');
    }
    final mappedKey = keyMapping(key);
    if (mappedKey.isEmpty) {
      throw ArgumentError('key $key is empty after KeyMapping applied');
    }
    return mappedKey;
  }

  /// Delete node for [transformedKey] starting from [rootNode] and return values
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
      if (!identical(currentNode, _root) && currentNode.numDFSDescendants == 0) {
        // Delete from parent
        currentNode.parent.deleteChild(currentNode, _runePool);
      } else {
        // Otherwise sinply remove its key end status
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
      // Child inherits values and keyend status
      child.takeValues(node);

      // and thus gains a key descendant
      node.numDFSDescendants++;
    }
  }

  void _setFromJson(
      JsonNodeFactory<V> jsonNodeFactory, Map<String, dynamic> json) {
    final nodes = json[_JSONKEY_NODES];

    if (nodes is List<dynamic>) {
      final nodeIdx = ByRef<int>(0);
      _root = _nodesFromJson(jsonNodeFactory, null, nodes, nodeIdx);
      if (nodeIdx.value != nodes.length) {
        throw ArgumentError.value(json,
            'nodeIdx.value (${nodeIdx.value}) != nodes.length (${nodes.length})');
      }
    } else {
      throw ArgumentError.value(json);
    }
  }

  Node<V> _nodesFromJson(JsonNodeFactory<V> jsonNodeFactory, Node<V> parent,
      List<dynamic> nodesJson, ByRef<int> nodesIdx) {
    if (nodesIdx.value < nodesJson.length) {
      parent = jsonNodeFactory(nodesJson[nodesIdx.value++] as List<dynamic>,
          _random, parent, _runePool);
      if (!identical(parent, null)) {
        parent
          ..left = _nodesFromJson(jsonNodeFactory, parent, nodesJson, nodesIdx)
          ..adjustPrioritiesForChild(parent.left)
          ..mid = _nodesFromJson(jsonNodeFactory, parent, nodesJson, nodesIdx)
          ..adjustPrioritiesForChild(parent.mid)
          ..right = _nodesFromJson(jsonNodeFactory, parent, nodesJson, nodesIdx)
          ..adjustPrioritiesForChild(parent.right)
          ..updateDescendantCounts();
        return parent;
      }
    }
    return null;
  }
}
