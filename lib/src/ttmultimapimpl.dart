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

/// 2^53 because javascript
const int _MAX_SAFE_INTEGER = 9007199254740991;

/// 2^32 specified because javascript
const int _MAX_RANDOM = 4294967296;

/// Map key and throw error if result is empty
String mapKeyErrorOnEmpty(String key, KeyMapping keyMapping) {
  final mappedKey = keyMapping(key);
  if (mappedKey.isEmpty) {
    throw ArgumentError('key $key is empty after KeyMapping applied');
  }
  return mappedKey;
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
class TTMultiMapSet<V> extends _TTMultiMapImpl<V> implements TTMultiMap<V>{
  /// Construct a new [TTMultiMapSet] with an optional [keyMapping]
  TTMultiMapSet([KeyMapping keyMapping])
      : super(
            (Iterable<int> codeUnit, int priority, Node<V> parent,
                    final HashSet<CodeUnitPoolEntry> _codeUnitPool) =>
                NodeSet<V>(codeUnit, priority, parent, _codeUnitPool),
            keyMapping);

  @override
  Set<V> operator [](String key) => super[key] as Set<V>;

  @override
  Map<String, Set<V>> asMap() => Map<String, Set<V>>.fromEntries(entries);

  @override
  Iterable<MapEntry<String, Set<V>>> get entries =>
      InOrderMapEntryIterableSet<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<MapEntry<String, Set<V>>> entriesByKeyPrefix(
          String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderMapEntryIterableSet<V>(_root, _version,
          prefix: mapKeyErrorOnEmpty(prefix, keyMapping).codeUnits,
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  void forEachKey(void Function(String key, Set<V> values) f) {
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue as Set<V>);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Set<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    final itr =
        entriesByKeyPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderMapEntryIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue as Set<V>);
    }
  }

  @override
  Set<V> removeValues(String key) {
    final values = super.removeValues(key);
    return values == null?null:values as Set<V>;
  }

  @override
  Set<V> removeAll(String key) {
    final values = super.removeAll(key);
    return values == null?null:values as Set<V>;
  }
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
  @override
  List<V> operator [](String key) => super[key] as List<V>;

  @override
  Map<String, List<V>> asMap() => Map<String, List<V>>.fromEntries(entries);

  @override
  Iterable<MapEntry<String, List<V>>> get entries =>
      InOrderMapEntryIterableList<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<MapEntry<String, List<V>>> entriesByKeyPrefix(
          String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderMapEntryIterableList<V>(_root, _version,
          prefix: mapKeyErrorOnEmpty(prefix, keyMapping).codeUnits,
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  void forEachKey(void Function(String key, List<V> values) f) {
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue as List<V>);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, List<V> values) f,
      {int maxPrefixEditDistance = 0}) {
    final itr =
        entriesByKeyPrefix(prefix, maxPrefixEditDistance: maxPrefixEditDistance)
            .iterator as InOrderMapEntryIterator<V>;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue as List<V>);
    }
  }

  @override
  List<V> removeValues(String key) {
    final values = super.removeValues(key);
    return values == null?null:values as List<V>;
  }

  @override
  List<V> removeAll(String key) {
    final values = super.removeAll(key);
    return values == null?null:values as List<V>;
  }
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
  Iterable<V> operator [](String key) {
    final keyNode = _root?.getKeyNode(mapKeyErrorOnEmpty(key, _keyMapping));

    if (keyNode == null) {
      return null;
    }

    return keyNode.values;
  }

  @override
  void operator []=(String key, Iterable<V> values) {
    final keyMapped = mapKeyErrorOnEmpty(key, _keyMapping);

    final addResult = _add(_root, keyMapped, null);
    _root = addResult.rootNode;
    var keyNode = addResult.addedNode;

    if (keyNode == null) {
      throw Error();
    }

    // Update values with shallow copy
    keyNode.setValues(values);

    _incVersion();
  }

  @override
  bool add(String key, [V value]) {
    final addResult = _add(_root, mapKeyErrorOnEmpty(key, _keyMapping), value);
    _root = addResult.rootNode;

    _incVersion();
    return addResult.newKey;
  }

  @override
  void addEntries(Iterable<MapEntry<String, Iterable<V>>> entries) {
    entries.forEach((final entry) {
      final mappedKey = mapKeyErrorOnEmpty(entry.key, _keyMapping);
      final data = entry.value;

      // map key alone for case where no data is associated with key
      final addResult = _add(_root, mappedKey, null);
      _root = addResult.rootNode;

      // copy data over
      for (final value in data) {
        addResult.addedNode.addValue(value);
      }
    });

    _incVersion();
  }

  @override
  void addKeys(Iterable<String> keys) {
    keys.forEach((final key) {
      add(key);
    });
  }

  @override
  void addValues(String key, Iterable<V> values) {
    final mappedKey = mapKeyErrorOnEmpty(key, _keyMapping);

    // map key alone for case where no data is associated with key
    final tuple = _add(_root, mappedKey, null);
    _root = tuple.rootNode;

    for (final value in values) {
      tuple.addedNode.addValue(value);
    }

    _incVersion();
  }

  @override
  Map<String, Iterable<V>> asMap() =>
      Map<String, Iterable<V>>.fromEntries(entries);

  @override
  void clear() {
    _incVersion();
    _root = null;
  }

  @override
  bool contains(String key, V value) {
    final keyNode = _root?.getKeyNode(mapKeyErrorOnEmpty(key, _keyMapping));

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
      InOrderMapEntryIterable<V>( _root, _version);

  @override
  PrefixEditDistanceIterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(
          String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderMapEntryIterable<V>( _root, _version,
          prefix: mapKeyErrorOnEmpty(prefix, _keyMapping).codeUnits,
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  void forEach(void Function(String key, V value) f) {
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;

    while (entryItr.moveNext()) {
      for (final value in entryItr.currentValue) {
        f(entryItr.currentKey, value);
      }
    }
  }

  @override
  void forEachKey(void Function(String key, Iterable<V> values) f) {
    final entryItr = entries.iterator as InOrderMapEntryIterator<V>;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue);
    }
  }

  @override
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f,
      {int maxPrefixEditDistance = 0}) {
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
          {int maxPrefixEditDistance = 0}) =>
      InOrderKeyIterable<V>(_root, _version,
          prefix: mapKeyErrorOnEmpty(prefix, _keyMapping).codeUnits,
          maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  int keyDepth(String key) {
    if (_root == null) {
      return -1;
    }

    final prefixDescendant = _root.getClosestPrefixDescendant(
        mapKeyErrorOnEmpty(key, _keyMapping).codeUnits);

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
  void likeKey(String key) {
    var keyNode = _root?.getKeyNode(mapKeyErrorOnEmpty(key, _keyMapping));

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

        final parentIsRoot = parent == _root;

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
  V lookup(String key, V value) {
    final keyNode = _root?.getKeyNode(mapKeyErrorOnEmpty(key, _keyMapping));

    // Does the key map to anything?
    if (keyNode == null) {
      return null;
    }

    return keyNode.lookupValue(value);
  }

  @override
  bool remove(String key, V value) {
    final keyNode = _root?.getKeyNode(mapKeyErrorOnEmpty(key, _keyMapping));

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
  Iterable<V> removeValues(String key) {
    final keyNode = _root?.getKeyNode(mapKeyErrorOnEmpty(key, _keyMapping));

    // Return empty Iterable when unmapped
    if (keyNode == null) {
      return null;
    }

    _incVersion();

    return keyNode.removeValues();
  }

  @override
  Iterable<V> removeAll(String key) {
    final transformedKey = mapKeyErrorOnEmpty(key, _keyMapping);

    Iterable<V> values;
    if (_root != null) {
      values = _remove(_root, transformedKey);
      if (_root.sizeDFSTree == 0) {
        /// There are no end nodes left in tree so delete root
        _root = null;
      }
    }
    // Return empty Iterable when unmapped
    if (values == null) {
      return null;
    }
    _incVersion();
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
  String suggestKey(String key) {
    final prefix = _keyMapping(key).codeUnits;
    final searchResult = _root?.getClosestPrefixDescendant(prefix);

    if (searchResult == null || !searchResult.isPrefixMatch) {
      return key;
    }

    // Can we find a suggestion by expanding the node itself
    var expansion = [
      ...prefix.getRange(0, searchResult.prefixCodeunitIdx),
      ...searchResult.node.codeUnits.getRange(
          searchResult.nodeCodeunitIdx, searchResult.node.codeUnits.length)
    ];

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
  PrefixEditDistanceIterable<V> get values =>
      InOrderValuesIterable<V>(_root, _version);

  @override
  PrefixEditDistanceIterable<V> valuesByKeyPrefix(String prefix,
          {int maxPrefixEditDistance = 0}) =>
      InOrderValuesIterable<V>(_root, _version,
          prefix: mapKeyErrorOnEmpty(prefix, _keyMapping).codeUnits,
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
      _rootNode = _nodeFactory(
          keyCodeUnits, _random.nextInt(_MAX_RANDOM), null, _codeUnitPool);
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
              _random.nextInt(_MAX_RANDOM),
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
              _random.nextInt(_MAX_RANDOM),
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
                  _random.nextInt(_MAX_RANDOM),
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

    bool newKey;
    if (newKey = currentNode.setAsKeyEnd()) {
      // If new node was inserted reverse back up to root node
      // to update node counts

      var reverseNode = currentNode;
      while (reverseNode != _rootNode.parent) {
        // Merge any ophaned mid children on our way back
        // Probably only useful after multiple add and delete cycles
        reverseNode.mergeMid(_codeUnitPool);

        // Rebalance
        reverseNode.rotateChildren();

        reverseNode.updateDescendantCounts();

        reverseNode = reverseNode.parent;
      }
    }

    if (value != null) {
      currentNode.addValue(value);
    }

    return _AddResult<V>(_rootNode, currentNode, newKey);
  }

  /// Delete node for [transformedKey] starting from [rootNode] and return values
  /// of null if key does not exist.
  ///
  /// Assumes [transformedKey] has been transformed
  Iterable<V> _remove(Node<V> rootNode, String transformedKey) {
    assert(rootNode!=null);
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
        _random.nextInt(_MAX_RANDOM),
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
}

/// The result of an add operation.
class _AddResult<V> {
  /// [rootNode] is the potentially new root node of treap after add.
  /// [addedNode] is the node created or affected by the add.
  /// [newKey] is true if a new key was created by this add.
  _AddResult(this.rootNode, this.addedNode, this.newKey);
  final Node<V> rootNode;
  final Node<V> addedNode;
  final bool newKey;
}
