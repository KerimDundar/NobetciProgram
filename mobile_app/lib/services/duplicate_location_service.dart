import 'text_normalizer.dart';

class DuplicateLocationService {
  const DuplicateLocationService({
    TextNormalizer normalizer = const TextNormalizer(),
  }) : _normalizer = normalizer;

  final TextNormalizer _normalizer;

  /// Maps roster_logic.duplicate_location_key.
  String duplicateLocationKey(String? value) {
    return _normalizer.duplicateLocationKey(value);
  }

  /// Maps roster_logic.is_duplicate_location.
  bool isDuplicateLocation(String? top, String? bottom) {
    final topKey = duplicateLocationKey(top);
    return topKey.isNotEmpty && topKey == duplicateLocationKey(bottom);
  }
}
