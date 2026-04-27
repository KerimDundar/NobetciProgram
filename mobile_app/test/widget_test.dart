import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/main.dart';
import 'package:nobetci_program_mobile/models/planning_mode.dart';
import 'package:nobetci_program_mobile/state/app_settings_state.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/edit_week_screen.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';

void main() {
  testWidgets('shows current roster state on home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NobetciProgramApp());

    expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bahçe'), 120);
    expect(find.text('Bahçe'), findsOneWidget);
  });

  testWidgets(
    'edit screen hides manual teacher input and keeps picker action',
    (WidgetTester tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-edit')));
      await tester.pumpAndSettle();

      expect(find.text('Hafta Düzenle'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-grid-teacher-input-0-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-0')),
        findsOneWidget,
      );
    },
  );

  testWidgets('picker adds teacher to cell and save persists roster', (
    WidgetTester tester,
  ) async {
    _useTallTestView(tester);
    final state = RosterState.initial();
    await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-item-edit')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2200));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('edit-grid-teacher-empty-0-2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-grid-pick-teacher-0-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T002')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('edit-grid-teacher-chip-0-2-0')),
      findsOneWidget,
    );
    expect(find.text('Ayse Demir'), findsWidgets);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(state.currentWeek.rows[2].teachersByDay[0], 'Ayse Demir');
  });

  testWidgets(
    'same teacher on same day across locations does not block edit save',
    (WidgetTester tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(
        MaterialApp(home: RosterHomeScreen(state: state)),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-edit')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2200));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('edit-grid-pick-teacher-0-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('teacher-picker-item-T001')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Nöbet Çizelgesi'), findsOneWidget);
      expect(find.text('Hafta kaydedildi.'), findsOneWidget);
      expect(state.currentWeek.rows[1].teachersByDay[0], isNotEmpty);
    },
  );

  group('PlanningMode modal', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Sonraki Hafta butonu dialog açmaz', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.text('Sonraki Hafta'));
      await tester.pumpAndSettle();

      expect(find.text('Planlama türü seçin'), findsNothing);
    });

    testWidgets('Planlama Türü menü seçeneği dialog açar', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-planning')));
      await tester.pumpAndSettle();

      expect(find.text('Planlama türü seçin'), findsOneWidget);
    });

    testWidgets('haftalık seçim mode weekly yapar', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();
      await appSettings.setMode(PlanningMode.monthly);

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-planning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planning-mode-weekly')));
      await tester.pumpAndSettle();

      expect(appSettings.mode, PlanningMode.weekly);
    });

    testWidgets('aylık seçim mode monthly yapar', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-planning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planning-mode-monthly')));
      await tester.pumpAndSettle();

      expect(appSettings.mode, PlanningMode.monthly);
    });

    testWidgets('mode değişimi currentWeek değiştirmez', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();
      final initialTitle = state.currentWeek.title;

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-planning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planning-mode-monthly')));
      await tester.pumpAndSettle();

      expect(state.currentWeek.title, initialTitle);
    });

    testWidgets('iptal edilirse mode değişmez', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-planning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planning-mode-cancel')));
      await tester.pumpAndSettle();

      expect(appSettings.mode, PlanningMode.weekly);
    });

    testWidgets('sağ üst yukarı/aşağı ikonları yok', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsNothing,
      );
    });

    testWidgets('Sonraki Hafta butonu haftayı ilerletir', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final initialTitle = state.currentWeek.title;

      await tester.pumpWidget(
        MaterialApp(home: RosterHomeScreen(state: state)),
      );

      await tester.tap(find.text('Sonraki Hafta'));
      await tester.pumpAndSettle();

      expect(state.currentWeek.title, isNot(initialTitle));
    });
  });

  group('Monthly generate button', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('button visible in weekly mode', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      expect(
        find.byKey(const Key('generate-monthly-button')),
        findsOneWidget,
      );
    });

    testWidgets('button not visible in monthly mode', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();
      await appSettings.setMode(PlanningMode.monthly);

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      expect(
        find.byKey(const Key('generate-monthly-button')),
        findsNothing,
      );
    });

    testWidgets('cancel does not generate monthly weeks', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('generate-monthly-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monthly-gen-cancel')));
      await tester.pumpAndSettle();

      expect(state.generatedMonthlyWeeks, isNull);
    });

    testWidgets('confirm generates 4 weeks', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('generate-monthly-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monthly-gen-confirm')));
      await tester.pumpAndSettle();

      expect(state.generatedMonthlyWeeks, hasLength(4));
    });

    testWidgets('confirm shows success snackbar', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('generate-monthly-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monthly-gen-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Aylık tablo oluşturuldu. Export ederek çıktıyı alabilirsiniz.',
        ),
        findsOneWidget,
      );
    });
  });

  group('UI/UX fix package #2', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('günlük plan satırı boş hücre Boş gösterir', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      expect(find.text('Boş'), findsWidgets);
    });

    testWidgets('günlük plan satırı dolu hücre N öğretmen gösterir',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      expect(find.text('1 öğretmen'), findsWidgets);
    });

    testWidgets('hücre detay dialogu showDialog ile açılır', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.text('1 öğretmen').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Gün:'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('hücre detay dialogunda Satır metni yok', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.text('1 öğretmen').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Satır'), findsNothing);
    });

    testWidgets('hamburger menüsü home-menu-button açar', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();

      expect(find.text('Haftayı Düzenle'), findsOneWidget);
      expect(find.text('Hakkımızda'), findsOneWidget);
      expect(find.text('Kullanım Kılavuzu'), findsOneWidget);
    });

    testWidgets('hamburger Hakkımızda snackbar gösterir', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-about')));
      await tester.pumpAndSettle();

      expect(
        find.text('Bu sayfa sonraki güncellemede eklenecek.'),
        findsOneWidget,
      );
    });

    testWidgets('hamburger Kullanım Kılavuzu snackbar gösterir', (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-guide')));
      await tester.pumpAndSettle();

      expect(
        find.text('Bu sayfa sonraki güncellemede eklenecek.'),
        findsOneWidget,
      );
    });

    testWidgets('edit screen Satır metni yok', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-edit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Satır'), findsNothing);
    });

    testWidgets('edit screen dolu hücre N öğretmen badge gösterir',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-edit')));
      await tester.pumpAndSettle();

      expect(find.text('1 öğretmen'), findsWidgets);
    });

    testWidgets('günlük plan satırına tıklayınca tüm gün atamaları görünür',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.text('1 öğretmen').first);
      await tester.pumpAndSettle();

      expect(find.text('Bahçe'), findsWidgets);
      expect(find.text('Koridor'), findsWidgets);
      expect(find.text('Kantin'), findsWidgets);
    });

    testWidgets('dialog başlığında gün adı ve tarih görünür', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.text('1 öğretmen').first);
      await tester.pumpAndSettle();

      // startDate=2026-02-02 (Pazartesi), dayIndex=0
      expect(find.text('Gün: Pazartesi 02.02.2026'), findsOneWidget);
    });

    testWidgets('hamburger butonu FloatingActionButton olarak görünür',
        (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('menü açıkken hamburger butonuna tekrar basınca menü kapanır',
        (tester) async {
      _useTallTestView(tester);
      await tester.pumpWidget(const NobetciProgramApp());

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      expect(find.text('Haftayı Düzenle'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      expect(find.text('Haftayı Düzenle'), findsNothing);
    });

    testWidgets('Planlama Türü ana ekranda ayrı buton yok', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      expect(find.byKey(const Key('planning-mode-button')), findsNothing);
    });

    testWidgets('Planlama Türü hamburger menüde görünür', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(
        MaterialApp(
          home: RosterHomeScreen(
            state: state,
            appSettingsState: appSettings,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();

      expect(find.text('Planlama Türü'), findsOneWidget);
    });

    testWidgets('menü açıkken arka plan tıklaması menüyü kapatır',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      expect(find.text('Haftayı Düzenle'), findsOneWidget);

      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();

      expect(find.text('Haftayı Düzenle'), findsNothing);
    });

    testWidgets(
        'menü açıkken arka plandaki butona tıklama sadece menüyü kapatır',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));
      final initialTitle = state.currentWeek.title;

      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();

      // Barrier absorbs the tap — Sonraki Hafta should NOT fire
      await tester.tap(find.text('Sonraki Hafta'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Haftayı Düzenle'), findsNothing);
      expect(state.currentWeek.title, initialTitle);
    });

    testWidgets(
        'menü kapandıktan sonra arka plandaki butona tıklama normal çalışır',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(MaterialApp(home: RosterHomeScreen(state: state)));
      final initialTitle = state.currentWeek.title;

      // Open menu, barrier tap closes it
      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sonraki Hafta'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Menu is now closed — tap Sonraki Hafta normally
      await tester.tap(find.text('Sonraki Hafta'));
      await tester.pumpAndSettle();

      expect(state.currentWeek.title, isNot(initialTitle));
    });
  });

  group('EditWeekScreen date validation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // RosterState.initial() has startDate=2026-02-02, endDate=2026-02-06.

    testWidgets('weekly: 7-day end date shows tooLong snackbar, date unchanged',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(MaterialApp(
        home: EditWeekScreen(
          state: state,
          appSettingsState: appSettings,
          testDatePickerOverride: (ctx, date) async => DateTime(2026, 2, 9),
        ),
      ));

      await tester.tap(find.text('Bitiş 06.02.2026'));
      await tester.pumpAndSettle();

      expect(
        find.text('Haftalık modda en fazla 1 hafta seçilebilir.'),
        findsOneWidget,
      );
      expect(find.text('Bitiş 06.02.2026'), findsOneWidget);
    });

    testWidgets('weekly: 6-day end date is valid, date changes', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(MaterialApp(
        home: EditWeekScreen(
          state: state,
          appSettingsState: appSettings,
          testDatePickerOverride: (ctx, date) async => DateTime(2026, 2, 8),
        ),
      ));

      await tester.tap(find.text('Bitiş 06.02.2026'));
      await tester.pumpAndSettle();

      expect(find.text('Bitiş 08.02.2026'), findsOneWidget);
    });

    testWidgets('monthly: 26-day range shows tooShort snackbar, date unchanged',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();
      await appSettings.setMode(PlanningMode.monthly);

      await tester.pumpWidget(MaterialApp(
        home: EditWeekScreen(
          state: state,
          appSettingsState: appSettings,
          testDatePickerOverride: (ctx, date) async => DateTime(2026, 2, 28),
        ),
      ));

      await tester.tap(find.text('Bitiş 06.02.2026'));
      await tester.pumpAndSettle();

      expect(
        find.text('Aylık modda en az 1 aylık aralık seçilmelidir.'),
        findsOneWidget,
      );
      expect(find.text('Bitiş 06.02.2026'), findsOneWidget);
    });

    testWidgets('monthly: 27-day range is valid, date changes', (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();
      await appSettings.setMode(PlanningMode.monthly);

      await tester.pumpWidget(MaterialApp(
        home: EditWeekScreen(
          state: state,
          appSettingsState: appSettings,
          testDatePickerOverride: (ctx, date) async => DateTime(2026, 3, 1),
        ),
      ));

      await tester.tap(find.text('Bitiş 06.02.2026'));
      await tester.pumpAndSettle();

      expect(find.text('Bitiş 01.03.2026'), findsOneWidget);
    });

    testWidgets('startDate after endDate shows invalidRange snackbar',
        (tester) async {
      _useTallTestView(tester);
      final state = RosterState.initial();
      final appSettings = AppSettingsState();

      await tester.pumpWidget(MaterialApp(
        home: EditWeekScreen(
          state: state,
          appSettingsState: appSettings,
          testDatePickerOverride: (ctx, date) async => DateTime(2026, 2, 8),
        ),
      ));

      await tester.tap(find.text('Başlangıç 02.02.2026'));
      await tester.pumpAndSettle();

      expect(
        find.text('Başlangıç tarihi bitiş tarihinden sonra olamaz.'),
        findsOneWidget,
      );
    });
  });
}

void _useTallTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
