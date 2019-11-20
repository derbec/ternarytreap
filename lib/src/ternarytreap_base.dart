import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';

const _maxSafeInteger = 9007199254740991;

/// A function mapping a string to a key.
///
/// This is applied before all operations.
/// For example a mapping may be defined between the set of strings
/// and their lowercase equivilents see: [TernaryTreap.lowercase]
typedef KeyMapping = String Function(String str);

// Visitor pattern signature
// Return value allows early stopping
// if return is true then traversal continues.
// if return is false traversal stops.
typedef _NodeVisitor<V> = bool Function(
    _Node<V> thisNode, String currentStr, int currentDepth);

class _TernaryTreeKeyIterable<V> extends IterableMixin<String> {
  _TernaryTreeKeyIterable(this._owner);
  final TernaryTreap<V> _owner;

  @override
  int get length => _owner.length;
  @override
  bool get isEmpty => _owner.isEmpty;

  @override
  Iterator<String> get iterator =>
      _TernaryTreeKeyIterator<V>(_owner, _owner._root);
}

class _TernaryTreeValueIterable<V> extends IterableMixin<List<V>> {
  _TernaryTreeValueIterable(this._owner);
  final TernaryTreap<V> _owner;

  @override
  int get length => _owner.length;
  @override
  bool get isEmpty => _owner.isEmpty;

  @override
  Iterator<List<V>> get iterator =>
      _TernaryTreeValueIterator<V>(_owner, _owner._root);
}

class _TernaryTreeMapEntryIterable<V>
    extends IterableMixin<MapEntry<String, List<V>>> {
  _TernaryTreeMapEntryIterable(this._owner);
  final TernaryTreap<V> _owner;

  @override
  int get length => _owner.length;
  @override
  bool get isEmpty => _owner.isEmpty;

  @override
  Iterator<MapEntry<String, List<V>>> get iterator =>
      _TernaryTreeMapEntryIterator<V>(_owner, _owner._root);
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
    if (root == null) {
      throw ArgumentError.notNull('root');
    }
    if (prefix == null) {
      throw ArgumentError.notNull('prefix');
    }

    _pushAllLeft(_StackFrame<V>(root, prefix));
  }

  final ListQueue<_StackFrame<V>> _stack = ListQueue<_StackFrame<V>>();

  final TernaryTreap<V> _owner;

  final int _ownerStartingVersion;

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
  bool moveNext() {
    if (_owner._version != _ownerStartingVersion) {
      throw ConcurrentModificationError(_owner);
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

      if (context.node._isEnd) {
        _currentKey =
            context.prefix + String.fromCharCode(context.node._codeUnit);
        _currentValue = context.node.values;
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

/// Iterate through keys
class _TernaryTreeValueIterator<V> extends _TernaryTreeIteratorBase<V>
    implements Iterator<List<V>> {
  /// Construct new [_TernaryTreeKeyIterator]
  _TernaryTreeValueIterator(TernaryTreap<V> owner, _Node<V> root)
      : super(owner, root);

  @override
  List<V> get current => _currentValue;
}

/// Iterate through keys
class _TernaryTreeMapEntryIterator<V> extends _TernaryTreeIteratorBase<V>
    implements Iterator<MapEntry<String, List<V>>> {
  /// Construct new [_TernaryTreeKeyIterator]
  _TernaryTreeMapEntryIterator(TernaryTreap<V> owner, _Node<V> root)
      : super(owner, root);

  @override
  MapEntry<String, List<V>> get current => MapEntry(_currentKey, _currentValue);
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
  /// @returns New [TernaryTreap].
  TernaryTreap([KeyMapping keyMapping]) : _keyMapping = keyMapping;

  /// Key for stats map.
  ///
  /// Maximum [_Node] depth.
  static const String depth = 'depth';

  /// Key for stats map node count value.
  ///
  /// Total number of [_Node] objects.
  static const String nodeCount = 'nodecount';

  /// Key for stats map key count value.
  ///
  /// Number of unique keys
  static const String keyCount = 'keycount';

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
  final KeyMapping _keyMapping;
  _Node<V> _root;
  int _numKeys = 0;
  int _version = 0;

  @override
  int get length => _numKeys;

  int get length2 => _root.numDecendants;

  @override
  bool get isEmpty => _numKeys == 0;

  @override
  bool get isNotEmpty => _numKeys > 0;

  @override
  bool containsKey(Object key) => this[key] != null;

  @override
  Iterable<String> get keys => _TernaryTreeKeyIterable<V>(this);

  @override
  Iterable<List<V>> get values => _TernaryTreeValueIterable<V>(this);

  @override
  Iterable<MapEntry<String, List<V>>> get entries =>
      _TernaryTreeMapEntryIterable<V>(this);

  /// Insert a key and optional value.
  ///
  /// @param [key] A unique sequence of characters to be stored for retrieval.
  /// @param [value] A user specified value to associate with this key.
  /// The value is checked against existing entries for this key (==) and
  /// if already associated with the key is not added. @see [_Node.values]
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
  void forEach(void Function(String key, List<V> values) f) {
    _inorderTraversalFromNode(_root, '', 0,
        (_Node<V> thisNode, String currentStr, int currentDepth) {
      if (thisNode._isEnd) {
        f(currentStr, thisNode.values);
      }
      return true;
    });
  }

  /// Applies [f] to each key/value pair of the [TernaryTreap]
  /// where key (after [KeyMapping] applied) is prefixed by [prefix].
  ///
  /// Calling [f] must not add or remove keys from the [TernaryTreap]
  /// The return value of [f] is used for early stopping.
  /// This is useful when only a subset of the entire resultset is required.
  /// When [f] returns true iteration continues.
  /// When [f] returns false iteration stops.
  /// @throws ArgumentError if [prefix] is empty
  void forEachPrefixedBy(
      String prefix, bool Function(String key, List<V> value) f) {
    if (prefix.isEmpty) {
      throw ArgumentError();
    }

    final String prefixMapped = _transformKey(prefix);
    //Traverse from last node of prefix
    final _Node<V> lastPrefixNode =
        _descendToPrefixLastNode(_root, prefixMapped.codeUnits, 0);
    _prefixTraversalFromNode(lastPrefixNode, '', 0,
        (_Node<V> thisNode, String currentStr, int currentDepth) {
      if (thisNode._isEnd) {
        return f(prefixMapped + currentStr, thisNode.values);
      } else {
        return true;
      }
    });
  }

  /// Return value for specified [key].
  ///
  /// @param [key] The key to get.
  /// @returns List of values corresponding to [key].
  /// If no value associated with key then return empty [List].
  /// If key found then return null.
  @override
  List<V> operator [](Object key) {
    if (!(key is String)) {
      throw ArgumentError();
    }
    final String keyMapped = _transformKey(key as String);
    final _Node<V> lastPrefixNode =
        _descendToPrefixLastNode(_root, keyMapped.codeUnits, 0);
    if (lastPrefixNode == null) {
      return null;
    }
    assert(lastPrefixNode._isEnd, 'Not at word end');
    return lastPrefixNode.values;
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
    _inorderTraversalFromNode(_root, '', 0,
        (_Node<V> thisNode, String currentStr, int currentDepth) {
      if (thisNode._isEnd) {
        final String keyPadding =
            ''.padLeft(currentDepth + 1 - currentStr.length, paddingChar);
        final String valuePadding = ''.padLeft(keyPadding.length, ' ');
        lines.writeln(keyPadding + currentStr);
        for (final V datum in thisNode.values) {
          lines.writeln(valuePadding + datum.toString());
        }
      }
      return true;
    });
    return lines.toString();
  }

  /// Generate stats for this [TernaryTreap].
  ///
  /// @returns A [Map] with statistical info accessed via keys:
  ///   * [depth] - Maximum [_Node] depth.
  ///   * [nodeCount] - Total number of [_Node] objects.
  ///   * [keyCount] - Total number of unique keys.
  Map<String, int> stats() {
    int depth = 0;
    int nodeCount = 0;
    int keyCount = 0;
    _inorderTraversalFromNode(_root, '', 0,
        (_Node<V> thisNode, String currentStr, int currentDepth) {
      if (currentDepth > depth) {
        depth = currentDepth;
      }
      nodeCount++;
      if (thisNode._isEnd) {
        keyCount++;
      }
      return true;
    });
    return <String, int>{
      TernaryTreap.depth: depth,
      TernaryTreap.nodeCount: nodeCount,
      TernaryTreap.keyCount: keyCount
    };
  }

  // increment modification version
  void _incVersion() =>
      _version = (_version >= _maxSafeInteger) ? 0 : _version + 1;

  // Map key using specified [KeyMapping]
  String _transformKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError();
    }

    return _keyMapping == null ? key : _keyMapping(key);
  }

  _Node<V> _add(_Node<V> thisNode, List<int> codeUnits, int i, dynamic value) {
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
        if (_thisNode.values == null) {
          //This is a new key
          _thisNode.values ??= <V>[];
          _numKeys++;
        }

        if (value != null) {
          // check if value already attached to node
          // prevent duplicates.
          if (!_thisNode.values.contains(value)) {
            _thisNode.values.add(value as V);
          }
        }
      }
    }

    _updateDescendantCounts(_thisNode);

    return _thisNode;
  }

  void _updateDescendantCounts(_Node<V> _thisNode) {
    // Accumulate descendant counts and update own count
    _thisNode.numDecendants = (_thisNode._left == null
            ? 0
            : (_thisNode._left.numDecendants +
                (_thisNode._left._isEnd ? 1 : 0))) +
        (_thisNode._mid == null
            ? 0
            : (_thisNode._mid.numDecendants +
                (_thisNode._mid._isEnd ? 1 : 0))) +
        (_thisNode._right == null
            ? 0
            : (_thisNode._right.numDecendants +
                (_thisNode._right._isEnd ? 1 : 0)));
  }

  _Node<V> _descendToPrefixLastNode(
      _Node<V> thisNode, List<int> codeUnits, int ptr) {
    if (thisNode == null) {
      return null;
    }

    if (codeUnits[ptr] < thisNode._codeUnit) {
      return _descendToPrefixLastNode(thisNode._left, codeUnits, ptr);
    } else {
      if (codeUnits[ptr] > thisNode._codeUnit) {
        return _descendToPrefixLastNode(thisNode._right, codeUnits, ptr);
      } else {
        if (ptr == (codeUnits.length - 1)) {
          return thisNode;
        } else {
          return _descendToPrefixLastNode(thisNode._mid, codeUnits, ptr + 1);
        }
      }
    }
  }

  void _inorderTraversalFromNode(_Node<V> thisNode, String currentStr,
      int currentDepth, _NodeVisitor<V> visitor) {
    if (thisNode != null) {
      _inorderTraversalFromNode(
          thisNode._left, currentStr, currentDepth + 1, visitor);
      final String nextStr =
          currentStr + String.fromCharCode(thisNode._codeUnit);
      // allow early stopping by visitor
      if (!visitor(thisNode, nextStr, currentDepth)) {
        return;
      }
      _inorderTraversalFromNode(
          thisNode._mid, nextStr, currentDepth + 1, visitor);
      _inorderTraversalFromNode(
          thisNode._right, currentStr, currentDepth + 1, visitor);
    }
  }

  void _prefixTraversalFromNode(_Node<V> thisNode, String currentStr,
      int currentDepth, _NodeVisitor<V> visitor) {
    if (thisNode != null) {
      // Allow early stopping by visitor
      if (!visitor(thisNode, currentStr, currentDepth)) {
        return;
      }
      _inorderTraversalFromNode(
          thisNode._mid, currentStr, currentDepth + 1, visitor);
    }
  }

  //      a            b
  //     / \          / \
  //    b   e   -->  c   a
  //   / \              / \
  //  c   d            d   e
  _Node<V> _rotateRight(_Node<V> a) {
    final _Node<V> b = a._left;
    final _Node<V> c = b._left;
    final _Node<V> d = b._right;
    final _Node<V> e = a._right;

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
    final _Node<V> c = b._left;
    final _Node<V> d = a._left;
    final _Node<V> e = a._right;

    // Rotate
    b._right = d;
    a._left = b;

    // Adjust descendant counts from bottom up
    _updateDescendantCounts(b);
    _updateDescendantCounts(a);

    return a;
  }

  @override
  void operator []=(String key, List<V> value) {
    // TODO: implement []=
  }

  @override
  void clear() {
    // TODO: implement clear
  }

  @override
  List<V> remove(Object key) {
    // TODO: implement remove
    return null;
  }
}

class _Node<V> {
  _Node(this._codeUnit, this._priority);

  final int _codeUnit;
  final int _priority;
  int numDecendants = 0; //Number of end nodes below this node.

  // A single node may map to multiple values due to KeyMapping.
  // Is maintained as a set, i.e. only one instance of a
  // particular value is associated with a particular key
  List<V> values;

  _Node<V> _left;
  _Node<V> _mid;
  _Node<V> _right;

  bool get _isEnd => values != null;
}
