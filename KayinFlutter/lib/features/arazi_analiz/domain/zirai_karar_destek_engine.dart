import 'package:flutter/material.dart' show DateUtils;
import '../../../core/services/hava_durumu_servisi.dart';
import '../../parsel_harita/domain/entities/parsel_entity.dart';
import '../../parsel_harita/domain/sulama.dart';
import 'ecocrop_engine.dart';

class IlaclamaTavsiyesi {
  final bool uygun;
  final String durumRozeti;
  final String baslik;
  final String detay;
  final String idealSaatler;

  const IlaclamaTavsiyesi({
    required this.uygun,
    required this.durumRozeti,
    required this.baslik,
    required this.detay,
    required this.idealSaatler,
  });
}

class GubrelemeTavsiyesi {
  final bool yagisAlarmiVar;
  final String baslik;
  final String detay;
  final double beklenenYagisMm;
  final int kacGunSonra;

  const GubrelemeTavsiyesi({
    required this.yagisAlarmiVar,
    required this.baslik,
    required this.detay,
    required this.beklenenYagisMm,
    required this.kacGunSonra,
  });
}

class EkimTavTavsiyesi {
  final bool toprakTavinda;
  final String durum;
  final String baslik;
  final String detay;

  const EkimTavTavsiyesi({
    required this.toprakTavinda,
    required this.durum,
    required this.baslik,
    required this.detay,
  });
}

class SulamaTavsiyesi {
  final bool sulamaGerekli;
  final String aciliyet;
  final String baslik;
  final String detay;
  final double donumBasiTon;

  const SulamaTavsiyesi({
    required this.sulamaGerekli,
    required this.aciliyet,
    required this.baslik,
    required this.detay,
    required this.donumBasiTon,
  });
}

class ZiraiKararPaketi {
  final IlaclamaTavsiyesi ilaclama;
  final GubrelemeTavsiyesi gubreleme;
  final EkimTavTavsiyesi ekimTavi;
  final SulamaTavsiyesi sulama;

  const ZiraiKararPaketi({
    required this.ilaclama,
    required this.gubreleme,
    required this.ekimTavi,
    required this.sulama,
  });
}

/// Çiftçiye sıfır soru sorarak tarlanın verilerine göre anlık zirai kararları üreten motor.
class ZiraiKararDestekEngine {
  static ZiraiKararPaketi kararlariUret({
    required ParselEntity parsel,
    required TarlaHavaOzeti hava,
  }) {
    return ZiraiKararPaketi(
      ilaclama: ilaclamaTavsiyesi(hava),
      gubreleme: _gubrelemeHesapla(hava, parsel),
      ekimTavi: _ekimTaviHesapla(hava, parsel),
      sulama: _sulamaHesapla(hava, parsel),
    );
  }

  // ── 1. İlaçlama Radarı ───────────────────────────────────────────────────
  // Günlük en yüksek rüzgar öğleden sonrasını yansıtır; sabah saatleri çoğu gün
  // sakin olduğu için karar saatlik tahminden "ilaçlama penceresi" aranarak verilir.

  static const double _maksRuzgarKm = 15.0;
  static const double _maksSicaklik = 28.0;
  static const double _minSicaklik = 5.0;
  static const int _ilkSaat = 5; // 05:00'ten önce ve
  static const int _sonSaat = 20; // 21:00'den sonra ilaçlama önerilmez
  static const int _minPencereSaat = 2;

  /// Bir saatin ilaçlamaya uygun olmama nedeni; uygunsa null.
  static String? _uygunsuzlukNedeni(List<SaatlikHava> saatler, int i) {
    final s = saatler[i];
    if (s.zaman.hour < _ilkSaat || s.zaman.hour > _sonSaat) return 'gece';
    // İlacın yaprağa tutunması için o saat ve sonraki 2 saat kuru olmalı.
    final yagis = saatler.skip(i).take(3).fold<double>(0, (t, x) => t + x.yagisMm);
    if (yagis >= 0.5) return 'yağış';
    if (s.ruzgarKm >= _maksRuzgarKm) return 'rüzgar';
    if (s.sicaklik > _maksSicaklik) return 'sıcak';
    if (s.sicaklik < _minSicaklik) return 'soğuk';
    return null;
  }

  static String _saat(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:00';

  static IlaclamaTavsiyesi ilaclamaTavsiyesi(TarlaHavaOzeti hava, {DateTime? simdi}) {
    final saatler = hava.gelecekSaatler;
    if (saatler.isEmpty) return _ilaclamaGunluk(hava);

    final bugun = DateUtils.dateOnly(simdi ?? DateTime.now());

    // İlk uygun pencere: art arda en az [_minPencereSaat] uygun saat.
    var bas = 0;
    var uzunluk = 0;
    for (var i = 0; i < saatler.length; i++) {
      final uygun = _uygunsuzlukNedeni(saatler, i) == null;
      final ardisik = i > 0 && saatler[i].zaman.difference(saatler[i - 1].zaman).inHours == 1;
      if (uygun && uzunluk > 0 && ardisik) {
        uzunluk++;
        continue;
      }
      if (uzunluk >= _minPencereSaat) break; // pencere bitti
      bas = i;
      uzunluk = uygun ? 1 : 0;
    }

    if (uzunluk >= _minPencereSaat) {
      final p = saatler.sublist(bas, bas + uzunluk);
      final aralik = '${_saat(p.first.zaman)} – ${_saat(p.last.zaman.add(const Duration(hours: 1)))}';
      final maksRuzgar = p.map((s) => s.ruzgarKm).reduce((a, b) => a > b ? a : b);
      final sicakliklar = p.map((s) => s.sicaklik).toList()..sort();
      final ozet = 'Rüzgar en fazla ${maksRuzgar.toStringAsFixed(0)} km/s, sıcaklık '
          '${sicakliklar.first.toStringAsFixed(0)}–${sicakliklar.last.toStringAsFixed(0)}°C, yağış yok.';
      final gun = DateUtils.dateOnly(p.first.zaman);

      if (DateUtils.isSameDay(gun, bugun)) {
        return IlaclamaTavsiyesi(
          uygun: true,
          durumRozeti: 'BUGÜN UYGUN',
          baslik: 'Bugün $aralik arası ilaçlamaya uygun',
          detay: ozet,
          idealSaatler: 'Bugün $aralik',
        );
      }
      final gunAdi = DateUtils.isSameDay(gun, bugun.add(const Duration(days: 1))) ? 'Yarın' : '${gun.day}.${gun.month}';
      return IlaclamaTavsiyesi(
        uygun: false,
        durumRozeti: 'BUGÜN UYGUN DEĞİL',
        baslik: 'Bugün uygun saat yok — $gunAdi $aralik',
        detay: '${_bugunNedeni(saatler, bugun)} $gunAdi $aralik arası uygun: $ozet',
        idealSaatler: '$gunAdi $aralik',
      );
    }

    return IlaclamaTavsiyesi(
      uygun: false,
      durumRozeti: 'UYGUN DEĞİL',
      baslik: 'Önümüzdeki 2 günde ilaçlamaya uygun saat yok',
      detay: _bugunNedeni(saatler, bugun),
      idealSaatler: 'Tahmin yenilenince tekrar bakın',
    );
  }

  /// Bugünün kalan gündüz saatlerinde en sık görülen engel.
  static String _bugunNedeni(List<SaatlikHava> saatler, DateTime bugun) {
    final sayac = <String, int>{};
    for (var i = 0; i < saatler.length; i++) {
      if (!DateUtils.isSameDay(saatler[i].zaman, bugun)) continue;
      final n = _uygunsuzlukNedeni(saatler, i);
      if (n != null && n != 'gece') sayac[n] = (sayac[n] ?? 0) + 1;
    }
    if (sayac.isEmpty) return 'Bugün için gündüz saati kalmadı.';
    final enSik = sayac.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return switch (enSik) {
      'yağış' => 'Bugün yağış bekleniyor; ilaç yapraktan yıkanır.',
      'rüzgar' => 'Bugün rüzgar ${_maksRuzgarKm.toStringAsFixed(0)} km/s üzerinde; ilaç sürüklenir.',
      'sıcak' => 'Bugün sıcaklık ${_maksSicaklik.toStringAsFixed(0)}°C üzerinde; yaprak yanığı ve buharlaşma riski var.',
      _ => 'Bugün hava çok soğuk; ilaç etkisi düşer.',
    };
  }

  /// Saatlik tahmin yoksa (eski önbellek kaydı) günlük değerlerle kaba karar.
  static IlaclamaTavsiyesi _ilaclamaGunluk(TarlaHavaOzeti hava) {
    final ruzgar = hava.bugunRuzgarHiziKm;
    final yagis = hava.bugunYagisMm;
    final maxTemp = hava.bugunMaxSicaklik;

    if (yagis > 1.0) {
      return IlaclamaTavsiyesi(
        uygun: false,
        durumRozeti: 'YAĞMUR VAR 🌧️',
        baslik: 'Bugün İlaçlama Yapmayın! (Yağış Nedeniyle İlaç Yıkanır)',
        detay: 'Bugün tarlaya ${yagis.toStringAsFixed(1)} mm yağmur bekleniyor. Atacağınız ilaç yapraktan yıkanıp toprağa akar ve etkisini kaybeder.',
        idealSaatler: 'Yağışsız gün beklenmeli',
      );
    }

    if (ruzgar > 15.0) {
      return IlaclamaTavsiyesi(
        uygun: false,
        durumRozeti: 'RÜZGARLI 💨',
        baslik: 'Bugün İlaçlama Yapmayın! (Sürüklenme ve Buharlaşma Riski)',
        detay: 'Rüzgar hızı ${ruzgar.toStringAsFixed(0)} km/s seviyesinde. İlaç damlacıkları hedef yaprağa ulaşmadan havada savrulur.',
        idealSaatler: 'Rüzgarın 15 km/s altına ineceği gün',
      );
    }

    if (maxTemp > 28.0) {
      return IlaclamaTavsiyesi(
        uygun: true,
        durumRozeti: 'SABAH / AKŞAM UYGUN ⚠️',
        baslik: 'Gündüz Sıcağında Atmayın — Sabah Erken Saatleri Seçin',
        detay: 'Gündüz sıcaklığı ${maxTemp.toStringAsFixed(0)}°C üzerine çıkıyor. Öğlen saatlerinde fitotoksite (yaprak yanığı) riski vardır.',
        idealSaatler: '06:30 - 09:30 veya 17:30 - 20:00',
      );
    }

    return IlaclamaTavsiyesi(
      uygun: true,
      durumRozeti: 'MÜKEMMEL 🟢',
      baslik: 'Bugün İlaçlama İçin Hava Mükemmel!',
      detay: 'Rüzgar sakin (${ruzgar.toStringAsFixed(0)} km/s), yağış yok ve sıcaklık ideal (${maxTemp.toStringAsFixed(0)}°C). Pas, ot ve böcek ilaçları tam tutunur.',
      idealSaatler: '07:00 - 11:30 & 16:30 - 19:30',
    );
  }

  // ── 2. Gübreleme & Yağmur Uyarısı ────────────────────────────────────────
  static GubrelemeTavsiyesi _gubrelemeHesapla(TarlaHavaOzeti hava, ParselEntity parsel) {
    // Gelecek 7 günün tahmininde yağmur arayışı
    int gunIndex = -1;
    double beklenenYagis = 0.0;

    for (int i = 0; i < hava.gelecekYediGunTahmin.length; i++) {
      final g = hava.gelecekYediGunTahmin[i];
      if (g.yagisMm >= 6.0) {
        gunIndex = i;
        beklenenYagis = g.yagisMm;
        break;
      }
    }

    if (gunIndex != -1) {
      final gunMetni = gunIndex == 0 ? 'Bugün' : (gunIndex == 1 ? 'Yarın' : '$gunIndex gün sonra');
      return GubrelemeTavsiyesi(
        yagisAlarmiVar: true,
        kacGunSonra: gunIndex,
        beklenenYagisMm: beklenenYagis,
        baslik: '🌧️ $gunMetni ${beklenenYagis.toStringAsFixed(0)} mm Yağış Geliyor!',
        detay: 'Üst azot gübresini (Üre %46 veya Nitrat %26) yağıştan 1 gün önce tarlaya saçarsanız yağmurla birlikte kök bölgesine taşınır ve amonyak (gaz) kaybı belirgin şekilde azalır.',
      );
    }

    return GubrelemeTavsiyesi(
      yagisAlarmiVar: false,
      kacGunSonra: 0,
      beklenenYagisMm: 0.0,
      baslik: 'Önümüzdeki Günlerde Önemli Yağış Beklenmiyor',
      detay: parsel.sulu == false
          ? 'Toprakta yeterli nem yokken kuru toprağa üre gübresi atmaktan kaçının (gazlaşma ve buharlaşma kaybı yüksek olur). Kuru tarımda üst gübreyi yağış beklentisine göre zamanlayın.'
          : 'Toprakta yeterli nem yokken kuru toprağa üre gübresi atmaktan kaçının (gazlaşma ve buharlaşma kaybı yüksek olur). '
              '${parsel.sulu == true ? 'Gübreyi sulamadan hemen önce verin ya da damlama ile gübreleyin.' : 'Damlama gübreleme tercih edilebilir.'}',
    );
  }

  // ── 3. Toprak Tavı & Ekim Zamanlaması ────────────────────────────────────
  // Nem değeri: kök bölgesinde tahmini kullanılabilir su (%), 0 = solma noktası,
  // 100 = tarla kapasitesi (Open-Meteo model toprak nemi + toprak türü sabitleri).
  static EkimTavTavsiyesi _ekimTaviHesapla(TarlaHavaOzeti hava, ParselEntity parsel) {
    final nem = hava.guncelToprakNemiYuzde;
    final minTemp = hava.bugunMinSicaklik;

    if (minTemp <= 0.0) {
      return EkimTavTavsiyesi(
        toprakTavinda: false,
        durum: 'DON RİSKİ ❄️',
        baslik: 'Gece Don Riski Mevcut (Ekim Önerilmez)',
        detay: 'Gece sıcaklığı ${minTemp.toStringAsFixed(0)}°C\'ye düşüyor. Tohum çimlenmesi durur veya tohum çürür.',
      );
    }

    if (nem == null) {
      return const EkimTavTavsiyesi(
        toprakTavinda: false,
        durum: 'VERİ YOK ❔',
        baslik: 'Toprak Nemi Verisi Alınamadı',
        detay: 'Bu konum için model toprak nemi verisi yok. Tavı elle kontrol edin: avuçta sıkılan toprak top olup parmakla kolayca dağılıyorsa tavdadır.',
      );
    }

    if (hava.toprakDoygun || nem >= 95.0) {
      return EkimTavTavsiyesi(
        toprakTavinda: false,
        durum: 'ÇAMUR / DOYGUN 💧',
        baslik: 'Toprak Aşırı Islak (Tavda Değil)',
        detay: 'Toprak tarla kapasitesinin üzerinde nemli (kullanılabilir su %${nem.toStringAsFixed(0)}). Traktör taban sıkışması yapar; toprağın tavını bulması beklenmeli.',
      );
    }

    if (nem < 40.0) {
      return EkimTavTavsiyesi(
        toprakTavinda: false,
        durum: 'KURU 🏜️',
        baslik: 'Toprak Kuru (Tav Yetersiz)',
        detay: parsel.sulu == false
            ? 'Kullanılabilir su %${nem.toStringAsFixed(0)}. Kuru tarımda kuruya ekilen tohumun çıkışı yağmura kalır; mümkünse yağış sonrası tavı bekleyin ya da tohumu nemli katmana (derine) bırakın.'
            : 'Kullanılabilir su %${nem.toStringAsFixed(0)}. Kuruya ekim yapılacaksa ekim sonrası can suyu verilmesi gerekir.',
      );
    }

    return EkimTavTavsiyesi(
      toprakTavinda: true,
      durum: 'TAVDA 🌱',
      baslik: 'Toprak Tavında (Ekime Uygun)',
      detay: 'Kullanılabilir su %${nem.toStringAsFixed(0)} ve gece sıcaklığı donun üzerinde.',
    );
  }

  static String _ec(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Sulama suyu tuz sınıfı ve bu suyla toprağın ulaşacağı tuzluluğun ekili ürüne etkisi.
  static String _suTuzNotu(double ecw, String urun, double? esik) {
    final sinif = SuTuzSinifi.icin(ecw);
    final toprak = beklenenToprakEc(ecw);
    final etki = esik == null
        ? ''
        : toprak > esik
            ? ' Bu suyla toprak zamanla ~${_ec(toprak)} dS/m\'ye tuzlanır; $urun için eşik ${_ec(esik)} — verim düşer, yıkama suyu ve drenaj şart.'
            : ' $urun bu tuzluluğa dayanır (eşik ${_ec(esik)}).';
    return 'Sulama suyu ${_ec(ecw)} dS/m: ${sinif.ad} (${sinif.aciklama}).$etki';
  }

  // ── 4. Sulama İhtiyacı ──────────────────────────────────────────────────
  // Klasik kural: kullanılabilir suyun yarısı tükendiğinde (%50) sulama planlanır,
  // %30'un altında bitki su stresine girer.
  static SulamaTavsiyesi _sulamaHesapla(TarlaHavaOzeti hava, ParselEntity parsel) {
    final nem = hava.guncelToprakNemiYuzde;
    final acik = hava.suAcigiTonDonum ?? 0.0;

    if (nem == null) {
      return const SulamaTavsiyesi(
        sulamaGerekli: false,
        aciliyet: 'Bilinmiyor',
        baslik: 'Toprak Nemi Verisi Yok',
        detay: 'Sulama kararı için toprak nemi verisi alınamadı. Tarlada 20-30 cm derinlikte toprağı elle kontrol edin.',
        donumBasiTon: 0.0,
      );
    }

    // Önümüzdeki 3 günde anlamlı yağış bekleniyorsa sulamayı ertele önerisi.
    final yakinYagis = hava.gelecekYediGunTahmin.take(3).fold<double>(0, (s, g) => s + g.yagisMm);

    // Kuru tarla: sulama önerilmez; nemi korumaya yönelik öneri verilir.
    if (parsel.sulu == false) {
      if (nem >= 50.0) {
        return SulamaTavsiyesi(
          sulamaGerekli: false,
          aciliyet: 'Yeterli',
          baslik: 'Toprak Nemi Yeterli (Kuru Tarım)',
          detay: 'Kök bölgesinde kullanılabilir su %${nem.toStringAsFixed(0)}.',
          donumBasiTon: 0.0,
        );
      }
      return SulamaTavsiyesi(
        sulamaGerekli: false,
        aciliyet: nem < 30.0 ? 'Acil' : 'Normal',
        baslik: nem < 30.0 ? 'Su Stresi (Kuru Tarım)' : 'Nem Azalıyor (Kuru Tarım)',
        detay: 'Kullanılabilir su %${nem.toStringAsFixed(0)}. Tarla sulanmadığı için nemi korumak önemli: '
            'kaymak bağlamışsa yüzeysel çapa yapın, yabancı otu temizleyin (su çalar), azotlu üst gübreyi yağış beklentisine erteleyin.'
            '${yakinYagis >= 10 ? ' Önümüzdeki 3 günde ${yakinYagis.toStringAsFixed(0)} mm yağış bekleniyor.' : ''}',
        donumBasiTon: 0.0,
      );
    }

    // Toprağa girmesi gereken net su; verilecek (brüt) su yöntemin kayıplarıyla artar.
    final yontem = parsel.sulu == true ? parsel.sulamaYontemi : null;
    // Tuzlu suyla sulamada tuzu kök bölgesinden atmak için fazladan yıkama suyu gerekir (FAO 29).
    final suEc = parsel.sulu == true ? parsel.suEc : null;
    final tolerans = EcoCropEngine.tuzToleransi(parsel.ekilmisUrun);
    final yikama = suEc == null || tolerans == null
        ? 0.0
        : yikamaIhtiyaci(suEc, tolerans.esik, tolerans.egim, yontem: yontem);
    final kayiplarla = brutSu(acik, yontem);
    final brut = kayiplarla / (1 - yikama);
    final yikamaMetni = yikama >= 0.05
        ? '; suyun tuzu için %${(yikama * 100).toStringAsFixed(0)} yıkama payıyla toplam dönüme ~${brut.toStringAsFixed(0)} ton'
        : '';
    final miktar = (yontem == null
            ? 'dönüme yaklaşık ${acik.toStringAsFixed(0)} ton su gerekir'
            : 'toprağa dönüme ~${acik.toStringAsFixed(0)} ton su girmeli; ${yontem.ad.toLowerCase()} sulamada '
                'kayıplarla (randıman %${(yontem.randiman * 100).toStringAsFixed(0)}) dönüme ~${kayiplarla.toStringAsFixed(0)} ton verin') +
        yikamaMetni;
    final notlar = parsel.sulu == true
        ? [
            if (suEc != null) _suTuzNotu(suEc, parsel.ekilmisUrun, tolerans?.esik),
            ...sulamaNotlari(yontem, parsel.suKaynagi, ruzgarKm: hava.bugunRuzgarHiziKm, maksSicaklik: hava.bugunMaxSicaklik),
          ]
        : const <String>[];
    final notMetni = notlar.isEmpty ? '' : '\n• ${notlar.join('\n• ')}';

    if (nem < 30.0) {
      return SulamaTavsiyesi(
        sulamaGerekli: true,
        aciliyet: 'Acil',
        baslik: 'Su Stresi (Sulama Başlatın)',
        detay: 'Kök bölgesinde kullanılabilir su %${nem.toStringAsFixed(0)}. Tarla kapasitesine getirmek için $miktar.'
            '${yakinYagis >= 10 ? ' Önümüzdeki 3 günde ${yakinYagis.toStringAsFixed(0)} mm yağış bekleniyor; miktarı buna göre azaltabilirsiniz.' : ''}'
            '$notMetni',
        donumBasiTon: brut,
      );
    }

    if (nem < 50.0) {
      return SulamaTavsiyesi(
        sulamaGerekli: true,
        aciliyet: 'Normal',
        baslik: yakinYagis >= 10 ? 'Nem Azalıyor — Yağış Bekleniyor' : 'Nem Azalıyor (Sulama Planlayın)',
        detay: yakinYagis >= 10
            ? 'Kullanılabilir su %${nem.toStringAsFixed(0)}, ancak önümüzdeki 3 günde ${yakinYagis.toStringAsFixed(0)} mm yağış bekleniyor. Yağıştan sonra tekrar değerlendirin.'
            : 'Kullanılabilir su %${nem.toStringAsFixed(0)}. Önümüzdeki günlerde sulama yapılması verimi korur: $miktar.$notMetni',
        donumBasiTon: brut,
      );
    }

    return SulamaTavsiyesi(
      sulamaGerekli: false,
      aciliyet: 'Yeterli',
      baslik: 'Toprak Nemi Yeterli',
      detay: 'Kök bölgesinde kullanılabilir su %${nem.toStringAsFixed(0)}; sulamaya gerek yok.'
          // Suyun tuz uyarısı nem yeterliyken de görünsün (uzun vadeli risk).
          '${suEc != null && SuTuzSinifi.icin(suEc) != SuTuzSinifi.sorunsuz ? '\n• ${notlar.first}' : ''}',
      donumBasiTon: 0.0,
    );
  }
}
