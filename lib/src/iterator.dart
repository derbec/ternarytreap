library iterable;

import 'dart:collection';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:ternarytreap/src/ttmultimap.dart';

import 'node.dart';
import 'prefixeditdistanceiterable.dart';
import 'utility.dart';

const int _INVALID_DISTANCE = -1;

const int _INVALID_CODE_UNIT = -1;

/// Base class for in order iterables
abstract class _InOrderIterableBase<V, I> extends IterableMixin<I>
    implements PrefixEditDistanceIterable<I> {
  /// Construct InOrderIterableBase
  _InOrderIterableBase(this._root, this._currentVersion,
      {List<int> prefix, this.maxPrefixEditDistance = 0})
      : _validVersion = _currentVersion.value,
        _prefixSearchResult = _root == null
            ? null
            : prefix == null ? null : _root.getClosestPrefixDescendant(prefix);

  /// Maximum edit distance of returns
  final int maxPrefixEditDistance;
  final PrefixSearchResult<V> _prefixSearchResult;
  final int _validVersion;
  final ByRef<int> _currentVersion;
  final Node<V> _root;

  @override
  int get length {
    if (_currentVersion.value != _validVersion) {
      throw ConcurrentModificationError();
    }

    if (_root == null) {
      return 0;
    }

    // No query, traversing entire tree
    if (_prefixSearchResult == null) {
      return _root.sizeDFSTree;
    }

    // Prefix found
    if (_prefixSearchResult.isPrefixMatch) {
      return _prefixSearchResult.node.sizePrefixTree;
    }

    // No shortcut to calulate length for distance queries
    if (maxPrefixEditDistance > 0.0) {
      return super.length;
    }

    // Partial or no match on non fuzzy search can only return 0;
    return 0;
  }

  @override
  bool get isEmpty => length == 0;
}

/// Iterates through keys of the [TTMultiMap].
class InOrderKeyIterable<V> extends _InOrderIterableBase<V, String> {
  /// Construct InOrderKeyIterable
  InOrderKeyIterable(Node<V> root, ByRef<int> currentVersion,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  PrefixEditDistanceIterator<String> get iterator => InOrderKeyIterator<V>._(
      _root, _currentVersion, _validVersion, _prefixSearchResult,
      maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through values of the [TTMultiMap].
///
/// Values are ordered first by key and then by insertion order.
/// Due to the 1 to n relationship between key and values
/// (necessary for key mapping) each element returned will be an [Iterable]
/// containing 1 or more elemets that are associated with a key.
///
/// If a key maps to an empty values [Iterable] then it is skipped, no
/// empty [Iterable] is returned.
class InOrderValuesIterable<V> extends _InOrderIterableBase<V, V> {
  /// Constructs a TernaryTreeValuesIterable
  InOrderValuesIterable(Node<V> root, ByRef<int> currentVersion,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  PrefixEditDistanceIterator<V> get iterator => InOrderValuesIterator<V>(
      _root, _currentVersion, _validVersion, _prefixSearchResult,
      maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through map entries of the [TTMultiMap] with value as Iterable.
class InOrderMapEntryIterable<V>
    extends _InOrderIterableBase<V, MapEntry<String, Iterable<V>>> {
  /// Constructs a InOrderMapEntryIterable
  InOrderMapEntryIterable(Node<V> root, ByRef<int> currentVersion,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  PrefixEditDistanceIterator<MapEntry<String, Iterable<V>>> get iterator =>
      _InOrderMapEntryIteratorIterator<V>(
          _root, _currentVersion, _validVersion, _prefixSearchResult,
          maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through map entries of the [TTMultiMap] with value as Set.
class InOrderMapEntryIterableSet<V>
    extends _InOrderIterableBase<V, MapEntry<String, Set<V>>> {
  /// Constructs a InOrderMapEntryIterableSet
  InOrderMapEntryIterableSet(Node<V> root, ByRef<int> currentVersion,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  PrefixEditDistanceIterator<MapEntry<String, Set<V>>> get iterator =>
      InOrderMapEntryIteratorSet<V>(
          _root, _currentVersion, _validVersion, _prefixSearchResult,
          maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through map entries of the [TTMultiMap] with value as List.
class InOrderMapEntryIterableList<V>
    extends _InOrderIterableBase<V, MapEntry<String, List<V>>> {
  /// Constructs a InOrderMapEntryIterableList
  InOrderMapEntryIterableList(Node<V> root, ByRef<int> currentVersion,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  PrefixEditDistanceIterator<MapEntry<String, List<V>>> get iterator =>
      InOrderMapEntryIteratorList<V>(
          _root, _currentVersion, _validVersion, _prefixSearchResult,
          maxPrefixEditDistance: maxPrefixEditDistance);
}

/// store call stack data for iterators
@immutable
class _StackFrame<V> {
  _StackFrame(this.node, this.prefix,
      {this.distance = _INVALID_DISTANCE, this.ignoreChild});
  final Node<V> node;
  final int distance;

  final List<int> prefix;
  final Node<V> ignoreChild;

  @override
  String toString() =>
      '${String.fromCharCodes(prefix)} : $node : ignoreChild -> $ignoreChild -> $distance';

  _StackFrame<V> copyWith(
          {Node<V> node,
          List<int> prefix,
          int distance,
          Node<V> ignoreChild,
          bool ignoreThis}) =>
      _StackFrame<V>(node ?? this.node, prefix ?? this.prefix,
          distance: distance ?? this.distance,
          ignoreChild: ignoreChild ?? this.ignoreChild);
}

@immutable
class _UnVisited<V> {
  _UnVisited(this.node, this.prefix);
  final List<int> prefix;
  final Node<V> node;
}

enum _DistanceState { DISTANCE_INIT, FUZZY_WORKING, NO_DISTANCE }

/// Base class for in order [TTMultiMap] iterators.
abstract class _InOrderIteratorBase<V> {
  /// Construct new [_InOrderIteratorBase] to start from
  /// [prefixSearchResult] node which belongs to [owner]. Is result of prefix search, may be exact or only closest lexicographic match
  /// If [prefix] is specified then it is prefixed to all returned keys.
  /// If [distance]>0 then after initial exploration from [prefixSearchResult] back to [root] further
  /// explorations from [root] are performed, each with increasing hamming distance
  /// until [distance] is reached.
  ///
  /// Note:
  /// * Distance ordering is based on the assumption that first
  /// prefix characters are more likely to be correct than later characters.
  /// * Additional work for fuzzy searches is defered until absolutely neccessary.
  /// This means that initial matches are returned rapidly and cost no more than
  /// non fuzzy matching.
  _InOrderIteratorBase(this.root, this.currentVersion, this.validVersion,
      this.prefixSearchResult,
      {int maxPrefixEditDistance = 0})
      : assert(maxPrefixEditDistance != null),
        assert(validVersion != null),
        maxPrefixEditDistance = prefixSearchResult == null
            ? maxPrefixEditDistance
            : min(maxPrefixEditDistance,
                prefixSearchResult.prefixCodeUnits.length - 1),
        stack = Stack<_StackFrame<V>>(10),
        distanceState = maxPrefixEditDistance > 0
            ? _DistanceState.DISTANCE_INIT
            : _DistanceState.NO_DISTANCE,
        // Init the worklist for fuzzy search if needed
        distanceList = maxPrefixEditDistance > 0
            ? List<ListQueue<_UnVisited<V>>>(maxPrefixEditDistance + 1)
            : null {
    if (prefixSearchResult == null && maxPrefixEditDistance > 0) {
      throw ArgumentError(
          'prefixSearchResult == null && maxPrefixEditDistance > 0');
    }

    if (maxPrefixEditDistance > 0 &&
        maxPrefixEditDistance >= prefixSearchResult.prefixCodeUnits.length) {
      throw ArgumentError(
          'maxPrefixEditDistance ($maxPrefixEditDistance) > 0 && maxPrefixEditDistance >= prefix.length (${prefixSearchResult.prefixCodeUnits.length})');
    }

    if (root != null) {
      if (prefixSearchResult == null) {
        // Simple DFS traversal requested
        pushDFS(_StackFrame<V>(root, []));
        return;
      }

      // A search was requested, what sort of match was found?
      // Set up intial stack frame parameters
      if (prefixSearchResult.prefixCodeunitIdx == _INVALID_CODE_UNIT) {
        // No match at all was found
        if (maxPrefixEditDistance < 1) {
          /// Bail if fuzzy not selected
          return;
        }

        // All we know is that minimum possible distance is 1
        currentDistance = 1;

        // Search entire tree from root
        prefixFrame = _StackFrame<V>(root, []);

        // There is no initial subtree intialisation to dodge around
        distanceState = _DistanceState.FUZZY_WORKING;

        pushDFS(prefixFrame);
      } else {
        // Some kind of match was found
        var matchDistance = 0;

        // What distance is intial match?
        if (!prefixSearchResult.isPrefixMatch) {
          // Prefix was only partially matched so trim accordingly and
          // add any remainding code units of match node
          // Calculate distance of this partial match
          matchDistance = prefixDistance(
              prefixSearchResult.prefixCodeUnits,
              prefixSearchResult.prefixCodeUnits
                  .getRange(0, prefixSearchResult.prefixCodeunitIdx),
              prefixSearchResult.node.codeUnits.getRange(
                  prefixSearchResult.nodeCodeunitIdx,
                  prefixSearchResult.node.codeUnits.length));

          // Given no exact match present, minimum possible search distance is 1
          currentDistance = 1;
        }

        // Set the start frame for prefix query.
        // Because the moveNext method constructs keys as:
        // prefix + codeUnits we need to remove matched codeUnits from
        // the prefix.
        prefixFrame = _StackFrame<V>(
            prefixSearchResult.node,
            prefixSearchResult.prefixCodeUnits.sublist(
                0,
                prefixSearchResult.prefixCodeunitIdx -
                    prefixSearchResult.nodeCodeunitIdx),
            distance: matchDistance);

        // Ensure that only mid child explored for initial run
        // by instructing moveNext() to ignore right child
        stack.push(
            prefixFrame.copyWith(ignoreChild: prefixSearchResult.node.right));
      }
    }
  }

  final Stack<_StackFrame<V>> stack;

  /// Version for which this iterator is valid
  final int validVersion;

  final ByRef<int> currentVersion;

  final Node<V> root;

  final PrefixSearchResult<V> prefixSearchResult;

  /// Max distance is when all but one prefix code units are altered.
  /// Because 0 is a valid distance the total number of distances explored is
  /// [maxPrefixEditDistance] +1.
  final int maxPrefixEditDistance;

  /// Collection of nodes and associated distance for future processing.
  /// Tree traversal and calculation of node distance is fairly expensive so we
  /// trade memory for speed. Nodes are sorted first by edit distance, then by
  /// occurance in tree in order traversal.
  final List<ListQueue<_UnVisited<V>>> distanceList;

  /// Current state of fuzzy search
  _DistanceState distanceState;

  /// The startying frame for each search distance
  _StackFrame<V> prefixFrame;

  /// Distance currently being explored
  int currentDistance = 0;

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
    if (currentVersion.value != validVersion) {
      throw ConcurrentModificationError();
    }
    if (root != null) {
      while (currentDistance <= maxPrefixEditDistance) {
        while (stack.isNotEmpty) {
          final context = stack.pop();

          // Avoid recalculating if possible
          final nodeDistance = prefixSearchResult == null
              ? 0
              : context.distance == _INVALID_DISTANCE
                  ? prefixDistance(prefixSearchResult.prefixCodeUnits,
                      context.prefix, context.node.codeUnits)
                  : context.distance;

          // Push right for later consumption
          // Exclude initial path root
          if (context.node.right != null &&
              context.node.right != context.ignoreChild) {
            pushDFS(_StackFrame<V>(context.node.right, context.prefix));
          }

          // Only generate this if necessary
          List<int> nodeCodeUnits;

          // Push right for later consumption
          // Exclude initial path root
          if (context.node.mid != null &&
              context.node.mid != context.ignoreChild &&
              // Only follow if within max distance or
              // not computable. Must follow uncomputable pathways
              // to gain access to computable children.
              nodeDistance <= maxPrefixEditDistance) {
            nodeCodeUnits = context.prefix + context.node.codeUnits;
            pushDFS(
                _StackFrame<V>(context.node.mid, nodeCodeUnits,
                    distance: nodeDistance),
                nodeDistance);
          }

          // If key has current distance then return
          if (context.node.isKeyEnd) {
            if (nodeDistance == currentDistance) {
              currentKey = String.fromCharCodes(
                  nodeCodeUnits ?? context.prefix + context.node.codeUnits);
              currentValue = context.node.values;
              return true;
            } else {
              // ... other wise save for future
              if (distanceList != null &&
                  nodeDistance != _INVALID_DISTANCE &&
                  nodeDistance <= maxPrefixEditDistance) {
                final fuzzyIdx = nodeDistance;

                if (distanceList[fuzzyIdx] == null) {
                  distanceList[fuzzyIdx] = ListQueue<_UnVisited<V>>(1);
                }
                distanceList[fuzzyIdx]
                    .addLast(_UnVisited<V>(context.node, context.prefix));
              }
            }
          }
        }

        // Complete fuzzy search if requested
        switch (distanceState) {
          case _DistanceState.DISTANCE_INIT:
            // Backtrack
            pushBacktrackPath();
            distanceState = _DistanceState.FUZZY_WORKING;
            break;
          case _DistanceState.FUZZY_WORKING:
            // return the next key/value for current distance if available
            final fuzzyQueue = distanceList[currentDistance];

            if (fuzzyQueue != null && fuzzyQueue.isNotEmpty) {
              final visit = fuzzyQueue.removeFirst();
              currentKey =
                  String.fromCharCodes(visit.prefix + visit.node.codeUnits);
              currentValue = visit.node.values;
              return true;
            }

            currentDistance++;
            break;
          default:
            // Fuzzy search not requested to stop
            return false;
        }
      }
    }
    return false;
  }

  /// Set up stack for backtracking
  // For distance searching we want to traverse in this order:
  // * prefixRoot -> descendants
  // * prefixRoot -> root
  // * root -> rest of tree
  //
  // This gives preference to strings lexiographically similar to prefix.
  void pushBacktrackPath() {
    assert(stack.isEmpty);

    var prefixNode = prefixFrame.node;
    var currentPrefix = prefixFrame.prefix;

    // prefixNode and prefixNode->mid have already been explored so explore left and right only
    if (prefixNode.left != null) {
      pushDFS(_StackFrame<V>(prefixNode.left, currentPrefix));
    }

    if (prefixNode.right != null) {
      pushDFS(_StackFrame<V>(prefixNode.right, currentPrefix));
    }

    while (prefixNode != root) {
      var parentNode = prefixNode.parent;
      assert(parentNode != null);
      // Parent node prefix depends upon child position.
      // If mid child then need to remove parent code units.
      if (prefixNode == parentNode.mid) {
        currentPrefix = currentPrefix.sublist(
            0, currentPrefix.length - parentNode.codeUnits.length);
      }

      // DFS from parent if last node is not left child
      if (parentNode.left != prefixNode) {
        pushDFS(
            _StackFrame<V>(parentNode, currentPrefix, ignoreChild: prefixNode));
      } else {
        stack.push(
            _StackFrame<V>(parentNode, currentPrefix, ignoreChild: prefixNode));
      }

      prefixNode = parentNode;
    }

    stack.reverse();
  }

  /// Calculate distance from [comparePrefix] to the concatenation of:
  /// [keyPrefix] and [keySuffix].
  ///
  /// By accepting [keyPrefix] and [keySuffix] separately we avoid the need to
  /// actually concatenate them.
  ///
  /// Cannot calculate distance if ([keyPrefix] + [keySuffix]) is shorter than [comparePrefix]
  /// so return [_INVALID_DISTANCE] in this case.
  ///
  /// Return distance as number of edits between [comparePrefix] and
  /// first [comparePrefix].length codeunits of ([keyPrefix] + [keySuffix]).
  static int prefixDistance(final Iterable<int> comparePrefix,
      final Iterable<int> keyPrefix, final Iterable<int> keySuffix) {
    final keyPrefixLength = keyPrefix.length;
    final keySuffixLength = keySuffix.length;

    final comparePrefixLength = comparePrefix.length;

    if ((keyPrefixLength + keySuffixLength) < comparePrefixLength) {
      // cannot compute hamming distance here as
      return _INVALID_DISTANCE;
    }

    // Assume worst case and improve if possible
    var distance = comparePrefixLength;
    var comparePrefixIdx = 0;

    // Improve if possible by comparing to keyPrefix and keySuffix
    for (var i = 0;
        comparePrefixIdx < comparePrefixLength && i < keyPrefixLength;
        i++) {
      if (comparePrefix.elementAt(comparePrefixIdx) == keyPrefix.elementAt(i)) {
        distance--;
      }
      comparePrefixIdx++;
    }

    for (var i = 0;
        comparePrefixIdx < comparePrefixLength && i < keySuffixLength;
        i++) {
      if (comparePrefix.elementAt(comparePrefixIdx) == keySuffix.elementAt(i)) {
        distance--;
      }
      comparePrefixIdx++;
    }

    return distance;
  }

  /// Add [context] to [stack] and then follow left children down.
  /// Child inherit prefix
  void pushDFS(_StackFrame<V> context, [int distance = _INVALID_DISTANCE]) {
    // add current frame to stack and drill down the left

    stack.push(context);

    var node = context.node;
    while (node.left != null) {
      node = node.left;
      stack.push(_StackFrame<V>(node, context.prefix, distance: distance));
    }
  }

  int get prefixEditDistance => currentDistance;
}

/// Iterate through keys
class InOrderKeyIterator<V> extends _InOrderIteratorBase<V>
    implements PrefixEditDistanceIterator<String> {
  /// Construct new [InOrderKeyIterator]
  InOrderKeyIterator._(Node<V> root, ByRef<int> currentVersion,
      int validVersion, PrefixSearchResult<V> prefixRoot,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixRoot,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  String get current => currentKey;
}

/// Iterate through values
class InOrderValuesIterator<V> extends _InOrderIteratorBase<V>
    implements PrefixEditDistanceIterator<V> {
  /// Construct new [InOrderKeyIterator]
  InOrderValuesIterator(Node<V> root, ByRef<int> currentVersion,
      int validVersion, PrefixSearchResult<V> prefixRoot,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixRoot,
            maxPrefixEditDistance: maxPrefixEditDistance);

  Iterator<V> _currentItr;

  @override
  bool moveNext() {
    // Flatten out value collections into single iterable
    var next = false;

    // First time round
    if (_currentItr == null) {
      next = super.moveNext();
      //  Skip empty collections
      while (next && currentValue.isEmpty) {
        next = super.moveNext();
      }
      if (next) {
        _currentItr = currentValue.iterator;
        return _currentItr.moveNext();
      }
      return false;
    }

    // Check current iterator
    next = _currentItr.moveNext();
    if (next) {
      return true;
    }

    // Move to next iterator
    next = super.moveNext();
    // skip empty value lists
    while (next && currentValue.isEmpty) {
      next = super.moveNext();
    }
    if (next) {
      _currentItr = currentValue.iterator;
      return _currentItr.moveNext();
    }
    return false;
  }

  @override
  V get current => _currentItr.current;
}

/// Iterate through entries
abstract class InOrderMapEntryIterator<V> extends _InOrderIteratorBase<V> {
  /// Construct new [InOrderKeyIterator]
  InOrderMapEntryIterator(Node<V> root, ByRef<int> currentVersion,
      int validVersion, PrefixSearchResult<V> prefixSearchResult,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  
}

class _InOrderMapEntryIteratorIterator<V> extends InOrderMapEntryIterator<V>
    implements PrefixEditDistanceIterator<MapEntry<String, Iterable<V>>> {
  /// Construct new [InOrderKeyIterator]
  _InOrderMapEntryIteratorIterator(Node<V> root, ByRef<int> currentVersion,
      int validVersion, PrefixSearchResult<V> prefixSearchResult,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  MapEntry<String, Iterable<V>> get current =>
      MapEntry<String, Iterable<V>>(currentKey, currentValue as Set<V>);
}

/// Iterator for Map entries with Set value
class InOrderMapEntryIteratorSet<V> extends InOrderMapEntryIterator<V>
    implements PrefixEditDistanceIterator<MapEntry<String, Set<V>>> {
  /// Construct new [InOrderKeyIterator]
  InOrderMapEntryIteratorSet(Node<V> root, ByRef<int> currentVersion,
      int validVersion, PrefixSearchResult<V> prefixSearchResult,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  MapEntry<String, Set<V>> get current =>
      MapEntry<String, Set<V>>(currentKey, currentValue as Set<V>);
}

/// Iterator for Map entries with List value
class InOrderMapEntryIteratorList<V> extends InOrderMapEntryIterator<V>
    implements PrefixEditDistanceIterator<MapEntry<String, List<V>>> {
  /// Construct new [InOrderKeyIterator]
  InOrderMapEntryIteratorList(Node<V> root, ByRef<int> currentVersion,
      int validVersion, PrefixSearchResult<V> prefixSearchResult,
      {List<int> prefix, int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            prefix: prefix, maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  MapEntry<String, List<V>> get current =>
      MapEntry<String, List<V>>(currentKey, currentValue as List<V>);
}
