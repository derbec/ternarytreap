/// This library defines 2 [Multimaps](https://en.wikipedia.org/wiki/Multimap) and a Set
/// implemented as self balancing compact ternary trees allowing fast, memory efficient
/// prefix and near neighbour searching over a set of String keys
///
/// *  **TTMultiMapSet**  - Keys map to Set of Values
/// *  **TTMultiMapList** - Keys map to Sequence of Values
/// *  **TTSet**          - A Set of Strings
///
/// Balancing is achieved via  [Treap](https://en.wikipedia.org/wiki/Treap) algorithm where
/// each node is assigned a random priority and [tree rotation](https://en.wikipedia.org/wiki/Tree_rotation)
/// used to maintain heap ordering.

library ternarytreap;

export 'src/ttset.dart';
export 'src/ttmultimap.dart';
export 'src/ttmultimapimpl.dart';
export 'src/key_mapping.dart';
export 'src/ttiterable.dart';
