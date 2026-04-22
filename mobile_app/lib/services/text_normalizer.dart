class TextNormalizer {
  const TextNormalizer();

  /// Maps roster_logic.normalize_name_text.
  String displayClean(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Maps roster_logic.normalize_text with Turkish-aware FIX 1 behavior.
  String canonical(String? value) {
    final cleaned = _normalizeCommonTurkishComposed(displayClean(value));
    if (cleaned.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final rune in cleaned.runes) {
      final char = String.fromCharCode(rune);
      if (char == 'i') {
        buffer.write('\u0130');
      } else if (char == '\u0131') {
        buffer.write('I');
      } else {
        buffer.write(char.toUpperCase());
      }
    }
    return buffer.toString();
  }

  bool canonicalEquals(String? left, String? right) {
    return canonical(left) == canonical(right);
  }

  /// Maps roster_logic.duplicate_location_key with FIX 4 dash handling.
  String duplicateLocationKey(String? value) {
    final text = canonical(value);
    if (text.isEmpty) {
      return '';
    }
    return text.replaceAll(_duplicateLocationSeparators, '');
  }

  String _normalizeCommonTurkishComposed(String value) {
    return value
        .replaceAll('C\u0327', '\u00C7')
        .replaceAll('c\u0327', '\u00E7')
        .replaceAll('G\u0306', '\u011E')
        .replaceAll('g\u0306', '\u011F')
        .replaceAll('I\u0307', '\u0130')
        .replaceAll('i\u0307', 'i')
        .replaceAll('O\u0308', '\u00D6')
        .replaceAll('o\u0308', '\u00F6')
        .replaceAll('S\u0327', '\u015E')
        .replaceAll('s\u0327', '\u015F')
        .replaceAll('U\u0308', '\u00DC')
        .replaceAll('u\u0308', '\u00FC');
  }

  static final RegExp _duplicateLocationSeparators = RegExp(
    '[\\s\\-\u2010\u2011\u2012\u2013\u2014\u2015\u2212\uFE58\uFE63\uFF0D]+',
    unicode: true,
  );
}
