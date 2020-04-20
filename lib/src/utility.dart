library utility;

import 'dart:collection';

/// A stack
class Stack<T> {
  /// Construct new [Stack]
  Stack([int initialSize = 0])
      : assert(initialSize != null),
        _list = ListQueue<T>(initialSize);

  ListQueue<T> _list;

  /// Number of elements in this [Stack]
  int get length => _list.length;

  /// Is this [Stack] empty?
  bool get isEmpty => _list.isEmpty;

  /// Is this [Stack] not empty?
  bool get isNotEmpty => _list.isNotEmpty;

  /// Return the current top element of [Stack]
  T get top => _list.last;

  /// Push a new element on top of [Stack]
  void push(T e) => _list.addLast(e);

  /// Pop element off [Stack]
  T pop() => _list.removeLast();

  /// Reverse elements in [Stack]
  void reverse() => _list = ListQueue.from(_list.toList().reversed);
}

/// Allow a reference to an object of primitive type to be stored
class ByRef<T> {
  /// Construct new [ByRef]
  ByRef(this.value);

  /// Value of this [ByRef]
  T value;
}
