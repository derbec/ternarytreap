library iterable;

import 'dart:collection';
import 'dart:math';
import 'package:meta/meta.dart';
import 'node.dart';
import 'ttiterable.dart';
import 'utility.dart';

const int _INVALID_DISTANCE = -1;

const int _INVALID_RUNE_IDX = -1;

/// (2^53)-1 because javascript
const int _MAX_SAFE_INTEGER = 9007199254740991;

/// Store version information for [TTMultiMap]
class Version {
  /// Create new version
  Version(this._keysVersion, this._valuesVersion);

  /// Current version of structure updates
  int _keysVersion;

  /// Current version of value updates
  int _valuesVersion;

  /// Increment keys/structure version
  void incKeysVersion() {
    _keysVersion = (_keysVersion >= _MAX_SAFE_INTEGER) ? 1 : _keysVersion + 1;
  }

  /// Increment values version
  void incValuesVersion() {
    _valuesVersion =
        (_valuesVersion >= _MAX_SAFE_INTEGER) ? 1 : _valuesVersion + 1;
  }

  /// Increment both key and values versions
  void incVersions() {
    incKeysVersion();
    incValuesVersion();
  }

  /// Check keys version is valid
  void checkKeysVersion(VersionSnapshot snapshot) {
    if (snapshot.keysVersion != _keysVersion) {
      throw ConcurrentModificationError();
    }
  }

  /// Check keys version is valid
  void checkValuesVersion(VersionSnapshot snapshot) {
    if (snapshot.valuesVersion != _valuesVersion) {
      throw ConcurrentModificationError();
    }
  }

  /// Check both versions are valid
  void checkVersions(VersionSnapshot snapshot) {
    checkKeysVersion(snapshot);
    checkValuesVersion(snapshot);
  }

  /// Return [VersionSnapshot] of current state
  VersionSnapshot snapshot() => VersionSnapshot(_keysVersion, _valuesVersion);
}

/// snapshot of version info
class VersionSnapshot {
  /// Construct new snapshot
  VersionSnapshot(this.keysVersion, this.valuesVersion);

  /// Keys version
  final int keysVersion;

  /// Values version
  final int valuesVersion;
}

/// Base class for in order iterables
abstract class _InOrderIterableBase<V, I> extends IterableMixin<I>
    implements TTIterable<I> {
  /// Construct InOrderIterableBase
  _InOrderIterableBase(this._root, this._currentVersion,
      {this.prefixSearchResult, this.maxPrefixEditDistance = 0})
      : assert(!identical(maxPrefixEditDistance, null)),
        assert(!identical(_currentVersion, null)),
        _validVersion = _currentVersion.value.snapshot();

  /// Maximum edit distance of returns
  final int maxPrefixEditDistance;
  final PrefixSearchResult<V>? prefixSearchResult;
  final VersionSnapshot _validVersion;
  final ByRef<Version> _currentVersion;
  final Node<V> _root;

  @override
  int get length {
    _currentVersion.value.checkVersions(_validVersion);

    if (identical(_root, null)) {
      return 0;
    }

    final prefixSearchResult = this.prefixSearchResult;

    // No query, traversing entire tree
    if (identical(prefixSearchResult, null)) {
      return _root.sizeDFSTree;
    }

    // Prefix found
    if (prefixSearchResult.isPrefixMatch) {
      return prefixSearchResult.node.sizePrefixTree;
    }

    // No shortcut to calulate length for distance or filtered queries
    if (maxPrefixEditDistance > 0.0) {
      return super.length;
    }

    // Partial or no match on non fuzzy search can only return 0;
    return 0;
  }

  @override
  bool get isEmpty => length == 0;
}

/// Iterates through keys inorder.
class InOrderKeyIterable<V> extends _InOrderIterableBase<V, String> {
  /// Construct InOrderKeyIterable
  InOrderKeyIterable(Node<V> root, ByRef<Version> currentVersion,
      {PrefixSearchResult<V>? prefixSearchResult,
      int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefixSearchResult: prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  TTIterator<String> get iterator => InOrderKeyIterator<V>._(
      _root, _currentVersion, _validVersion, prefixSearchResult,
      maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through values.
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
  InOrderValuesIterable(Node<V> root, ByRef<Version> currentVersion,
      {PrefixSearchResult<V>? prefixSearchResult,
      int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefixSearchResult: prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  TTIterator<V> get iterator => InOrderValuesIterator<V>(
      _root, _currentVersion, _validVersion, prefixSearchResult,
      maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through map entries with value as Iterable.
class InOrderMapEntryIterable<V>
    extends _InOrderIterableBase<V, MapEntry<String, Iterable<V>>> {
  /// Constructs a InOrderMapEntryIterable
  InOrderMapEntryIterable(Node<V> root, ByRef<Version> currentVersion,
      {PrefixSearchResult<V>? prefixSearchResult,
      int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefixSearchResult: prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  TTIterator<MapEntry<String, Iterable<V>>> get iterator =>
      _InOrderMapEntryIteratorIterator<V>(
          _root, _currentVersion, _validVersion, prefixSearchResult,
          maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through map entries with value as Set.
class InOrderMapEntryIterableSet<V>
    extends _InOrderIterableBase<V, MapEntry<String, Set<V>>> {
  /// Constructs a InOrderMapEntryIterableSet
  InOrderMapEntryIterableSet(Node<V> root, ByRef<Version> currentVersion,
      {PrefixSearchResult<V>? prefixSearchResult,
      int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefixSearchResult: prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  TTIterator<MapEntry<String, Set<V>>> get iterator =>
      InOrderMapEntryIteratorSet<V>(
          _root, _currentVersion, _validVersion, prefixSearchResult,
          maxPrefixEditDistance: maxPrefixEditDistance);
}

/// Iterates through map entries of the with value as List.
class InOrderMapEntryIterableList<V>
    extends _InOrderIterableBase<V, MapEntry<String, List<V>>> {
  /// Constructs a InOrderMapEntryIterableList
  InOrderMapEntryIterableList(Node<V> root, ByRef<Version> currentVersion,
      {PrefixSearchResult<V>? prefixSearchResult,
      int maxPrefixEditDistance = 0})
      : super(root, currentVersion,
            prefixSearchResult: prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  TTIterator<MapEntry<String, List<V>>> get iterator =>
      InOrderMapEntryIteratorList<V>(
          _root, _currentVersion, _validVersion, prefixSearchResult,
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
  final Node<V>? ignoreChild;

  @override
  String toString() =>
      '${String.fromCharCodes(prefix)} : $node : ignoreChild -> $ignoreChild -> $distance';

  _StackFrame<V> copyWith(
          {Node<V>? node,
          List<int>? prefix,
          int? distance,
          Node<V>? ignoreChild,
          bool? ignoreThis}) =>
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

enum _DistanceState { DISTANCE_INIT, FUZZY_WORKING }

/// Base class for in order iterators.
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
      : assert(!identical(maxPrefixEditDistance, null)),
        assert(!identical(currentVersion, null)),
        assert(!identical(validVersion, null)),
        maxPrefixEditDistance = identical(prefixSearchResult, null)
            ? maxPrefixEditDistance
            : min(maxPrefixEditDistance,
                prefixSearchResult.prefixRunes.length - 1),
        stack = Stack<_StackFrame<V>>(10),
        distanceState = _DistanceState.DISTANCE_INIT,
        // Init the worklist for fuzzy search if needed
        distanceList = maxPrefixEditDistance > 0
            ? List<ListQueue<_UnVisited<V>>>.generate(maxPrefixEditDistance + 1,
                (int index) => ListQueue<_UnVisited<V>>())
            : null {
    final prefixSearchResult = this.prefixSearchResult;
    if (identical(prefixSearchResult, null) && maxPrefixEditDistance > 0) {
      throw ArgumentError(
          'identical(prefixSearchResult , null) && maxPrefixEditDistance > 0');
    }

    if (identical(prefixSearchResult, null)) {
      // Simple DFS traversal requested
      pushDFS(_StackFrame<V>(root, []));
      return;
    }

    // A search was requested, what sort of match was found?
    // Set up intial stack frame parameters
    if (prefixSearchResult.prefixRuneIdx == _INVALID_RUNE_IDX) {
      // No match at all was found
      if (maxPrefixEditDistance < 1) {
        /// Bail if fuzzy not selected
        return;
      }

      // All we know is that minimum possible distance is 1
      _prefixEditDistance = 1;

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
        // add any remainding runes of match node
        // Calculate distance of this partial match
        matchDistance = prefixDistance(
            prefixSearchResult.prefixRunes,
            prefixSearchResult.prefixRunes
                .getRange(0, prefixSearchResult.prefixRuneIdx),
            prefixSearchResult.node.runes.getRange(
                prefixSearchResult.nodeRuneIdx,
                prefixSearchResult.node.runes.length));

        // Given no exact match present, minimum possible search distance is 1
        _prefixEditDistance = 1;
      }

      // Set the start frame for prefix query.
      // Because the moveNext method constructs keys as:
      // prefix + runes we need to remove matched runes from
      // the prefix.
      prefixFrame = _StackFrame<V>(
          prefixSearchResult.node,
          prefixSearchResult.prefixRunes.sublist(
              0,
              prefixSearchResult.prefixRuneIdx -
                  prefixSearchResult.nodeRuneIdx),
          distance: matchDistance);

      // Ensure that only mid child explored for initial run
      // by instructing moveNext() to ignore right child
      stack.push(
          prefixFrame.copyWith(ignoreChild: prefixSearchResult.node.right));
    }
  }

  final Stack<_StackFrame<V>> stack;

  /// Version for which this iterator is valid
  final VersionSnapshot validVersion;

  final ByRef<Version> currentVersion;

  final Node<V> root;

  final PrefixSearchResult<V>? prefixSearchResult;

  /// Max distance is when all but one prefix runes are altered.
  /// Because 0 is a valid distance the total number of distances explored is
  /// [maxPrefixEditDistance] +1.
  final int maxPrefixEditDistance;

  /// Collection of nodes and associated distance for future processing.
  /// Tree traversal and calculation of node distance is fairly expensive so we
  /// trade memory for speed. Nodes are sorted first by edit distance, then by
  /// occurance in tree in order traversal.
  final List<ListQueue<_UnVisited<V>>>? distanceList;

  /// Current state of fuzzy search
  _DistanceState distanceState;

  /// The starting frame for each search distance
  late _StackFrame<V> prefixFrame;

  /// Distance currently being explored
  int _prefixEditDistance = 0;

  int get prefixEditDistance => _hasCurrentValue
      ? _prefixEditDistance
      : throw TTIterator.noPrefixEditDistanceError;

  late String currentKey;
  late Iterable<V> currentValue;

  /// Have [currentKey] and [currentValue] been set yet?
  /// Why doesn't Dart provide a way to check if late variables have been initialised?
  bool _hasCurrentValue = false;

  bool get hasCurrentValue => _hasCurrentValue;

  /// Apply appropriate modification checks.
  /// By default checks both keys and values.
  /// Some iterators have looser constraints thus may
  /// override this check.
  void checkVersion() {
    currentVersion.value.checkVersions(validVersion);
  }

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
    checkVersion();

    final distanceList = this.distanceList;
    final prefixSearchResult = this.prefixSearchResult;

    while (_prefixEditDistance <= maxPrefixEditDistance) {
      while (stack.isNotEmpty) {
        final context = stack.pop();

        // Avoid recalculating if possible
        final nodeDistance = identical(prefixSearchResult, null)
            ? 0
            : context.distance == _INVALID_DISTANCE
                ? prefixDistance(prefixSearchResult.prefixRunes, context.prefix,
                    context.node.runes)
                : context.distance;

        // Push right for later consumption
        // Exclude initial path root
        if (!identical(context.node.right, null) &&
            !identical(context.node.right, context.ignoreChild)) {
          pushDFS(_StackFrame<V>(context.node.right!, context.prefix));
        }

        // Only generate this if necessary
        List<int>? nodeRunes;

        // Push right for later consumption
        // Exclude initial path root
        if (!identical(context.node.mid, null) &&
            !identical(context.node.mid, context.ignoreChild) &&
            // Only follow if within max distance or
            // not computable. Must follow uncomputable pathways
            // to gain access to computable children.
            nodeDistance <= maxPrefixEditDistance) {
          nodeRunes = context.prefix + context.node.runes;
          pushDFS(
              _StackFrame<V>(context.node.mid!, nodeRunes,
                  distance: nodeDistance),
              nodeDistance);
        }

        // If key has current distance then return
        if (context.node.isKeyEnd) {
          if (nodeDistance == _prefixEditDistance) {
            currentKey = String.fromCharCodes(
                nodeRunes ?? context.prefix + context.node.runes);
            currentValue = context.node.values;
            _hasCurrentValue = true;
            return true;
          } else {
            // ... other wise save for future
            if (!identical(distanceList, null) &&
                nodeDistance != _INVALID_DISTANCE &&
                nodeDistance <= maxPrefixEditDistance) {
              final fuzzyIdx = nodeDistance;

              distanceList[fuzzyIdx]
                  .addLast(_UnVisited<V>(context.node, context.prefix));
            }
          }
        }
      }

      // Complete fuzzy search if requested
      if (identical(distanceList, null)) {
        return false;
      } else {
        switch (distanceState) {
          case _DistanceState.DISTANCE_INIT:
            // Backtrack
            pushBacktrackPath();
            distanceState = _DistanceState.FUZZY_WORKING;
            break;
          case _DistanceState.FUZZY_WORKING:
            // return the next key/value for current distance if available
            final fuzzyQueue = distanceList[_prefixEditDistance];

            if (!identical(fuzzyQueue, null) && fuzzyQueue.isNotEmpty) {
              final visit = fuzzyQueue.removeFirst();
              currentKey =
                  String.fromCharCodes(visit.prefix + visit.node.runes);
              currentValue = visit.node.values;
              _hasCurrentValue = true;
              return true;
            }

            _prefixEditDistance++;
            break;
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
    if (!identical(prefixNode.left, null)) {
      pushDFS(_StackFrame<V>(prefixNode.left!, currentPrefix));
    }

    if (!identical(prefixNode.right, null)) {
      pushDFS(_StackFrame<V>(prefixNode.right!, currentPrefix));
    }

    while (!identical(prefixNode, root)) {
      var parentNode = prefixNode.parent;
      if (identical(parentNode, null)) {
        throw StateError('Node parent not set');
      } else {
        // Parent node prefix depends upon child position.
        // If mid child then need to remove parent runes.
        if (identical(prefixNode, parentNode.mid)) {
          currentPrefix = currentPrefix.sublist(
              0, currentPrefix.length - parentNode.runes.length);
        }

        // DFS from parent if last node is not left child
        if (!identical(parentNode.left, prefixNode)) {
          pushDFS(_StackFrame<V>(parentNode, currentPrefix,
              ignoreChild: prefixNode));
        } else {
          stack.push(_StackFrame<V>(parentNode, currentPrefix,
              ignoreChild: prefixNode));
        }

        prefixNode = parentNode;
      }
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
  /// first [comparePrefix].length runes of ([keyPrefix] + [keySuffix]).
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
    while (!identical(node.left, null)) {
      node = node.left!;
      stack.push(_StackFrame<V>(node, context.prefix, distance: distance));
    }
  }
}

/// Iterate through keys
class InOrderKeyIterator<V> extends _InOrderIteratorBase<V>
    implements TTIterator<String> {
  /// Construct new [InOrderKeyIterator]
  InOrderKeyIterator._(Node<V> root, ByRef<Version> currentVersion,
      VersionSnapshot validVersion, PrefixSearchResult<V>? prefixRoot,
      {int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixRoot,
            maxPrefixEditDistance: maxPrefixEditDistance);

  /// Deny alteration of keys but allow for values.
  @override
  void checkVersion() {
    currentVersion.value.checkKeysVersion(validVersion);
  }

  @override
  String get current =>
      hasCurrentValue ? currentKey : throw TTIterator.noCurrentValueError;
}

/// Iterate through values
class InOrderValuesIterator<V> extends _InOrderIteratorBase<V>
    implements TTIterator<V> {
  /// Construct new [InOrderKeyIterator]
  InOrderValuesIterator(Node<V> root, ByRef<Version> currentVersion,
      VersionSnapshot validVersion, PrefixSearchResult<V>? prefixRoot,
      {int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixRoot,
            maxPrefixEditDistance: maxPrefixEditDistance) {
    _currentItr = Iterable<V>.empty().iterator;
  }

  late Iterator<V> _currentItr;

  @override
  bool moveNext() {
    // Flatten out values iterator
    // Check current iterator
    var next = _currentItr.moveNext();
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
  V get current => hasCurrentValue
      ? _currentItr.current
      : throw TTIterator.noCurrentValueError;
}

/// Iterate through entries
abstract class InOrderMapEntryIterator<V> extends _InOrderIteratorBase<V> {
  /// Construct new [InOrderKeyIterator]
  InOrderMapEntryIterator(Node<V> root, ByRef<Version> currentVersion,
      VersionSnapshot validVersion, PrefixSearchResult<V>? prefixSearchResult,
      {int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);
}

class _InOrderMapEntryIteratorIterator<V> extends InOrderMapEntryIterator<V>
    implements TTIterator<MapEntry<String, Iterable<V>>> {
  /// Construct new [InOrderKeyIterator]
  _InOrderMapEntryIteratorIterator(Node<V> root, ByRef<Version> currentVersion,
      VersionSnapshot validVersion, PrefixSearchResult<V>? prefixSearchResult,
      {int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  MapEntry<String, Iterable<V>> get current => hasCurrentValue
      ? MapEntry<String, Iterable<V>>(currentKey, currentValue as Set<V>)
      : throw TTIterator.noCurrentValueError;
}

/// Iterator for Map entries with Set value
class InOrderMapEntryIteratorSet<V> extends InOrderMapEntryIterator<V>
    implements TTIterator<MapEntry<String, Set<V>>> {
  /// Construct new [InOrderKeyIterator]
  InOrderMapEntryIteratorSet(Node<V> root, ByRef<Version> currentVersion,
      VersionSnapshot validVersion, PrefixSearchResult<V>? prefixSearchResult,
      {int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  MapEntry<String, Set<V>> get current => hasCurrentValue
      ? MapEntry<String, Set<V>>(currentKey, currentValue as Set<V>)
      : throw TTIterator.noCurrentValueError;
}

/// Iterator for Map entries with List value
class InOrderMapEntryIteratorList<V> extends InOrderMapEntryIterator<V>
    implements TTIterator<MapEntry<String, List<V>>> {
  /// Construct new [InOrderKeyIterator]
  InOrderMapEntryIteratorList(Node<V> root, ByRef<Version> currentVersion,
      VersionSnapshot validVersion, PrefixSearchResult<V>? prefixSearchResult,
      {int maxPrefixEditDistance = 0})
      : super(root, currentVersion, validVersion, prefixSearchResult,
            maxPrefixEditDistance: maxPrefixEditDistance);

  @override
  MapEntry<String, List<V>> get current => hasCurrentValue
      ? MapEntry<String, List<V>>(currentKey, currentValue as List<V>)
      : throw TTIterator.noCurrentValueError;
}
