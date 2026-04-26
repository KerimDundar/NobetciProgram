# Flutter Dev — Post-Update Emulator Refresh Rule

Flutter/mobile app üzerinde kod değişikliği yapıldıktan sonra, özellikle state,
SharedPreferences, navigation, export, UI flow veya build behavior etkilenmişse,
çalışma tamamlandı sayılmadan önce aşağıdaki adımlar uygulanır.

## Post-Update Emulator Refresh Rule

### 1. Her değişikliğin ardından (zorunlu)
```
flutter test
flutter analyze
```

### 2. Emulator testi istenecekse veya UI davranışı değişmişse
```
# çalışan uygulamayı durdur
adb uninstall com.example.nobetci_program_mobile   # SharedPreferences etkileyen değişikliklerde
flutter clean
flutter pub get
flutter run -d emulator-5554
```

### 3. Uninstall/reinstall ne zaman tercih edilir?
SharedPreferences, state persistence, navigation stack veya launch behavior etkileyen
değişikliklerde uninstall/reinstall tercih edilir.
Çünkü eski local state yeni davranışı maskeleyebilir.

### 4. Rapor formatı
```
TESTS: flutter test — X passed / Y failed
ANALYZE: clean / N warnings
CLEAN BUILD: yapıldı / yapılmadı
EMULATOR REINSTALL: yapıldı / yapılmadı
APP LAUNCHED: başarılı / başarısız / test edilmedi
MANUEL KONTROL: <beklenen senaryolar veya "yok">
```

### 5. Kapsam sınırları
- Bu kural **sadece Flutter/mobile app** değişikliklerinde uygulanır.
- Desktop Python/Tkinter veya dokümantasyon-only değişikliklerde zorunlu değildir.
- Her küçük değişiklikte tam rapor gerekmez; sadece emulator testi istenirse
  veya UI/state/export akışı etkilenmişse tam adımlar uygulanır.
- Emulator yükleme yapılamadıysa açıkça raporlanır; yapılmış gibi gösterilmez.
- Kod değişikliği istenmediyse bu adımda yeni kod yazılmaz — sadece doğrulama,
  temiz build ve emulator yükleme yapılır.
