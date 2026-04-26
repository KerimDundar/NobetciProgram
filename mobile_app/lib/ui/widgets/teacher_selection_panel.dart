import 'package:flutter/material.dart';

import '../../models/teacher.dart';
import '../../models/week.dart';
import '../../services/teacher_assignment_lookup_service.dart';

Future<Teacher?> showTeacherSelectionPanel(
  BuildContext context, {
  required List<Teacher> teachers,
  required String title,
  Week? week,
  int? assignmentDayIndex,
  TeacherAssignmentLookupService? assignmentLookupService,
}) {
  return showModalBottomSheet<Teacher>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return TeacherSelectionPanel(
        title: title,
        teachers: teachers,
        week: week,
        assignmentDayIndex: assignmentDayIndex,
        assignmentLookupService: assignmentLookupService,
      );
    },
  );
}

class TeacherSelectionPanel extends StatefulWidget {
  const TeacherSelectionPanel({
    super.key,
    required this.title,
    required this.teachers,
    this.week,
    this.assignmentDayIndex,
    this.assignmentLookupService,
    this.embedded = false,
    this.onTeacherTap,
  });

  final String title;
  final List<Teacher> teachers;
  final Week? week;
  final int? assignmentDayIndex;
  final TeacherAssignmentLookupService? assignmentLookupService;
  final bool embedded;
  final ValueChanged<Teacher>? onTeacherTap;

  @override
  State<TeacherSelectionPanel> createState() => _TeacherSelectionPanelState();
}

class _TeacherSelectionPanelState extends State<TeacherSelectionPanel> {
  late final TextEditingController _searchController;
  late final TeacherAssignmentLookupService _assignmentLookupService;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _assignmentLookupService =
        widget.assignmentLookupService ??
        const TeacherAssignmentLookupService();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleTeachers = _visibleTeachers();
    final content = Column(
      mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(widget.title, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('teacher-picker-search'),
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Ogretmen ara',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.separated(
            key: const ValueKey('teacher-picker-list'),
            shrinkWrap: true,
            itemCount: visibleTeachers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final teacher = visibleTeachers[index];
              return ListTile(
                key: ValueKey('teacher-picker-item-${teacher.id}'),
                leading: CircleAvatar(child: Text(_initials(teacher.name))),
                title: Text(teacher.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(teacher.isActive ? 'Aktif' : 'Pasif'),
                    ),
                    if (widget.week != null)
                      IconButton(
                        key: ValueKey('teacher-picker-info-${teacher.id}'),
                        tooltip: 'Gorev bilgisi',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showTeacherAssignments(teacher),
                      ),
                  ],
                ),
                onTap: () {
                  if (widget.onTeacherTap != null) {
                    widget.onTeacherTap!(teacher);
                    return;
                  }
                  Navigator.of(context).pop(teacher);
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(height: 560, child: content),
      ),
    );
  }

  Future<void> _showTeacherAssignments(Teacher teacher) async {
    final week = widget.week;
    if (week == null) {
      return;
    }

    final assignments = _assignmentLookupService.assignmentsFromWeek(
      week: week,
      teacherName: teacher.name,
      dayIndex: widget.assignmentDayIndex,
    );

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              key: ValueKey('teacher-assignment-sheet-${teacher.id}'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        teacher.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('teacher-assignment-close-${teacher.id}'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (assignments.isEmpty)
                  const Text(
                    'Bu hafta gorev atamasi yok.',
                    key: ValueKey('teacher-assignment-empty'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: assignments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final assignment = assignments[index];
                        final location = assignment.location.isEmpty
                            ? 'Satir ${assignment.rowIndex + 1}'
                            : assignment.location;
                        return ListTile(
                          key: ValueKey(
                            'teacher-assignment-item-${teacher.id}-$index',
                          ),
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(location),
                          subtitle: Text(assignment.dayName),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Teacher> _visibleTeachers() {
    final query = _searchController.text.trim().toLowerCase();

    return widget.teachers
        .where((teacher) {
          if (query.isEmpty) {
            return true;
          }
          return teacher.name.toLowerCase().contains(query);
        })
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }
}
