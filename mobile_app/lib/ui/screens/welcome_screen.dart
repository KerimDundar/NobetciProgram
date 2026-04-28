import 'package:flutter/material.dart';

import '../../state/app_settings_state.dart';
import '../../state/roster_state.dart';
import '../theme/app_theme.dart';
import 'projects_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.rosterState,
    required this.appSettingsState,
  });

  final RosterState rosterState;
  final AppSettingsState appSettingsState;

  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppTheme.seedBlue,
      brightness: Brightness.dark,
    );
    return Theme(
      data: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.pagePadding + 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        size: 52,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'HOŞ GELDİNİZ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nöbet Çizelgesi',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nöbet çizelgenizi kolayca oluşturun, düzenleyin ve PDF/Excel olarak dışa aktarın.',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                        height: 1.65,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _FeatureChip(
                          label: 'Haftalık Plan',
                          icon: Icons.view_week_outlined,
                          cs: cs,
                        ),
                        _FeatureChip(
                          label: 'PDF Çıktı',
                          icon: Icons.picture_as_pdf_outlined,
                          cs: cs,
                        ),
                        _FeatureChip(
                          label: 'Excel Aktarım',
                          icon: Icons.table_chart_outlined,
                          cs: cs,
                        ),
                      ],
                    ),
                    const Spacer(flex: 3),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('welcome-start-button'),
                        onPressed: () => _navigateToHome(context),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Nöbet çizelgesi oluşturmaya başla'),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ProjectsScreen(
          rosterState: rosterState,
          appSettingsState: appSettingsState,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.label,
    required this.icon,
    required this.cs,
  });

  final String label;
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: cs.onPrimaryContainer),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: cs.onPrimaryContainer,
        ),
      ),
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.7),
      side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
