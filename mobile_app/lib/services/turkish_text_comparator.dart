class TurkishTextComparator {
  static const List<String> _alphabet = [
    'a', 'b', 'c', 'ç', 'd', 'e', 'f', 'g', 'ğ', 'h',
    'ı', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'ö', 'p',
    'r', 's', 'ş', 't', 'u', 'ü', 'v', 'y', 'z',
  ];

  static final Map<String, int> _order = {
    for (var i = 0; i < _alphabet.length; i++) _alphabet[i]: i,
  };

  // Turkish-aware lowercase: I→ı, İ→i before generic toLowerCase
  static String toLower(String s) =>
      s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  // Turkish-aware uppercase: i→İ, ı→I before generic toUpperCase
  static String toUpper(String s) =>
      s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  // Returns the Turkish-uppercase first character of a name for avatar display
  static String initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return toUpper(trimmed[0]);
  }

  static int compare(String a, String b) {
    final la = toLower(a);
    final lb = toLower(b);
    final len = la.length < lb.length ? la.length : lb.length;
    for (var i = 0; i < len; i++) {
      final ca = la[i];
      final cb = lb[i];
      if (ca == cb) continue;
      final ia = _order[ca] ?? 999;
      final ib = _order[cb] ?? 999;
      if (ia != ib) return ia.compareTo(ib);
    }
    return la.length.compareTo(lb.length);
  }
}
