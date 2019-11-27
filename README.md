# TernaryTreap
Self balancing ternary tree designed for:

* Autocompletion tasks - autocompleting textboxes etc.
* Use as a generic, fast and memory efficient collection allowing prefixed based searching.
* Includes class PrefixMatcher which suffices for most autocomplete cases.

# Usage

## TL;DR

For simple prefix matching within a set of strings use: [PrefixMatcher](#prefixmatcher) with appropriate [KeyMapping](ternarytreap/KeyMapping.html).


```dart
// PrefixMatcher class is optimised for matching a prefix to a set of input strings.
  final PrefixMatcher matcher = PrefixMatcher(TernaryTreap.lowerCollapse)
    ..addAll(['cat', 'Cat', 'CAT', 'CanaRy', 'CANARY']);
```
```dart
print(matcher.match('can'));
```
```shell
(CanaRy, CANARY)
```

For more complex usage read on.

## Most basic case

Insert keys and later return those starting with a given prefix.

This is useful for implementing autocompletion text boxes etc.

```dart
void main(List<String> args) {
  final TernaryTreap<String> ternaryTreap = TernaryTreap<String>()
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
print(ternaryTreap.values.flatten);
```
```shell
(CAT, Canary, cat, dog, zebra)
```
```dart
print(ternaryTreap.valuesByKeyPrefix('ca').flatten);
```
```shell
(cat)
```
```dart
print(ternaryTreap.toString());
```
```shell
-CAT
 CAT
Canary
Canary
cat
cat
dog
dog
zebra
zebra
```
## Case insensitivity and other key mappings

The above example matches strings exactly, i.e. `keysByPrefix('ca')`
returns 'cat' but not 'CAT'.

To add case insensitivity or other mappings use a [KeyMapping](ternarytreap/KeyMapping.html) when constructing TernaryTree.

```dart
import 'package:ternarytreap/ternarytreap.dart';

void main(List<String> args) {
  final TernaryTreap<String> ternaryTreap =
      TernaryTreap<String>(keyMapping: TernaryTreap.lowercase)
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
print(ternaryTreap.values.flatten);
```
```shell
(canary, cat, dog, zebra)
```
```dart
print(ternaryTreap.valuesByKeyPrefix('ca').flatten);
```
```shell
(canary, cat)
```
```dart
print(ternaryTreap.toString());
```
```shell
canary
canary
cat
cat
dog
dog
zebra
zebra
```

Some common `KeyMapping` options are supplied such as:

* [lowerCase](ternarytreap/TernaryTreap/lowercase.html)
* [collapseWhitespace](ternarytreap/TernaryTreap/collapseWhitespace.html)
* [lowerCollapse](ternarytreap/TernaryTreap/lowerCollapse.html)

Create your own easily.

## Attaching String Data to Retain Key->Input Mapping

`KeyMapping` functions may represent an n to 1 relation from input strings to keys.

When a `KeyMapping` such as `lowercase` maps multiple inputs to the same key the original input strings are lost.

In the example below this results in input strings 'CAT' and 'Cat' being lost.

```dart
final TernaryTreap<String> ternaryTreap2 =
      TernaryTreap<String>(keyMapping: TernaryTreap.lowercase)
        ..add('cat')
        ..add('Cat')
        ..add('CAT');

  print(ternaryTreap2.valuesByKeyPrefix('ca').flatten);
```
```shell
(cat)
```

To retain the original string you may attach it as data during insertion.

These strings may now be recovered during subsequent queries.

```dart
import 'package:ternarytreap/ternarytreap.dart';

void main(List<String> args) {
  final TernaryTreap<String> ternaryTreap =
      TernaryTreap<String>(keyMapping: TernaryTreap.lowercase)
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
print(ternaryTreap.values.flatten);
```
```shell
(canary, CanaRy, CANARY, cat, Cat, CAT)
```
```dart
print(ternaryTreap.valuesByKeyPrefix('cat').flatten);
```
```shell
(cat, Cat, CAT)
```
```dart
print(ternaryTreap.toString());
```
```shell
canary
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

For example to store an 'Animal' with name, description and a timestamp the following datatype may suffice:

```dart
import 'package:ternarytreap/ternarytreap.dart';

// An example of a data object, takes a name and description,
// and adds a timestamp.
class Animal {
  Animal(this.name, this.description)
      : timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  /// name - will be set to original input string pre KeyMapping
  final String name;

  final String description;

  final String timestamp;

  /// Return String value.
  ///
  /// @returns String repesenting object.
  @override
  String toString() => <String, dynamic>{
        'name': name,
        'description': description,
        'timestamp': timestamp,
      }.toString();
}

void main(List<String> args) {
  final TernaryTreap<Animal> ternaryTreap =
      TernaryTreap<Animal>(keyMapping: TernaryTreap.lowerCollapse)
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
([{name: Canary, description: Yellow, timestamp: 1574730578753}], [{name: Cat, description: Purrs, timestamp: 1574730578735}, {name: CAT, description: Scan, timestamp: 1574730578754}], [{name: Dog, description: Friend, timestamp: 1574730578754}], [{name: Zebra, description: Stripes, timestamp: 1574730578754}])
```
```dart
print(ternaryTreap.valuesByKeyPrefix('ca'));
```
```shell
([{name: Canary, description: Yellow, timestamp: 1574730578753}], [{name: Cat, description: Purrs, timestamp: 1574730578735}, {name: CAT, description: Scan, timestamp: 1574730578754}])
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

[tracker]: https://github.com/derbec/ternarytreap/issues