import 'package:flutter/material.dart';

import '../../models/roster_row.dart';
import '../../models/week.dart';
import '../../services/export_file_service.dart';
import '../../services/week_grid_projection_service.dart';
import '../../state/roster_state.dart';
import 'edit_week_screen.dart';

class RosterHomeScreen extends StatelessWidget {
  const RosterHomeScreen({
    super.key,
    required this.state,
    this.exportFileService = const ExportFileService(),
  });

  final RosterState state;
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
                tooltip: 'Düzenle',
                onPressed: () => _openEditScreen(context),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: 'Önceki hafta',
                onPressed: state.goToPreviousWeek,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Sonraki hafta',
                onPressed: state.goToNextWeek,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _WeekHeader(week: week),
                const SizedBox(height: 8),
                _DayGridPreview(week: week),
                const SizedBox(height: 12),
                _WeekDashboard(week: week),
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
      MaterialPageRoute<bool>(builder: (_) => EditWeekScreen(state: state)),
    );
    if (saved != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hafta kaydedildi.')));
  }
}

class _DayGridPreview extends StatefulWidget {
  const _DayGridPreview({required this.week});

  final Week week;

  @override
  State<_DayGridPreview> createState() => _DayGridPreviewState();
}

class _DayGridPreviewState extends State<_DayGridPreview> {
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
                Text('Satır: ${cell.rowIndex + 1}'),
                if (cell.isDuplicateLocation) ...[
                  const SizedBox(height: 8),
                  const Text('Tekrar eden görev yeri'),
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
            Text(selectedDay.dayName, style: textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final day in projection.days)
                ButtonSegment<int>(
                  value: day.dayIndex,
                  label: Text(shortDayName(day.dayName)),
                ),
            ],
            selected: {selectedDayIndex},
            onSelectionChanged: (values) {
              onSelectionChanged(values.single);
            },
          ),
        ),
        const SizedBox(height: 6),
        _SelectedDayBanner(
          dayName: selectedDay.dayName,
          filledCount: selectedDay.cells.where((cell) => !cell.isEmpty).length,
          totalCount: selectedDay.cells.length,
        ),
      ],
    );
  }
}

class _DayGridRow extends StatelessWidget {
  const _DayGridRow({required this.cell, required this.onTap});

  final WeekGridCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayTeacher = cell.teacher.isEmpty ? '-' : cell.teacher;
    final statusLabel = cell.isEmpty ? 'Boş' : 'Dolu';

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
                _GridStatusBadge(label: statusLabel, isFilled: !cell.isEmpty),
                if (cell.isDuplicateLocation) ...[
                  const SizedBox(width: 4),
                  const _DuplicateLocationBadge(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayBanner extends StatelessWidget {
  const _SelectedDayBanner({
    required this.dayName,
    required this.filledCount,
    required this.totalCount,
  });

  final String dayName;
  final int filledCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('day-grid-selected-day-label'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.today, color: colors.onPrimaryContainer, size: 16),
          Text(
            'Seçili gün: $dayName',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$filledCount/$totalCount dolu',
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _GridStatusBadge extends StatelessWidget {
  const _GridStatusBadge({required this.label, required this.isFilled});

  final String label;
  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        isFilled ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        size: 14,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor: isFilled
          ? colors.secondaryContainer
          : colors.surfaceContainerHighest,
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _DuplicateLocationBadge extends StatelessWidget {
  const _DuplicateLocationBadge();

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
            icon: const Icon(Icons.chevron_left),
            label: const Text('Önceki Hafta'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Sonraki Hafta'),
          ),
        ),
      ],
    );
  }
}

class _WeekDashboard extends StatelessWidget {
  const _WeekDashboard({required this.week});

  final Week week;

  @override
  Widget build(BuildContext context) {
    final projection = const WeekGridProjectionService().project(week);
    final filledCount = _filledCount(projection);
    final totalCount = week.rows.length * rosterDayCount;
    final emptyCount = totalCount - filledCount;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text('Hafta Özeti', style: textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SummaryChip(label: 'Görev yeri', value: '${week.rows.length}'),
              _SummaryChip(label: 'Dolu', value: '$filledCount'),
              _SummaryChip(label: 'Boş', value: '$emptyCount'),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final day in projection.days)
                  _DayDensityChip(day: day, totalLocations: week.rows.length),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _filledCount(WeekGridProjection projection) {
    return projection.days.fold<int>(0, (total, day) {
      return total + day.cells.where((cell) => !cell.isEmpty).length;
    });
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Chip(
      label: Text('$label: $value'),
      backgroundColor: colors.surfaceContainerHighest,
    );
  }
}

class _DayDensityChip extends StatelessWidget {
  const _DayDensityChip({required this.day, required this.totalLocations});

  final WeekGridDay day;
  final int totalLocations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filled = day.cells.where((cell) => !cell.isEmpty).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            shortDayName(day.dayName),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text('$filled/$totalLocations'),
        ],
      ),
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
