/// An iterable that returns [TTIterator].
abstract class TTIterable<V> extends Iterable<V> {
  @override
  TTIterator<V> get iterator;

  /// Return [TTIterable] over marked subset.
  TTIterable<V> get marked;

  /// Return [TTIterable] over unmarked subset.
  TTIterable<V> get unmarked;
}

/// An iterator that also reports [prefixEditDistance] and [isMarked].
abstract class TTIterator<V> implements Iterator<V> {
  /// The key prefix edit distance associated with current iterator value.
  int get prefixEditDistance;

  /// Is the current key part of the marked set?
  bool get isMarked;
}
