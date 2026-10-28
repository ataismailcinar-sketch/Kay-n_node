/// Uygulama genelinde kullanılan sabitler.
/// Zero-Keyboard UI prensibi gereği minimum dokunma hedefi 56dp'dir.
class AppConstants {
  AppConstants._();

  // ── API ───────────────────────────────────────────────────────────────
  /// Derlemede verilir: `flutter run --dart-define=API_URL=http://192.168.1.20:5000/api`
  /// Verilmezse `localhost` kullanılır. Telefonda USB ile denerken
  /// `adb reverse tcp:5000 tcp:5000` çalıştırılırsa telefondaki localhost bilgisayara bağlanır;
  /// Android emülatöründe bilgisayarın adresi `10.0.2.2`'dir.
  static const String apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5000/api');

  // ── Dokunma Hedefi (Zero-Keyboard UI) ────────────────────────────────
  /// WCAG ve tarım sahasındaki nasır/eldiven koşulları için minimum 56dp.
  static const double minTouchTarget = 56.0;

  /// Dev butonlar — kategori seçimi için.
  static const double bigButtonHeight = 72.0;
  static const double bigButtonWidth = 72.0;

  // ── Senkronizasyon ────────────────────────────────────────────────────
  /// Sync deneme aralığı (saniye) — bağlantı varsa bu sıklıkta kontrol et.
  static const int syncIntervalSeconds = 30;

  /// Tek seferlik push'ta maksimum kayıt sayısı (batch size).
  static const int syncBatchSize = 50;

  // ── Toprak Nemi Eşikleri ──────────────────────────────────────────────
  /// Bu değerin altında → Kırmızı uyarı (Acil Su).
  static const double criticalMoistureThreshold = 30.0;

  /// Bu değerin üstünde → Yeşil (Su Yeterli).
  static const double adequateMoistureThreshold = 60.0;

  // ── Muhasebe Hızlı Ekleme Değerleri ──────────────────────────────────
  static const List<double> quickAddAmounts = [500, 1000, 2000, 5000, 10000];

  // ── Kategori Listeleri (Zero-Keyboard) ───────────────────────────────
  /// Veritabanında/sunucuda saklanan kategori kodları ASCII'dir (geriye uyumluluk);
  /// ekranda [kategoriAdi] ile Türkçe gösterilir.
  static String kategoriAdi(String kod, {String islemTuru = 'Gider'}) => switch (kod) {
        'Gubre' => 'Gübre',
        'Ilac' => 'İlaç',
        'Iscilik' => 'İşçilik',
        'Hasat' => 'Hasat Satışı',
        'Destek' => 'Destekleme',
        'Diger' => islemTuru == 'Gelir' ? 'Diğer Gelir' : 'Diğer',
        _ => kod,
      };

  /// Alt kategori listesi. "Diger" kodu gelir ve gider için farklı listeye bakar.
  static List<String> altKategorilerFor(String kategori, String islemTuru) =>
      altKategoriler[kategori == 'Diger' && islemTuru == 'Gelir' ? 'DigerGelir' : kategori] ?? const ['Genel'];

  static const Map<String, List<String>> altKategoriler = {
    'Gubre': ['Üre', 'DAP', 'Kompoze', 'Potasyum', 'Kireç'],
    'Ilac': ['Herbisit', 'Fungusit', 'İnsektisit', 'Yaprak Gübresi'],
    'Mazot': ['Tarla', 'Taşıma', 'Jeneratör'],
    'Iscilik': ['Hasat', 'Ekim', 'Bakım', 'Sulama'],
    'Tohum': ['Sertifikalı Tohum', 'Fide', 'Hibrit'],
    'Hasat': ['Buğday Satışı', 'Mısır Satışı', 'Ayçiçeği Satışı', 'Pamuk Satışı', 'Domates Satışı', 'Ürün Satışı'],
    'Destek': ['Mazot/Gübre Desteği', 'Fark Ödemesi / Prim', 'Alan Bazlı Destek', 'Sertifikalı Tohum Desteği'],
    'Diger': ['Ekipman / Tamir', 'Elektrik / Sulama', 'Kira / Arazi', 'Diğer'],
    'DigerGelir': ['Hayvancılık', 'Kira Geliri', 'Ekipman Satışı', 'Diğer'],
  };
}
