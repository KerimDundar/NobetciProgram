import 'package:flutter/material.dart';

import '../../models/roster_row.dart';
import '../../models/week.dart';
import '../../services/export_file_service.dart';
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
                for (final row in week.rows) ...[
                  _LocationCard(row: row),
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

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.week});

  final Week week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(week.schoolName, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(week.title, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)}',
              style: textTheme.bodyMedium,
            ),
          ],
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.row});

  final RosterRow row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.location, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var index = 0; index < rosterDayCount; index++)
              _DayAssignment(
                dayName: rosterDayNames[index],
                teacherName: row.teachersByDay[index],
              ),
          ],
        ),
      ),
    );
  }
}

class _DayAssignment extends StatelessWidget {
  const _DayAssignment({required this.dayName, required this.teacherName});

  final String dayName;
  final String teacherName;

  @override
  Widget build(BuildContext context) {
    final displayName = teacherName.isEmpty ? '-' : teacherName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              dayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(displayName)),
        ],
      ),
    );
  }
}
