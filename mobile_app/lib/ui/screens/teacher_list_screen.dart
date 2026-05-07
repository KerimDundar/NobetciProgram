import 'package:flutter/material.dart';

import '../../models/teacher.dart';
import '../../models/week.dart';
import '../../state/teacher_list_state.dart';
import '../widgets/teacher_selection_panel.dart';

class TeacherListScreen extends StatelessWidget {
  const TeacherListScreen({
    super.key,
    required this.state,
    this.currentWeek,
    this.onTeacherDeletedFromRoster,
  });

  final TeacherListStateAdapter state;
  final Week? currentWeek;
  final int Function(Teacher teacher)? onTeacherDeletedFromRoster;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Öğretmenler')),
          body: _buildBody(context),
          floatingActionButton: FloatingActionButton(
            key: const ValueKey('teacher-list-add-button'),
            onPressed: () => _openCreateTeacherForm(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('teacher-list-loading')),
      );
    }

    final errorMessage = state.errorMessage;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorMessage,
            key: const ValueKey('teacher-list-error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.teachers.isEmpty) {
      return const Center(
        child: Text(
          'Henüz öğretmen kaydı yok.',
          key: ValueKey('teacher-list-empty'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return TeacherSelectionPanel(
      embedded: true,
      title: 'Öğretmen Listesi',
      teachers: state.teachers,
      week: currentWeek,
      onTeacherTap: (teacher) => _openEditTeacherForm(context, teacher),
    );
  }

  Future<void> _openCreateTeacherForm(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _TeacherCreateForm(state: state);
      },
    );

    if (created != true || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Öğretmen eklendi.')));
  }

  Future<void> _openEditTeacherForm(
    BuildContext context,
    Teacher teacher,
  ) async {
    final result = await showModalBottomSheet<_TeacherEditAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _TeacherEditForm(state: state, teacher: teacher);
      },
    );

    if (result == null || !context.mounted) {
      return;
    }
    final message = switch (result) {
      _TeacherEditAction.updated => 'Öğretmen güncellendi.',
      _TeacherEditAction.deleted => _deleteMessage(teacher),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deleteMessage(Teacher teacher) {
    final clearedCount = onTeacherDeletedFromRoster?.call(teacher) ?? 0;
    if (clearedCount <= 0) {
      return 'Öğretmen silindi.';
    }
    return 'Öğretmen silindi. $clearedCount hücre temizlendi.';
  }
}

enum _TeacherEditAction { updated, deleted }

class _TeacherCreateForm extends StatefulWidget {
  const _TeacherCreateForm({required this.state});

  final TeacherListStateAdapter state;

  @override
  State<_TeacherCreateForm> createState() => _TeacherCreateFormState();
}

class _TeacherCreateFormState extends State<_TeacherCreateForm> {
  late final TextEditingController _nameController;
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Öğretmen Ekle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('teacher-create-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                key: const ValueKey('teacher-create-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(_isActive ? 'Aktif' : 'Pasif'),
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _isActive = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  key: const ValueKey('teacher-create-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('teacher-create-save'),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Ad Soyad zorunludur.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final error = await widget.state.createTeacher(
      Teacher(
        id: _nextTeacherId(widget.state.teachers),
        name: name,
        isActive: _isActive,
      ),
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _isSaving = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  String _nextTeacherId(List<Teacher> teachers) {
    var maxValue = 0;
    final pattern = RegExp(r'^T(\d+)$');
    for (final teacher in teachers) {
      final match = pattern.firstMatch(teacher.id);
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value == null) {
        continue;
      }
      if (value > maxValue) {
        maxValue = value;
      }
    }
    final next = maxValue + 1;
    return 'T${next.toString().padLeft(3, '0')}';
  }
}

class _TeacherEditForm extends StatefulWidget {
  const _TeacherEditForm({required this.state, required this.teacher});

  final TeacherListStateAdapter state;
  final Teacher teacher;

  @override
  State<_TeacherEditForm> createState() => _TeacherEditFormState();
}

class _TeacherEditFormState extends State<_TeacherEditForm> {
  late final TextEditingController _nameController;
  late bool _isActive;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final teacher = widget.teacher;
    _nameController = TextEditingController(text: teacher.name);
    _isActive = teacher.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Öğretmen Düzenle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('teacher-edit-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                key: const ValueKey('teacher-edit-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(_isActive ? 'Aktif' : 'Pasif'),
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _isActive = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  key: const ValueKey('teacher-edit-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('teacher-edit-delete'),
                onPressed: _isSaving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Sil'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('teacher-edit-save'),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Ad Soyad zorunludur.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final error = await widget.state.updateTeacher(
      widget.teacher.copyWith(name: name, isActive: _isActive),
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _isSaving = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pop(_TeacherEditAction.updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Öğretmeni Sil'),
          content: const Text('Bu öğretmen kaydı silinsin mi?'),
          actions: [
            TextButton(
              key: const ValueKey('teacher-delete-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const ValueKey('teacher-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final error = await widget.state.deleteTeacher(widget.teacher.id);
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _isSaving = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pop(_TeacherEditAction.deleted);
  }
}
