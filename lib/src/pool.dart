library pool;

import 'package:collection/collection.dart';
import 'dart:collection';
import 'global.dart';

/// A single entry on the pool
class RunePoolEntry {
  /// Construct a new RunePoolEntry.
  /// Assumes _runes is passed an EfficientLength iterator that also
  /// provides efficient elementAt() method.
  /// Such as ListIterable or SubListIterable
  RunePoolEntry(this._runes, this._count);
  final Iterable<int> _runes;
  int _count;

  @override
  String toString()=> String.fromCharCodes(_runes);
}

/// Size of pool in bytes
int sizeOfPool(final HashSet<RunePoolEntry> runePool) {
  var poolSize = 0;
  for (final entry in runePool) {
    poolSize += (entry._runes.length + 1) * SIZE_OF_INT;
  }
  return poolSize;
}

/// Create a new pool
HashSet<RunePoolEntry> createPool() {
  final _iterableEquality = IterableEquality<int>();
  return HashSet<RunePoolEntry>(
      equals: (RunePoolEntry runePoolEntry1, RunePoolEntry runePoolEntry2) =>
          _iterableEquality.equals(
              runePoolEntry1._runes, runePoolEntry2._runes),
      hashCode: (final RunePoolEntry runePoolEntry) =>
          _iterableEquality.hash(runePoolEntry._runes));
}

/// Allocate new runes, drawing from pool if possible
List<int> allocateRunes(
    Iterable<int> runes,  HashSet<RunePoolEntry> runePool) {
  final key = RunePoolEntry(runes, 0);

  var poolEntry = runePool.lookup(key);
  if (identical(poolEntry, null)) {
    poolEntry = RunePoolEntry(List<int>.unmodifiable(runes), 1);
    runePool.add(poolEntry);
  } else {
    poolEntry._count++;
  }
  return poolEntry._runes as List<int>;
}

/// Free runes, remove form pool if no more refrences
void freeRunes(
     Iterable<int> runes,  HashSet<RunePoolEntry> runePool) {
  final key = RunePoolEntry(runes, 0);
  final poolEntry = runePool.lookup(key);
  // Avoid check for null because the getter will check anyways
  poolEntry._count--;

  if (poolEntry._count < 1) {
    runePool.remove(key);
  }
}
