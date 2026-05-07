import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanım Kılavuzu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuideSection(
              key: const Key('guide-section-intro'),
              title: 'Uygulama Ne İşe Yarar?',
              children: [
                const Text(
                  'Nöbetçi Program, okul nöbet çizelgelerini haftalık veya aylık olarak '
                  'hazırlamak, düzenlemek ve PDF/Excel çıktısı almak için geliştirilmiştir.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Temel kavramlar: proje (çizelge dosyası), öğretmen listesi, '
                  'görev yerleri, haftalık/aylık plan ve PDF/Excel dışa aktarma.',
                ),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-first-use'),
              title: 'İlk Kullanım',
              children: const [
                _GuideStepList(steps: [
                  'Uygulamayı açın.',
                  'Hoş geldiniz ekranından devam edin.',
                  'Çizelgelerim ekranına geçin.',
                  'Yeni proje oluştur butonuna basın.',
                  'Proje adını girin.',
                  'Haftalık veya aylık plan türünü seçin.',
                  'Kaydedin.',
                ]),
                _GuideImage(label: 'Çizelgelerim ekranı'),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-project'),
              title: 'Proje Nedir?',
              children: [
                const Text(
                  'Proje, ayrı bir nöbet çizelgesi dosyası gibi düşünülebilir. '
                  'Her projenin öğretmenleri, görev yerleri ve nöbet planı '
                  'birbirinden bağımsızdır.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Örnekler: "2025–2026 1. Dönem", "Şubat Ayı Nöbet Çizelgesi", '
                  '"Ortaokul Nöbet Planı".',
                ),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-create-project'),
              title: 'Yeni Proje Oluşturma',
              children: const [
                _GuideStepList(steps: [
                  'Çizelgelerim ekranında Yeni proje oluştur butonuna basın.',
                  'Proje adını yazın.',
                  'Haftalık veya aylık plan türünü seçin.',
                  'Oluştur dediğinizde düzenleme ekranı açılır.',
                  'Gerekli bilgileri girip Kaydet\'e basın.',
                ]),
                _GuideImage(label: 'Yeni proje oluşturma'),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-delete-project'),
              title: 'Proje Silme',
              children: const [
                _GuideStepList(steps: [
                  'Çizelgelerim ekranında silmek istediğiniz projenin yanındaki çöp kutusu ikonuna basın.',
                  'Onay penceresi açılır.',
                  'Sil derseniz proje kalıcı olarak silinir.',
                  'İptal derseniz işlem yapılmaz.',
                ]),
                SizedBox(height: 8),
                _GuideWarning(
                  text:
                      'Silinen proje geri alınamaz. Silmeden önce doğru projeyi seçtiğinizden emin olun.',
                ),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-teachers'),
              title: 'Öğretmen Ekleme ve Listeleme',
              children: const [
                _GuideStepList(steps: [
                  'Hamburger menüden Öğretmenler sayfasına girin.',
                  'Sağ alttaki + butonuna basarak öğretmen ekleyin.',
                  'Ad Soyad girin ve Kaydet\'e basın.',
                ]),
                SizedBox(height: 8),
                _GuideTip(
                  text:
                      'Öğretmen listesi Türk alfabesine göre sıralanır. '
                      'İ, I, Ç, Ş, Ö, Ü ve Ğ harfleri doğru sıraya göre değerlendirilir.',
                ),
                _GuideImage(label: 'Öğretmen listesi'),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-locations'),
              title: 'Görev Yeri Ekleme',
              children: const [
                Text(
                  'Hafta düzenleme ekranında görev yerleri eklenir.',
                ),
                SizedBox(height: 8),
                _GuideStepList(steps: [
                  'Bahçe, Koridor, Kantin gibi görev yerleri tanımlanabilir.',
                  'Her görev yerine bir veya birden fazla öğretmen atanabilir.',
                  'Boş görev yerleri takip edilebilir.',
                ]),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-weekly'),
              title: 'Haftalık Plan Oluşturma',
              children: const [
                _GuideStepList(steps: [
                  'Haftalık plan bir haftalık tarih aralığı için kullanılır.',
                  'Pazartesi–Cuma günleri görünür.',
                  'Önceki Hafta / Sonraki Hafta ile hafta geçişi yapılır.',
                ]),
                _GuideImage(label: 'Haftalık plan'),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-monthly'),
              title: 'Aylık Plan Oluşturma',
              children: const [
                _GuideStepList(steps: [
                  'Aylık plan tam ay aralığında çalışır.',
                  'Ayın ilk günü ile son günü esas alınır.',
                ]),
                SizedBox(height: 8),
                _GuideTip(
                  text:
                      'Aylık tablo oluşturulduktan sonra çıktıyı almak için '
                      'PDF veya Excel dışa aktarma butonunu kullanmalısınız.',
                ),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-edit-week'),
              title: 'Hafta Düzenleme Ekranı',
              children: const [
                _GuideStepList(steps: [
                  'Gün sekmeleri: Pazartesi, Salı, Çarşamba, Perşembe, Cuma.',
                  'Seçili güne göre içerik görünür.',
                  'Görev yeri ekleme, öğretmen seçme ve kaydetme yapılır.',
                  'Boş/dolu görev yeri göstergesi bulunur.',
                  'Öğretmen bilgi ikonundan haftalık görevler görülebilir.',
                ]),
                _GuideImage(label: 'Hafta düzenleme'),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-daily'),
              title: 'Günlük Plan Görüntüleme',
              children: const [
                _GuideStepList(steps: [
                  'Ana ekranda gün seçilir.',
                  'O güne ait tüm görev yerleri ve atamalar görünür.',
                  'Görev yerine tıklanınca o güne ait tüm atama bilgileri açılır.',
                  'Tarih ve gün bilgisi gösterilir.',
                ]),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-pdf'),
              title: 'PDF Çıktısı Alma',
              children: const [
                _GuideStepList(steps: [
                  'Ana ekranda PDF Dışa Aktar butonuna basın.',
                  'Reklam ekranı çıkabilir — reklamı kapatın.',
                  'PDF oluşturma devam eder.',
                  'Dosya kaydetme ekranından konum seçin.',
                  'PDF dosyası kaydedilir.',
                ]),
                SizedBox(height: 8),
                _GuideTip(
                  text: 'Reklam yüklenmezse çıktı alma işlemi engellenmez.',
                ),
                _GuideImage(label: 'PDF dışa aktarma'),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-excel'),
              title: 'Excel Çıktısı Alma',
              children: const [
                _GuideStepList(steps: [
                  'Excel Dışa Aktar butonuna basın.',
                  'Dosya kaydetme ekranından konum seçin.',
                  'Excel dosyası oluşturulur.',
                ]),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-storage'),
              title: 'Veriler Nerede Saklanır?',
              children: const [
                _GuideStepList(steps: [
                  'Projeler cihazda saklanır.',
                  'Uygulama kapatılıp açıldığında veriler korunur.',
                  'Uygulama kaldırılır veya uygulama verileri silinirse veriler kaybolabilir.',
                  'PDF/Excel çıktıları kullanıcı seçtiği konuma kaydedilir.',
                ]),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-premium'),
              title: 'Test Sürümü Hakkında',
              children: const [
                _GuideTip(
                  text:
                      'Bu test sürümünde tüm temel özellikler test amacıyla açıktır. '
                      'İlerleyen sürümlerde birden fazla proje oluşturma ve reklamsız PDF çıktısı '
                      'gibi bazı özellikler Premium kapsamında sunulabilir.',
                ),
              ],
            ),
            _GuideSection(
              key: const Key('guide-section-faq'),
              title: 'Sık Karşılaşılan Durumlar',
              children: const [
                _GuideFaqItem(
                  question: 'PDF çıktısı alırken reklam çıkıyor, normal mi?',
                  answer:
                      'Evet. PDF çıktısı öncesinde reklam gösterilebilir. '
                      'Reklam kapandıktan sonra PDF oluşturma devam eder.',
                ),
                _GuideFaqItem(
                  question: 'Projelerim kaybolur mu?',
                  answer:
                      'Uygulama verilerini silmediğiniz veya uygulamayı kaldırmadığınız '
                      'sürece projeleriniz cihazda saklanır.',
                ),
                _GuideFaqItem(
                  question:
                      'Bir projeyi yanlışlıkla oluşturursam ne yapabilirim?',
                  answer:
                      'Çizelgelerim ekranında projenin yanındaki silme ikonuna basarak '
                      'projeyi silebilirsiniz.',
                ),
                _GuideFaqItem(
                  question: 'Öğretmenler neden farklı sırada görünüyor?',
                  answer:
                      'Öğretmenler Türk alfabesine göre sıralanır. '
                      'Türkçe karakterler doğru sıraya göre değerlendirilir.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 12),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _GuideStepList extends StatelessWidget {
  const _GuideStepList({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(child: Text(steps[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: cs.onPrimaryContainer))),
        ],
      ),
    );
  }
}

class _GuideWarning extends StatelessWidget {
  const _GuideWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 18, color: cs.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: cs.onErrorContainer))),
        ],
      ),
    );
  }
}

class _GuideFaqItem extends StatelessWidget {
  const _GuideFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(answer),
        ],
      ),
    );
  }
}

// Placeholder widget — gerçek ekran görüntüleri ileride assets/guide/ altına eklenir.
// pubspec.yaml'a "- assets/guide/" eklendikten sonra Image.asset ile gösterilebilir.
class _GuideImage extends StatelessWidget {
  const _GuideImage({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 100,
          color: cs.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 28, color: cs.onSurfaceVariant),
                const SizedBox(height: 4),
                Text(
                  label ?? 'Ekran görseli eklenecek',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
