/// An iterable that returns [TTIterator].
///
/// Throws [ConcurrentModificationError] if underlying collection changes between calls
/// to [iterator].
abstract class TTIterable<V> extends Iterable<V> {
  /// Construct [TTIterable]
  TTIterable();

  /// Return an empty iterable
  factory TTIterable.empty() = _EmptyTTIterable<V>;

  @override
  TTIterator<V> get iterator;
}

/// An iterator that also reports [prefixEditDistance].
///
/// Throws [ConcurrentModificationError] if underlying collection changes during calls to [moveNext].
abstract class TTIterator<V> implements Iterator<V> {
  /// Value thrown when [current] accessed before calling [moveNext].
  static final noCurrentValueError = StateError('No current value');

  /// Value thrown when [prefixEditDistance] accessed before calling [moveNext].
  static final noPrefixEditDistanceError = StateError('No edit distance');

  /// The key prefix edit distance associated with current iterator value.
  int get prefixEditDistance;

  /// Return true if current value is set, otherwise false.
  /// Accessing [current] or [prefixEditDistance] before calling
  /// [moveNext] throws [StateError]. This getter provides a way to check
  /// if iterator has been initialised without triggering this error.
  bool get hasCurrentValue;
}

class _EmptyTTIterable<V> extends TTIterable<V> {
  @override
  TTIterator<V> get iterator => _EmptyTTIterator();
}

class _EmptyTTIterator<V> extends TTIterator<V> {
  @override
  V get current => throw TTIterator.noCurrentValueError;

  @override
  bool moveNext() => false;

  @override
  int get prefixEditDistance => throw TTIterator.noPrefixEditDistanceError;

  @override
  bool get hasCurrentValue => false;
}
