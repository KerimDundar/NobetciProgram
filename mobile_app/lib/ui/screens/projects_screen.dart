import 'package:flutter/material.dart';

import '../../models/planning_mode.dart';
import '../../services/week_service.dart';
import '../../state/app_settings_state.dart';
import '../../state/roster_state.dart';
import '../../state/teacher_state.dart';
import '../theme/app_theme.dart';
import 'edit_week_screen.dart';
import 'roster_home_screen.dart';

const List<String> _kMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _rangeLabel(DateTime start, DateTime end) {
  final sd = start.day.toString().padLeft(2, '0');
  final ed = end.day.toString().padLeft(2, '0');
  final sm = _kMonths[start.month - 1];
  final em = _kMonths[end.month - 1];
  if (start.year == end.year) return '$sd $sm - $ed $em ${end.year}';
  return '$sd $sm ${start.year} - $ed $em ${end.year}';
}

class _NewProjectResult {
  const _NewProjectResult({required this.name, required this.planningMode});
  final String name;
  final PlanningMode planningMode;
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.rosterState,
    this.teacherState,
    this.appSettingsState,
  });

  final RosterState rosterState;
  final TeacherState? teacherState;
  final AppSettingsState? appSettingsState;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.rosterState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Çizelgelerim')),
          floatingActionButton: FloatingActionButton(
            key: const Key('projects-new-button'),
            onPressed: () => _openNewProjectDialog(context),
            child: const Icon(Icons.add),
          ),
          body: widget.rosterState.hasActiveRoster
              ? _buildProjectList(context)
              : _buildEmptyState(context),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined, size: 72, color: cs.outline),
            const SizedBox(height: 20),
            Text(
              'Henüz çizelge oluşturulmadı.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'İlk nöbet çizelgenizi oluşturmak için başlayın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const Key('projects-create-button'),
              onPressed: () => _openNewProjectDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Yeni çizelge oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(BuildContext context) {
    final appSettings = widget.appSettingsState;
    if (appSettings != null) {
      return AnimatedBuilder(
        animation: appSettings,
        builder: (context, _) => _buildCardList(context, appSettings.mode),
      );
    }
    return _buildCardList(context, PlanningMode.weekly);
  }

  Widget _buildCardList(BuildContext context, PlanningMode mode) {
    final state = widget.rosterState;
    final week = state.currentWeek;
    final projectName = state.projectName.isNotEmpty
        ? state.projectName
        : (week.title.isNotEmpty ? week.title : 'Nöbet Çizelgesi');

    final planLabel =
        mode == PlanningMode.monthly ? 'Aylık Plan' : 'Haftalık Plan';
    DateTime rangeEnd = week.endDate;
    if (mode == PlanningMode.monthly) {
      rangeEnd = WeekService().monthEnd(week.startDate);
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        Card(
          child: InkWell(
            key: const Key('projects-roster-card'),
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          projectName,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          planLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          _rangeLabel(week.startDate, rangeEnd),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openNewProjectDialog(BuildContext context) async {
    final navigator = Navigator.of(context);
    final result = await showDialog<_NewProjectResult>(
      context: context,
      builder: (_) => const _NewProjectDialog(),
    );
    if (result == null || !mounted) return;

    widget.rosterState.setProjectMetadata(name: result.name);

    DateTime? initialStart;
    DateTime? initialEnd;
    if (result.planningMode == PlanningMode.monthly) {
      final range = WeekService().currentMonthRange(DateTime.now());
      initialStart = range.startDate;
      initialEnd = range.endDate;
    }

    if (widget.appSettingsState != null) {
      await widget.appSettingsState!.setMode(result.planningMode);
    }
    if (!mounted) return;

    final saved = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditWeekScreen(
          state: widget.rosterState,
          teacherState: widget.teacherState,
          appSettingsState: widget.appSettingsState,
          initialStartDate: initialStart,
          initialEndDate: initialEnd,
        ),
      ),
    );
    if (saved == true && mounted) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RosterHomeScreen(
            state: widget.rosterState,
            teacherState: widget.teacherState,
            appSettingsState: widget.appSettingsState,
          ),
        ),
      );
    }
  }
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _nameController = TextEditingController();
  PlanningMode _planningMode = PlanningMode.weekly;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni proje oluştur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('new-project-name-field'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Proje adı',
              errorText: _nameError,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          SegmentedButton<PlanningMode>(
            key: const Key('new-project-plan-type'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: PlanningMode.weekly,
                label: Text('Haftalık'),
              ),
              ButtonSegment(
                value: PlanningMode.monthly,
                label: Text('Aylık'),
              ),
            ],
            selected: {_planningMode},
            onSelectionChanged: (values) {
              setState(() => _planningMode = values.single);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('new-project-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const Key('new-project-create'),
          onPressed: _submit,
          child: const Text('Oluştur'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Proje adı boş bırakılamaz.');
      return;
    }
    Navigator.of(context).pop(
      _NewProjectResult(name: name, planningMode: _planningMode),
    );
  }
}
