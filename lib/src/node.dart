library node;

import 'dart:collection';

import 'package:meta/meta.dart';
import 'pool.dart';

/// Stores result of prefix search.
@immutable
class PrefixSearchResult<V> {
  /// Construct new PrefixSearchResult
  PrefixSearchResult(this.prefixCodeUnits, this.node, this.prefixCodeunitIdx,
      this.nodeCodeunitIdx, this.isPrefixMatch, this.depth);

  /// The prefix searched for
  final List<int> prefixCodeUnits;

  /// Node at which search terminated.
  final Node<V> node;

  /// The final matching codeunit index in prefix.
  final int prefixCodeunitIdx;

  /// The final matching codeunit index in [node].
  final int nodeCodeunitIdx;

  /// Is true then the prefix was fully matched.
  final bool isPrefixMatch;

  /// Depth of node from search root
  final int depth;

  @override
  String toString() =>
      'Node: $node, prefixCodeunitIdx: $prefixCodeunitIdx, nodeCodeunitIdx: $nodeCodeunitIdx, isPrefixMatch:$isPrefixMatch';
}

/// Base for all node types
abstract class Node<V> {
  /// Construct new Node
  Node(Iterable<int> codeUnits, this.priority, this.parent,
      final HashSet<CodeUnitPoolEntry> _codeUnitPool)
      : codeUnits = allocateCodeUnits(codeUnits, _codeUnitPool);

  /// Release node resources
  void destroy(final HashSet<CodeUnitPoolEntry> _codeUnitPool) {
    freeCodeUnits(codeUnits, _codeUnitPool);
  }

  /// Avoids the need for an empty valued [Node]
  /// to incur space overhead of empty container which is presumably greater
  /// in memory usage than a reference to this shared iterator.
  static const Object _emptyValues = Object();

  /// Reference to fixed size array of unicode code units stored in pool
  List<int> codeUnits;

  /// Randomly generated value for balancing
  /// May be changed later when reducing node proximity to root.
  int priority;

  /// Number of end nodes below this node if a DFS was performed.
  /// Allows fast calculation of subtree size
  int numDFSDescendants = 0;

  /// Left child
  Node<V> left;

  /// Mid child
  Node<V> mid;

  /// Right child
  Node<V> right;

  /// Costs space but much faster than maintaining explicit stack.
  /// during add operation. Maybe can use for near neighbour or something.
  Node<V> parent;

  /// A single node may map to multiple values.
  /// How this is managed depends on Node sub class.
  /// If null then is not end node
  Object _values;

  /// If node is not already key End then set as key end
  ///
  /// If node was already a key end then returns true, falsde otherwaise.
  bool setAsKeyEnd() {
    if (_values == null) {
      _values = _emptyValues;
      return true;
    } else {
      return false;
    }
  }

  /// Remove key end status from node
  void clearKeyEnd() {
    _values = null;
  }

  /// Take reference to values from other node removing
  /// its keyend status in the process.
  void takeValues(Node<V> other) {
    _values = other._values;
    other._values = null;
  }

  /// Return first value that is equal to [value]
  ///
  /// If not found return null.
  V lookupValue(V value);

  /// Set to shallow copy of [values]
  void setValues(Iterable<V> values);

  /// Add a single [value] to the node
  void addValue(V value);

  /// Remove a single [value]  the node
  bool removeValue(V value);

  /// Remove all values from this node and return said values.
  Iterable<V> removeValues();

  /// Return Node values
  Iterable<V> get values;

  /// Does this node represent the final character of a key?
  bool get isKeyEnd => _values != null;

  /// return number of end nodes in subtree with this node as root
  int get sizeDFSTree =>
      _values == null ? numDFSDescendants : numDFSDescendants + 1;

  /// return number of end nodes in subtree with this node as prefix root
  int get sizePrefixTree {
    var size = _values == null ? 0 : 1;
    if (mid != null) {
      size += mid.sizeDFSTree;
    }

    return size;
  }

  /// Set codeunits to fixed size array
  void setCodeUnits(Iterable<int> codeUnits,
      final HashSet<CodeUnitPoolEntry> _codeUnitPool) {
    freeCodeUnits(this.codeUnits, _codeUnitPool);
    this.codeUnits = allocateCodeUnits(codeUnits, _codeUnitPool);
  }

  /// Return _Node descendant corresponding to a transformed key.
  /// Returns null if key does not map to a node.
  /// Assumes key has already been transformed by KeyMapping
  Node<V> getKeyNode(String transformedKey) {
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
  /// Return [PrefixSearchResult] where:
  ///
  /// * [PrefixSearchResult.node] = Node containing end of prefix or closest to it. Equal to this node if no match found.
  /// * [PrefixSearchResult.prefixCodeunitIdx] = The index of final matching prefix codeunit
  /// or [_INVALID_CODE_UNIT] if prefix not processed at all.
  /// * [PrefixSearchResult.nodeCodeunitIdx] = The index of final matching node codeunit.
  /// * [PrefixSearchResult.isPrefixMatch] = true if full match was found otherwise false.
  PrefixSearchResult<V> getClosestPrefixDescendant(
      final List<int> prefixCodeUnits) {
    assert(prefixCodeUnits != null);
    final prefixCodeUnitsLength = prefixCodeUnits.length;

    Node<V> closestNode;
    var nextNode = this;
    var prefixIdx = 0;
    var codeUnitIdx = 0;
    var depth = -1;

    var prefixCodeUnit = prefixCodeUnits[prefixIdx];

    while (true) {
      if (nextNode == null) {
        return PrefixSearchResult<V>(prefixCodeUnits, closestNode,
            prefixIdx - 1, codeUnitIdx - 1, false, depth);
      }

      depth++;

      final codeUnits = nextNode.codeUnits;

      // Compare current prefix unit to first unit of new node
      // All nodes have at least one code unit so this wont go out of bounds
      if (prefixCodeUnit < codeUnits[0]) {
        nextNode = nextNode.left;
      } else if (prefixCodeUnit > codeUnits[0]) {
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
        while (prefixIdx < prefixCodeUnitsLength &&
            codeUnitIdx < codeUnits.length &&
            codeUnits[codeUnitIdx] == prefixCodeUnits[prefixIdx]) {
          codeUnitIdx++;
          prefixIdx++;
        }

        if (prefixIdx == prefixCodeUnitsLength) {
          // Found match in current node!
          return PrefixSearchResult<V>(prefixCodeUnits, closestNode,
              prefixIdx - 1, codeUnitIdx - 1, true, depth);
        }

        prefixCodeUnit = prefixCodeUnits[prefixIdx];

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
  void updateChild(Node<V> oldChild, Node<V> newChild) {
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
  Node<V> rotateIfNeeded() {
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
  Node<V> rotateLeft() {
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
  Node<V> rotateRight() {
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
  void mergeMid(final HashSet<CodeUnitPoolEntry> _codeUnitPool) {
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

    setCodeUnits(codeUnits + child.codeUnits, _codeUnitPool);

    // Take on mid grandchild
    mid = child.mid;

    // Node takes on child values/keyend status
    // If child was a key node then node has 1 less descendant
    if (child.isKeyEnd) {
      _values = child._values;
      // Child has been absorbed so 1 less descendant
      numDFSDescendants--;
    }

    if (mid != null) {
      mid.parent = this;
    }
    child.destroy(_codeUnitPool);
  }

  @override
  String toString() => '${String.fromCharCodes(codeUnits)}';
}

/// A Node that stores values in [Set].
class NodeSet<V> extends Node<V> {
  /// Constrcut a NodeSet
  NodeSet(Iterable<int> codeUnits, int priority, Node<V> parent,
      final HashSet<CodeUnitPoolEntry> _codeUnitPool)
      : super(codeUnits, priority, parent, _codeUnitPool);

  @override
  Set<V> get values =>
      identical(_values, Node._emptyValues) ? <V>{} : super._values as Set<V>;

  @override
  V lookupValue(V value) => values.lookup(value);

  @override
  void setValues(Iterable<V> values) {
    _values = Set<V>.from(values);
  }

  @override
  bool removeValue(V value) =>
      identical(_values, Node._emptyValues) ? false : values.remove(value);

  @override
  Set<V> removeValues() {
    if (identical(_values, Node._emptyValues)) {
      return <V>{};
    }
    final ret = values;
    _values = Node._emptyValues;
    return ret;
  }

  @override
  void addValue(V value) {
    if (identical(_values, Node._emptyValues)) {
      setValues([value]);
    } else {
      (_values as Set<V>).add(value);
    }
  }
}

/// A Node that stores values in [List].
class NodeList<V> extends Node<V> {
  /// Construct a NodeList
  NodeList(Iterable<int> codeUnit, int priority, Node<V> parent,
      final HashSet<CodeUnitPoolEntry> _codeUnitPool)
      : super(codeUnit, priority, parent, _codeUnitPool);

  @override
  List<V> get values =>
      identical(_values, Node._emptyValues) ? <V>[] : super._values as List<V>;

  @override
  V lookupValue(V value) {
    for (final val in values) {
      if (val == value) {
        return val;
      }
    }
    return null;
  }

  @override
  void setValues(Iterable<V> values) {
    _values = List<V>.from(values);
  }

  @override
  bool removeValue(V value) => identical(_values, Node._emptyValues)
      ? false
      : (_values as Set<V>).remove(value);

  @override
  List<V> removeValues() {
    if (identical(_values, Node._emptyValues)) {
      return <V>[];
    }

    final ret = values;
    _values = Node._emptyValues;
    return ret;
  }

  @override
  void addValue(V value) {
    if (identical(_values, Node._emptyValues)) {
      setValues([value]);
    } else {
      values.add(value);
    }
  }
}
