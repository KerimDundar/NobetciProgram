import 'package:flutter/material.dart';

import '../../models/week.dart';
import '../../services/export_file_service.dart';
import '../../services/grid_cell_status_service.dart';
import '../../services/week_grid_projection_service.dart';
import '../../state/roster_state.dart';
import '../../state/teacher_state.dart';
import '../theme/app_theme.dart';
import 'edit_week_screen.dart';
import 'teacher_list_screen.dart';

class RosterHomeScreen extends StatelessWidget {
  const RosterHomeScreen({
    super.key,
    required this.state,
    this.teacherState,
    this.exportFileService = const ExportFileService(),
  });

  final RosterState state;
  final TeacherState? teacherState;
  final ExportFileService exportFileService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final week = state.currentWeek;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nöbet Çizelgesi'),
            actions: [
              IconButton(
                tooltip: 'Ogretmenler',
                onPressed: teacherState == null
                    ? null
                    : () => _openTeacherScreen(context),
                icon: const Icon(Icons.groups_outlined),
              ),
              IconButton(
                tooltip: 'Düzenle',
                onPressed: () => _openEditScreen(context),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: 'Önceki hafta',
                onPressed: state.goToPreviousWeek,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Sonraki hafta',
                onPressed: state.goToNextWeek,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              children: [
                _WeekHeader(week: week),
                const SizedBox(height: 8),
                _DayGridPreview(week: week),
                const SizedBox(height: 16),
                _WeekActions(
                  onPrevious: state.goToPreviousWeek,
                  onNext: state.goToNextWeek,
                ),
                const SizedBox(height: 12),
                _ExportActions(
                  state: state,
                  exportFileService: exportFileService,
                ),
                const SizedBox(height: 16),
                if (week.rows.isEmpty) ...[
                  const _EmptyRosterCard(),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditScreen(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditWeekScreen(state: state, teacherState: teacherState),
      ),
    );
    if (saved != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hafta kaydedildi.')));
  }

  Future<void> _openTeacherScreen(BuildContext context) async {
    final teacherState = this.teacherState;
    if (teacherState == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeacherListScreen(
          state: teacherState,
          currentWeek: state.currentWeek,
          onTeacherDeletedFromRoster: (teacher) {
            return state.clearAssignmentsForTeacher(teacher.name);
          },
        ),
      ),
    );
  }
}

class _DayGridPreview extends StatefulWidget {
  const _DayGridPreview({required this.week});

  final Week week;

  @override
  State<_DayGridPreview> createState() => _DayGridPreviewState();
}

class _DayGridPreviewState extends State<_DayGridPreview> {
  static const GridCellStatusService _statusService = GridCellStatusService();
  int _selectedDayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final projection = const WeekGridProjectionService().project(widget.week);
    final selectedDay = projection.dayAt(_selectedDayIndex);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GridHeader(
              selectedDay: selectedDay,
              onSelectionChanged: (value) {
                setState(() {
                  _selectedDayIndex = value;
                });
              },
              selectedDayIndex: _selectedDayIndex,
              projection: projection,
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 2),
            if (selectedDay.cells.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Bu hafta için görev yeri yok.'),
              )
            else
              for (final cell in selectedDay.cells)
                _DayGridRow(
                  cell: cell,
                  status: _statusService.statusForCell(
                    day: selectedDay,
                    cell: cell,
                  ),
                  onTap: () => _showCellDetails(context, selectedDay, cell),
                ),
          ],
        ),
      ),
    );
  }

  void _showCellDetails(
    BuildContext context,
    WeekGridDay day,
    WeekGridCell cell,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final teacher = cell.teacher.isEmpty ? 'Boş' : cell.teacher;
        final status = _statusService.statusForCell(day: day, cell: cell);
        final statusText = switch (status) {
          GridCellStatus.empty => 'Boş',
          GridCellStatus.filled => 'Dolu',
          GridCellStatus.conflict => 'Çakışma',
        };

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atama Detayı',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text('Gün: ${day.dayName}'),
                Text('Görev yeri: ${cell.location}'),
                Text('Öğretmen: $teacher'),
                Text('Durum: $statusText'),
                Text('Satır: ${cell.rowIndex + 1}'),
                if (cell.isDuplicateLocation) ...[
                  const SizedBox(height: 8),
                  const Text('Tekrar eden görev yeri'),
                  Text('Grup: ${cell.duplicateRunGroup}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({
    required this.selectedDay,
    required this.onSelectionChanged,
    required this.selectedDayIndex,
    required this.projection,
  });

  final WeekGridDay selectedDay;
  final ValueChanged<int> onSelectionChanged;
  final int selectedDayIndex;
  final WeekGridProjection projection;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Günlük Plan', style: textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final day in projection.days)
                ButtonSegment<int>(
                  value: day.dayIndex,
                  label: Text(
                    shortDayName(day.dayName),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
            ],
            selected: {selectedDayIndex},
            onSelectionChanged: (values) {
              onSelectionChanged(values.single);
            },
          ),
        ),
      ],
    );
  }
}

class _DayGridRow extends StatelessWidget {
  const _DayGridRow({
    required this.cell,
    required this.status,
    required this.onTap,
  });

  final WeekGridCell cell;
  final GridCellStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTeacher = cell.teacher.isEmpty ? '-' : cell.teacher;
    final statusLabel = switch (status) {
      GridCellStatus.empty => 'Boş',
      GridCellStatus.filled => 'Dolu',
      GridCellStatus.conflict => 'Çakışma',
    };

    return Semantics(
      button: true,
      label:
          '${cell.location}, ${cell.teacher.isEmpty ? 'boş' : cell.teacher}, $statusLabel',
      child: InkWell(
        key: ValueKey('day-grid-cell-${cell.dayIndex}-${cell.rowIndex}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    cell.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    displayTeacher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _GridStatusBadge(status: status, label: statusLabel),
                if (cell.isDuplicateLocation) ...[
                  const SizedBox(width: 4),
                  _DuplicateLocationBadge(group: cell.duplicateRunGroup),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _GridStatusBadge extends StatelessWidget {
  const _GridStatusBadge({required this.status, required this.label});

  final GridCellStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = switch (status) {
      GridCellStatus.empty => colors.surfaceContainerHighest,
      GridCellStatus.filled => colors.secondaryContainer,
      GridCellStatus.conflict => colors.errorContainer,
    };
    final icon = switch (status) {
      GridCellStatus.empty => Icons.radio_button_unchecked,
      GridCellStatus.filled => Icons.check_circle_outline,
      GridCellStatus.conflict => Icons.warning_amber_outlined,
    };

    return Chip(
      avatar: Icon(icon, size: 14),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor: backgroundColor,
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _DuplicateLocationBadge extends StatelessWidget {
  const _DuplicateLocationBadge({required this.group});

  final String group;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.layers_outlined, size: 14),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      label: Text('Tekrar', style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ExportActions extends StatefulWidget {
  const _ExportActions({required this.state, required this.exportFileService});

  final RosterState state;
  final ExportFileService exportFileService;

  @override
  State<_ExportActions> createState() => _ExportActionsState();
}

class _ExportActionsState extends State<_ExportActions> {
  ExportFileType? _exportingType;

  @override
  Widget build(BuildContext context) {
    final isBusy = _exportingType != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _export(ExportFileType.pdf),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _export(ExportFileType.excel),
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export Excel'),
                  ),
                ),
              ],
            ),
            if (isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _export(ExportFileType type) async {
    setState(() {
      _exportingType = type;
    });

    try {
      final snapshot = widget.state.exportSnapshot;
      final result = switch (type) {
        ExportFileType.pdf => await widget.exportFileService.exportPdf(
          snapshot,
        ),
        ExportFileType.excel => await widget.exportFileService.exportExcel(
          snapshot,
        ),
      };

      if (!mounted) {
        return;
      }

      if (result == null) {
        _showMessage('Dışa aktarma iptal edildi.');
        return;
      }

      final label = type == ExportFileType.pdf ? 'PDF' : 'Excel';
      _showMessage('$label kaydedildi: ${result.path}');
    } on ExportFileException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } on FormatException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Dosya kaydedilemedi.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingType = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WeekActions extends StatelessWidget {
  const _WeekActions({required this.onPrevious, required this.onNext});

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Önceki Hafta'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Sonraki Hafta'),
          ),
        ),
      ],
    );
  }
}

String shortDayName(String value) {
  return switch (value) {
    'PAZARTESİ' => 'PZT',
    'ÇARŞAMBA' => 'ÇAR',
    'PERŞEMBE' => 'PER',
    _ => value.length <= 3 ? value : value.substring(0, 3),
  };
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.week});

  final Week week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 56,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  week.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class _EmptyRosterCard extends StatelessWidget {
  const _EmptyRosterCard();

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
                'Henüz görev yeri yok. Düzenle ile ilk görev yerini ekleyin.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
