library keymapping;

final RegExp _matchAlphaNumeric =
    RegExp(r'[\p{L}\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchNonAlphaNumeric =
    RegExp(r'[^\p{L}\p{Nl}\p{Nd}]+', unicode: true);
final RegExp _matchSeparators = RegExp(r'[\p{Zl}\p{Zp}\p{Zs}]+', unicode: true);

/// Often it is desirable to define equivalences between Key
/// strings, for example for case insensitivity.
///
/// This is achieved via the surjection:
///
/// * <i>m</i> : <i>S</i>&twoheadrightarrow; <i>K  &sube; S</i>
///
/// such that:
///
/// * <i>S</i> is set of all strings
/// * <i>K</i> is set of Keys
///
/// <i>m</i>(<i>m</i>(x)) = <i>m</i>(x), i.e. <i>m</i> must be
/// [idempotent](https://en.wikipedia.org/wiki/Idempotence),
/// repeated applications do not change the result.
///
/// For example:
///
/// * <i>m</i>(x) = lowercase(x).
///
/// [KeyMapping] is optionally specified during construction and
/// applied to keys during all operations.
///
/// If no [KeyMapping] is supplied then the default identity function is used.
///
/// * <i>m</i>(x) = x.
///
/// Predefined mappings include:
///
/// * [lowercase]
/// * [uppercase]
/// * [collapseWhitespace]
/// * [nonLetterToSpace]
/// * [lowerCollapse]
/// * [joinSingleLetters]
typedef KeyMapping = String Function(String str);

/// Return [str] unchanged.
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client
String identity(String str) => str;

/// Transform [str] such that all characters are lowercase.
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client
String lowercase(String str) => str.toLowerCase();

/// Transform [str] such that all characters are uppercase.
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client
String uppercase(String str) => str.toUpperCase();

/// Transform [str] such that each non letter character is
/// replaced by a space character.
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client
String nonLetterToSpace(String str) =>
    str.replaceAll(_matchNonAlphaNumeric, ' ');

/// Transform [str] such that adjacent single alphanumeric symbols separated by
/// whitespace are joined together. For example:
///
/// '    a b   a   b  abcd a b' -> 'ab   ab  abcd ab'
///
/// When used after [nonLetterToSpace] this ensures that 'U.S.A' and 'USA'
/// are equivilent after [KeyMapping] applied.
///
/// Note: This transform trims and collapses whitespace during operation
/// and is thus equivilent also to performing [collapseWhitespace].
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client
String joinSingleLetters(String str) {
  final chunks = str.trim().split(_matchSeparators);

  final res = <String>[];
  //join all adjacent chunks with size 1
  final newChunk = StringBuffer();

  for (final chunk in chunks) {
    // if chuck is single Letter
    if (chunk.length == 1 && _matchAlphaNumeric.matchAsPrefix(chunk) != null) {
      newChunk.write(chunk);
    } else {
      if (newChunk.isNotEmpty) {
        res.add(newChunk.toString());
        newChunk.clear();
      }
      res.add(chunk);
    }
  }
  if (newChunk.isNotEmpty) {
    res.add(newChunk.toString());
  }
  return res.join(' ');
}

/// Transform [str] such that:
///
/// * Whitespace is trimmed from start and end
/// * Runs of multiple whitespace characters are collapsed into a single ' '.
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client.
String collapseWhitespace(String str) =>
    str.trim().replaceAll(_matchSeparators, ' ');

/// Transform [str] with both [lowercase] and [collapseWhitespace].
///
/// When passed to [TernaryTreap()] this [KeyMapping] will be applied
/// to all key arguments passed by client
String lowerCollapse(String str) => collapseWhitespace(str).toLowerCase();
