library pool;

import 'dart:collection';

const _SIZE_OF_INT = 4;


/// A single entry on the pool
class CodeUnitPoolEntry {
  /// Construct a new CodeUnitPoolEntry
  CodeUnitPoolEntry(this._codeUnits, this._count);
  final Iterable<int> _codeUnits;
  int _count;
}

/// Size of pool in bytes
int sizeOfPool(final HashSet<CodeUnitPoolEntry> codeUnitPool) {
  var poolSize = 0;
    for (final entry in codeUnitPool) {
      poolSize += (entry._codeUnits.length + 1) * _SIZE_OF_INT;
    }
  return poolSize;
}

/// Create a new pool
HashSet<CodeUnitPoolEntry> createPool() => HashSet<CodeUnitPoolEntry>(equals:
      (final CodeUnitPoolEntry codeUnitPoolEntry1,
          final CodeUnitPoolEntry codeUnitPoolEntry2) {
    if (codeUnitPoolEntry1 == null || codeUnitPoolEntry2 == null) {
      return false;
    }

    final codeUnits1 = codeUnitPoolEntry1._codeUnits;
    final codeUnits2 = codeUnitPoolEntry2._codeUnits;

    if (identical(codeUnits1, codeUnits2)) {
      return true;
    }

    final length = codeUnits1.length;
    if (length != codeUnits2.length) {
      return false;
    }

    for (var i = 0; i < length; i++) {
      if (codeUnits1.elementAt(i) != codeUnits2.elementAt(i)) {
        return false;
      }
    }

    return true;
  }, hashCode: (final CodeUnitPoolEntry codeUnitPoolEntry) {
    // Stolen from Quiver: lib/src/core/hash.dart
    var hash = 0;
    final codeUnits = codeUnitPoolEntry._codeUnits;

    final length = codeUnits.length;
    for (var i = 0; i < length; i++) {
      hash = 0x1fffffff & (hash + codeUnits.elementAt(i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    }
    return hash ^ (hash >> 6);
  });

/// Allocate new code units, drawing from pool if possible
List<int> allocateCodeUnits(final Iterable<int> codeUnits,
    final HashSet<CodeUnitPoolEntry> codeUnitPool) {
  final key = CodeUnitPoolEntry(codeUnits, 0);

  var poolEntry = codeUnitPool.lookup(key);
  if (poolEntry == null) {
    poolEntry = CodeUnitPoolEntry(List<int>.unmodifiable(codeUnits), 1);
    codeUnitPool.add(poolEntry);
  } else {
    poolEntry._count++;
  }
  return poolEntry._codeUnits as List<int>;
}

/// Free code units, remove form pool if no more refrences
void freeCodeUnits(final Iterable<int> codeUnits,
    final HashSet<CodeUnitPoolEntry> codeUnitPool) {
  final key = CodeUnitPoolEntry(codeUnits, 0);
  final poolEntry = codeUnitPool.lookup(key);
  // Avoid check for null because the getter will check anyways
  poolEntry._count--;
  if (poolEntry._count < 1) {
    codeUnitPool.remove(key);
  }
}
