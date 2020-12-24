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
  /// The key prefix edit distance associated with current iterator value.
  int get prefixEditDistance;
}

class _EmptyTTIterable<V> extends TTIterable<V> {
  @override
  TTIterator<V> get iterator => _EmptyTTIterator();
}

class _EmptyTTIterator<V> extends TTIterator<V> {
  @override
  V get current =>
      throw UnsupportedError('Empty iterator has no current value');

  @override
  bool moveNext() => false;

  @override
  int get prefixEditDistance =>
      throw UnsupportedError('Empty iterator has no edit distance');
}
