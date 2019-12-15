import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';

// 2^53-1
const int _maxSafeInteger = 9007199254740991;

// Unicode categories rock!
final RegExp _matchLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _matchNonLetter = RegExp(r'\P{L}', unicode: true);
final RegExp _matchSeperators = RegExp(r'\p{Z}+', unicode: true);

/// A function mapping a string to a key.
///
/// This is optionally during construction and used to transform input
/// strings into keys.
///
/// A [KeyMapping] must be [idempotent](https://en.wikipedia.org/wiki/Idempotence).
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

/// A hybrid of [Ternary search trie](https://en.wikipedia.org/wiki/Ternary_search_tree)
/// and [Treap](https://en.wikipedia.org/wiki/Treap) with following properties:
///
/// * Fast prefix searching and low memory cost of a ternary search tree.
/// * Self balancing capability of a treap.
///
/// As a [Multimap](https://en.wikipedia.org/wiki/Multimap) each unique key can be
/// associated with 0..n arbitrary values determined by the behaviour of a
/// [KeyMapping].
///
/// For example the key 'it' may map to 'IT', 'It' or 'it'.
/// Each of these values could also store
/// metadata such as weighting etc.
/// # Structure
///
/// A [TernaryTreap] is a tree of [_Node].
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
/// Each [_Node] stores:
///
/// * A character [_Node.codeUnit] such that Ternary Tree invarient
/// is maintained.
/// * An integer priority value [_Node.priority] such that Treap invarient:
/// '(_Node._left._priority > _Node._priority) &&
/// (_Node._right._priority > _Node._priority)' is maintained.
class TernaryTreap<V> {
  /// Constructs a new [TernaryTreap].
  ///
  /// The [keyMapping] argument supplies an optional instance of
  /// [KeyMapping] to be applied to all keys processed by this [TernaryTreap].
  TernaryTreap([this.keyMapping]);

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
    final List<String> chunks = str.trim().split(_matchSeperators);

    final List<String> res = <String>[];
    //join all adjacent chunks with size 1
    final StringBuffer newChunk = StringBuffer();

    for (final String chunk in chunks) {
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

  final Random _random = Random();

  /// The [KeyMapping] in use by this [TernaryTreap]
  ///
  /// See: [KeyMapping].
  final KeyMapping keyMapping;

  _Node<V> _root;
  int _version = 0;

  /// The number of keys in the [TernaryTreap].
  int get length => _root == null ? 0 : _root.sizeDFSTree;

  /// The maximum node depth of the [TernaryTreap].
  int get depth {
    final _MapEntryIterator<V> itr = entries.iterator;
    int maxDepth = 0;
    while (itr.moveNext()) {
      final int currentDepth = itr.stack.length;

      if (currentDepth > maxDepth) {
        maxDepth = currentDepth;
      }
    }
    return maxDepth;
  }

  /// Returns true if there is no key in the [TernaryTreap].
  bool get isEmpty => _root == null;

  /// Returns true if there is at least one key in the [TernaryTreap].
  bool get isNotEmpty => _root != null;

  /// Return [Iterable] view of keys
  Iterable<String> get keys => _KeyIterable<V>(this, _root);

  /// Return [Iterable] view of values
  ///
  /// Return an iterable that combines individual Key->Values
  /// relations into a single flat ordering.
  ///
  /// `[['Card', 'card'],['Cat', 'cat', 'CAT']]` ->
  /// `['Card', 'card','Cat', 'cat', 'CAT']`.
  Iterable<V> get values =>
      _ValuesIterable<V>(this, _root).expand((Iterable<V> values) => values);

  /// Iterates through [TernaryTreap] as [MapEntry] objects.
  ///
  /// Each [MapEntry] contains a key (after [KeyMapping] applied)
  /// and its associated values.
  Iterable<MapEntry<String, Iterable<V>>> get entries =>
      _MapEntryIterable<V>(this, _root);

  /// Iterates through [TernaryTreap] as [MapEntry] objects such
  /// that only keys prefixed by [mapKey]`(`[prefix]`)` are included.
  ///
  /// Each [MapEntry] contains a key and its associated values.
  ///
  /// If [mapKey]`(`[prefix]`)` is empty then returns [entries].
  ///
  /// Throws [ArgumentError] if [prefix] is empty.
  Iterable<MapEntry<String, Iterable<V>>> entriesByKeyPrefix(String prefix) {
    final String prefixMapped = mapKey(prefix);

    if (prefixMapped.isEmpty) {
      return entries;
    }

    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode = _getPrefixNode(_root, prefixMapped);

    return _MapEntryIterable<V>(this, lastPrefixNode, prefixMapped);
  }

  /// Returns [Iterable] collection of each key of the [TernaryTreap]
  /// where key is prefixed by [mapKey]`(`[prefix]`)`.
  ///
  /// If [mapKey]`(`[prefix]`)` is empty then returns [keys].
  ///
  /// Throws [ArgumentError] if [prefix] is empty.
  Iterable<String> keysByPrefix(String prefix) {
    final String prefixMapped = mapKey(prefix);

    if (prefixMapped.isEmpty) {
      return keys;
    }

    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode = _getPrefixNode(_root, prefixMapped);

    return _KeyIterable<V>(this, lastPrefixNode, prefixMapped);
  }

  /// Returns [_ValuesIterable] giving each value
  /// of the [TernaryTreap] where key is prefixed by [mapKey]`(`[prefix]`)`.
  ///
  /// If [mapKey]`(`[prefix]`)` is empty then returns [values].
  ///
  /// Throws ArgumentError if [prefix] is empty.
  Iterable<V> valuesByKeyPrefix(String prefix) {
    final String prefixMapped = mapKey(prefix);

    if (prefixMapped.isEmpty) {
      return values;
    }

    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode = _getPrefixNode(_root, prefixMapped);

    return _ValuesIterable<V>(this, lastPrefixNode, prefixMapped)
        .expand((Iterable<V> values) => values);
  }

  /// Insert a [key] and optional [value].
  ///
  /// [key] is a string to be converted via [KeyMapping] into a key.
  /// An optional [value] may be supplied to associate with this key.
  ///
  /// If no value is supplied then [key] is added with no attached value.
  /// The [key] will still be returned in [keys] and [keysByPrefix] results and
  ///
  /// A [value] is checked for equality against existing values for
  /// this key via '==' operator and if already associated with [key] it is
  /// not added.
  ///
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  void add(String key, [V value]) {
    _root = _add(_root, _mapKeyErrorOnEmpty(key), value);

    _incVersion();
  }

  /// Adds all associations of other to this [TernaryTreap].
  ///
  /// Is equivilent to calling [addValues]`(key, other[key])`
  /// for all `other.`[keys].
  ///
  /// [mapKey] is applied to all incoming keys so
  /// if `this.`[keyMapping] != `other`.[keyMapping] then
  /// keys may be altered during copying from [other] to `this`.
  ///
  /// For example if `this.`[keyMapping] == [lowercase] and
  /// [other]`.`[keyMapping] == [uppercase] then the keys of [other]
  /// will be converted from lowercase to uppercase during the
  /// copying to `this`.
  ///
  /// Throws [ArgumentError] if [mapKey]`(key)` is empty for any
  /// incoming keys of [other].
  void addAll(TernaryTreap<V> other) {
    final _MapEntryIterator<V> entryItr = other.entries.iterator;
    while (entryItr.moveNext()) {
      final String mappedKey = _mapKeyErrorOnEmpty(entryItr.currentKey);

      // map key alone for case where no data is associated with key
      _root = _add(_root, mappedKey, null);

      for (final V value in entryItr.currentValue) {
        _root = _add(_root, mappedKey, value);
      }
    }

    _incVersion();
  }

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
  void addValues(String key, Iterable<V> values) {
    final String mappedKey = _mapKeyErrorOnEmpty(key);

    // map key alone for case where no data is associated with key
    _root = _add(_root, mappedKey, null);

    for (final V value in values) {
      _root = _add(_root, mappedKey, value);
    }

    _incVersion();
  }

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  void forEach(void Function(String key, V value) f) {
    final _MapEntryIterator<V> entryItr = entries.iterator;

    while (entryItr.moveNext()) {
      for (final V value in entryItr.currentValue) {
        f(entryItr.currentKey, value);
      }
    }
  }

  /// Applies [f] to each key/values pair of the [TernaryTreap] where
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  void forEachKey(void Function(String key, Iterable<V> values) f) {
    final _MapEntryIterator<V> entryItr = entries.iterator;
    while (entryItr.moveNext()) {
      f(entryItr.currentKey, entryItr.currentValue);
    }
  }

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  /// where key is prefixed by [prefix] (after [KeyMapping] applied).
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  ///
  /// Throws ArgumentError if [prefix] is empty
  void forEachKeyPrefixedBy(
      String prefix, void Function(String key, Iterable<V> values) f) {
    final _MapEntryIterator<V> itr = entriesByKeyPrefix(prefix).iterator;

    while (itr.moveNext()) {
      f(itr.currentKey, itr.currentValue);
    }
  }

  /// Return list of values for specified [key].
  ///
  /// If no value associated with key then returns empty [Iterable].
  /// If key not found then returns null.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  Iterable<V> operator [](Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final String keyMapped = mapKey(key as String);

    if (keyMapped.isEmpty) {
      return null;
    }

    final _Node<V> keyNode = _getKeyNode(keyMapped);

    if (keyNode == null) {
      return null;
    }

    return keyNode.values;
  }

  /// Set [Iterable] of values corresponding to [key].
  ///
  /// Any existing [values] of [key] are replaced.
  ///
  /// Throws [ArgumentError] if [mapKey]`(`[key]`)` is empty.
  void operator []=(String key, Iterable<V> values) {
    final String keyMapped = _mapKeyErrorOnEmpty(key);
    _Node<V> keyNode = _getKeyNode(keyMapped);

    if (keyNode == null) {
      // Node does not exist so insert a new one
      add(key);
      // Get newly added now
      keyNode = _getKeyNode(keyMapped);

      if (keyNode == null) {
        throw Error();
      }
    }

    // Update values with shallow copy
    keyNode.values = Set<V>.from(values);

    _incVersion();
  }

  /// Removes all data from the [TernaryTreap].
  void clear() {
    _incVersion();
    _root = null;
  }

  /// Returns whether this [TernaryTreap] contains an
  /// association between [key[] and [value].
  bool contains(Object key, Object value) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final String transformedKey = mapKey(key);

    if (transformedKey.isEmpty) {
      return false;
    }

    final _Node<V> keyNode = _getKeyNode(transformedKey);

    // Does the key map to anything?
    if (keyNode == null) {
      return false;
    }

    return keyNode.values.contains(value);
  }

  /// Returns whether this [TernaryTreap] contains the given [key].
  bool containsKey(Object key) => this[key] != null;

  /// Returns whether this [TernaryTreap] contains the given [value]
  /// at least once.
  bool containsValue(Object value) => values.contains(value);

  /// Removes the association between the given [key] and [value].
  ///
  /// Returns `true` if the association existed, `false` otherwise
  bool remove(Object key, V value) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final _Node<V> keyNode = _getKeyNode(mapKey(key));

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

  /// Removes all values associated with [key].
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  Iterable<V> removeValues(Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final _Node<V> keyNode = _getKeyNode(mapKey(key));

    // Return empty Iterable when unmapped
    if (keyNode == null) {
      return Iterable<V>.empty();
    }

    _incVersion();

    return keyNode.removeValues();
  }

  /// Removes [key] and all associated values.
  ///
  /// Returns the collection of values associated with key,
  /// or an empty iterable if key was unmapped.
  Iterable<V> removeKey(Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }
    _incVersion();
    final String transformedKey = mapKey(key);
    final Iterable<V> values =
        _remove(_root, null, transformedKey.codeUnits, 0);
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
  String toString([String paddingChar = '-']) {
    final StringBuffer lines = StringBuffer();
    final _MapEntryIterator<V> itr = entries.iterator;

    // We can avoid an object creation per key by not accessing the
    // 'current' getter of itr.
    while (itr.moveNext()) {
      final int currentDepth = itr.stack.length;

      final String keyPadding =
          ''.padLeft(currentDepth + 1 - itr.currentKey.length, paddingChar);

      final String valuePadding = ''.padLeft(keyPadding.length, ' ');
      lines.writeln(keyPadding + itr.currentKey);
      for (final V datum in itr.currentValue) {
        lines.writeln(valuePadding + datum.toString());
      }
    }
    return lines.toString();
  }

  /// Return a view of this [TernaryTreap] as a [Map]
  Map<String, Iterable<V>> asMap() =>
      Map<String, Iterable<V>>.fromEntries(entries);

  /// Return key transformed by [keyMapping] specified
  /// during construction.
  ///
  /// Throws [ArgumentError] if [key] is empty.
  String mapKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError();
    }

    return keyMapping == null ? key : keyMapping(key);
  }

  /// Map key and throw error if result is empty
  String _mapKeyErrorOnEmpty(String key) {
    final String mappedKey = mapKey(key);
    if (mappedKey.isEmpty) {
      throw ArgumentError('key $key is empty after KeyMapping applied');
    }
    return mappedKey;
  }

  /// Increment modification version.
  /// Wrap backto 0 when [_maxSafeInteger] exceeded
  void _incVersion() =>
      _version = (_version >= _maxSafeInteger) ? 0 : _version + 1;

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
  /// Iterative version: More complicated but three times as fast as recursive
  _Node<V> _add(_Node<V> rootNode, String key, V value) {
    final List<int> keyCodeUnits = key.codeUnits;

    int currentIdx = 0;
    _Node<V> _rootNode = rootNode;
    _Node<V> currentNode = _rootNode ??=
        _NodeSet<V>(keyCodeUnits[currentIdx], _random.nextInt(1 << 32), null)

          // stop marker for reverse iteration
          ..parent = null;

    // Create a path down to key node
    while (currentIdx < keyCodeUnits.length) {
      final int keyCodeUnit = keyCodeUnits[currentIdx];
      if (keyCodeUnit < currentNode.codeUnit) {
        // create left path if needed
        currentNode.left ??=
            _NodeSet<V>(keyCodeUnit, _random.nextInt(1 << 32), currentNode);

        // rotate node and update parent if needed
        if (currentNode.left.priority > currentNode.priority) {
          final _Node<V> currentParent = currentNode.parent;
          final _Node<V> rotatedNode = _rotateRight(currentNode);
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
            _NodeSet<V>(keyCodeUnit, _random.nextInt(1 << 32), currentNode);

        if (currentNode.right.priority > currentNode.priority) {
          final _Node<V> currentParent = currentNode.parent;
          final _Node<V> rotatedNode = _rotateLeft(currentNode);
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
          currentNode = currentNode.right;
        }
      } else {
        currentIdx++;
        if (currentIdx < keyCodeUnits.length) {
          currentNode.mid ??= _NodeSet<V>(
              keyCodeUnits[currentIdx], _random.nextInt(1 << 32), currentNode);

          currentNode = currentNode.mid;
        }
      }
    }

    if (currentNode.setAsKeyEnd()) {
      // If new node was inserted reverse back up to root node
      // to update node counts
      _Node<V> reverseNode = currentNode;
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
      final Iterable<V> values =
          _remove(thisNode.left, thisNode, codeUnits, idx);
      if (values != null) {
        _updateDescendantCounts(thisNode);
      }
      return values;
    } else {
      if (codeUnits[idx] > thisNode.codeUnit) {
        final Iterable<V> values =
            _remove(thisNode.right, thisNode, codeUnits, idx);
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
          final Iterable<V> values = thisNode.values;
          thisNode.values = null;
          return values;
        } else {
          final Iterable<V> values =
              _remove(thisNode.mid, thisNode, codeUnits, idx + 1);
          if (values != null) {
            _updateDescendantCounts(thisNode);
          }
          return values;
        }
      }
    }
  }

  /// Return _Node corresponding to a transformed key.
  /// Returns null if key does not map to a node.
  /// Assumes key has already been transformed by KeyMapping
  _Node<V> _getKeyNode(String transformedKey) {
    if (transformedKey.isEmpty) {
      return null;
    }

    final _Node<V> lastPrefixNode = _getPrefixNode(_root, transformedKey);

    if (lastPrefixNode == null || !lastPrefixNode.isKeyEnd) {
      return null;
    }
    return lastPrefixNode;
  }

  /// Return the node that is parent to all keys starting with [prefix]
  _Node<V> _getPrefixNode(_Node<V> thisNode, String prefix) {
    final List<int> prefixCodeUnits = prefix.codeUnits;
    _Node<V> currentNode, nextNode = thisNode;
    int currentIdx = 0;

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

  /// ```
  ///      a            b
  ///     / \          / \
  ///    b   e   -->  c   a
  ///   / \              / \
  ///  c   d            d   e ```
  _Node<V> _rotateRight(_Node<V> a) {
    final _Node<V> b = a.left;
    final _Node<V> d = b.right;

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
    final _Node<V> a = b.right;
    final _Node<V> d = a.left;

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

  _Node<V> parent; // only used for certain operations such as add

  Iterable<V> removeValues();

  /// If node is not already key End then set as key end
  bool setAsKeyEnd();

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
    int size = values == null ? 0 : 1;
    if (mid != null) {
      size += mid.sizeDFSTree;
    }
    return size;
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
    final Iterable<V> ret = values;
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

class _FastStack<E> {
  _FastStack(int initialSize) : stack = List<E>(initialSize);
  List<E> stack;
  int ptrTop = -1;

  int get length => ptrTop + 1;

  bool get isNotEmpty => ptrTop > -1;
  void push(E value) {
    if (++ptrTop >= stack.length) {
      final List<E> newStack =
          List<E>(stack.length * 2); //simplest growth strategy
      for (int i = 0; i < stack.length; i++) {
        newStack[i] = stack[i];
      }
      stack = newStack;
    }
    stack[ptrTop] = value;
  }

  E pop() => stack[ptrTop--];
}

abstract class _IterableBase<V, I> extends IterableMixin<I> {
  _IterableBase(this.owner, this.root, this.prefix);
  final TernaryTreap<V> owner;
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
  _KeyIterable(TernaryTreap<V> owner, _Node<V> root, [String prefix = ''])
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
  _ValuesIterable(TernaryTreap<V> owner, _Node<V> root, [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<Iterable<V>> get iterator => _ValuesIterator<V>(owner, root, prefix);
}

class _MapEntryIterable<V>
    extends _IterableBase<V, MapEntry<String, Iterable<V>>> {
  _MapEntryIterable(TernaryTreap<V> owner, _Node<V> root, [String prefix = ''])
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
abstract class _IteratorBase<V> {
  /// Construct new [_IteratorBase] to start from
  /// [root] which belongs to owner
  _IteratorBase(this.owner, _Node<V> root, [String prefix = ''])
      : ownerStartingVersion = owner._version,
        stack = _FastStack<_StackFrame<V>>(owner.length) {
    if (prefix == null) {
      throw ArgumentError.notNull('prefix');
    }
    if (root != null) {
      // If prefix was specified then our result tree is hanging
      // from _root.mid however current value must reflect _root
      // after first call of moveNext()
      if (prefix.isNotEmpty) {
        if (root.isKeyEnd) {
          prefixFrame = _StackFrame<V>(root, prefix);
        }
        if (root.mid != null) {
          pushAllLeft(_StackFrame<V>(root.mid, prefix));
        }
      } else {
        pushAllLeft(_StackFrame<V>(root, ''));
      }
    }
  }

  final _FastStack<_StackFrame<V>> stack;

  final TernaryTreap<V> owner;

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
    if (owner._version != ownerStartingVersion) {
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
      final _StackFrame<V> context = stack.pop();

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
    _StackFrame<V> _context = context;
    // add frame to stack and drill down the left
    stack.push(_context);
    while (_context.node.left != null) {
      _context = _StackFrame<V>(_context.node.left, _context.prefix);
      stack.push(_context);
    }
  }
}

/// Iterate through keys
class _KeyIterator<V> extends _IteratorBase<V> implements Iterator<String> {
  /// Construct new [_KeyIterator]
  _KeyIterator(TernaryTreap<V> owner, _Node<V> root, [String prefix = ''])
      : super(owner, root, prefix);

  @override
  String get current => currentKey;
}

/// Iterate through values
class _ValuesIterator<V> extends _IteratorBase<V>
    implements Iterator<Iterable<V>> {
  /// Construct new [_KeyIterator]
  _ValuesIterator(TernaryTreap<V> owner, _Node<V> root, [String prefix = ''])
      : super(owner, root, prefix);

  @override
  bool moveNext() {
    bool next = super.moveNext();
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
class _MapEntryIterator<V> extends _IteratorBase<V>
    implements Iterator<MapEntry<String, Iterable<V>>> {
  /// Construct new [_KeyIterator]
  _MapEntryIterator(TernaryTreap<V> owner, _Node<V> root, [String prefix = ''])
      : super(owner, root, prefix);

  @override
  MapEntry<String, Iterable<V>> get current =>
      MapEntry<String, Iterable<V>>(currentKey, currentValue);
}
