class Teacher {
  Teacher({
    required String? id,
    required String? name,
    bool? isActive,
  }) : id = _cleanText(id),
       name = _cleanText(name),
       isActive = isActive ?? true;

  final String id;
  final String name;
  final bool isActive;

  bool get isValid => id.isNotEmpty && name.isNotEmpty;

  Teacher copyWith({
    String? id,
    String? name,
    bool? isActive,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }

  static String _cleanText(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
