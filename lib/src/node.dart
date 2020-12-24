library node;

import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'pool.dart';

/// (2^32)
const int _MAX_PRIORITY = 4294967296;

/// Stores result of prefix search.
@immutable
class PrefixSearchResult<V> {
  /// Construct new PrefixSearchResult
  PrefixSearchResult(this.prefixRunes, this.node, this.prefixRuneIdx,
      this.nodeRuneIdx, this.isPrefixMatch);

  /// The prefix searched for
  final List<int> prefixRunes;

  /// Node at which search terminated.
  final Node<V> node;

  /// The final matching rune index in prefix.
  final int prefixRuneIdx;

  /// The final matching rune index in [node].
  final int nodeRuneIdx;

  /// Is true then the prefix was fully matched.
  final bool isPrefixMatch;

  @override
  String toString() =>
      'Node: $node, prefixRuneIdx: $prefixRuneIdx, nodeRuneIdx: $nodeRuneIdx, isPrefixMatch:$isPrefixMatch';
}

final _listEquality = ListEquality();
final _setEquality = SetEquality();

/// Determine equality of nodes
/// [Node] is equivilent to [other] node if:
/// * parent status is same
/// * child status is same
/// * keyEnd status is same
/// * runes are same
/// * values collection type and content are same
/// * decendant count are same
/// * subtree is same
bool nodeEquality(Node? e1, Node? e2) {
  // If both are null or same object then true
  if (identical(e1, e2)) {
    return true;
  }
  // If only 1 null then false
  if (identical(e1, null) || identical(e2, null)) {
    return false;
  }

  return
      // Compare parent status
      (e1.hasParent == e2.hasParent) &&
          // Compare child status
          (e1.hasLeft == e2.hasLeft) &&
          (e1.hasMid == e2.hasMid) &&
          (e1.hasRight == e2.hasRight) &&
          // Compare keyEnd
          (e1.isKeyEnd == e2.isKeyEnd) &&
          // Compare descendant count
          (e1.numDFSDescendants == e2.numDFSDescendants) &&
          // Compare runes
          (_listEquality.equals(e1.runes, e2.runes)) &&
          // Compare types and values
          ((e1 is NodeList &&
                  e2 is NodeList &&
                  _listEquality.equals(e1.values, e2.values)) ||
              ((e1 is NodeSet &&
                  e2 is NodeSet &&
                  _setEquality.equals(e1.values, e2.values)))) &&
          // Compare subtree
          nodeEquality(e1.left, e2.left) &&
          nodeEquality(e1.mid, e2.mid) &&
          nodeEquality(e1.right, e2.right);
}

/// Pointer to function for generating [Node] objects
typedef NodeFactory<V> = Node<V> Function(
    Iterable<int> runes,
    Random priorityGenerator,
    Node<V>? parent,
    HashSet<RunePoolEntry> _runePool);

/// Pointer to function for generating [Node] objects from json
typedef JsonNodeFactory<V> = Node<V> Function(
    List<dynamic> json,
    Random priorityGenerator,
    Node<V>? parent,
    HashSet<RunePoolEntry> _runePool);

/// A Node that stores values in [Set].
class NodeSet<V> extends Node<V> {
  /// Construct a NodeSet representing specified runes
  NodeSet(Iterable<int> runes, Random priorityGenerator, Node<V>? parent,
      HashSet<RunePoolEntry> _runePool)
      : super(runes, priorityGenerator, parent, _runePool);

  /// Construct a NodeSet from [other] with parent [parent]
  NodeSet.from(Node<V> other, Node<V>? parent, HashSet<RunePoolEntry> _runePool)
      : super.from(other, parent, _runePool) {
    final otherLeft = other.left,
        otherMid = other.mid,
        otherRight = other.right;

    left = identical(otherLeft, null)
        ? null
        : NodeSet.from(otherLeft, this, _runePool);

    mid = identical(otherMid, null)
        ? null
        : NodeSet.from(otherMid, this, _runePool);

    right = identical(otherRight, null)
        ? null
        : NodeSet.from(otherRight, this, _runePool);
  }

  /// Construct a NodeSet from the given Json
  factory NodeSet.fromJson(List<dynamic> json, Random priorityGenerator,
      Node<V>? parent, HashSet<RunePoolEntry> _runePool) {
    if (json.isEmpty) {
      throw ArgumentError.value(json, 'json', 'Empty json');
    }

    final runes = json[0].toString().runes.toList();

    return NodeSet(runes, priorityGenerator, parent, _runePool)
      .._setFromJson(json);
  }

  @override
  Set<V> get values =>
      identical(_values, null) || identical(_values, Node._emptyValues)
          ? <V>{}
          : super._values as Set<V>;

  /// Return values as a Json encodable type
  @override
  Iterable<dynamic> valuesToJson(dynamic Function(V value) toEncodable) =>
      values.map((e) => toEncodable(e)).toList();

  @override
  V? lookupValue(V value) => values.lookup(value);

  @override
  Object _createValuesCollection(Iterable<V> values) => Set<V>.from(values);

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
  bool addValue(V value) {
    if (identical(_values, Node._emptyValues)) {
      // Currently set to empty values.
      setValues([value]);
      return true;
    } else {
      return (_values as Set<V>).add(value);
    }
  }
}

/// A Node that stores values in [List].
class NodeList<V> extends Node<V> {
  /// Construct a NodeList
  NodeList(Iterable<int> rune, Random priorityGenerator, Node<V>? parent,
      HashSet<RunePoolEntry> _runePool)
      : super(rune, priorityGenerator, parent, _runePool);

  /// Construct a NodeList from [other]
  NodeList.from(
      Node<V> other, Node<V>? parent, HashSet<RunePoolEntry> _runePool)
      : super.from(other, parent, _runePool) {
    final otherLeft = other.left,
        otherMid = other.mid,
        otherRight = other.right;
    left = identical(otherLeft, null)
        ? null
        : NodeList.from(otherLeft, this, _runePool);

    mid = identical(otherMid, null)
        ? null
        : NodeList.from(otherMid, this, _runePool);

    right = identical(otherRight, null)
        ? null
        : NodeList.from(otherRight, this, _runePool);
  }

  /// Construct a NodeSet from the given Json
  factory NodeList.fromJson(List<dynamic> json, Random priorityGenerator,
      Node<V>? parent, HashSet<RunePoolEntry> _runePool) {
    if (json.isEmpty) {
      throw ArgumentError.value(json, 'json', 'Empty json');
    }

    final runes = json[0].toString().runes.toList();

    return NodeList(runes, priorityGenerator, parent, _runePool)
      .._setFromJson(json);
  }

  @override
  List<V> get values =>
      identical(_values, null) || identical(_values, Node._emptyValues)
          ? <V>[]
          : super._values as List<V>;

  @override
  V? lookupValue(V value) {
    for (final val in values) {
      if (val == value) {
        return val;
      }
    }
    return null;
  }

  @override
  Object _createValuesCollection(Iterable<V> values) => List<V>.from(values);

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
  bool addValue(V value) {
    if (identical(_values, Node._emptyValues)) {
      // Node currently has empty value
      setValues([value]);
      return true;
    } else {
      values.add(value);
      // Adding to list always changes list
      return true;
    }
  }
}

/// Base for all node types
abstract class Node<V> {
  /// Construct new Node
  Node(Iterable<int> runes, Random priorityGenerator, this.parent,
      final HashSet<RunePoolEntry> _runePool)
      : runes = allocateRunes(runes, _runePool),
        priority = priorityGenerator.nextInt(_MAX_PRIORITY);

  /// Construct new node from [other]
  Node.from(Node<V> other, this.parent, final HashSet<RunePoolEntry> _runePool)
      : assert(!identical(other, null)),
        assert(!identical(_runePool, null)),
        runes = allocateRunes(other.runes, _runePool),
        priority = other.priority,
        numDFSDescendants = other.numDFSDescendants {
    if (other.isKeyEnd) {
      setAsKeyEnd();
      setValues(other.values);
    }
  }

  /// Release resources of node and all children
  void destroy(HashSet<RunePoolEntry> _runePool) {
    freeRunes(runes, _runePool);
    // Don't forget children!
    left?.destroy(_runePool);
    mid?.destroy(_runePool);
    right?.destroy(_runePool);
  }

  /// Shared amongst empty valued key nodes.
  static const Object _emptyValues = Object();

  /// Reference to fixed size array of unicode code units stored in pool
  List<int> runes;

  /// Randomly generated value for balancing
  /// May be changed later when reducing node proximity to root.
  int priority;

  /// Number of end nodes below this node if a DFS was performed.
  /// Allows fast calculation of subtree size
  int numDFSDescendants = 0;

  /// Left child
  Node<V>? left;

  /// Mid child
  Node<V>? mid;

  /// Right child
  Node<V>? right;

  /// Costs space but much faster than maintaining explicit stack.
  /// during add operation and useful for near neighbour search.
  Node<V>? parent;

  /// A single node may map to multiple values.
  /// How this is managed depends on Node sub class.
  /// If null then is not end node
  Object? _values;

  /// If node is not already key End then set as key end
  ///
  /// If node was not already a key end then returns true, false otherwaise.
  bool setAsKeyEnd() {
    if (identical(_values, null)) {
      _values = _emptyValues;
      return true;
    }
    return false;
  }

  /// Return Map for Json conversion
  ///
  /// If [includeValues] is true then values are included.
  List<dynamic> toJson(
      bool includeValues, dynamic Function(V value) toEncodable) {
    includeValues &= isKeyEnd;
    final json = <dynamic>[];
    json.add(String.fromCharCodes(runes));
    if (isKeyEnd) {
      if (includeValues) {
        json.add(valuesToJson(toEncodable));
      } else {
        // Empty collection specifies keyend
        json.add([]);
      }
    }

    return json;
  }

  /// Return values as a Json encodable type
  Iterable<dynamic> valuesToJson(dynamic Function(V value) toEncodable) =>
      values.map((e) => toEncodable(e)).toList();

  /// Remove key end status from node
  void clearKeyEnd() {
    _values = null;
  }

  /// Take keyend status from [other].
  void takeKeyEnd(Node<V> other) {
    _values = other._values;
    other._values = null;
  }

  /// Return first value that is equal to [value]
  ///
  /// If not found return null.
  V? lookupValue(V value);

  /// Set to shallow copy of [values]
  void setValues(Iterable<V> values) {
    assert(isKeyEnd);
    _values =
        values.isEmpty ? Node._emptyValues : _createValuesCollection(values);
  }

  Object _createValuesCollection(Iterable<V> values);

  /// Add a single [value] to the node
  /// Return true if value collection has changed.
  /// Return false if value collection is unchanged.
  bool addValue(V value);

  /// Add all values to node
  void addValues(Iterable<V> values) {
    for (final value in values) {
      addValue(value);
    }
  }

  /// Remove a single [value]  the node
  bool removeValue(V value);

  /// Remove all values from this node and return said values.
  Iterable<V> removeValues();

  /// Return Node values
  Iterable<V> get values;

  /// Does this node represent the final character of a key?
  bool get isKeyEnd => !identical(_values, null);

  /// Does this node have a parent node?
  bool get hasParent => !identical(parent, null);

  /// Does this node have a left node?
  bool get hasLeft => !identical(left, null);

  /// Does this node have a left node?
  bool get hasMid => !identical(mid, null);

  /// Does this node have a left node?
  bool get hasRight => !identical(right, null);

  /// return number of end nodes in subtree with this node as root
  int get sizeDFSTree =>
      identical(_values, null) ? numDFSDescendants : numDFSDescendants + 1;

  /// return number of end nodes in subtree with this node as prefix root
  int get sizePrefixTree =>
      (identical(_values, null) ? 0 : 1) + (mid?.sizeDFSTree ?? 0);

  /// Set runes to fixed size array
  void setRunes(Iterable<int> runes, final HashSet<RunePoolEntry> _runePool) {
    freeRunes(this.runes, _runePool);
    this.runes = allocateRunes(runes, _runePool);
  }

  /// Return _Node descendant corresponding to a transformed key.
  /// Returns null if key does not map to a node.
  /// Assumes key has already been transformed by KeyMapping
  Node<V>? getKeyNode(String transformedKey) {
    if (transformedKey.isEmpty) {
      return null;
    }

    final prefixDescendant =
        getClosestPrefixDescendant(transformedKey.runes.toList());

    // The node must represent only this key
    if (!prefixDescendant.isPrefixMatch ||
        prefixDescendant.nodeRuneIdx !=
            prefixDescendant.node.runes.length - 1 ||
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
  /// * [PrefixSearchResult.prefixRuneIdx] = The index of final matching prefix rune
  /// or [_INVALID_CODE_UNIT] if prefix not processed at all.
  /// * [PrefixSearchResult.nodeRuneIdx] = The index of final matching node rune.
  /// * [PrefixSearchResult.isPrefixMatch] = true if full match was found otherwise false.
  PrefixSearchResult<V> getClosestPrefixDescendant(
      final List<int> prefixRunes) {
    assert(!identical(prefixRunes, null));
    final prefixRunesLength = prefixRunes.length;

    var closestNode = this;
    Node<V>? nextNode = this;
    var prefixIdx = 0;
    var runeIdx = 0;
    //var depth = -1;

    var prefixRune = prefixRunes[prefixIdx];

    while (true) {
      if (identical(nextNode, null)) {
        return PrefixSearchResult<V>(
            prefixRunes, closestNode, prefixIdx - 1, runeIdx - 1, false);
      }

      final runes = nextNode.runes;

      // Compare current prefix unit to first unit of new node
      // All nodes have at least one code unit so this wont go out of bounds
      if (prefixRune < runes[0]) {
        nextNode = nextNode.left;
      } else if (prefixRune > runes[0]) {
        nextNode = nextNode.right;
      } else {
        // There is a match between prefix unit and first code unit of this node
        // so this is the closest match node currently
        closestNode = nextNode;

        // Continue matching for this node
        runeIdx = 1;
        prefixIdx++;
        nextNode = null;

        // The prefix may live in this node or its mid descendants
        // Match with this nodes runes
        while (prefixIdx < prefixRunesLength &&
            runeIdx < runes.length &&
            runes[runeIdx] == prefixRunes[prefixIdx]) {
          runeIdx++;
          prefixIdx++;
        }

        if (prefixIdx == prefixRunesLength) {
          // Found match in current node!
          return PrefixSearchResult<V>(
              prefixRunes, closestNode, prefixIdx - 1, runeIdx - 1, true);
        }

        prefixRune = prefixRunes[prefixIdx];

        if (runeIdx == runes.length) {
          // Made it to end of node runes.
          // Hunt for rest of prefix down mid child.
          nextNode = closestNode.mid;
        }
      }
    }
  }

  /// Accumulate prefix descendant counts and update own count
  void updateDescendantCounts() {
    numDFSDescendants = (left?.sizeDFSTree ?? 0) +
        (mid?.sizeDFSTree ?? 0) +
        (right?.sizeDFSTree ?? 0);
  }

  /// Adjust priority relationship with the specified child
  void adjustPrioritiesForChild(Node<V>? child) {
    if (!identical(child, null)) {
      assert(identical(child.parent, this));
      if (child.priority > priority) {
        final tmp = priority;
        priority = child.priority;
        child.priority = tmp;
      }
    }
  }

  /// Update [oldChild] with [newChild]
  void updateChild(Node<V> oldChild, Node<V>? newChild) {
    if (identical(left, oldChild)) {
      left = newChild;
    } else if (identical(mid, oldChild)) {
      mid = newChild;
    } else if (identical(right, oldChild)) {
      right = newChild;
    } else {
      throw Error();
    }
  }

  /// Delete [child] from this node
  void deleteChild(Node<V> child, HashSet<RunePoolEntry> runePool) {
    updateChild(child, null);
    child.destroy(runePool);
  }

  /// If children exist then rotate if needed.
  void rotateChildren() {
    left = left?.rotateIfNeeded();
    right = right?.rotateIfNeeded();
  }

  /// Rotate node tree if needed to maintain
  /// heap invarient:
  ///
  /// ([left.priority] < [priority]) &&
  /// ([right.priority] <[priority])
  ///
  /// Return possibly new root of rotated node tree
  Node<V> rotateIfNeeded() {
    final left = this.left, right = this.right;
    if (!identical(left, null) && left.priority > priority) {
      return rotateRight();
    }

    if (!identical(right, null) && right.priority > priority) {
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

    if (identical(a, null)) {
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

    if (!identical(d, null)) {
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

    if (identical(b, null)) {
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

    if (!identical(d, null)) {
      d.parent = a;
    }

    // Adjust descendant counts from bottom up
    a.updateDescendantCounts();
    b.updateDescendantCounts();

    return b;
  }

  /// Merge node and mid child such that:
  /// * runes becomes runes + mid.runes.
  /// * node takes on all children of mid.
  /// * node takes on values children of mid.
  ///
  /// Operation only performed if:
  /// * mid is not null.
  /// * is not an end node.
  /// * child has no Left or Right children.
  void mergeMid(final HashSet<RunePoolEntry> _runePool) {
    if (identical(mid, null)) {
      // No child to merge
      return;
    }

    if (isKeyEnd) {
      // Would result in lost key/values for node.
      // Node and child need to be kept separated.
      return;
    }

    final child = mid!;

    if (!identical(child.left, null) || !identical(child.right, null)) {
      // Would disrupt tree ordering
      return;
    }

    setRunes(runes + child.runes, _runePool);

    // Take on mid grandchild
    mid = child.mid;

    // Node takes on child values/keyend status
    // If child was a key node then node has 1 less descendant
    if (child.isKeyEnd) {
      takeKeyEnd(child);
      // Child has been absorbed so 1 less descendant
      numDFSDescendants--;
    }

    mid?.parent = this;

    child.destroy(_runePool);
  }

  @override
  String toString() => '${String.fromCharCodes(runes)}';

  /// Update node values from json
  void _setFromJson(List<dynamic> json) {
    if (json.length > 1) {
      final obj = json[1];

      if (obj is List) {
        setAsKeyEnd();
        setValues(obj.cast<V>().toList());
      } else {
        throw ArgumentError.value(obj, 'Invalid Json value');
      }
    }
  }
}
