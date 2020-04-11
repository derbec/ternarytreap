# TernaryTreap

This library defines 2 [Multimaps](https://en.wikipedia.org/wiki/Multimap) implemented as self balancing ternary trees allowing fast, memory efficient prefix and near neighbour searching over a set of String keys

*  **TernaryTreapSet**  - Keys map to Set of Values
*  **TernaryTreapList** - Keys map to Sequence of Values

Balancing is achieved via  [Treap](https://en.wikipedia.org/wiki/Treap) algorithm where each node is assigned a random priority and [tree rotation](https://en.wikipedia.org/wiki/Tree_rotation) used to maintain heap ordering.

/// ```dart
/// final  TernaryTreap<String> ternaryTreap = TernaryTreapSet<String>()
/// ..add('cat')
/// ..add('Canary')
/// ..add('dog')
/// ..add('zebr
/// ..add('CAT');
///
/// print(ternaryTreap.keys);
/// ```
/// ```
/// (CAT, Canary, cat, dog, zebra)
/// ```
/// ```dart
/// print(ternaryTreap.keysByPrefix('ca'));
/// ```
/// ```shell
/// (cat)
/// ```
/// ```dart
/// print(ternaryTreap.toString());
/// ```
/// ```shell
/// -CAT
/// Canary
/// cat
/// dog
/// zebra
/// ```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/derbec/ternarytreap/issues
