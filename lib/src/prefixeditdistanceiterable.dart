/// An iterable over a [TTMultiMap] that returns
/// [PrefixEditDistanceIterator].
abstract class PrefixEditDistanceIterable<V> extends Iterable<V> {
  @override
  PrefixEditDistanceIterator<V> get iterator;
}

/// An iterator that returns items that fall within an edit
/// distance of search query.
abstract class PrefixEditDistanceIterator<V> implements Iterator<V> {
  /// the key edit distance associated with current iterator value.
  int get prefixEditDistance;
}
