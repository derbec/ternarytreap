import 'package:ternarytreap/ternarytreap.dart';

// An example of a data object, takes a title and description,
// and adds a timestamp.
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

void main(List<String> args) {
  final ternaryTreap =
      TernaryTreap<Metadata>(keyMapping: TernaryTreap.lowerCollapse)
        ..add('Cat', Metadata('Cat', 'Purrs'))
        ..add('Cart', Metadata('Cart', 'Transport'))
        ..add('Dog', Metadata('Dog', 'Friend'))
        ..add('Zebra', Metadata('Zebra', 'Stripes'))
        ..add('CAT', Metadata('CAT', 'Scan'));

  //print(ternaryTreap.searchByPrefix('ca'));

  //print(ternaryTreap.searchByPrefix('z'));

  // show arrangment of inserted data
  print(ternaryTreap.toString());
}
