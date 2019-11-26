import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';

// 2^53-1
const int _maxSafeInteger = 9007199254740991;

/// A function mapping a string to a key.
///
/// This is applied before all operations.
/// For example a mapping may be defined between the set of strings
/// and their lowercase equivilents see: [TernaryTreap.lowercase]
typedef KeyMapping = String Function(String str);

abstract class _TernaryTreeIterableBase<V, I> extends IterableMixin<I> {
  _TernaryTreeIterableBase(this._owner, this._root, this._prefix);
  final TernaryTreap<V> _owner;
  final _Node<V> _root;
  final String _prefix;

  //
  @override
  int get length {
    if (_root == null) {
      return 0;
    }

    return _prefix.isEmpty ? _root._sizeDFSTree : _root._sizePrefixTree;
  }

  @override
  bool get isEmpty => _root == null;
}

class _TernaryTreeKeyIterable<V> extends _TernaryTreeIterableBase<V, String> {
  _TernaryTreeKeyIterable(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<String> get iterator =>
      _TernaryTreeKeyIterator<V>(_owner, _root, _prefix);
}

/// Iterates through values of the [TernaryTreap].
///
/// Values are ordered first by key and then by insertion order.
/// Due to the 1 to n relationship between key and values
/// (necessary for key mapping) each element returned will be a list
/// containing 1 or more elemets that are associated with a key.
///
/// If a key maps to an empty values list then it is skipped, no
/// empty lists are returned.
///
/// For convenience the getter [flattened] may be used to flatten
/// this into a single combined list. @see [flattened]
class TernaryTreeValuesIterable<V>
    extends _TernaryTreeIterableBase<V, List<V>> {
  /// Constructs a TernaryTreeValuesIterable
  TernaryTreeValuesIterable(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<List<V>> get iterator =>
      _TernaryTreeValuesIterator<V>(_owner, _root, _prefix);

  /// Return an iterable that combines individual Key->Values
  /// relations into a single flat ordering.
  ///
  /// For example if [TernaryTreap.valuesByKeyPrefix] returns:
  /// `[['Card', 'card'],['Cat', 'cat', 'CAT']]` then
  /// [TernaryTreap.valuesByKeyPrefix.flattened] will return
  /// `['Card', 'card','Cat', 'cat', 'CAT']`.
  Iterable<V> get flattened => expand((List<V> values) => values);
}

class _TernaryTreeMapEntryIterable<V>
    extends _TernaryTreeIterableBase<V, MapEntry<String, List<V>>> {
  _TernaryTreeMapEntryIterable(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  Iterator<MapEntry<String, List<V>>> get iterator =>
      _TernaryTreeMapEntryIterator<V>(_owner, _root, _prefix);
}

// store call stack data for iterators
@immutable
class _StackFrame<V> {
  const _StackFrame(this.node, this.prefix);
  final _Node<V> node;
  final String prefix;
}

/// Base class for in order [TernaryTreap] iterators.
abstract class _TernaryTreeIteratorBase<V> {
  /// Construct new [_TernaryTreeIteratorBase] to start from
  /// [root] which belongs to owner
  _TernaryTreeIteratorBase(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : _owner = owner,
        _ownerStartingVersion = owner._version {
    if (prefix == null) {
      throw ArgumentError.notNull('prefix');
    }
    if (root != null) {
      // If prefix was specified then our result tree is hanging
      // from _root.mid however current value must reflect _root
      // after first call of moveNext()
      if (prefix.isNotEmpty) {
        if (root._isKeyEnd) {
          _prefixFrame = _StackFrame<V>(root, prefix);
        }
        if (root._mid != null) {
          _pushAllLeft(_StackFrame<V>(root._mid, prefix));
        }
      } else {
        _pushAllLeft(_StackFrame<V>(root, ''));
      }
    }
  }

  final ListQueue<_StackFrame<V>> _stack = ListQueue<_StackFrame<V>>();

  final TernaryTreap<V> _owner;

  final int _ownerStartingVersion;

  _StackFrame<V> _prefixFrame; // Handle prefix end node
  String _currentKey;
  List<V> _currentValue;

  /// Moves to the next element.
  ///
  /// Returns true if current contains the next element.
  /// Returns false if no elements are left.
  /// It is safe to invoke moveNext even when the
  /// iterator is already positioned after the last element.
  /// In this case moveNext returns false again and has no effect.
  /// A call to moveNext may throw [ConcurrentModificationError] if
  /// iteration has been broken by changing the underlying collection.
  ///
  /// Note: The Values list returned may or may not be a reference to the
  /// underlying list stored in [_Node] dpending on the value of
  /// [TernaryTreap.treatKeyAsStringValue].
  bool moveNext() {
    if (_owner._version != _ownerStartingVersion) {
      throw ConcurrentModificationError(_owner);
    }

    // Handle one time case where root node represents final char of
    // prefix and should not be explored
    if (_prefixFrame != null) {
      _currentKey = _prefixFrame.prefix;
      // Handle string map as special case by inserting key as first value.
      if (_owner.treatKeyAsStringValue && V == String) {
        _currentValue = <V>[_currentKey as V, ..._prefixFrame.node._values];
      } else {
        _currentValue = _prefixFrame.node._values;
      }
      _prefixFrame = null;
      return true;
    }

    while (_stack.isNotEmpty) {
      final _StackFrame<V> context = _stack.removeLast();

      // push right and mid for later consumption
      if (context.node._right != null) {
        _pushAllLeft(_StackFrame<V>(context.node._right, context.prefix));
      }

      if (context.node._mid != null) {
        _pushAllLeft(_StackFrame<V>(context.node._mid,
            context.prefix + String.fromCharCode(context.node._codeUnit)));
      }

      if (context.node._isKeyEnd) {
        _currentKey =
            context.prefix + String.fromCharCode(context.node._codeUnit);

        // Handle string map as special case by inserting key as first value.
        if (_owner.treatKeyAsStringValue && V == String) {
          _currentValue = <V>[_currentKey as V, ...context.node._values];
        } else {
          _currentValue = context.node._values;
        }
        return true;
      }
    }
    return false;
  }

  void _pushAllLeft(_StackFrame<V> context) {
    _StackFrame<V> _context = context;
    // add frame to stack and drill down the left
    _stack.addLast(_context);
    while (_context.node._left != null) {
      _context = _StackFrame<V>(_context.node._left, _context.prefix);
      _stack.addLast(_context);
    }
  }
}

/// Iterate through keys
class _TernaryTreeKeyIterator<V> extends _TernaryTreeIteratorBase<V>
    implements Iterator<String> {
  /// Construct new [_TernaryTreeKeyIterator]
  _TernaryTreeKeyIterator(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  String get current => _currentKey;
}

/// Iterate through values
class _TernaryTreeValuesIterator<V> extends _TernaryTreeIteratorBase<V>
    implements Iterator<List<V>> {
  /// Construct new [_TernaryTreeKeyIterator]
  _TernaryTreeValuesIterator(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  bool moveNext() {
    bool next = super.moveNext();
    // skip empty value lists
    while (next && _currentValue.isEmpty) {
      next = super.moveNext();
    }
    return next;
  }

  @override
  List<V> get current => _currentValue;
}

/// Iterate through keys
class _TernaryTreeMapEntryIterator<V> extends _TernaryTreeIteratorBase<V>
    implements Iterator<MapEntry<String, List<V>>> {
  /// Construct new [_TernaryTreeKeyIterator]
  _TernaryTreeMapEntryIterator(TernaryTreap<V> owner, _Node<V> root,
      [String prefix = ''])
      : super(owner, root, prefix);

  @override
  MapEntry<String, List<V>> get current =>
      MapEntry<String, List<V>>(_currentKey, _currentValue);
}

/// A hybrid of [Ternary search trie](https://en.wikipedia.org/wiki/Ternary_search_tree)
/// and [Treap](https://en.wikipedia.org/wiki/Treap) with following properties:
///
/// * Fast prefix searching and low memory cost of a ternary search tree.
/// * Self balancing capability of a treap to flatten tree and
///   minimise search paths.
///
/// Additionally each unique key can be associated with 0..n arbitrary
/// values (where n is number of inserts over same key).
///
/// For example the key 'it' may map to 'IT', 'It' or 'it'.
/// Each of these key representations could require its own
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
/// * A character [_Node._codeUnit] such that Ternary Tree invarient
/// is maintained.
/// * An integer priority value [_Node._priority] such that Treap invarient:
/// (_thisNode._left._priority > _thisNode._priority) &&
/// (_thisNode._right._priority > _thisNode._priority)
class TernaryTreap<V> with MapMixin<String, List<V>> {
  /// Constructs a new [TernaryTreap].
  ///
  /// @param [keyMapping] Optional instance of [KeyMapping] to be
  /// applied to all keys processed by this [TernaryTreap].
  /// @param [treatKeyAsStringValue] if true then keys are returned as values.
  /// @returns New [TernaryTreap].
  TernaryTreap({this.keyMapping, this.treatKeyAsStringValue = true});

  /// Transform a key to all lowercase.
  /// When passed to [TernaryTreap()] this transform will be applied
  /// to all key arguments passed by client
  ///
  /// @param key A key to transform.
  /// @returns key after transformation.
  static String lowercase(String str) => str.toLowerCase();

  /// Transform a key such that:
  ///
  /// * Whitespace is trimmed from start and end
  /// * Runs of multiple whitespace characters are collapsed into a single ' '.
  ///
  /// When passed to [TernaryTreap()] this transform will be applied
  /// to all key arguments passed by client.
  ///
  /// @param key A key to transform.
  /// @returns key after transformation.
  static String collapseWhitespace(String str) =>
      str.replaceAll(RegExp(r'^\s+|\s+$'), '').replaceAll(RegExp(r'\s+'), ' ');

  /// Transform a key with both [lowercase] and [collapseWhitespace].
  /// When passed to [TernaryTreap()] this transform will be applied
  /// to all key arguments passed by client
  ///
  /// @param key A key to transform.
  /// @returns key after transformation.
  static String lowerCollapse(String str) =>
      collapseWhitespace(str).toLowerCase();

  final Random _random = Random();

  /// The [KeyMapping] is use by this [TernaryTreap]
  final KeyMapping keyMapping;

  /// If true then keys will be included as values during processing
  /// when [TernaryTreap] is configured for objects of type [String]
  /// This prevents storing the same string twice for the common
  /// [TernaryTreap<String>] case.
  final bool treatKeyAsStringValue;

  _Node<V> _root;
  int _version = 0;

  @override
  int get length => _root == null ? 0 : _root._sizeDFSTree;

  @override
  bool get isEmpty => _root == null;

  @override
  bool containsKey(Object key) => this[key] != null;

  @override
  Iterable<String> get keys => _TernaryTreeKeyIterable<V>(this, _root);

  @override
  TernaryTreeValuesIterable<V> get values =>
      TernaryTreeValuesIterable<V>(this, _root);

  @override
  Iterable<MapEntry<String, List<V>>> get entries =>
      _TernaryTreeMapEntryIterable<V>(this, _root);

  /// Returns [Iterable] collection of each key/value pair of the [TernaryTreap]
  /// where key (after [KeyMapping] applied) is prefixed by [prefix].
  ///
  /// @throws ArgumentError if [prefix] is empty
  Iterable<MapEntry<String, List<V>>> entriesByKeyPrefix(String prefix) {
    final String prefixMapped = _transformKey(prefix);

    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode =
        _getPrefixLastNode(_root, prefixMapped.codeUnits, 0);

    return _TernaryTreeMapEntryIterable<V>(this, lastPrefixNode, prefixMapped);
  }

  /// Returns [Iterable] collection of each key of the [TernaryTreap]
  /// where key (after [KeyMapping] applied) is prefixed by [prefix].
  ///
  /// @throws ArgumentError if [prefix] is empty
  Iterable<String> keysByPrefix(String prefix) {
    final String prefixMapped = _transformKey(prefix);

    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode =
        _getPrefixLastNode(_root, prefixMapped.codeUnits, 0);

    return _TernaryTreeKeyIterable<V>(this, lastPrefixNode, prefixMapped);
  }

  /// Returns [TernaryTreeValuesIterable] giving of each value
  /// of the [TernaryTreap] where key (after [KeyMapping] applied)
  /// is prefixed by [prefix].
  ///
  /// Each element will be a [List<V>] object, to flatten iterator into
  /// single [List] @see [TernaryTreeValuesIterable.flattened]
  ///
  /// @throws ArgumentError if [prefix] is empty
  TernaryTreeValuesIterable<V> valuesByKeyPrefix(String prefix) {
    final String prefixMapped = _transformKey(prefix);

    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode =
        _getPrefixLastNode(_root, prefixMapped.codeUnits, 0);

    return TernaryTreeValuesIterable<V>(this, lastPrefixNode, prefixMapped);
  }

  /// Insert a key and optional value.
  ///
  /// @param [key] A unique sequence of characters to be stored for retrieval.
  /// @param [value] A user specified value to associate with this key.
  /// The value is checked against existing entries for this key (==) and
  /// if already associated with the key is not added. @see [_Node._values]
  /// @throws [ArgumentError] if key is empty.
  void add(String key, [V value]) {
    if (key.isEmpty) {
      throw ArgumentError();
    }
    _incVersion();
    _root = _add(_root, _transformKey(key).codeUnits, 0, value);
  }

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  @override
  void forEach(void Function(String key, List<V> values) f) {
    final _TernaryTreeMapEntryIterator<V> itr = entries.iterator;

    // We can avoid an object creation per key by not accessing the
    // 'current' getter of itr.
    while (itr.moveNext()) {
      f(itr._currentKey, itr._currentValue);
    }
  }

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  /// where key (after [KeyMapping] applied) is prefixed by [prefix].
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  /// @throws ArgumentError if [prefix] is empty
  void forEachPrefixedBy(
      String prefix, void Function(String key, List<V> values) f) {
    final _TernaryTreeMapEntryIterator<V> itr =
        entriesByKeyPrefix(prefix).iterator;

    // We can avoid an object creation per key by not accessing the
    // 'current' getter of itr.
    while (itr.moveNext()) {
      f(itr._currentKey, itr._currentValue);
    }
  }

  /// Return value for specified [key].
  ///
  /// @param [key] The key to get.
  /// @returns List of values corresponding to [key].
  /// If no value associated with key then return empty [List].
  /// If key not found then return null.
  @override
  List<V> operator [](Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }

    final _Node<V> lastPrefixNode =
        _getPrefixLastNode(_root, _transformKey(key as String).codeUnits, 0);

    if (lastPrefixNode == null || !lastPrefixNode._isKeyEnd) {
      return null;
    }

    // Handle string map as special case by inserting key as first value.
    if (treatKeyAsStringValue && V == String) {
      return <V>[key as V, ...lastPrefixNode._values];
    } else {
      return lastPrefixNode._values;
    }
  }

  /// Set list of values corresponding to [key]
  @override
  void operator []=(String key, List<V> value) {
    _incVersion();
    final String keyMapped = _transformKey(key);
    _Node<V> lastPrefixNode = _getPrefixLastNode(_root, keyMapped.codeUnits, 0);

    if (lastPrefixNode == null) {
      // Node does not exists so insert a new one
      add(key);
      // Get newly added now
      lastPrefixNode = _getPrefixLastNode(_root, keyMapped.codeUnits, 0);
    }

    // Update values with shallow copy
    lastPrefixNode._values = value.toList();

    // Take into account String special case and remove key from list of
    // values if present
    if (treatKeyAsStringValue && V == String) {
      lastPrefixNode._values.remove(key);
    }
  }

  @override
  void clear() {
    _incVersion();
    _root = null;
  }

  @override
  List<V> remove(Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }
    _incVersion();
    final List<V> values =
        _remove(_root, null, _transformKey(key).codeUnits, 0);
    if (_root != null && _root._numDFSDescendants == 0) {
      /// There are no end nodes left in tree so delete root
      _root = null;
    }
    return values;
  }

  /// Generate a string representation of this [TernaryTreap].
  /// Requires that values be json encodable.
  ///
  /// @param [paddingChar] Optional left padding to indicate tree depth.
  /// Default = '-', use '' for no depth.
  /// @returns String representation of objects in order of traversal
  /// formated as:
  /// key -> value (json encoded)
  @override
  String toString([String paddingChar = '-']) {
    final StringBuffer lines = StringBuffer();
    final _TernaryTreeMapEntryIterator<V> itr = entries.iterator;

    // We can avoid an object creation per key by not accessing the
    // 'current' getter of itr.
    while (itr.moveNext()) {
      final int currentDepth = itr._stack.length;

      final String keyPadding =
          ''.padLeft(currentDepth + 1 - itr._currentKey.length, paddingChar);

      final String valuePadding = ''.padLeft(keyPadding.length, ' ');
      lines.writeln(keyPadding + itr._currentKey);
      for (final V datum in itr._currentValue) {
        lines.writeln(valuePadding + datum.toString());
      }
    }
    return lines.toString();
  }

  // increment modification version
  void _incVersion() =>
      _version = (_version >= _maxSafeInteger) ? 0 : _version + 1;

  // Map key using specified [KeyMapping]
  String _transformKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError();
    }

    return keyMapping == null ? key : keyMapping(key);
  }

  _Node<V> _add(_Node<V> thisNode, List<int> codeUnits, int i, V value) {
    _Node<V> _thisNode;
    if (thisNode == null) {
      _thisNode = _Node<V>(codeUnits[i], _random.nextInt(1 << 32));
    } else {
      _thisNode = thisNode;
    }

    if (codeUnits[i] < _thisNode._codeUnit) {
      _thisNode._left = _add(_thisNode._left, codeUnits, i, value);
      if (_thisNode._left._priority > _thisNode._priority) {
        _thisNode = _rotateRight(_thisNode);
      }
    } else if (codeUnits[i] > _thisNode._codeUnit) {
      _thisNode._right = _add(_thisNode._right, codeUnits, i, value);
      if (_thisNode._right._priority > _thisNode._priority) {
        _thisNode = _rotateLeft(_thisNode);
      }
    } else {
      if (i + 1 < codeUnits.length) {
        _thisNode._mid = _add(_thisNode._mid, codeUnits, i + 1, value);
      } else {
        // Terminal node for this key
        //This is a new key
        _thisNode._values ??= <V>[];

        // If a value has been specified then consider adding it to list
        if (value != null) {
          // Check special case where value is the same as key
          // When this is the case we dont need to store seperatly
          // in value list.
          if (!(treatKeyAsStringValue &&
              V == String &&
              (value as String) == String.fromCharCodes(codeUnits))) {
            // check if value already attached to node
            if (!_thisNode._values.contains(value)) {
              _thisNode._values.add(value);
            }
          }
        }
      }
    }

    return _updateDescendantCounts(_thisNode);
  }

  _Node<V> _updateDescendantCounts(_Node<V> _thisNode) {
    if (_thisNode != null) {
      // Accumulate prefix descendant counts and update own count
      _thisNode._numDFSDescendants =
          (_thisNode._left == null ? 0 : _thisNode._left._sizeDFSTree) +
              (_thisNode._mid == null ? 0 : _thisNode._mid._sizeDFSTree) +
              (_thisNode._right == null ? 0 : _thisNode._right._sizeDFSTree);
    }
    return _thisNode;
  }

  List<V> _remove(
      _Node<V> thisNode, _Node<V> parentNode, List<int> codeUnits, int idx) {
    if (thisNode == null) {
      return null;
    }

    if (codeUnits[idx] < thisNode._codeUnit) {
      final List<V> values = _remove(thisNode._left, thisNode, codeUnits, idx);
      if (values != null) {
        _updateDescendantCounts(thisNode);
      }
      return values;
    } else {
      if (codeUnits[idx] > thisNode._codeUnit) {
        final List<V> values =
            _remove(thisNode._right, thisNode, codeUnits, idx);
        if (values != null) {
          _updateDescendantCounts(thisNode);
        }
        return values;
      } else {
        // This node represents word end for key
        if (idx == (codeUnits.length - 1)) {
          // First check if key exists
          if (!thisNode._isKeyEnd) {
            // Key doesnt exist
            return null;
          }
          // Node has no key descendants
          if (thisNode._numDFSDescendants == 0) {
            // Delete from parent and return
            if (parentNode != null) {
              parentNode._mid = null;
            }
          }
          // Remove end node status
          final List<V> values = thisNode._values;
          thisNode._values = null;
          return values;
        } else {
          final List<V> values =
              _remove(thisNode._mid, thisNode, codeUnits, idx + 1);
          if (values != null) {
            _updateDescendantCounts(thisNode);
          }
          return values;
        }
      }
    }
  }

  _Node<V> _getPrefixLastNode(_Node<V> thisNode, List<int> codeUnits, int idx) {
    if (thisNode == null) {
      return null;
    }

    if (codeUnits[idx] < thisNode._codeUnit) {
      return _getPrefixLastNode(thisNode._left, codeUnits, idx);
    } else {
      if (codeUnits[idx] > thisNode._codeUnit) {
        return _getPrefixLastNode(thisNode._right, codeUnits, idx);
      } else {
        if (idx == (codeUnits.length - 1)) {
          return thisNode;
        } else {
          return _getPrefixLastNode(thisNode._mid, codeUnits, idx + 1);
        }
      }
    }
  }

  //      a            b
  //     / \          / \
  //    b   e   -->  c   a
  //   / \              / \
  //  c   d            d   e
  _Node<V> _rotateRight(_Node<V> a) {
    final _Node<V> b = a._left;
    final _Node<V> d = b._right;

    // Rotate
    a._left = d;
    b._right = a;

    // Adjust descendant counts from bottom up
    _updateDescendantCounts(a);
    _updateDescendantCounts(b);

    return b;
  }

  //     b              a
  //    / \            / \
  //   c   a    -->   b   e
  //      / \        / \
  //     d   e      c   d
  _Node<V> _rotateLeft(_Node<V> b) {
    final _Node<V> a = b._right;
    final _Node<V> d = a._left;

    // Rotate
    b._right = d;
    a._left = b;

    // Adjust descendant counts from bottom up
    _updateDescendantCounts(b);
    _updateDescendantCounts(a);

    return a;
  }
}

class _Node<V> {
  _Node(this._codeUnit, this._priority);

  final int _codeUnit;
  final int _priority;
  // Number of end nodes below this node if a DFS was performed.
  // Allows fast calculation of subtree size
  int _numDFSDescendants = 0;

  // A single node may map to multiple values due to KeyMapping.
  // Is maintained as a set, i.e. only one instance of a
  // particular value is associated with a particular key
  List<V> _values;

  _Node<V> _left;
  _Node<V> _mid;
  _Node<V> _right;

  // Does this node represent the final character of a key?
  bool get _isKeyEnd => _values != null;
  // return number of end nodes in subtree with this node as root
  int get _sizeDFSTree =>
      _values == null ? _numDFSDescendants : _numDFSDescendants + 1;

  // return number of end nodes in subtree with this node as prefix root
  int get _sizePrefixTree {
    int size = _values == null ? 0 : 1;
    if (_mid != null) {
      size += _mid._sizeDFSTree;
    }
    return size;
  }
}
