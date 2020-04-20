import 'dart:collection';
import 'dart:math';

import 'package:ternarytreap/ternarytreap.dart';

import 'key_mapping.dart';
import 'pool.dart';
import 'prefixeditdistanceiterable.dart';
import 'ttmultimap.dart';
import 'node.dart';
import 'iterator.dart';
import 'utility.dart';

const _SIZE_OF_INT = 4;
const _SIZE_OF_REF = 4; // 64 bit pointers

/// (2^53)-1 because javascript
const int _MAX_SAFE_INTEGER = 9007199254740991;

/// The result of an add operation.
class _AddResult<V> {
  /// [rootNode] is the potentially new root node of treap after add.
  /// [targetNode] is the node created or affected by the add.
  /// [newKeyValue] is true if a new key or value was created by this add.
  _AddResult(this.rootNode, this.targetNode, this.newKeyValue)
      : assert(rootNode != null),
        assert(targetNode != null);
  final Node<V> rootNode;
  final Node<V> targetNode;
  final bool newKeyValue;
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
            (Iterable<int> codeUnit, int priority, Node<V> parent,
                    final HashSet<CodeUnitPoolEntry> _codeUnitPool) =>
                NodeSet<V>(codeUnit, priority, parent, _codeUnitPool),
            keyMapping);

  /// Create a [TTMultiMapSet] from a [TTMultiMap].
  factory TTMultiMapSet.from(TTMultiMap<V> other, [KeyMapping keyMapping]) {
    ArgumentError.checkNotNull(other, 'other');
    final ttMultiMap = TTMultiMapSet<V>(keyMapping);

    final entryItr = other.entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      ttMultiMap.addValues(entryItr.currentKey, entryItr.currentValue);
    }

    return ttMultiMap;
  }

  /// Create a [TTMultiMapSet] from a [Map].
  factory TTMultiMapSet.fromMap(Map<String, Iterable<V>> map,
      [KeyMapping keyMapping]) {
    ArgumentError.checkNotNull(map, 'map');
    final ttMultiMap = TTMultiMapSet<V>(keyMapping);

    for (final key in map.keys) {
      ttMultiMap.addValues(key, map[key]);
    }
    return ttMultiMap;
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
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits,
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
  Set<V> removeAll(String key) => super.removeAll(key) as Set<V>;
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
            (Iterable<int> codeUnit, int priority, Node<V> parent,
                    final HashSet<CodeUnitPoolEntry> _codeUnitPool) =>
                NodeList<V>(codeUnit, priority, parent, _codeUnitPool),
            keyMapping);

  /// Create a [TTMultiMapList] from a [TTMultiMap].
  factory TTMultiMapList.from(TTMultiMap<V> other, [KeyMapping keyMapping]) {
    ArgumentError.checkNotNull(other, 'other');
    final ttMultiMap = TTMultiMapList<V>(keyMapping);
    final entryItr = other.entries.iterator as InOrderMapEntryIterator<V>;

    while (entryItr.moveNext()) {
      ttMultiMap.addValues(entryItr.currentKey, entryItr.currentValue);
    }
    return ttMultiMap;
  }

  /// Create a [TTMultiMapList] from a [Map].
  factory TTMultiMapList.fromMap(Map<String, Iterable<V>> map,
      [KeyMapping keyMapping]) {
    ArgumentError.checkNotNull(map, 'map');
    final ttMultiMap = TTMultiMapList<V>(keyMapping);

    for (final key in map.keys) {
      ttMultiMap.addValues(key, map[key]);
    }
    return ttMultiMap;
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
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits,
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
  List<V> removeAll(String key) => super.removeAll(key) as List<V>;
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
  final Node<V> Function(Iterable<int> codeUnit, int priority, Node<V> parent,
      HashSet<CodeUnitPoolEntry> _codeUnitPool) _nodeFactory;

  /// Pool codeUnits among nodes to reduce memory usage
  final _codeUnitPool = createPool();

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
    final addResult = _add(_root, _mapKeyErrorOnEmpty(key), null);

    _root = addResult.rootNode;

    addResult.targetNode.setValues(values);

    _incVersion();
  }

  @override
  bool add(String key, V value) {
    ArgumentError.checkNotNull(value, 'value');
    final addResult = _add(_root, _mapKeyErrorOnEmpty(key), value);

    _root = addResult.rootNode;

    _incVersion();

    return addResult.newKeyValue;
  }

  @override
  void addAll(TTMultiMap<V> other) {
    ArgumentError.checkNotNull(other, 'other');
    final entryItr = other.entries.iterator as InOrderMapEntryIterator<V>;

    while (entryItr.moveNext()) {
      _addIterable(
          _mapKeyErrorOnEmpty(entryItr.currentKey), entryItr.currentValue);
    }

    _incVersion();
  }

  @override
  void addEntries(Iterable<MapEntry<String, Iterable<V>>> entries) {
    ArgumentError.checkNotNull(entries, 'entries');
    entries.forEach((final entry) {
      _addIterable(_mapKeyErrorOnEmpty(entry.key), entry.value);
    });

    _incVersion();
  }

  @override
  bool addKey(String key) {
    final addResult = _add(_root, _mapKeyErrorOnEmpty(key), null);

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
    _addIterable(_mapKeyErrorOnEmpty(key), values);

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
    if (keyNode == null) {
      return false;
    }

    return keyNode.values.contains(value);
  }

  @override
  bool containsKey(String key) => this[key] != null;

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
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits,
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
  bool get isEmpty => _root == null;

  @override
  bool get isNotEmpty => _root != null;

  @override
  Iterable<String> get keys => InOrderKeyIterable<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<String> keysByPrefix(String prefix,
          {int maxPrefixEditDistance = 0, bool filterMarked = false}) =>
      InOrderKeyIterable<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits,
          maxPrefixEditDistance: maxPrefixEditDistance, filterMarked: filterMarked);

  @override
  int keyDepth(String key) {
    if (_root == null) {
      return -1;
    }

    final prefixDescendant =
        _root.getClosestPrefixDescendant(_mapKeyErrorOnEmpty(key).codeUnits);

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
  KeyMapping get keyMapping => _keyMapping;

  @override
  int get length => _root == null ? 0 : _root.sizeDFSTree;

  @override
  void markKey(String key) {
    var keyNode = _root?.getKeyNode(_mapKeyErrorOnEmpty(key));

    if (keyNode == null) {
      throw ArgumentError('key: $key not found');
    }

    // Promote node priority
    keyNode.mark();

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

        final parentIsRoot = parent == _root;

        // Also need grandparent to swap parent child relationship.
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

    if (keyNode != null && keyNode.removeValue(value)) {
      _incVersion();
      return true;
    }

    return false;
  }

  @override
  Iterable<V> removeValues(String key) {
    final keyNode = _root?.getKeyNode(_mapKeyErrorOnEmpty(key));

    if (keyNode != null) {
      _incVersion();
      return keyNode.removeValues();
    }
    return null;
  }

  @override
  Iterable<V> removeAll(String key) {
    Iterable<V> values;
    if (_root != null) {
      values = _remove(_root, _mapKeyErrorOnEmpty(key));
      if (_root.sizeDFSTree == 0) {
        /// There are no end nodes left in tree so delete root
        _root = null;
      }
      if (values != null) {
        _incVersion();
      }
    }
    return values;
  }

  @override
  int sizeOf([int valueSizeInBytes = 0]) {
    if (_root == null) {
      return 0;
    }

    // String pool size
    var poolSize = sizeOfPool(_codeUnitPool);

    // get tree size
    return (4 * _SIZE_OF_REF) + poolSize + _sizeOfTree(_root, valueSizeInBytes);
  }

  int _sizeOfTree(Node<V> p, int valueSizeInBytes) {
    if (p == null) {
      return 0;
    }

    final sizeThisNode = ((2 * _SIZE_OF_INT) + (6 * _SIZE_OF_REF)) +
        (p.isKeyEnd
            ? (p.values.length * (_SIZE_OF_REF + valueSizeInBytes))
            : 0);

    return sizeThisNode +
        _sizeOfTree(p.left, valueSizeInBytes) +
        _sizeOfTree(p.mid, valueSizeInBytes) +
        _sizeOfTree(p.right, valueSizeInBytes);
  }

  @override
  String lastMarkedKeyByPrefix(String key) {
    final prefix = _mapKeyErrorOnEmpty(key).codeUnits;
    final searchResult = _root?.getClosestPrefixDescendant(prefix);

    if (searchResult == null || !searchResult.isPrefixMatch) {
      return null;
    }

    // Expand prefix with remaining node codeunits
    var expansion = [
      ...prefix.getRange(0, searchResult.prefixCodeunitIdx),
      ...searchResult.node.codeUnits.getRange(
          searchResult.nodeCodeunitIdx, searchResult.node.codeUnits.length)
    ];

    // Concatenate mid descendants until key is found
    var suggestionNode = searchResult.node;

    while (!suggestionNode.isMarked && suggestionNode.mid != null) {
      suggestionNode = suggestionNode.mid;
      expansion += suggestionNode.codeUnits;
    }

    return suggestionNode.isMarked
        ? String.fromCharCodes(expansion)
        : null;
  }

  @override
  String toString([String paddingChar = '-']) {
    final lines = StringBuffer();
    final itr = entries.iterator as InOrderMapEntryIterator<V>;

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

  @override
  Iterable<V> get values => InOrderValuesIterable<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<V> valuesByKeyPrefix(String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderValuesIterable<V>(_root, _version,
          prefix: _mapKeyErrorOnEmpty(prefix).codeUnits,
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
  _AddResult<V> _add(Node<V> rootNode, String key, V value) {
    final keyCodeUnits = key.codeUnits;

    var keyCodeIdx = 0;
    var _rootNode = rootNode;

    // Create new root node if needed
    if (_rootNode == null) {
      _rootNode =
          _nodeFactory(keyCodeUnits, _newPriority(), null, _codeUnitPool);
      keyCodeIdx = keyCodeUnits.length;
    }

    var currentNode = _rootNode;

    // Create a path down to key node, rotating as we go.
    while (keyCodeIdx < keyCodeUnits.length) {
      final keyCodeUnit = keyCodeUnits[keyCodeIdx];
      if (keyCodeUnit < currentNode.codeUnits[0]) {
        // create left path as end node if able
        if (currentNode.left == null) {
          currentNode.left = _nodeFactory(
              keyCodeUnits.getRange(keyCodeIdx, keyCodeUnits.length),
              _newPriority(),
              currentNode,
              _codeUnitPool);

          keyCodeIdx = keyCodeUnits.length;
        }
        currentNode = currentNode.left;
      } else if (keyCodeUnit > currentNode.codeUnits[0]) {
        // Create right path if needed
        if (currentNode.right == null) {
          currentNode.right = _nodeFactory(
              keyCodeUnits.getRange(keyCodeIdx, keyCodeUnits.length),
              _newPriority(),
              currentNode,
              _codeUnitPool);
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
            _split(currentNode, nodeCodeIdx, _codeUnitPool);
          } else {
            // If key was not consumed but node was then grow down
            // and continue from new child
            if (currentNode.mid == null) {
              currentNode.mid = _nodeFactory(
                  keyCodeUnits.getRange(keyCodeIdx, keyCodeUnits.length),
                  _newPriority(),
                  currentNode,
                  _codeUnitPool);
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
            _split(currentNode, nodeCodeIdx, _codeUnitPool);
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
      while (reverseNode != _rootNode.parent) {
        // Merge any ophaned mid children on our way back
        reverseNode.mergeMid(_codeUnitPool);

        // Rebalance
        reverseNode.rotateChildren();

        reverseNode.updateDescendantCounts();

        reverseNode = reverseNode.parent;
      }
    }

    if (value != null) {
      newKeyValue = currentNode.addValue(value) || newKeyValue;
    }

    return _AddResult<V>(_rootNode, currentNode, newKeyValue);
  }

  void _addIterable(String key, Iterable<V> values) {
    // map key alone for case where no data is associated with key
    final tuple = _add(_root, _mapKeyErrorOnEmpty(key), null);
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
  /// of null if key does not exist.
  ///
  /// Assumes [transformedKey] has been transformed
  Iterable<V> _remove(Node<V> rootNode, String transformedKey) {
    assert(rootNode != null);
    final keyCodeUnits = transformedKey.codeUnits;

    var keyCodeIdx = 0;

    var currentNode = rootNode;

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
        currentNode.clearKeyEnd();
      }

      // reverse back up to root node to update node counts
      while (currentNode != rootNode.parent) {
        // Merge any ophaned mid children on our way back
        currentNode.mergeMid(_codeUnitPool);

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
  /// * Created child [Node] has remainder codeUnits
  /// * Created child inherits node mid child.
  /// * If node is an end node then child is instead.
  /// * Created child [Node] is attached to node.mid.
  void _split(Node<V> node, int codeUnitIdx,
      final HashSet<CodeUnitPoolEntry> _codeUnitPool) {
    if (node.codeUnits.length < 2) {
      // Nothing to split
      throw ArgumentError();
    }

    if (codeUnitIdx >= node.codeUnits.length) {
      // Both parent and child must have at least 1 codeunit
      throw ArgumentError(codeUnitIdx);
    }

    final child = _nodeFactory(
        node.codeUnits.getRange(codeUnitIdx, node.codeUnits.length),
        _newPriority(),
        node,
        _codeUnitPool);

    child.mid = node.mid;

    // Update child counts and grandchildren if any
    if (child.mid != null) {
      child.numDFSDescendants = child.mid.sizeDFSTree;
      child.mid.parent = child;
    }

    node.setCodeUnits(node.codeUnits.getRange(0, codeUnitIdx), _codeUnitPool);

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

  int _newPriority() => _random.nextInt(MAX_PRIORITY);

}
