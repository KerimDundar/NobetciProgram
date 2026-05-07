import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nobetci_program_mobile/config/feature_flags.dart';
import 'package:nobetci_program_mobile/state/roster_state.dart';
import 'package:nobetci_program_mobile/ui/screens/roster_home_screen.dart';
import 'package:nobetci_program_mobile/ui/screens/user_guide_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UserGuideScreen — widget testler', () {
    testWidgets('Kullanım Kılavuzu başlığı görünür', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserGuideScreen()),
      );
      expect(find.text('Kullanım Kılavuzu'), findsOneWidget);
    });

    testWidgets('Ana bölümler görünür', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserGuideScreen()),
      );
      expect(find.text('Uygulama Ne İşe Yarar?'), findsOneWidget);
      expect(find.text('İlk Kullanım'), findsOneWidget);
      expect(find.text('Öğretmen Ekleme ve Listeleme'), findsOneWidget);
      expect(find.text('PDF Çıktısı Alma'), findsOneWidget);
      expect(find.text('Excel Çıktısı Alma'), findsOneWidget);
      expect(find.text('Sık Karşılaşılan Durumlar'), findsOneWidget);
    });

    testWidgets('Proje nedir ve Proje silme bölümleri görünür', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserGuideScreen()),
      );
      expect(find.text('Proje Nedir?'), findsOneWidget);
      expect(find.text('Proje Silme'), findsOneWidget);
    });

    testWidgets('asset yokken ekran crash etmez', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserGuideScreen()),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ekran scroll edilebilir (SingleChildScrollView)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserGuideScreen()),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('geri tuşuyla önceki ekrana dönülebilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserGuideScreen(),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      expect(find.text('Kullanım Kılavuzu'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Kullanım Kılavuzu'), findsNothing);
      expect(find.text('Aç'), findsOneWidget);
    });

    testWidgets('premium zorlayıcı metin içermiyor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserGuideScreen()),
      );
      expect(find.text('Premium satın alın'), findsNothing);
      expect(find.text('Premium Ol'), findsNothing);
    });
  });

  group('Hamburger menü — Kullanım Kılavuzu navigation', () {
    void useTallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('Kullanım Kılavuzu menü öğesi UserGuideScreen açar',
        (tester) async {
      useTallView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(
        MaterialApp(home: RosterHomeScreen(state: state)),
      );
      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-guide')));
      await tester.pumpAndSettle();
      expect(find.byType(UserGuideScreen), findsOneWidget);
      expect(find.text('Kullanım Kılavuzu'), findsOneWidget);
    });

    testWidgets('Kullanım Kılavuzu açıkken geri tuşu ana ekrana döner',
        (tester) async {
      useTallView(tester);
      final state = RosterState.initial();
      await tester.pumpWidget(
        MaterialApp(home: RosterHomeScreen(state: state)),
      );
      await tester.tap(find.byKey(const Key('home-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-item-guide')));
      await tester.pumpAndSettle();
      expect(find.byType(UserGuideScreen), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(UserGuideScreen), findsNothing);
      expect(find.byType(RosterHomeScreen), findsOneWidget);
    });
  });

  group('Feature flag kontrolü', () {
    test('FeatureFlags.premiumGateEnabled hâlâ false', () {
      expect(FeatureFlags.premiumGateEnabled, isFalse);
    });
  });
}
