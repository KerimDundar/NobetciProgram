import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../models/planning_mode.dart';
import '../../models/week.dart';
import '../../services/week_service.dart';
import '../../state/app_settings_state.dart';
import '../../state/premium_state.dart';
import '../../state/roster_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_paywall_dialog.dart';
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
    this.appSettingsState,
    this.premiumState,
  });

  final RosterState rosterState;
  final AppSettingsState? appSettingsState;
  final PremiumState? premiumState;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool get _isPremium => widget.premiumState?.isPremium ?? false;

  @override
  Widget build(BuildContext context) {
    final premiumState = widget.premiumState;
    if (premiumState != null) {
      return AnimatedBuilder(
        animation: premiumState,
        builder: (context, _) => _buildRosterListener(),
      );
    }
    return _buildRosterListener();
  }

  Widget _buildRosterListener() {
    return AnimatedBuilder(
      animation: widget.rosterState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Çizelgelerim')),
          floatingActionButton: FloatingActionButton(
            key: const Key('projects-new-button'),
            onPressed: () => _onNewProjectTap(context),
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
              onPressed: () => _onNewProjectTap(context),
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
    return _buildCardList(context, widget.rosterState.activePlanningMode);
  }

  Widget _buildCardList(BuildContext context, PlanningMode displayMode) {
    final state = widget.rosterState;
    final projects = state.projects;

    if (projects.isEmpty) {
      return _buildSingleCard(
        context,
        name: state.projectName.isNotEmpty
            ? state.projectName
            : 'Nöbet Çizelgesi',
        week: state.currentWeek,
        mode: displayMode,
        isFirst: true,
        projectId: null,
        isLocked: false,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        for (var i = 0; i < projects.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < projects.length - 1 ? 12 : 0),
            child: _buildSingleCard(
              context,
              name: projects[i].name.isNotEmpty
                  ? projects[i].name
                  : 'Nöbet Çizelgesi',
              week: projects[i].currentWeek,
              mode: displayMode,
              isFirst: i == 0,
              projectId: projects[i].id,
              isLocked: FeatureFlags.premiumGateEnabled &&
                  !state.canAccessProject(projects[i].id, _isPremium),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleCard(
    BuildContext context, {
    required String name,
    required Week week,
    required PlanningMode mode,
    required bool isFirst,
    required String? projectId,
    required bool isLocked,
  }) {
    final planLabel =
        mode == PlanningMode.monthly ? 'Aylık Plan' : 'Haftalık Plan';
    final rangeEnd = mode == PlanningMode.monthly
        ? WeekService().monthEnd(week.startDate)
        : week.endDate;

    return Card(
      child: InkWell(
        key: isFirst ? const Key('projects-roster-card') : null,
        onTap: () => _onProjectTap(context, projectId, isLocked),
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
                      name,
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
              if (projectId != null)
                IconButton(
                  key: isFirst
                      ? const Key('projects-delete-button')
                      : ValueKey('projects-delete-$projectId'),
                  tooltip: 'Projeyi sil',
                  iconSize: 20,
                  onPressed: () =>
                      _onDeleteProjectTap(context, projectId, name),
                  icon: const Icon(Icons.delete_outline),
                ),
              if (isLocked)
                const Icon(Icons.lock_outline, size: 20)
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _onProjectTap(
    BuildContext context,
    String? projectId,
    bool isLocked,
  ) {
    if (isLocked && FeatureFlags.premiumGateEnabled) {
      final premiumState = widget.premiumState;
      if (premiumState != null) {
        PremiumPaywallDialog.show(context, premiumState);
      }
      return;
    }

    if (projectId != null) {
      widget.rosterState.openProject(projectId);
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RosterHomeScreen(
            state: widget.rosterState,
            appSettingsState: widget.appSettingsState,
            premiumState: widget.premiumState,
          ),
        ),
      );
    }
  }

  Future<void> _onNewProjectTap(BuildContext context) async {
    if (FeatureFlags.premiumGateEnabled &&
        !widget.rosterState.canCreateProject(_isPremium)) {
      final premiumState = widget.premiumState;
      if (premiumState != null) {
        await PremiumPaywallDialog.show(context, premiumState);
      }
      return;
    }
    if (mounted) {
      await _openNewProjectDialog(context);
    }
  }

  Future<void> _onDeleteProjectTap(
    BuildContext context,
    String projectId,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projeyi sil'),
        content: Text(
          '"$name" projesini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            key: const Key('project-delete-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            key: const Key('project-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    widget.rosterState.deleteProject(projectId);
    messenger.showSnackBar(const SnackBar(content: Text('Proje silindi.')));
  }

  Future<void> _openNewProjectDialog(BuildContext context) async {
    final navigator = Navigator.of(context);
    final result = await showDialog<_NewProjectResult>(
      context: context,
      builder: (_) => const _NewProjectDialog(),
    );
    if (result == null || !mounted) return;

    DateTime? initialStart;
    DateTime? initialEnd;
    if (result.planningMode == PlanningMode.monthly) {
      final range = WeekService().currentMonthRange(DateTime.now());
      initialStart = range.startDate;
      initialEnd = range.endDate;
    }

    widget.rosterState.createProject(
      name: result.name,
      planningMode: result.planningMode,
      startDate: initialStart,
      endDate: initialEnd,
    );

    if (widget.appSettingsState != null) {
      await widget.appSettingsState!.setMode(result.planningMode);
    }
    if (!mounted) return;

    final saved = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditWeekScreen(
          state: widget.rosterState,
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
            appSettingsState: widget.appSettingsState,
            premiumState: widget.premiumState,
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
