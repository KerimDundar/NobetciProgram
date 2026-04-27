import 'package:flutter/material.dart';

import '../../models/planning_mode.dart';
import '../../models/week.dart';
import '../../services/export_file_service.dart';
import '../../services/grid_cell_status_service.dart';
import '../../services/week_grid_projection_service.dart';
import '../../services/week_service.dart';
import '../../state/app_settings_state.dart';
import '../../state/roster_state.dart';
import '../../state/teacher_state.dart';
import '../theme/app_theme.dart';
import 'edit_week_screen.dart';
import 'projects_screen.dart';
import 'teacher_list_screen.dart';

enum _HomeMenuAction { editWeek, teachers, planningMode, projects, about, guide }

class RosterHomeScreen extends StatefulWidget {
  const RosterHomeScreen({
    super.key,
    required this.state,
    this.teacherState,
    this.appSettingsState,
    this.exportFileService = const ExportFileService(),
  });

  final RosterState state;
  final TeacherState? teacherState;
  final AppSettingsState? appSettingsState;
  final ExportFileService exportFileService;

  @override
  State<RosterHomeScreen> createState() => _RosterHomeScreenState();
}

class _RosterHomeScreenState extends State<RosterHomeScreen> {
  final _menuController = MenuController();
  bool _menuOpen = false;

  void _toggleMenu() {
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final week = widget.state.currentWeek;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nöbet Çizelgesi'),
          ),
          floatingActionButton: MenuAnchor(
            controller: _menuController,
            onOpen: () => setState(() => _menuOpen = true),
            onClose: () => setState(() => _menuOpen = false),
            menuChildren: [
              MenuItemButton(
                key: const Key('menu-item-edit'),
                leadingIcon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    _onMenuAction(context, _HomeMenuAction.editWeek),
                child: const Text('Haftayı Düzenle'),
              ),
              MenuItemButton(
                key: const Key('menu-item-teachers'),
                leadingIcon: const Icon(Icons.groups_outlined),
                onPressed: widget.teacherState != null
                    ? () => _onMenuAction(context, _HomeMenuAction.teachers)
                    : null,
                child: const Text('Öğretmenler'),
              ),
              if (widget.appSettingsState != null)
                MenuItemButton(
                  key: const Key('menu-item-planning'),
                  leadingIcon: const Icon(Icons.tune),
                  onPressed: () =>
                      _onMenuAction(context, _HomeMenuAction.planningMode),
                  child: const Text('Planlama Türü'),
                ),
              MenuItemButton(
                key: const Key('menu-item-projects'),
                leadingIcon: const Icon(Icons.folder_outlined),
                onPressed: () =>
                    _onMenuAction(context, _HomeMenuAction.projects),
                child: const Text('Projeler'),
              ),
              const Divider(),
              MenuItemButton(
                key: const Key('menu-item-about'),
                leadingIcon: const Icon(Icons.info_outlined),
                onPressed: () => _onMenuAction(context, _HomeMenuAction.about),
                child: const Text('Hakkımızda'),
              ),
              MenuItemButton(
                key: const Key('menu-item-guide'),
                leadingIcon: const Icon(Icons.help_outline),
                onPressed: () => _onMenuAction(context, _HomeMenuAction.guide),
                child: const Text('Kullanım Kılavuzu'),
              ),
            ],
            child: FloatingActionButton(
              key: const Key('home-menu-button'),
              onPressed: _toggleMenu,
              child: const Icon(Icons.menu),
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                child: widget.state.hasActiveRoster
                    ? ListView(
                        padding: const EdgeInsets.all(AppTheme.pagePadding),
                        children: [
                          _buildWeekHeader(week),
                          const SizedBox(height: 8),
                          _DayGridPreview(week: week),
                          const SizedBox(height: 16),
                          _WeekActions(
                            onPrevious: widget.state.goToPreviousWeek,
                            onNext: widget.state.goToNextWeek,
                          ),
                          const SizedBox(height: 12),
                          if (widget.appSettingsState != null)
                            AnimatedBuilder(
                              animation: widget.appSettingsState!,
                              builder: (_, child) {
                                if (widget.appSettingsState!.mode !=
                                    PlanningMode.weekly) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      key: const Key('generate-monthly-button'),
                                      onPressed: () =>
                                          _generateMonthly(context),
                                      icon: const Icon(
                                        Icons.calendar_view_month,
                                      ),
                                      label: const Text('Aylık tablo oluştur'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          _ExportActions(
                            state: widget.state,
                            exportFileService: widget.exportFileService,
                          ),
                          const SizedBox(height: 16),
                          if (week.rows.isEmpty) ...[
                            const _EmptyRosterCard(),
                            const SizedBox(height: 12),
                          ],
                        ],
                      )
                    : _buildNoRosterBody(context),
              ),
              if (_menuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _menuController.close(),
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoRosterBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Henüz çizelge oluşturulmadı.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Yeni çizelge oluşturmak için Projeler ekranından başlayın.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('roster-home-go-to-projects'),
              onPressed: () => _openProjectsScreen(context),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Projelerime git'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProjectsScreen(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectsScreen(
          rosterState: widget.state,
          teacherState: widget.teacherState,
          appSettingsState: widget.appSettingsState,
        ),
      ),
    );
  }

  Future<void> _openEditScreen(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditWeekScreen(
          state: widget.state,
          teacherState: widget.teacherState,
          appSettingsState: widget.appSettingsState,
        ),
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
    final teacherState = widget.teacherState;
    if (teacherState == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeacherListScreen(
          state: teacherState,
          currentWeek: widget.state.currentWeek,
          onTeacherDeletedFromRoster: (teacher) {
            return widget.state.clearAssignmentsForTeacher(teacher.name);
          },
        ),
      ),
    );
  }

  Future<void> _generateMonthly(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aylık tablo oluştur'),
        content: const Text(
          'Mevcut haftadan başlayarak 4 haftalık aylık tablo oluşturulsun mu?',
        ),
        actions: [
          TextButton(
            key: const Key('monthly-gen-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            key: const Key('monthly-gen-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    widget.state.generateMonthlyWeeks();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aylık tablo oluşturuldu. Export ederek çıktıyı alabilirsiniz.',
        ),
      ),
    );
  }

  void _onMenuAction(BuildContext context, _HomeMenuAction action) {
    switch (action) {
      case _HomeMenuAction.editWeek:
        _openEditScreen(context);
      case _HomeMenuAction.teachers:
        _openTeacherScreen(context);
      case _HomeMenuAction.planningMode:
        _openPlanningModeDialog(context);
      case _HomeMenuAction.projects:
        _openProjectsScreen(context);
      case _HomeMenuAction.about:
      case _HomeMenuAction.guide:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu sayfa sonraki güncellemede eklenecek.'),
          ),
        );
    }
  }

  Widget _buildWeekHeader(Week week) {
    final appSettings = widget.appSettingsState;
    final projectName = widget.state.projectName;
    if (appSettings == null) {
      return _WeekHeader(week: week, projectName: projectName);
    }
    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) {
        if (appSettings.mode != PlanningMode.monthly) {
          return _WeekHeader(week: week, projectName: projectName);
        }
        final endDate = WeekService().monthEnd(week.startDate);
        return _WeekHeader(
          week: week,
          monthlyEndDate: endDate,
          projectName: projectName,
        );
      },
    );
  }

  Future<void> _openPlanningModeDialog(BuildContext context) async {
    final settings = widget.appSettingsState;
    if (settings == null) return;

    final selected = await showDialog<PlanningMode>(
      context: context,
      builder: (_) => const _PlanningModeDialog(),
    );

    if (selected == null || !context.mounted) return;
    await settings.setMode(selected);
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
                  onTap: () => _showDayDetails(context, selectedDay),
                ),
          ],
        ),
      ),
    );
  }

  void _showDayDetails(BuildContext context, WeekGridDay day) {
    final dayDate = widget.week.startDate.add(Duration(days: day.dayIndex));
    final dateStr = _formatDayDate(dayDate);
    final displayDayName = _dayDisplayName(day.dayName);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Gün: $displayDayName $dateStr'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cell in day.cells) ...[
                  Text(
                    cell.location.isEmpty ? '—' : cell.location,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (cell.teachers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 4),
                      child: Text('- Boş'),
                    )
                  else
                    ...cell.teachers.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('- $t'),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  String _formatDayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _dayDisplayName(String upperName) {
    return const {
      'PAZARTESİ': 'Pazartesi',
      'SALI': 'Salı',
      'ÇARŞAMBA': 'Çarşamba',
      'PERŞEMBE': 'Perşembe',
      'CUMA': 'Cuma',
      'CUMARTESİ': 'Cumartesi',
      'PAZAR': 'Pazar',
    }[upperName] ?? upperName;
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
    final teacherCount = cell.teachers.length;
    final statusLabel = status == GridCellStatus.conflict
        ? 'Çakışma'
        : teacherCount == 0
        ? 'Boş'
        : '$teacherCount öğretmen';

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
  const _WeekHeader({
    required this.week,
    this.monthlyEndDate,
    this.projectName,
  });

  final Week week;
  final DateTime? monthlyEndDate;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final endDate = monthlyEndDate ?? week.endDate;
    final displayName =
        (projectName?.isNotEmpty == true) ? projectName! : 'Nöbet Çizelgesi';

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
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_formatDate(week.startDate)} - ${_formatDate(endDate)}',
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

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

class _PlanningModeDialog extends StatelessWidget {
  const _PlanningModeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Planlama türü seçin'),
      actions: [
        TextButton(
          key: const Key('planning-mode-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        TextButton(
          key: const Key('planning-mode-weekly'),
          onPressed: () => Navigator.of(context).pop(PlanningMode.weekly),
          child: const Text('Haftalık plan'),
        ),
        TextButton(
          key: const Key('planning-mode-monthly'),
          onPressed: () => Navigator.of(context).pop(PlanningMode.monthly),
          child: const Text('Aylık plan'),
        ),
      ],
    );
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
