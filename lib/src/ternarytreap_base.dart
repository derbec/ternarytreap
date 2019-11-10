import 'dart:convert';
import 'dart:math';

/// A function that transforms a key
typedef KeyTransform = String Function(String key);

typedef _Visitor<T> = void Function(
    _Node<T> thisNode, String currentStr, int currentDepth);

/// Wraps search results of [TernaryTreap.search()] and
/// [TernaryTreap.searchPrefix()].
/// A single [key] can be inserted multiple times with different
/// data thus [data] is a list.
class TernaryTreapResult<T> {
  /// Constructs a new [TernaryTreapResult].
  ///
  /// @param [key] The unique key for this result
  /// @param [data] The data for this result
  /// @throws [ArgumentError] If passed null data.
  TernaryTreapResult(this.key, this.data) {
    if (key == null) {
      throw ArgumentError.notNull('key');
    }
    if (data == null) {
      throw ArgumentError.notNull('data');
    }
  }

  /// The unique key for this result.
  final String key;

  /// A list of user supplied data objects.
  ///
  /// Because user may insert the same key multiple times with different
  /// data this is a list. Will never be null.
  final List<T> data;

  /// Create map for json encoding.
  ///
  /// @returns Map repesenting object.
  Map<String, dynamic> toJson() => <String, dynamic>{
        TernaryTreap._key: key,
        TernaryTreap._data: data,
      };
}

/// A hybrid of [Ternary search trie](https://en.wikipedia.org/wiki/Ternary_search_tree)
/// and [Treap](https://en.wikipedia.org/wiki/Treap) with following properties:
///
/// * Fast prefix searching and low memory cost of a ternary search tree.
/// * Self balancing capability of a treap to flatten tree and
///   minimise search paths.
///
/// Additionally each unique key can be associated with 0..n arbitrary
/// data objects (where n is number of inserts over same key).
///
/// For example the key 'it' may map to 'IT', 'It' or 'it'.
/// Each of these key representations could require its own
/// metadata such as weighting etc.
/// # Structure
/// ```
///                +---+   Graph with 3 keys,
///                | C |   each associated with
///                +-+-+   different number of
///                  |     data objects:
///                  |
///                +-+-+   CAN: no data
///   +------------+ U |   CUP: 2 data objects
///   |            +-+-+   CUT: 1 data object
/// +-+-+            |
/// | A |            |
/// +-+-+          +-+-+
///   |            | P +-------------+
/// +-+-+          +-+-+             |
/// | N |            |             +-+-+
/// +---+            |             | T |
///          +------+++------+     +-+-+
///          | Data | | Data |       |
///          +------+-+------+       |
///                               +--+---+
///                               | Data |
///                               +------+
/// ```
/// Note: Each node also contains a priority value for balancing purposes.
class TernaryTreap<T> {
  /// Constructs a new [TernaryTreap].
  ///
  /// @param [keyTransform] Optional instance of [KeyTransform] to be
  /// applied to all keys processed by this [TernaryTreap].
  /// @returns New [TernaryTreap].
  TernaryTreap([KeyTransform keyTransform]) : _keyTransform = keyTransform;

  /// Key for stats map depth value.
  static const String depth = 'depth';

  /// Key for stats map node count value.
  static const String nodeCount = 'nodecount';

  /// Key for stats map key count value.
  static const String keyCount = 'keycount';

  static const String _key = 'key';
  static const String _data = 'data';

  /// Transform a key to all lowercase.
  /// When passed to [TernaryTreap()] this transform will be applied
  /// to all key arguments passed by client
  ///
  /// @param key A key to transform.
  /// @returns key after transformation.
  static String lowerCase(String key) => key.toLowerCase();

  /// Transform a key such that:
  ///
  /// * Whitespace is trimmed from start and end
  /// * Runs of multiple whitespace characters are collapsed into a single ' '.
  ///
  /// When passed to [TernaryTreap()] this transform will be applied
  /// to all key arguments passed by client.
  ///
  /// @param key A key to transform.
  /// @returns key after transformation.
  static String collapseWhitespace(String key) =>
      key.replaceAll(RegExp(r'^\s+|\s+$'), '').replaceAll(RegExp(r'\s+'), ' ');

  /// Transform a key with both [lowerCase()] and [collapseWhitespace()].
  /// When passed to [TernaryTreap()] this transform will be applied
  /// to all key arguments passed by client
  ///
  /// @param key A key to transform.
  /// @returns key after transformation.
  static String lowerCollapse(String key) =>
      collapseWhitespace(key).toLowerCase();

  final Random _random = Random();
  _Node<T> _root;
  final KeyTransform _keyTransform;

  /// Insert a key and optional data object.
  ///
  /// @param [key] A unique sequence of characters to be stored for retrieval.
  /// @param [data] A user specified data object to associate with this key.
  /// @throws [ArgumentError] if key is empty.
  void insert(String key, [T data]) {
    if (key.isEmpty) {
      throw ArgumentError();
    }
    _root = _insert(_root, _transformKey(key).codeUnits, 0, data);
  }

  /// Search for all keys that contain [prefix].
  ///
  /// @param [prefix] A prefix to search for.
  /// If [prefix] is empty then all keys are returned.
  /// @returns A list of [TernaryTreapResult] objects representing all keys
  /// starting with prefix and any associated data objects.
  /// List is in order of traversal. If no keys found then empty list returned.
  List<TernaryTreapResult<T>> searchPrefix(String prefix) {
    final String prefixTransformed = _transformKey(prefix);
    final List<TernaryTreapResult<T>> entries = <TernaryTreapResult<T>>[];
    if (prefixTransformed.isEmpty) {
      //Traverse entire tree
      _inorderTraversalFromNode(_root, '', 0,
          (_Node<T> thisNode, String currentStr, int currentDepth) {
        if (thisNode._isEnd) {
          entries.add(TernaryTreapResult<T>(currentStr, thisNode.data));
        }
      });
    } else {
      //Traverse from last node of prefix
      final _Node<T> lastPrefixNode =
          _descendToPrefixLastNode(_root, prefixTransformed.codeUnits, 0);
      _prefixTraversalFromNode(lastPrefixNode, '', 0,
          (_Node<T> thisNode, String currentStr, int currentDepth) {
        if (thisNode._isEnd) {
          entries.add(TernaryTreapResult<T>(
              prefixTransformed + currentStr, thisNode.data));
        }
      });
    }
    return entries;
  }

  /// Search for specified [key].
  ///
  /// @param [key] The key to search for.
  /// @returns An instance of [TernaryTreapResult] representing [key]
  /// and any associated data objects.
  /// If no keys found then empty list returned.
  TernaryTreapResult<T> search(String key) {
    if (key.isEmpty) {
      throw ArgumentError();
    }
    final String prefixTransformed = _transformKey(key);
    final _Node<T> lastPrefixNode =
        _descendToPrefixLastNode(_root, prefixTransformed.codeUnits, 0);
    if (lastPrefixNode == null) {
      return null;
    }
    assert(lastPrefixNode._isEnd, 'Not at word end');
    return TernaryTreapResult<T>(prefixTransformed, lastPrefixNode.data);
  }

  /// Generate a string representation of this [TernaryTreap].
  /// Requires that data objects be json encodable.
  ///
  /// @param [padding] Optional left padding to indicate depth.
  /// @returns An list of [String] objects in order of traversal formated as:
  /// key -> data (json encoded)
  List<String> formattedTree([String padding = '-']) {
    final List<String> lines = <String>[];
    _inorderTraversalFromNode(_root, '', 0,
        (_Node<T> thisNode, String currentStr, int currentDepth) {
      if (thisNode._isEnd) {
        lines.add('${currentStr.padLeft(currentDepth + 1, padding)}'
            ' -> ${json.encode(thisNode.data)}');
      }
    });
    return lines;
  }

  /// Generate stats for this [TernaryTreap].
  ///
  /// @returns A [Map] with statistical info accessed via keys:
  ///           [Depth] - Maximum depth of [TernaryTreap].
  ///           [NodeCount] - Total number of nodes in [TernaryTreap].
  ///           [KeyCount] - Total number of keys in [TernaryTreap].
  Map<String, int> stats() {
    int depth = 0;
    int nodeCount = 0;
    int keyCount = 0;
    _inorderTraversalFromNode(_root, '', 0,
        (_Node<T> thisNode, String currentStr, int currentDepth) {
      if (currentDepth > depth) {
        depth = currentDepth;
      }
      nodeCount++;
      if (thisNode._isEnd) {
        keyCount++;
      }
    });
    return <String, int>{
      TernaryTreap.depth: depth,
      TernaryTreap.nodeCount: nodeCount,
      TernaryTreap.keyCount: keyCount
    };
  }

  String _transformKey(String key) =>
      _keyTransform == null ? key : _keyTransform(key);

  _Node<T> _insert(
      _Node<T> thisNode, List<int> codeUnits, int i, dynamic data) {
    _Node<T> _thisNode;
    if (null == thisNode) {
      _thisNode = _Node<T>(codeUnits[i], _random.nextInt(1 << 32));
    } else {
      _thisNode = thisNode;
    }

    if (codeUnits[i] < _thisNode._codeUnit) {
      _thisNode._left = _insert(_thisNode._left, codeUnits, i, data);
      if (_thisNode._left._priority > _thisNode._priority) {
        _thisNode = _rotateRight(_thisNode);
      }
    } else if (codeUnits[i] > _thisNode._codeUnit) {
      _thisNode._right = _insert(_thisNode._right, codeUnits, i, data);
      if (_thisNode._right._priority > _thisNode._priority) {
        _thisNode = _rotateLeft(_thisNode);
      }
    } else {
      if (i + 1 < codeUnits.length) {
        _thisNode._mid = _insert(_thisNode._mid, codeUnits, i + 1, data);
      } else {
        _thisNode.data ??= <T>[];
        if (data != null) {
          _thisNode.data.add(data);
        }
      }
    }

    return _thisNode;
  }

  _Node<T> _descendToPrefixLastNode(
      _Node<T> thisNode, List<int> codeUnits, int ptr) {
    if (thisNode == null) {
      return null;
    }

    if (codeUnits[ptr] < thisNode._codeUnit) {
      return _descendToPrefixLastNode(thisNode._left, codeUnits, ptr);
    } else {
      if (codeUnits[ptr] > thisNode._codeUnit) {
        return _descendToPrefixLastNode(thisNode._right, codeUnits, ptr);
      } else {
        if (ptr == (codeUnits.length - 1)) {
          return thisNode;
        } else {
          return _descendToPrefixLastNode(thisNode._mid, codeUnits, ptr + 1);
        }
      }
    }
  }

  void _inorderTraversalFromNode(_Node<T> thisNode, String currentStr,
      int currentDepth, _Visitor<T> visitor) {
    if (thisNode != null) {
      _inorderTraversalFromNode(
          thisNode._left, currentStr, currentDepth + 1, visitor);
      final String nextStr =
          currentStr + String.fromCharCode(thisNode._codeUnit);
      visitor(thisNode, nextStr, currentDepth);
      _inorderTraversalFromNode(
          thisNode._mid, nextStr, currentDepth + 1, visitor);
      _inorderTraversalFromNode(
          thisNode._right, currentStr, currentDepth + 1, visitor);
    }
  }

  void _prefixTraversalFromNode(_Node<T> thisNode, String currentStr,
      int currentDepth, _Visitor<T> visitor) {
    if (thisNode != null) {
      visitor(thisNode, currentStr, currentDepth);
      _inorderTraversalFromNode(
          thisNode._mid, currentStr, currentDepth + 1, visitor);
    }
  }

  //      a            b
  //     / \          / \
  //    b   e   -->  c   a
  //   / \              / \
  //  c   d            d   e
  _Node<T> _rotateRight(_Node<T> a) {
    final _Node<T> b = a._left;
    final _Node<T> d = b._right;
    b._right = a;
    a._left = d;
    return b;
  }

  //     b              a
  //    / \            / \
  //   c   a    -->   b   e
  //      / \        / \
  //     d   e      c   d
  _Node<T> _rotateLeft(_Node<T> b) {
    final _Node<T> a = b._right;
    final _Node<T> d = a._left;
    a._left = b;
    b._right = d;
    return a;
  }
}

class _Node<T> {
  _Node(this._codeUnit, this._priority);

  final int _codeUnit;
  final int _priority;

  //A single node may map to multiple data objects
  List<T> data;

  _Node<T> _left;
  _Node<T> _mid;
  _Node<T> _right;

  bool get _isEnd => data != null;
}
