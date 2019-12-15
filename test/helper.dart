dynamic toEncodable(dynamic obj) {
  if (obj is Iterable<String>) {
    return obj.toList();
  }
  if (obj is Set) {
    return obj.toList();
  }
  if (obj is MapEntry<String, Iterable<int>>) {
    return <String, dynamic>{'key': obj.key, 'val': obj.value.toList()};
  }
  if (obj is MapEntry<String, int>) {
    return <String, dynamic>{'key': obj.key, 'val': obj.value};
  }

  return null;
}
