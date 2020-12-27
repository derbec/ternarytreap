/// An iterable that returns [TTIterator].
abstract class TTIterable<V> extends Iterable<V> {
  /// Construct [TTIterable]
  TTIterable();

  /// Return an empty iterable
  factory TTIterable.empty() = _EmptyTTIterable<V>;

  @override
  TTIterator<V> get iterator;
}

/// An iterator that also reports [prefixEditDistance] and [isMarked].
abstract class TTIterator<V> implements Iterator<V> {
  /// Value thrown when [current] accessed before calling [moveNext].
  static final noCurrentValueError = StateError('No current value');

  /// Value thrown when [prefixEditDistance] accessed before calling [moveNext].
  static final noPrefixEditDistanceError = StateError('No edit distance');

  /// The key prefix edit distance associated with current iterator value.
  int get prefixEditDistance;
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
}
