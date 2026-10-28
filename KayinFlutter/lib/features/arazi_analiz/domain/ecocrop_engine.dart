/// FAO EcoCrop Modeli & Replantio Arazi Uygunluk / Rekolte Motoru.
///
/// Tarlanin koordinat iklim degerlerini (Sicaklik, Yagis, Don Riski, Toprak Tipi)
/// urunlerin biyolojik yetisme esikleriyle trapezoid fonksiyonlarla karsilastirarak
/// uygunluk skoru (A/B/C/D), rekolte ve gelir tahmini uretir.
class EcoCropEngine {
  /// Trapezoid uyelik fonksiyonu: a (mutlak min), b (optimum min), c (optimum max), d (mutlak max)
  static double _trapezoid(double x, double a, double b, double c, double d) {
    if (x <= a || x >= d) return 0.0;
    if (x >= b && x <= c) return 1.0;
    if (x < b) return (x - a) / (b - a);
    return (d - x) / (d - c);
  }

  /// Turkiye kosullarina kalibre edilmis urun profilleri
  static final List<_UrunProfili> urunProfilleri = [
    _UrunProfili(
      ad: 'Buğday',
      emoji: '🌾',
      kategori: 'Tahil',
      tMin: 5.0, tOptMin: 15.0, tOptMax: 24.0, tMax: 32.0,
      yagisMin: 350.0, yagisOptMin: 500.0, yagisOptMax: 850.0, yagisMax: 1400.0,
      donToleransi: true,
      minSicaklikDayanimi: -18.0,
      uygunTopraklar: ['Tinli', 'Killi', 'Kirecli'],
      phMin: 5.0, phOptMin: 6.0, phOptMax: 8.2, phMax: 8.9,
      tuzEsigi: 6.0, tuzEgimi: 7.1,
      ortalamaVerimKgDonum: 450.0,
      ortalamaFiyatTLKg: 10.5,
      tavsiyeNotu: 'Orta Anadolu ve Trakya ikliminde en yuksek guvenceli stratejik urun.',
    ),
    _UrunProfili(
      ad: 'Arpa',
      emoji: '🌾',
      kategori: 'Tahil',
      tMin: 4.0, tOptMin: 12.0, tOptMax: 22.0, tMax: 30.0,
      yagisMin: 280.0, yagisOptMin: 400.0, yagisOptMax: 700.0, yagisMax: 1100.0,
      donToleransi: true,
      minSicaklikDayanimi: -20.0,
      uygunTopraklar: ['Kirecli', 'Tinli', 'Kumlu'],
      phMin: 5.0, phOptMin: 6.0, phOptMax: 8.2, phMax: 9.0,
      tuzEsigi: 8.0, tuzEgimi: 5.0,
      ortalamaVerimKgDonum: 400.0,
      ortalamaFiyatTLKg: 8.5,
      tavsiyeNotu: 'Kurak ve kirecli topraklarda bugdaya gore daha yuksek adaptasyon gosterir.',
    ),
    _UrunProfili(
      ad: 'Mısır',
      emoji: '🌽',
      kategori: 'Tahil & Yem',
      tMin: 10.0, tOptMin: 20.0, tOptMax: 30.0, tMax: 38.0,
      yagisMin: 500.0, yagisOptMin: 650.0, yagisOptMax: 1100.0, yagisMax: 1800.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: 2.0,
      uygunTopraklar: ['Tinli', 'Killi'],
      phMin: 5.0, phOptMin: 5.8, phOptMax: 7.8, phMax: 8.7,
      tuzEsigi: 1.7, tuzEgimi: 12.0,
      ortalamaVerimKgDonum: 1250.0,
      ortalamaFiyatTLKg: 8.0,
      tavsiyeNotu: 'Yuksek sicaklik ve duzenli damlama/yagmurlama sulamada rekor getiri saglar.',
    ),
    _UrunProfili(
      ad: 'Ayçiçeği',
      emoji: '🌻',
      kategori: 'Yagli Tohum',
      tMin: 8.0, tOptMin: 18.0, tOptMax: 28.0, tMax: 36.0,
      yagisMin: 350.0, yagisOptMin: 500.0, yagisOptMax: 800.0, yagisMax: 1300.0,
      donToleransi: false,
      minSicaklikDayanimi: -2.0,
      uygunTopraklar: ['Tinli', 'Killi', 'Kirecli'],
      phMin: 5.0, phOptMin: 6.0, phOptMax: 8.0, phMax: 8.8,
      tuzEsigi: 4.8, tuzEgimi: 5.0,
      ortalamaVerimKgDonum: 280.0,
      ortalamaFiyatTLKg: 18.0,
      tavsiyeNotu: 'Kazik kok yapisiyla orta derinlikteki taban nemini mukemmel degerlendirir.',
    ),
    _UrunProfili(
      ad: 'Pamuk',
      emoji: '🌿',
      kategori: 'Endustriyel',
      tMin: 14.0, tOptMin: 24.0, tOptMax: 34.0, tMax: 40.0,
      yagisMin: 550.0, yagisOptMin: 700.0, yagisOptMax: 1200.0, yagisMax: 1600.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: 5.0,
      uygunTopraklar: ['Tinli', 'Killi'],
      phMin: 5.0, phOptMin: 5.8, phOptMax: 8.0, phMax: 8.9,
      tuzEsigi: 7.7, tuzEgimi: 5.2,
      ortalamaVerimKgDonum: 500.0,
      ortalamaFiyatTLKg: 24.0,
      tavsiyeNotu: 'Ege ve Guneydogu gibi yuksek guneslenme ve sicaklik alan ovalarda idealdir.',
    ),
    _UrunProfili(
      ad: 'Domates',
      emoji: '🍅',
      kategori: 'Sebze',
      tMin: 10.0, tOptMin: 18.0, tOptMax: 28.0, tMax: 35.0,
      yagisMin: 400.0, yagisOptMin: 600.0, yagisOptMax: 1000.0, yagisMax: 1500.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: 0.0,
      uygunTopraklar: ['Tinli', 'Kumlu'],
      phMin: 5.0, phOptMin: 6.0, phOptMax: 7.5, phMax: 8.5,
      tuzEsigi: 2.5, tuzEgimi: 9.9,
      ortalamaVerimKgDonum: 8000.0,
      ortalamaFiyatTLKg: 3.5,
      tavsiyeNotu: 'Organik maddece zengin, iyi drene edilmis topraklarda yogun kar birakir.',
    ),
    _UrunProfili(
      ad: 'Zeytin',
      emoji: '🫒',
      kategori: 'Meyve & Cok Yillik',
      tMin: 8.0, tOptMin: 16.0, tOptMax: 28.0, tMax: 40.0,
      yagisMin: 350.0, yagisOptMin: 550.0, yagisOptMax: 900.0, yagisMax: 1400.0,
      donToleransi: true,
      minSicaklikDayanimi: -8.0,
      uygunTopraklar: ['Kirecli', 'Tinli', 'Kumlu'],
      phMin: 5.5, phOptMin: 6.5, phOptMax: 8.2, phMax: 9.0,
      tuzEsigi: 4.0, tuzEgimi: 6.0,
      ortalamaVerimKgDonum: 600.0,
      ortalamaFiyatTLKg: 45.0,
      tavsiyeNotu: 'Akdeniz/Ege ikliminde kuraga dayanikli, tasli/egimli yamaclarda cok verimlidir.',
    ),
    _UrunProfili(
      ad: 'Üzüm',
      emoji: '🍇',
      kategori: 'Meyve & Bag',
      tMin: 8.0, tOptMin: 16.0, tOptMax: 27.0, tMax: 38.0,
      yagisMin: 350.0, yagisOptMin: 500.0, yagisOptMax: 800.0, yagisMax: 1200.0,
      donToleransi: true,
      minSicaklikDayanimi: -14.0,
      uygunTopraklar: ['Tinli', 'Kirecli', 'Kumlu'],
      phMin: 5.0, phOptMin: 6.0, phOptMax: 8.2, phMax: 8.8,
      tuzEsigi: 1.5, tuzEgimi: 9.6,
      ortalamaVerimKgDonum: 1800.0,
      ortalamaFiyatTLKg: 20.0,
      tavsiyeNotu: 'Gunes goren guney yamaclarda yuksek seker orani ve kaliteli mahsul verir.',
    ),
    _UrunProfili(
      ad: 'Soya',
      emoji: '🌱',
      kategori: 'Baklagil & Yagli',
      tMin: 10.0, tOptMin: 20.0, tOptMax: 30.0, tMax: 36.0,
      yagisMin: 450.0, yagisOptMin: 600.0, yagisOptMax: 950.0, yagisMax: 1500.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: 1.0,
      uygunTopraklar: ['Tinli', 'Killi'],
      phMin: 5.0, phOptMin: 6.0, phOptMax: 7.5, phMax: 8.4,
      tuzEsigi: 5.0, tuzEgimi: 20.0,
      ortalamaVerimKgDonum: 380.0,
      ortalamaFiyatTLKg: 17.0,
      tavsiyeNotu: 'Topraga azot baglayarak kendisinden sonraki urunun gubre masrafini dusurur.',
    ),
    // Verim: Türkiye ortalamasına yakın (TÜİK); fiyatlar kaba varsayım, piyasa fiyatı değildir.
    _UrunProfili(
      ad: 'Şeker Pancarı',
      emoji: '🥬',
      kategori: 'Endüstriyel',
      tMin: 5.0, tOptMin: 16.0, tOptMax: 25.0, tMax: 33.0,
      yagisMin: 400.0, yagisOptMin: 600.0, yagisOptMax: 900.0, yagisMax: 1300.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: -3.0,
      uygunTopraklar: ['Tinli', 'Killi'],
      phMin: 5.5, phOptMin: 6.5, phOptMax: 8.2, phMax: 8.8,
      tuzEsigi: 7.0, tuzEgimi: 5.9,
      ortalamaVerimKgDonum: 6500.0,
      ortalamaFiyatTLKg: 2.8,
      tavsiyeNotu: 'Fabrika sözleşmesi (kota) ile ekilir; sulama ister. Tuza dayanıklıdır, ekim nöbetinde 4 yılda bir aynı tarlaya gelmelidir.',
    ),
    _UrunProfili(
      ad: 'Nohut',
      emoji: '🫘',
      kategori: 'Baklagil',
      tMin: 7.0, tOptMin: 15.0, tOptMax: 25.0, tMax: 32.0,
      yagisMin: 280.0, yagisOptMin: 380.0, yagisOptMax: 650.0, yagisMax: 1000.0,
      donToleransi: false,
      minSicaklikDayanimi: -5.0,
      uygunTopraklar: ['Tinli', 'Kirecli', 'Kumlu'],
      phMin: 5.5, phOptMin: 6.0, phOptMax: 8.2, phMax: 8.8,
      tuzEsigi: 1.5, tuzEgimi: 14.0,
      ortalamaVerimKgDonum: 130.0,
      ortalamaFiyatTLKg: 35.0,
      tavsiyeNotu: 'Kurağa dayanıklı, nadas yerine ekilebilir; azot bağlar, buğdayla ekim nöbetine çok uygundur. Tuza hassastır.',
    ),
    _UrunProfili(
      ad: 'Mercimek',
      emoji: '🫘',
      kategori: 'Baklagil',
      tMin: 5.0, tOptMin: 12.0, tOptMax: 24.0, tMax: 30.0,
      yagisMin: 250.0, yagisOptMin: 350.0, yagisOptMax: 600.0, yagisMax: 1000.0,
      donToleransi: true,
      minSicaklikDayanimi: -12.0,
      uygunTopraklar: ['Tinli', 'Kirecli', 'Killi'],
      phMin: 5.5, phOptMin: 6.0, phOptMax: 8.2, phMax: 8.8,
      tuzEsigi: 1.5, tuzEgimi: 14.0,
      ortalamaVerimKgDonum: 140.0,
      ortalamaFiyatTLKg: 32.0,
      tavsiyeNotu: 'GAP\'ta kışlık kırmızı, İç Anadolu\'da ilkbaharda yeşil mercimek. Kuru tarımda buğday-mercimek nöbeti verimi artırır.',
    ),
    _UrunProfili(
      ad: 'Patates',
      emoji: '🥔',
      kategori: 'Yumru',
      tMin: 7.0, tOptMin: 15.0, tOptMax: 22.0, tMax: 30.0,
      yagisMin: 400.0, yagisOptMin: 550.0, yagisOptMax: 900.0, yagisMax: 1400.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: -1.0,
      uygunTopraklar: ['Tinli', 'Kumlu'],
      // Kireçli/alkali toprakta uyuz (scab) riski artar.
      phMin: 4.5, phOptMin: 5.2, phOptMax: 7.5, phMax: 8.5,
      tuzEsigi: 1.7, tuzEgimi: 12.0,
      ortalamaVerimKgDonum: 3300.0,
      ortalamaFiyatTLKg: 10.0,
      tavsiyeNotu: 'Serin yaz ve hafif (tınlı-kumlu) toprak sever; düzenli sulama ister. Sıcak gecelerde yumru bağlama zayıflar.',
    ),
    _UrunProfili(
      ad: 'Fasulye',
      emoji: '🫘',
      kategori: 'Baklagil',
      tMin: 10.0, tOptMin: 18.0, tOptMax: 27.0, tMax: 32.0,
      yagisMin: 400.0, yagisOptMin: 500.0, yagisOptMax: 800.0, yagisMax: 1200.0,
      kuruyaUygun: false,
      donToleransi: false,
      minSicaklikDayanimi: 1.0,
      uygunTopraklar: ['Tinli', 'Kumlu'],
      phMin: 5.5, phOptMin: 6.0, phOptMax: 7.5, phMax: 8.3,
      tuzEsigi: 1.0, tuzEgimi: 19.0,
      ortalamaVerimKgDonum: 220.0,
      ortalamaFiyatTLKg: 60.0,
      tavsiyeNotu: 'Kuru fasulye sulu tarımda yetişir; tuza ve dona en hassas ürünlerdendir. Çiçeklenmede su stresi çiçek döktürür.',
    ),
    _UrunProfili(
      ad: 'Yonca',
      emoji: '☘️',
      kategori: 'Yem (çok yıllık)',
      tMin: 5.0, tOptMin: 15.0, tOptMax: 28.0, tMax: 35.0,
      yagisMin: 350.0, yagisOptMin: 600.0, yagisOptMax: 1000.0, yagisMax: 1500.0,
      kuruyaUygun: false,
      donToleransi: true,
      minSicaklikDayanimi: -25.0,
      uygunTopraklar: ['Tinli', 'Killi', 'Kirecli'],
      phMin: 6.0, phOptMin: 6.5, phOptMax: 8.2, phMax: 8.8,
      tuzEsigi: 2.0, tuzEgimi: 7.3,
      ortalamaVerimKgDonum: 1000.0,
      ortalamaFiyatTLKg: 7.0,
      tavsiyeNotu: 'Kuru ot verimi; sulu şartlarda yılda 4-6 biçim. 4-6 yıl tarlada kalır, toprağa azot bırakır. Asit topraktan hoşlanmaz.',
    ),
  ];

  /// Tuzluluğa göre göreli verim (0.1–1): eşiğe kadar kayıp yok, sonra her dS/m için [egim] % düşer.
  static double tuzVerimi(double ec, {required double esik, required double egim}) =>
      (1 - egim * (ec - esik).clamp(0.0, double.infinity) / 100).clamp(0.1, 1.0);

  /// Ürünün tuz toleransı (eşik ECe dS/m, eşik üstü kayıp %/dS/m); ürün tanınmıyorsa null.
  static ({double esik, double egim})? tuzToleransi(String urun) {
    final n = _norm(urun);
    final p = urunProfilleri.where((p) => _norm(p.ad) == n).firstOrNull;
    return p == null ? null : (esik: p.tuzEsigi, egim: p.tuzEgimi);
  }

  static String _virgul(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Türkçe karakter/büyük-küçük harf farkını yok sayan karşılaştırma anahtarı
  /// ("Tınlı" == "Tinli", "Kireçli" == "Kirecli").
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .split(RegExp(r'[\s(/]')).first;

  /// Verilen cevre kosullarina gore tum urunleri puanlar ve en uygun olanlari siralar.
  ///
  /// [ortalamaSicaklik]: vejetasyon dönemi ortalaması (kışlık ürünler / çok yıllıklar için).
  /// [sicakDonemSicaklik]: yılın en sıcak ~4 ayının ortalaması (yazlık ürünler için);
  /// verilmezse [ortalamaSicaklik] kullanılır.
  /// [minSicaklik]: yılın mutlak en düşük sıcaklığı. Yazlık ürünler kışı tarlada
  /// geçirmediği için bunlara kış donu cezası uygulanmaz.
  /// [ph] ve [tuzlulukEc] (ECe, dS/m) tarlanın toprak analizinden; yoksa hesaba katılmaz.
  static List<MahsulUygunlukSonuc> analiziCalistir({
    required double ortalamaSicaklik,
    double? sicakDonemSicaklik,
    required double minSicaklik,
    required double maxSicaklik,
    required double yillikYagisMm,
    required String toprakTuru,
    required double alanDonum,
    double? ph,
    double? tuzlulukEc,
    bool? sulu,
    double? suEc,
  }) {
    // Sulu tarlada suyun tuzu zamanla toprakta birikir: beklenen ECe ≈ 1,5 × ECw (FAO 29).
    // Toprak analizi bundan yüksekse o geçerlidir.
    final sudanEc = sulu == true && suEc != null && suEc > 0 ? 1.5 * suEc : null;
    final etkinEc = switch ((tuzlulukEc, sudanEc)) {
      (null, null) => null,
      (final t?, null) => t,
      (null, final s?) => s,
      (final t?, final s?) => t > s ? t : s,
    };
    final sudanBaskin = sudanEc != null && etkinEc == sudanEc && (tuzlulukEc == null || sudanEc > tuzlulukEc);
    final sonuclar = <MahsulUygunlukSonuc>[];
    final toprak = _norm(toprakTuru);

    for (final p in urunProfilleri) {
      final sinirlayicilar = <String>[];
      final yazlik = !p.donToleransi;

      // 1. Sicaklik uygunlugu (Trapezoid 0..1)
      final sicaklikSkor = _trapezoid(
        yazlik ? (sicakDonemSicaklik ?? ortalamaSicaklik) : ortalamaSicaklik,
        p.tMin, p.tOptMin, p.tOptMax, p.tMax,
      );
      if (sicaklikSkor < 0.6) {
        sinirlayicilar.add('Bölge sıcaklığı optimum gelişim aralığının dışında');
      }

      // 2. Yagis / Su uygunlugu. Sulu tarlada yağış açığını sulama kapatır (fazla yağış yine sayılır).
      final yagisEksik = yillikYagisMm < p.yagisOptMin;
      final yagisSkor = sulu == true && yagisEksik
          ? 1.0
          : _trapezoid(yillikYagisMm, p.yagisMin, p.yagisOptMin, p.yagisOptMax, p.yagisMax);
      // Kuru tarlada sulama isteyen ürün: yıllık yağış ne olursa olsun yaz kuraklığında verim çöker.
      final kuruCezasi = sulu == false && !p.kuruyaUygun;
      if (kuruCezasi) {
        sinirlayicilar.add('Kuru tarımda yetiştirilmez — bu ürün yazın sulama ister');
      } else if (yagisEksik) {
        switch (sulu) {
          case true:
            break; // sulanıyor
          case false:
            sinirlayicilar.add(yillikYagisMm <= p.yagisMin
                ? 'Kuru tarımda yetişmez — yağış ürünün alt sınırının altında, sulama şart'
                : 'Kuru tarımda yağış yetersiz — verim düşük kalır');
          case null:
            sinirlayicilar.add('Doğal yağış yetersiz — sulama gerekir');
        }
      }

      // 3. Don Riski ve Kis Dayanimi
      double donSkor = 1.0;
      if (!yazlik && minSicaklik < p.minSicaklikDayanimi) {
        donSkor = 0.2;
        sinirlayicilar.add('Kış donu riski (son 12 ayda ${minSicaklik.toStringAsFixed(1)}°C, dayanım sınırı ${p.minSicaklikDayanimi.toStringAsFixed(0)}°C)');
      }

      // 4. Toprak bunyesi uygunlugu
      final toprakUygun = p.uygunTopraklar.any((t) => _norm(t) == toprak);
      final toprakSkor = toprakUygun ? 1.0 : 0.7;
      if (!toprakUygun) {
        sinirlayicilar.add('$toprakTuru toprak bu ürün için ideal değil');
      }

      // Bilesik Skor (Liebig Minimum Kanunu + Agirlikli Ortalama)
      final agirlikliSkor = (sicaklikSkor * 0.35) + (yagisSkor * 0.25) + (donSkor * 0.25) + (toprakSkor * 0.15);

      // 5. Toprak analizi: pH (en fazla %30 düşürür) ve tuzluluk (doğrudan verim kaybı).
      var analizCarpani = kuruCezasi ? 0.35 : 1.0;
      if (ph != null) {
        final phSkor = _trapezoid(ph, p.phMin, p.phOptMin, p.phOptMax, p.phMax);
        analizCarpani *= 0.7 + 0.3 * phSkor;
        if (phSkor < 1.0) {
          final yon = ph > p.phOptMax ? 'yüksek' : 'düşük';
          sinirlayicilar.add('pH ${_virgul(ph)} bu ürün için $yon (uygun ${_virgul(p.phOptMin)}–${_virgul(p.phOptMax)})');
        }
      }
      if (etkinEc != null) {
        final verim = tuzVerimi(etkinEc, esik: p.tuzEsigi, egim: p.tuzEgimi);
        analizCarpani *= verim;
        if (verim < 0.995) {
          final kayip = ((1 - verim) * 100).toStringAsFixed(0);
          sinirlayicilar.add(sudanBaskin
              ? 'Sulama suyu (${_virgul(suEc!)} dS/m) toprağı zamanla ~${_virgul(etkinEc)} dS/m\'ye tuzlandırır; '
                  'ürünün eşiği ${_virgul(p.tuzEsigi)}: verim ~%$kayip düşer'
              : 'Tuzluluk (${_virgul(etkinEc)} dS/m) ürünün eşiğini (${_virgul(p.tuzEsigi)}) aşıyor: verim ~%$kayip düşer');
        }
      }
      final netYuzde = (agirlikliSkor * analizCarpani * 100).clamp(0.0, 100.0);

      // Harf Derecesi
      final (derece, aciklama) = switch (netYuzde) {
        >= 82.0 => ('A', 'Mükemmel Uyum'),
        >= 68.0 => ('B', 'Yüksek Verim Potansiyeli'),
        >= 48.0 => ('C', 'Orta / Ek Bakım Gerekir'),
        _       => ('D', 'Düşük Verim / Yüksek Risk'),
      };

      // Rekolte ve Ciro Hesabi (Alan Bazli)
      final donumBasiVerim = p.ortalamaVerimKgDonum * (netYuzde / 100.0);
      final toplamTahminiHasatKg = donumBasiVerim * alanDonum;
      final toplamTahminiCiroTL = toplamTahminiHasatKg * p.ortalamaFiyatTLKg;

      sonuclar.add(
        MahsulUygunlukSonuc(
          urunAdi: p.ad,
          emoji: p.emoji,
          kategori: p.kategori,
          uygunlukSkoru: netYuzde,
          derece: derece,
          dereceAciklama: aciklama,
          tahminiVerimKgDonum: donumBasiVerim,
          toplamTahminiHasatKg: toplamTahminiHasatKg,
          toplamTahminiCiroTL: toplamTahminiCiroTL,
          sinirlayiciFaktorler: sinirlayicilar,
          tavsiyeNotu: p.tavsiyeNotu,
          varsayilanFiyatTLKg: p.ortalamaFiyatTLKg,
        ),
      );
    }

    // Skora gore yuksekten dusuge sirala
    sonuclar.sort((a, b) => b.uygunlukSkoru.compareTo(a.uygunlukSkoru));
    return sonuclar;
  }
}

class _UrunProfili {
  final String ad;
  final String emoji;
  final String kategori;
  final double tMin, tOptMin, tOptMax, tMax;
  final double yagisMin, yagisOptMin, yagisOptMax, yagisMax;
  final bool donToleransi;
  final double minSicaklikDayanimi;
  final List<String> uygunTopraklar;

  /// pH uygunluk aralığı (trapez: mutlak min, optimum min-max, mutlak max). FAO EcoCrop'tan yaklaşık.
  final double phMin, phOptMin, phOptMax, phMax;

  /// Tuz toleransı (Maas-Hoffman / FAO 29): verimin düşmeye başladığı ECe (dS/m) ve
  /// eşiğin üstündeki her 1 dS/m için verim kaybı (%).
  final double tuzEsigi, tuzEgimi;

  /// Türkiye'de sulamasız (kuru tarım) yetiştirilebilir mi. Yazlık ürünlerin çoğu yaz kuraklığında
  /// yağışla yetişmez; yıllık yağış toplamı yeterli görünse bile yağış kışın düşer.
  final bool kuruyaUygun;
  final double ortalamaVerimKgDonum;
  final double ortalamaFiyatTLKg;
  final String tavsiyeNotu;

  const _UrunProfili({
    required this.phMin,
    required this.phOptMin,
    required this.phOptMax,
    required this.phMax,
    required this.tuzEsigi,
    required this.tuzEgimi,
    this.kuruyaUygun = true,
    required this.ad,
    required this.emoji,
    required this.kategori,
    required this.tMin,
    required this.tOptMin,
    required this.tOptMax,
    required this.tMax,
    required this.yagisMin,
    required this.yagisOptMin,
    required this.yagisOptMax,
    required this.yagisMax,
    required this.donToleransi,
    required this.minSicaklikDayanimi,
    required this.uygunTopraklar,
    required this.ortalamaVerimKgDonum,
    required this.ortalamaFiyatTLKg,
    required this.tavsiyeNotu,
  });
}

class MahsulUygunlukSonuc {
  final String urunAdi;
  final String emoji;
  final String kategori;
  final double uygunlukSkoru;
  final String derece;
  final String dereceAciklama;
  final double tahminiVerimKgDonum;
  final double toplamTahminiHasatKg;
  final double toplamTahminiCiroTL;
  final List<String> sinirlayiciFaktorler;
  final String tavsiyeNotu;

  /// Ciro hesabında kullanılan SABİT varsayım fiyatı (güncel piyasa fiyatı değildir).
  final double varsayilanFiyatTLKg;

  const MahsulUygunlukSonuc({
    required this.urunAdi,
    required this.emoji,
    required this.kategori,
    required this.uygunlukSkoru,
    required this.derece,
    required this.dereceAciklama,
    required this.tahminiVerimKgDonum,
    required this.toplamTahminiHasatKg,
    required this.toplamTahminiCiroTL,
    required this.sinirlayiciFaktorler,
    required this.tavsiyeNotu,
    required this.varsayilanFiyatTLKg,
  });
}
