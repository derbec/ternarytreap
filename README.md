# TernaryTreap

This library defines 2 [Multimaps](https://en.wikipedia.org/wiki/Multimap) and a Set implemented as self balancing compact ternary trees allowing fast, memory efficient prefix and near neighbour searching over a set of String keys

*  **TTMultiMapSet**  - Keys map to Set of Values
*  **TTMultiMapList** - Keys map to Sequence of Values
*  **TTSet**          - A Set of Strings

Balancing is achieved via  [Treap](https://en.wikipedia.org/wiki/Treap) algorithm where each node is assigned a random priority and [tree rotation](https://en.wikipedia.org/wiki/Tree_rotation) used to maintain heap ordering.


 ## Usage

 Use as a generic multimap of arbitrary type.
 Key->Values relations are stored as either Set or List as below.

 ```dart
 final ttMultimapList = ternarytreap.TTMultiMapList<int>()
   ..add('zebra')
   ..addValues('zebra', [])
   ..add('zebra', 23)
   ..addValues('cat', [1, 2])
   ..addValues('canary', [3, 4])
   ..addValues('dog', [5, 6, 7, 9])
   ..addValues('cow', [4])
   ..addValues('donkey', [7, 5, 1])
   ..addValues('donkey', [6, 8, 3])
   ..add('goat', 7)
   ..add('pig', 3)
   ..addValues('horse', [9, 5, 8])
   ..add('rabbit')
   ..addValues('rat', [2, 3])
   ..add('sheep', 7)
   ..addValues('ape', [5, 6, 7])
   ..add('zonkey') // Yes it's a thing!
   ..add('dingo', 5)
   ..addValues('kangaroo', [4, 5, 7])
   ..add('chicken')
   ..add('hawk')
   ..add('crocodile', 5)
   ..addValues('cow', [3])
   ..addValues('zebra', [23, 24, 24, 25]);
 ```
 Entries with keys starting with 'z'

 ```dart
 print(ttMultimapList.keysByPrefix('z'));
 print(ttMultimapList.entriesByKeyPrefix('z'));
 print(ttMultimapList.valuesByKeyPrefix('z'));
 ```
 ```shell
 (zebra, zonkey)
 (MapEntry(zebra: [23, 23, 24, 24, 25]), MapEntry(zonkey: []))
 (23, 23, 24, 24, 25)
 ```

 Same data using Set for value storage. Repeated values are removed.
 ```dart
 final ttMultimapSet =
          ternarytreap.TTMultiMapSet<int>.from(ttMultimapList);
 ```
 Entries with keys starting with 'z' with values.
 ```dart
 print(ttMultimapSet.entriesByKeyPrefix('z'));
 ```
 ```shell
 (MapEntry(zebra: {23, 24, 25}), MapEntry(zonkey: {}))
 ```

 ## Near neighbour searching

 TTMultiMap supports near neighbour searching.
 Keys starting with 'cow' and maxPrefixEditDistance of 2.
 i.e.:
 <mark>cow</mark>, <mark>c</mark>hicken, <mark>c</mark>rocodile,
 <mark>c</mark>anary, <mark>c</mark>at, d<mark>o</mark>g,
 d<mark>o</mark>nkey, g<mark>o</mark>at, ha<mark>w</mark>k,
 h<mark>o</mark>rse, z<mark>o</mark>nkey
 ```dart
 print(ttMultimapSet.keysByPrefix('cow', maxPrefixEditDistance: 2).join(', '));
 ```
 ```shell
 cow, chicken, crocodile, canary, cat, dog, donkey, goat, hawk, horse, zonkey

 ```

 ## Case sensitivity and other key transformations

 Use key mappings to specify key transforms during all operations.

 ```dart
 final ttMultiMap = ternarytreap.TTMultiMapSet<String>(ternarytreap.lowercase)
   ..addKeys(['TeStInG', 'Cat', 'cAt', 'testinG', 'DOG', 'dog']);
 print(ttMultiMap.keys);
 ```
 ```shell
 (cat, dog, testing)
 ```

 Depending on the KeyMapping this may result in 1 to many relationships
 between input string and key.

 For example case insensitivity can be achieved by applying a lowercase
 mapping to all keys. If original strings are required than these must
 be stored as values.

 ```dart
 final keyValue = ternarytreap.TTMultiMapSet<String>(ternarytreap.lowercase)
   ..addKeyValues(['TeStInG', 'Cat', 'cAt', 'testinG', 'DOG', 'dog']);
 print(keyValue.entries);
 print(keyValue.valuesByKeyPrefix('CA'));
 ```
 ```shell
 (MapEntry(cat: {Cat, cAt}), MapEntry(dog: {DOG, dog}), MapEntry(testing: {TeStInG, testinG}))
 (Cat, cAt)
 ```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/derbec/ternarytreap/issues
