# TernaryTreap
Self balancing prefix search trie. Good for:

* Autocompletion tasks - autocompleting textboxes etc.
* As a generic, fast and memory efficient collection allowing prefixed based searching.

# Usage

## The Short Version

## The Long Version

### The simplest use case for TernaryTreap is prefix matching

Insert keys and later return those starting with a given prefix.

This is useful for implementing autocompletion text boxes etc.

```dart
import 'package:ternarytreap/ternarytreap.dart';

  final TernaryTreap ternaryTreap = TernaryTreap()
    ..insert('cat')
    ..insert('dog')
    ..insert('fish')
    ..insert('canary')
    ..insert('bird')
    ..insert('catfish');

  print(ternaryTreap.searchKeysByPrefix('ca'));
```
```shell
[canary, cat, catfish]
```
```dart
print(ternaryTreap.searchKeysByPrefix('cat'));
```
```shell
[cat, catfish]
```
```dart
print(ternaryTreap.searchKeysByPrefix('catf'));
```
```shell
[catfish]
```
```dart
print(ternaryTreap.searchKeysByPrefix('catfq'));
```
```shell
[]
```

### Case sensitivity and other key mappings

The above example matches strings exactly.

To add case insensitivity or other mappings use a [KeyMapping](ternarytreap/KeyMapping.html) when constructing TernaryTree.

```dart
  final ternaryTreap = TernaryTreap(TernaryTreap.lowerCase)
    ..insert('CAt')
    ..insert('doG')
    ..insert('cAnaRy')
    ..insert('caTfiSh');

  print(ternaryTreap.searchKeysByPrefix('ca'));
```
```shell
[canary, cat, catfish]
```

Some common [KeyMapping](ternarytreap/KeyMapping.html) options are supplied such as:

* [lowerCase](ternarytreap/TernaryTreap/lowercase.html)
* [collapseWhitespace](ternarytreap/TernaryTreap/collapseWhitespace.html)
* [lowerCollapse](ternarytreap/TernaryTreap/lowerCollapse.html)

Create your own easily.

### Attaching String Data to Retain Key->Input Mapping

[KeyMapping](ternarytreap/KeyMapping.html) functions may represent an n to 1 relation to input strings.

When a [KeyMapping](ternarytreap/KeyMapping.html) such as [lowercase](ternarytreap/TernaryTreap/lowercase.html) maps multiple inputs to the same key the original input keys are lost.

```dart
  final ternaryTreap = TernaryTreap(TernaryTreap.lowerCase)
    ..insert('cat')
    ..insert('Cat')
    ..insert('CAT');

  print(ternaryTreap.searchKeysByPrefix('ca'));
```
```shell
[cat]
```

To retain the original string you may attach it as data during insertion.

Subsequent searches will return [KeyData](ternarytreap/KeyData-class.html) instances that encapsulate the 1 to n relationship between key and data.

```dart
  final ternaryTreap = TernaryTreap(TernaryTreap.lowerCase)
    ..insert('cat', 'cat')
    ..insert('Cat', 'Cat')
    ..insert('CAT', 'CAT')
    ..insert('CanaRy', 'CanaRy')
    ..insert('CANARY', 'CANARY');

  // Note difference between searchKeysByPrefix and searchByPrefix
  print(ternaryTreap.searchKeysByPrefix('ca'));
  // searchByPrefix returns a struct [KeyData] to handle the
  // 1 to n relationship between keys and associated data.
  print(ternaryTreap.searchByPrefix('ca'));
```
```shell
[cat]
[{key: canary, data: [CanaRy, CANARY]}, {key: cat, data: [cat, Cat, CAT]}]
```

Use the [PrefixMatcher](ternarytreap/PrefixMatcher-class.html) class which simplifies this functionality for String data:

```dart
// PrefixMatcher class is optimised for matching a prefix to a set of input strings.
final prefixMatcher = PrefixMatcher(TernaryTreap.lowerCase)
    ..insert('cat')
    ..insert('Cat')
    ..insert('CAT')
    ..insert('CanaRy')
    ..insert('CANARY');

  print(prefixMatcher.searchByPrefix('ca'));
```

### Attaching Complex data Types

Sometimes it is useful to associate input strings with more complex datatypes.

For example to store title, description and a timestamp the following datatype may suffice:

```dart
// An example of a data object, takes a title and description, and adds a timestamp.
class Metadata {
  Metadata(this.title, this.description)
      : timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  /// Title - will be set to original input string pre KeyMapping
  final String title;

  final String description;

  final String timestamp;

  /// Return String value.
  ///
  /// @returns String repesenting object.
  @override
  String toString() => <String, dynamic>{
        'title': title,
        'description': description,
        'timestamp': timestamp,
      }.toString();
}
```

Insert as usual:

```dart
  final ternaryTreap = TernaryTreap<Metadata>(TernaryTreap.lowerCollapse)
    ..insert('Cat', Metadata('Cat', 'Purrs'))
    ..insert('Cart', Metadata('Cart', 'Transport'))
    ..insert('Dog', Metadata('Dog', 'Friend'))
    ..insert('Zebra', Metadata('Zebra', 'Stripes'))
    ..insert('CAT', Metadata('CAT', 'Scan'));

  // show arrangment of inserted data in TernaryTreap
  print(ternaryTreap.toString());
```

```shell
-cart
 {title: Cart, description: Transport, timestamp: 1573802305583}
--cat
  {title: Cat, description: Purrs, timestamp: 1573802305573}
  {title: CAT, description: Scan, timestamp: 1573802305584}
dog
{title: Dog, description: Friend, timestamp: 1573802305584}
-zebra
 {title: Zebra, description: Stripes, timestamp: 1573802305584}
```

Search for all that match prefix: 'ca'

```dart
  print(ternaryTreap.searchByPrefix('ca'));
```

```shell
[{key: cart, data: [{title: Cart, description: Transport, timestamp: 1573802305583}]}, {key: cat, data: [{title: Cat, description: Purrs, timestamp: 1573802305573}, {title: CAT, description: Scan, timestamp: 1573802305584}]}]
```

Search for all that match prefix: 'z'

```dart
  print(ternaryTreap.searchByPrefix('z'));
```

```shell
[{key: zebra, data: [{title: Zebra, description: Stripes, timestamp: 1573802305584}]}]
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/derbec/ternarytreap/issues