/// This library defines 2 [Multimaps](https://en.wikipedia.org/wiki/Multimap)
/// implemented as self balancing ternary trees allowing fast,
/// memory efficient prefix searching over a set of String keys
///
/// *  **TernaryTreapSet**  - Keys map to Set of Values.
/// *  **TernaryTreapList** - Keys map to Sequence of Values.
///
/// Balancing is achieved via  [Treap](https://en.wikipedia.org/wiki/Treap)
/// algorithm where each node is assigned a random priority and
/// [tree rotation](https://en.wikipedia.org/wiki/Tree_rotation) used to
/// maintain heap ordering.
library ternarytreap;

export 'src/prefixmatcher.dart';
export 'src/ternarytreap_base.dart';
