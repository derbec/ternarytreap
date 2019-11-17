# TernaryTreap example
* Demonstrates the key -> data relationship using different key transforms.
* Shows how to add a custom data type containing title, description and timestamp.
* Shows how the [TernaryTreap] is built and balanced.


## Usage:
dart main.dart <KeyMapping>

## KeyMapping Indexes:
0 - No key transform
1 - Lowercase key transform
2 - Collapse whitespace key transform
3 - Lowercase and Collapse whitespace key transform

## Examples:
dart main.dart 0
dart main.dart 1
dart main.dart 2
