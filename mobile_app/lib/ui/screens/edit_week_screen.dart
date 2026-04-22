import 'package:flutter/material.dart';

import '../../models/roster_row.dart';
import '../../state/roster_state.dart';

class EditWeekScreen extends StatefulWidget {
  const EditWeekScreen({super.key, required this.state});

  final RosterState state;

  @override
  State<EditWeekScreen> createState() => _EditWeekScreenState();
}

class _EditWeekScreenState extends State<EditWeekScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late final TextEditingController _schoolController;
  late final TextEditingController _principalController;
  late final List<_RosterRowDraft> _rows;
  late final String _initialSnapshot;
  bool _hasUnsavedChanges = false;
  bool _allowPop = false;
  String? _validationError;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final week = widget.state.currentWeek;
    _startDate = week.startDate;
    _endDate = week.endDate;
    _schoolController = TextEditingController(text: week.schoolName);
    _principalController = TextEditingController(text: week.principalName);
    _rows = week.rows.map(_RosterRowDraft.fromRow).toList(growable: true);
    if (_rows.isEmpty) {
      _rows.add(_RosterRowDraft.empty());
    }
    _schoolController.addListener(_updateDirtyState);
    _principalController.addListener(_updateDirtyState);
    for (final row in _rows) {
      row.addListener(_updateDirtyState);
    }
    _initialSnapshot = _draftSnapshot();
  }

  @override
  void dispose() {
    _schoolController.removeListener(_updateDirtyState);
    _principalController.removeListener(_updateDirtyState);
    _schoolController.dispose();
    _principalController.dispose();
    for (final row in _rows) {
      row.removeListener(_updateDirtyState);
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateError = _startDate.isAfter(_endDate)
        ? 'Başlangıç tarihi bitiş tarihinden büyük olamaz.'
        : null;
    final validationMessages = <String>[
      ?dateError,
      if (_validationError != null && _validationError != dateError)
        _validationError!,
    ];

    return PopScope<bool>(
      canPop: !_hasUnsavedChanges || _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldLeave = await _confirmDiscardChanges();
        if (!shouldLeave || !context.mounted) {
          return;
        }
        setState(() {
          _allowPop = true;
        });
        Navigator.of(context).pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hafta Düzenle'),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (validationMessages.isNotEmpty) ...[
                _ValidationPanel(messages: validationMessages),
                const SizedBox(height: 12),
              ],
              if (_statusMessage != null) ...[
                _StatusPanel(message: _statusMessage!),
                const SizedBox(height: 12),
              ],
              _DateSection(
                startDate: _startDate,
                endDate: _endDate,
                onPickStart: () => _pickDate(isStart: true),
                onPickEnd: () => _pickDate(isStart: false),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _schoolController,
                        decoration: const InputDecoration(labelText: 'Okul'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _principalController,
                        decoration: const InputDecoration(labelText: 'Müdür'),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _RotationActions(
                onRotateForward: () => _rotateDraft(forward: true),
                onRotateBackward: () => _rotateDraft(forward: false),
              ),
              const SizedBox(height: 12),
              if (_allRowsEmpty()) ...[
                const _EmptyDraftHint(),
                const SizedBox(height: 12),
              ],
              for (var index = 0; index < _rows.length; index++) ...[
                _EditableLocationCard(
                  key: ValueKey(_rows[index]),
                  index: index,
                  row: _rows[index],
                  onDelete: _rows.length == 1 ? null : () => _deleteRow(index),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Görev Yeri Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      }
      _syncDraftFlags(clearStatus: true);
    });
  }

  void _addRow() {
    final row = _RosterRowDraft.empty()..addListener(_updateDirtyState);
    setState(() {
      _rows.add(row);
      _syncDraftFlags(clearStatus: true);
    });
  }

  void _deleteRow(int index) {
    setState(() {
      final removed = _rows.removeAt(index);
      removed.removeListener(_updateDirtyState);
      removed.dispose();
      if (_rows.isEmpty) {
        final row = _RosterRowDraft.empty()..addListener(_updateDirtyState);
        _rows.add(row);
      }
      _syncDraftFlags(clearStatus: true);
    });
  }

  void _replaceRows(List<RosterRow> rows, {String? statusMessage}) {
    setState(() {
      for (final row in _rows) {
        row.removeListener(_updateDirtyState);
        row.dispose();
      }
      _rows
        ..clear()
        ..addAll(rows.map(_RosterRowDraft.fromRow));
      if (_rows.isEmpty) {
        _rows.add(_RosterRowDraft.empty());
      }
      for (final row in _rows) {
        row.addListener(_updateDirtyState);
      }
      _statusMessage = statusMessage;
      _syncDraftFlags(clearStatus: false);
    });
  }

  List<RosterRow> _currentRows() {
    return _rows.map((row) => row.toRow()).toList(growable: false);
  }

  void _rotateDraft({required bool forward}) {
    final rows = forward
        ? widget.state.rotateRowsForward(_currentRows())
        : widget.state.rotateRowsBackward(_currentRows());
    final message = forward
        ? 'Pazartesi-Cuma sütunları ileri döndürüldü.'
        : 'Pazartesi-Cuma sütunları geri döndürüldü.';
    _replaceRows(rows, statusMessage: message);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _save() {
    final error = widget.state.saveWeekDraft(
      startDate: _startDate,
      endDate: _endDate,
      schoolName: _schoolController.text,
      principalName: _principalController.text,
      rows: _currentRows(),
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        _validationError = error;
        _statusMessage = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _allowPop = true;
      _hasUnsavedChanges = false;
      _validationError = null;
      _statusMessage = null;
    });
    Navigator.of(context).pop(true);
  }

  void _updateDirtyState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _syncDraftFlags(clearStatus: true);
    });
  }

  void _syncDraftFlags({bool clearStatus = false}) {
    _hasUnsavedChanges = _draftSnapshot() != _initialSnapshot;
    _validationError = null;
    if (clearStatus) {
      _statusMessage = null;
    }
  }

  String _draftSnapshot() {
    final buffer = StringBuffer()
      ..writeln(_dateKey(_startDate))
      ..writeln(_dateKey(_endDate))
      ..writeln(_schoolController.text)
      ..writeln(_principalController.text)
      ..writeln(_rows.length);

    for (final row in _rows) {
      buffer.writeln(row.locationController.text);
      for (final controller in row.teacherControllers) {
        buffer.writeln(controller.text);
      }
    }

    return buffer.toString();
  }

  String _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  bool _allRowsEmpty() {
    return _rows.every((row) {
      final hasLocation = row.locationController.text.trim().isNotEmpty;
      final hasTeacher = row.teacherControllers.any((controller) {
        return controller.text.trim().isNotEmpty;
      });
      return !hasLocation && !hasTeacher;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kaydedilmemiş Değişiklikler'),
          content: const Text(
            'Çıkarsanız bu ekrandaki değişiklikler kaybolacak.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Kal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Vazgeç'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Card(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 8),
                  Text(
                    'Düzeltme Gerekli',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final message in messages)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Card(
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDraftHint extends StatelessWidget {
  const _EmptyDraftHint();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Henüz görev yeri yok. İlk kartı doldurun veya yeni görev yeri ekleyin.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tarih Aralığı',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickStart,
                  icon: const Icon(Icons.event),
                  label: Text('Başlangıç ${_formatDate(startDate)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onPickEnd,
                  icon: const Icon(Icons.event_available),
                  label: Text('Bitiş ${_formatDate(endDate)}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RotationActions extends StatelessWidget {
  const _RotationActions({
    required this.onRotateForward,
    required this.onRotateBackward,
  });

  final VoidCallback onRotateForward;
  final VoidCallback onRotateBackward;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rotasyon', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pazartesi-Cuma sütunları birlikte döndürülür.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRotateBackward,
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('Pazartesi-Cuma Geri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRotateForward,
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('Pazartesi-Cuma İleri'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableLocationCard extends StatelessWidget {
  const _EditableLocationCard({
    super.key,
    required this.index,
    required this.row,
    required this.onDelete,
  });

  final int index;
  final _RosterRowDraft row;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.locationController,
                    decoration: InputDecoration(
                      labelText: 'Görev Yeri ${index + 1}',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var day = 0; day < rosterDayCount; day++) ...[
              TextField(
                controller: row.teacherControllers[day],
                decoration: InputDecoration(labelText: rosterDayNames[day]),
                textInputAction: day == rosterDayCount - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
              ),
              if (day < rosterDayCount - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _RosterRowDraft {
  _RosterRowDraft({
    required String location,
    required List<String> teachersByDay,
  }) : locationController = TextEditingController(text: location),
       teacherControllers = List<TextEditingController>.generate(
         rosterDayCount,
         (index) => TextEditingController(
           text: index < teachersByDay.length ? teachersByDay[index] : '',
         ),
       );

  factory _RosterRowDraft.fromRow(RosterRow row) {
    return _RosterRowDraft(
      location: row.location,
      teachersByDay: row.teachersByDay,
    );
  }

  factory _RosterRowDraft.empty() {
    return _RosterRowDraft(location: '', teachersByDay: const []);
  }

  final TextEditingController locationController;
  final List<TextEditingController> teacherControllers;

  void addListener(VoidCallback listener) {
    locationController.addListener(listener);
    for (final controller in teacherControllers) {
      controller.addListener(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    locationController.removeListener(listener);
    for (final controller in teacherControllers) {
      controller.removeListener(listener);
    }
  }

  RosterRow toRow() {
    return RosterRow(
      location: locationController.text,
      teachersByDay: teacherControllers
          .map((controller) {
            return controller.text;
          })
          .toList(growable: false),
    );
  }

  void dispose() {
    locationController.dispose();
    for (final controller in teacherControllers) {
      controller.dispose();
    }
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}
