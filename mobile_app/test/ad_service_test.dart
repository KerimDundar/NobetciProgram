import 'package:flutter_test/flutter_test.dart';
import 'package:nobetci_program_mobile/services/interstitial_ad_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('InterstitialAdService', () {
    test('calls onContinue immediately when no ad is preloaded', () async {
      final service = InterstitialAdService();
      var called = false;
      await service.showBeforePdfExport(onContinue: () async {
        called = true;
      });
      expect(called, isTrue);
    });

    test('propagates exception thrown inside onContinue', () async {
      final service = InterstitialAdService();
      await expectLater(
        () => service.showBeforePdfExport(
          onContinue: () async => throw Exception('export error'),
        ),
        throwsException,
      );
    });

    test('dispose does not throw when no ad is loaded', () {
      final service = InterstitialAdService();
      expect(() => service.dispose(), returnsNormally);
    });

    test('dispose does not throw when called twice', () {
      final service = InterstitialAdService();
      service.dispose();
      expect(() => service.dispose(), returnsNormally);
    });

    test('showBeforePdfExport calls onContinue in order', () async {
      final service = InterstitialAdService();
      final log = <String>[];
      log.add('before');
      await service.showBeforePdfExport(onContinue: () async {
        log.add('onContinue');
      });
      log.add('after');
      expect(log, ['before', 'onContinue', 'after']);
    });
  });
}
