# TernaryTreap

This library defines 2 [Multimaps](https://en.wikipedia.org/wiki/Multimap) implemented as self balancing ternary trees allowing fast, memory efficient prefix and near neighbour searching over a set of String keys

*  **TernaryTreapSet**  - Keys map to Set of Values
*  **TernaryTreapList** - Keys map to Sequence of Values

Balancing is achieved via  [Treap](https://en.wikipedia.org/wiki/Treap) algorithm where each node is assigned a random priority and [tree rotation](https://en.wikipedia.org/wiki/Tree_rotation) used to maintain heap ordering.

# Specification

TernaryTreap Set and List multimaps are functions:

* <i>f</i> :  <i>K</i> &mapsto; &weierp; (<i>V</i>)
* <i>g</i> :  <i>K</i> &mapsto; <i>V</i><sup>&#8469;</sup> &cup; V<sup>&emptyset;</sup>

such that

* K is the set of all Keys
* V is the set of all Values
* &#8469; is the set of Natural numbers
* &weierp; (<i>V</i>) is the powerset of V
* <i>V</i><sup>&#8469;</sup> is the set of all functions &#8469; &mapsto; <i>V</i>
* <i>V</i><sup>&emptyset;</sup> contains the empty function &emptyset; &mapsto; <i>V</i>

The codomain of <i>f</i> and <i>g</i> include the empty set and empty sequence respectively. This is useful when you require only a set of Keys searching purposes.

Often it is desirable to define equivalences between Key strings, for example case insensitivity.

This is achieved via a [KeyMapping](https://pub.dev/documentation/ternarytreap/latest/ternarytreap/KeyMapping.html), defined as the surjection:

* <i>m</i> : <i>K</i>&twoheadrightarrow; <i>L  &sube; K</i>

such that:

* <i>m</i>(<i>m</i>(x)) = <i>m</i>(x), i.e. <i>m</i> must be [idempotent](https://en.wikipedia.org/wiki/Idempotence), repeated applications do not change the result.

For example:

* <i>m</i>(x) = x. Default identity function, preserve keys.

* <i>m</i>(x) = lowercase(x). Convert keys to lowercase.

TernaryTreap Multimaps are composite functions with KeyMapping parameter <i>m</i>.

* TernaryTreapSet<sub><i>m</i></sub>(x) = <i>f</i> &#8728; <i>m</i>(x)
* TernaryTreapList<sub><i>m</i></sub>(x) = <i>g</i> &#8728; <i>m</i>(x)

# Usage

## Most basic case

Insert keys and later return those starting with a given prefix.

```dart

void  main(List<String> args) {

final  TernaryTreap<String> ternaryTreap = TernaryTreapSet<String>()

..add('cat')

..add('Canary')

..add('dog')

..add('zebra')

..add('CAT');

```

```dart

print(ternaryTreap.keys);

```

```shell

(CAT, Canary, cat, dog, zebra)

```

```dart

print(ternaryTreap.keysByPrefix('ca'));

```

```shell

(cat)

```

```dart

print(ternaryTreap.toString());

```

```shell

-CAT

Canary

cat

dog

zebra

```

## Case insensitivity and other key mappings

The above example matches strings exactly, i.e. `keysByPrefix('ca')` returns 'cat' but not 'CAT'.

This is because the default identity KeyMapping: <i>m</i>(x) = x is used.
  
This can be overridden by specifying a KeyMapping during construction.

For example to achieve case insensitivity:

```dart

import  'package:ternarytreap/ternarytreap.dart'; 

void  main(List<String> args) {

final  TernaryTreap<String> ternaryTreap =

TernaryTreapSet<String>(TernaryTreap.lowercase)

..add('cat')

..add('Canary')

..add('dog')

..add('zebra')

..add('CAT');

}

```

```dart

print(ternaryTreap.keys);

```

```shell

(canary, cat, dog, zebra)

```

```dart

print(ternaryTreap.keysByPrefix('ca'));

```

```shell

(canary, cat)

```

```dart

print(ternaryTreap.toString());

```

```shell

canary

cat

dog

zebra

```

  

Some common `KeyMapping` options are supplied such as:

  

*  [lowerCase](https://pub.dev/documentation/ternarytreap/latest/ternarytreap/TernaryTreap/lowercase.html)

*  [collapseWhitespace](https://pub.dev/documentation/ternarytreap/latest/ternarytreap/TernaryTreap/collapseWhitespace.html)

*  [lowerCollapse](https://pub.dev/documentation/ternarytreap/latest/ternarytreap/TernaryTreap/lowerCollapse.html)

  

Create your own easily.

  

## Attaching String Data to Retain Key->Input Mapping

  

When a `KeyMapping` such as `lowercase` maps multiple inputs to the same key the original input strings are lost.

  

In the example below this results in input strings 'CAT' and 'Cat' being lost.

  

```dart

final  TernaryTreap<String> ternaryTreap =

TernaryTreapSet<String>(TernaryTreap.lowercase)

..add('cat')

..add('Cat')

..add('CAT');

  

print(ternaryTreap.keysByPrefix('ca'));

```

```shell

(cat)

```

  

To retain the original string you may attach it as a Value during insertion.


These strings may now be recovered during subsequent queries.

  
```dart

import  'package:ternarytreap/ternarytreap.dart';

  

void  main(List<String> args) {

final  TernaryTreap<String> ternaryTreap =

TernaryTreap<String>(TernaryTreap.lowercase)

..add('cat', 'cat')

..add('Cat', 'Cat')

..add('CAT', 'CAT')

..add('CanaRy', 'CanaRy')

..add('CANARY', 'CANARY');

}

```

```dart

print(ternaryTreap.keys);

```

```shell

(canary, cat)

```

```dart

print(ternaryTreap.keysByPrefix('ca'));

```

```shell

(canary, cat)

```

```dart

print(ternaryTreap.values);

```

```shell

(canary, CanaRy, CANARY, cat, Cat, CAT)

```

```dart

print(ternaryTreap.valuesByKeyPrefix('cat'));

```

```shell

(cat, Cat, CAT)

```

```dart

print(ternaryTreap.toString());

```

```shell

canary

CanaRy

CANARY

cat

cat

Cat

CAT

```

  

## Attaching Complex data Types
  

Sometimes it is useful to associate input strings with more complex datatypes.

  
For example the following datatype stores an 'Animal' with name, description and a timestamp:

  

```dart

import  'package:ternarytreap/ternarytreap.dart';

  

// An example of a data object, takes a name and description,

// and adds a timestamp.

class  Animal {

Animal(this.name, this.description)

: timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  

/// name - will be set to original input string pre KeyMapping

final  String name;

  

final  String description;

  

final  String timestamp;

  

/// Return String value.

///

/// @returns String repesenting object.

@override

String  toString() => <String, dynamic>{

'name': name,

'description': description,

'timestamp': timestamp,

}.toString();

}

  

void  main(List<String> args) {

final  TernaryTreap<Animal> ternaryTreap =

TernaryTreap<Animal>(TernaryTreap.lowerCollapse)

..add('Cat', Animal('Cat', 'Purrs'))

..add('Canary', Animal('Canary', 'Yellow'))

..add('Dog', Animal('Dog', 'Friend'))

..add('Zebra', Animal('Zebra', 'Stripes'))

..add('CAT', Animal('CAT', 'Scan'));

```

```dart

print(ternaryTreap.keys);

```

```shell

(canary, cat, dog, zebra)

```

```dart

print(ternaryTreap.keysByPrefix('ca'));

```

```shell

(canary, cat)

```

```dart

print(ternaryTreap.values);

```

```shell

({name: Canary, description: Yellow, timestamp: 1574730578753}, {name: Cat, description: Purrs, timestamp: 1574730578735}, {name: CAT, description: Scan, timestamp: 1574730578754}, {name: Dog, description: Friend, timestamp: 1574730578754}, {name: Zebra, description: Stripes, timestamp: 1574730578754})

```

```dart

print(ternaryTreap.valuesByKeyPrefix('ca'));

```

```shell

({name: Canary, description: Yellow, timestamp: 1574730578753}, {name: Cat, description: Purrs, timestamp: 1574730578735}, {name: CAT, description: Scan, timestamp: 1574730578754})

```

```dart

print(ternaryTreap.toString());

```

```shell

canary

{name: Canary, description: Yellow, timestamp: 1574730578753}

cat

{name: Cat, description: Purrs, timestamp: 1574730578735}

{name: CAT, description: Scan, timestamp: 1574730578754}

dog

{name: Dog, description: Friend, timestamp: 1574730578754}

zebra

{name: Zebra, description: Stripes, timestamp: 1574730578754}

```

  

## Features and bugs

  

Please file feature requests and bugs at the [issue tracker][tracker].

  

[tracker]: https://github.com/derbec/ternarytreap/issues
