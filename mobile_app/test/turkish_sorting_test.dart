import 'package:flutter_test/flutter_test.dart';

import 'package:nobetci_program_mobile/services/turkish_text_comparator.dart';
import 'package:nobetci_program_mobile/models/teacher.dart';
import 'package:nobetci_program_mobile/services/teacher_repository.dart';

void main() {
  group('TurkishTextComparator.initial (avatar ilk harf)', () {
    test('küçük i → büyük İ', () {
      expect(TurkishTextComparator.initial('ilkay'), 'İ');
      expect(TurkishTextComparator.initial('ibrahim'), 'İ');
    });

    test('küçük ı → büyük I', () {
      expect(TurkishTextComparator.initial('ışık'), 'I');
    });

    test('büyük Işık → I (zaten büyük, aynen kalır)', () {
      expect(TurkishTextComparator.initial('Işık'), 'I');
    });

    test('büyük İbrahim → İ (zaten büyük, aynen kalır)', () {
      expect(TurkishTextComparator.initial('İbrahim'), 'İ');
    });

    test('ü → Ü', () {
      expect(TurkishTextComparator.initial('ümit'), 'Ü');
    });

    test('ö → Ö', () {
      expect(TurkishTextComparator.initial('ömer'), 'Ö');
    });

    test('ş → Ş', () {
      expect(TurkishTextComparator.initial('şule'), 'Ş');
    });

    test('ç → Ç', () {
      expect(TurkishTextComparator.initial('çağla'), 'Ç');
    });

    test('ğ → Ğ', () {
      expect(TurkishTextComparator.initial('ğül'), 'Ğ');
    });

    test('boş string → ?', () {
      expect(TurkishTextComparator.initial(''), '?');
      expect(TurkishTextComparator.initial('   '), '?');
    });
  });

  group('TurkishTextComparator.toUpper', () {
    test('i → İ (Türkçe noktalı i)', () {
      expect(TurkishTextComparator.toUpper('i'), 'İ');
    });

    test('ı → I (Türkçe noktasız ı)', () {
      expect(TurkishTextComparator.toUpper('ı'), 'I');
    });

    test('diğer harfler standart büyük harf', () {
      expect(TurkishTextComparator.toUpper('ü'), 'Ü');
      expect(TurkishTextComparator.toUpper('ö'), 'Ö');
      expect(TurkishTextComparator.toUpper('ş'), 'Ş');
      expect(TurkishTextComparator.toUpper('ç'), 'Ç');
      expect(TurkishTextComparator.toUpper('ğ'), 'Ğ');
    });
  });

  group('TurkishTextComparator.compare sıralama', () {
    test('basic ASCII sırası korunur', () {
      expect(TurkishTextComparator.compare('Ali', 'Bora'), isNegative);
      expect(TurkishTextComparator.compare('Bora', 'Ali'), isPositive);
      expect(TurkishTextComparator.compare('Ali', 'Ali'), isZero);
    });

    test('ç c\'den sonra gelir', () {
      expect(TurkishTextComparator.compare('cam', 'çam'), isNegative);
      expect(TurkishTextComparator.compare('çam', 'cam'), isPositive);
    });

    test('ğ g\'den sonra gelir', () {
      expect(TurkishTextComparator.compare('gül', 'ğıl'), isNegative);
    });

    test('ı i\'den önce gelir (alfabe: h, ı, i)', () {
      expect(TurkishTextComparator.compare('ıspanak', 'iyi'), isNegative);
      expect(TurkishTextComparator.compare('iyi', 'ıspanak'), isPositive);
    });

    test('ö o\'dan sonra gelir', () {
      expect(TurkishTextComparator.compare('okul', 'öğretmen'), isNegative);
    });

    test('ş s\'den sonra gelir', () {
      expect(TurkishTextComparator.compare('sabah', 'şehir'), isNegative);
    });

    test('ü u\'dan sonra gelir', () {
      expect(TurkishTextComparator.compare('uzun', 'üzüm'), isNegative);
    });

    test('I → ı lowercase: IŞIK i\'den önce sıralanır', () {
      expect(TurkishTextComparator.compare('IŞIK', 'iyi'), isNegative);
    });

    test('İ → i lowercase: İyi == iyi', () {
      expect(TurkishTextComparator.compare('İyi', 'iyi'), isZero);
    });

    test('case insensitive: Ahmet == ahmet', () {
      expect(TurkishTextComparator.compare('Ahmet', 'ahmet'), isZero);
    });

    test('kısa önce uzundan önce gelir', () {
      expect(TurkishTextComparator.compare('Ali', 'Alim'), isNegative);
    });

    test('Işık < İbrahim < ilkay (ı=10 < i=11, bkz İbr→ibr b=1 < ilk l=12)', () {
      final names = ['ilkay', 'İbrahim', 'Işık'];
      names.sort(TurkishTextComparator.compare);
      expect(names, ['Işık', 'İbrahim', 'ilkay']);
    });

    test('spec\'te verilen tam sıralama örneği', () {
      final names = [
        'Vbv', 'kar', 'ilkay', 'cey', 'Işık', 'İbrahim',
        'Ömer', 'Ümit', 'Şule', 'Çağla', 'Deniz', 'Ali',
      ];
      names.sort(TurkishTextComparator.compare);
      expect(names, [
        'Ali',
        'cey',
        'Çağla',
        'Deniz',
        'Işık',
        'İbrahim',
        'ilkay',
        'kar',
        'Ömer',
        'Şule',
        'Ümit',
        'Vbv',
      ]);
    });

    test('ı < i sırasında Işık, İnci sırası', () {
      final names = ['İnci', 'Işık', 'Ayşe'];
      names.sort(TurkishTextComparator.compare);
      expect(names[0], 'Ayşe');
      expect(names[1], 'Işık');
      expect(names[2], 'İnci');
    });

    test('karma Türkçe öğretmen listesi sıralama', () {
      final names = ['Şahin Yıldız', 'Ali Yılmaz', 'Çetin Kaya', 'Ömer Demir', 'Bora Çelik'];
      names.sort(TurkishTextComparator.compare);
      expect(names, [
        'Ali Yılmaz',
        'Bora Çelik',
        'Çetin Kaya',
        'Ömer Demir',
        'Şahin Yıldız',
      ]);
    });
  });

  group('InMemoryTeacherRepository Türkçe sıralama', () {
    test('Türkçe alfabetik sıra ile döner', () async {
      final repo = InMemoryTeacherRepository(initialTeachers: [
        Teacher(id: 'T001', name: 'Şahin Demir', isActive: true),
        Teacher(id: 'T002', name: 'Ali Çelik', isActive: true),
        Teacher(id: 'T003', name: 'Çetin Kaya', isActive: true),
        Teacher(id: 'T004', name: 'Ömer Yıldız', isActive: true),
        Teacher(id: 'T005', name: 'Bora Arslan', isActive: true),
      ]);

      final teachers = await repo.list();
      final names = teachers.map((t) => t.name).toList();
      expect(names, [
        'Ali Çelik',
        'Bora Arslan',
        'Çetin Kaya',
        'Ömer Yıldız',
        'Şahin Demir',
      ]);
    });

    test('I / ı ayrımı: Işık < İnci', () async {
      final repo = InMemoryTeacherRepository(initialTeachers: [
        Teacher(id: 'T001', name: 'İnci Kara', isActive: true),
        Teacher(id: 'T002', name: 'Işık Aydın', isActive: true),
        Teacher(id: 'T003', name: 'Ahmet Demir', isActive: true),
      ]);

      final teachers = await repo.list();
      final names = teachers.map((t) => t.name).toList();
      expect(names[0], 'Ahmet Demir');
      expect(names[1], 'Işık Aydın');
      expect(names[2], 'İnci Kara');
    });
  });
}
