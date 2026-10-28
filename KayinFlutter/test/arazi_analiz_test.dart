import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/ecocrop_engine.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/fenoloji_engine.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';

void main() {
  group('Replantio EcoCrop Engine Testleri', () {
    test('İç Anadolu / Trakya buğday için A skoru ve rekolte üretmeli', () {
      final sonuclar = EcoCropEngine.analiziCalistir(
        ortalamaSicaklik: 16.0,
        minSicaklik: -5.0,
        maxSicaklik: 30.0,
        yillikYagisMm: 550.0,
        toprakTuru: 'Tinli',
        alanDonum: 50.0, // 50 dönüm
      );

      expect(sonuclar, isNotEmpty);
      final bugday = sonuclar.firstWhere((s) => s.urunAdi == 'Buğday');
      expect(bugday.derece, anyOf('A', 'B'));
      expect(bugday.uygunlukSkoru, greaterThan(70.0));
      expect(bugday.toplamTahminiHasatKg, greaterThan(15000.0)); // 50 dönümde ~20 ton civarı
      expect(bugday.toplamTahminiCiroTL, greaterThan(150000.0));
    });

    test('Düşük sıcaklıkta pamuk sınırlayıcı don uyarısı almalı', () {
      final sonuclar = EcoCropEngine.analiziCalistir(
        ortalamaSicaklik: 8.0,
        minSicaklik: -10.0,
        maxSicaklik: 20.0,
        yillikYagisMm: 400.0,
        toprakTuru: 'Killi',
        alanDonum: 10.0,
      );

      final pamuk = sonuclar.firstWhere((s) => s.urunAdi == 'Pamuk');
      expect(pamuk.derece, anyOf('C', 'D'));
      expect(pamuk.sinirlayiciFaktorler, isNotEmpty);
    });

    test('Türkçe toprak adı ("Tınlı") ASCII profil adıyla ("Tinli") eşleşir', () {
      final sonuclar = EcoCropEngine.analiziCalistir(
        ortalamaSicaklik: 16.0,
        minSicaklik: -5.0,
        maxSicaklik: 30.0,
        yillikYagisMm: 550.0,
        toprakTuru: 'Tınlı',
        alanDonum: 10.0,
      );
      final bugday = sonuclar.firstWhere((s) => s.urunAdi == 'Buğday');
      expect(bugday.sinirlayiciFaktorler.any((f) => f.contains('toprak')), isFalse);
    });

    test('Yazlık ürüne (mısır) kış donu cezası verilmez, sıcak dönem kullanılır', () {
      final sonuclar = EcoCropEngine.analiziCalistir(
        ortalamaSicaklik: 15.0,
        sicakDonemSicaklik: 23.0,
        minSicaklik: -15.0,
        maxSicaklik: 36.0,
        yillikYagisMm: 400.0,
        toprakTuru: 'Tınlı',
        alanDonum: 10.0,
      );
      final misir = sonuclar.firstWhere((s) => s.urunAdi == 'Mısır');
      expect(misir.sinirlayiciFaktorler.any((f) => f.contains('don')), isFalse);
      expect(misir.sinirlayiciFaktorler.any((f) => f.contains('sulama')), isTrue);
    });

    List<MahsulUygunlukSonuc> calistir({double? ph, double? ec}) => EcoCropEngine.analiziCalistir(
          ortalamaSicaklik: 16.0,
          sicakDonemSicaklik: 24.0,
          minSicaklik: -5.0,
          maxSicaklik: 34.0,
          yillikYagisMm: 600.0,
          toprakTuru: 'Tınlı',
          alanDonum: 10.0,
          ph: ph,
          tuzlulukEc: ec,
        );
    MahsulUygunlukSonuc urun(List<MahsulUygunlukSonuc> l, String ad) => l.firstWhere((s) => s.urunAdi == ad);

    test('Analiz yoksa ya da değerler uygunsa skor değişmez', () {
      final yok = calistir();
      final iyi = calistir(ph: 7.0, ec: 1.0);
      for (final ad in ['Buğday', 'Mısır', 'Domates']) {
        expect(urun(iyi, ad).uygunlukSkoru, urun(yok, ad).uygunlukSkoru, reason: ad);
        expect(urun(iyi, ad).sinirlayiciFaktorler.any((f) => f.contains('pH') || f.contains('Tuzluluk')), isFalse);
      }
    });

    test('Tuzlu tarlada mısır düşer, tuza dayanıklı arpa etkilenmez', () {
      final yok = calistir();
      final tuzlu = calistir(ec: 6.0);
      expect(urun(tuzlu, 'Arpa').uygunlukSkoru, urun(yok, 'Arpa').uygunlukSkoru);
      // Mısır: eşik 1,7, eğim %12 → %51,6 kayıp
      expect(urun(tuzlu, 'Mısır').uygunlukSkoru, closeTo(urun(yok, 'Mısır').uygunlukSkoru * 0.484, 0.01));
      expect(urun(tuzlu, 'Mısır').sinirlayiciFaktorler.any((f) => f.contains('Tuzluluk')), isTrue);
      expect(urun(tuzlu, 'Mısır').tahminiVerimKgDonum, lessThan(urun(yok, 'Mısır').tahminiVerimKgDonum));
    });

    test('Yüksek pH soyayı cezalandırır, arpayı cezalandırmaz; ceza en fazla %30', () {
      final yok = calistir();
      final alkali = calistir(ph: 8.2);
      expect(urun(alkali, 'Arpa').uygunlukSkoru, urun(yok, 'Arpa').uygunlukSkoru);
      expect(urun(alkali, 'Soya').uygunlukSkoru, lessThan(urun(yok, 'Soya').uygunlukSkoru));
      expect(urun(alkali, 'Soya').sinirlayiciFaktorler.any((f) => f.contains('pH 8,2') && f.contains('yüksek')), isTrue);
      final asiri = calistir(ph: 11);
      expect(urun(asiri, 'Soya').uygunlukSkoru, closeTo(urun(yok, 'Soya').uygunlukSkoru * 0.7, 0.01));
    });

    test('Tarlaya seçilebilen her ürünün uygunluk profili ve kendi gelişim takvimi var', () {
      final adlar = calistir().map((s) => s.urunAdi).toSet();
      for (final u in ParselEntity.urunSecenekleri) {
        expect(adlar, contains(u), reason: u);
        expect(FenolojiEngine.hesapla(ekilmisUrun: u, ekimTarihi: DateTime.now().subtract(const Duration(days: 30))).evreAciklama,
            isNot('Standart ürün gelişim takvimi.'),
            reason: u);
      }
      expect(adlar.length, ParselEntity.urunSecenekleri.length);
      expect(FenolojiEngine.cokYillik('Yonca'), isTrue);
    });

    test('Profil eşikleri sıralı (min ≤ optimum ≤ max)', () {
      for (final p in EcoCropEngine.urunProfilleri) {
        expect(p.tMin <= p.tOptMin && p.tOptMin <= p.tOptMax && p.tOptMax <= p.tMax, isTrue, reason: '${p.ad} sıcaklık');
        expect(p.yagisMin <= p.yagisOptMin && p.yagisOptMin <= p.yagisOptMax && p.yagisOptMax <= p.yagisMax, isTrue,
            reason: '${p.ad} yağış');
        expect(p.phMin < p.phOptMin && p.phOptMin <= p.phOptMax && p.phOptMax < p.phMax, isTrue, reason: '${p.ad} pH');
        expect(p.tuzEsigi > 0 && p.tuzEgimi > 0, isTrue, reason: '${p.ad} tuz');
      }
    });

    test('Tuzlu tarlada şeker pancarı uygun kalır, fasulye ve nohut düşer', () {
      final tuzlu = calistir(ec: 6.0);
      final yok = calistir();
      expect(urun(tuzlu, 'Şeker Pancarı').uygunlukSkoru, urun(yok, 'Şeker Pancarı').uygunlukSkoru);
      expect(urun(tuzlu, 'Fasulye').uygunlukSkoru, lessThan(urun(yok, 'Fasulye').uygunlukSkoru * 0.2));
      expect(urun(tuzlu, 'Nohut').uygunlukSkoru, lessThan(urun(yok, 'Nohut').uygunlukSkoru * 0.5));
    });

    test('Asit toprak yoncayı cezalandırır; kurak İç Anadolu\'da nohut-mercimek iyi sonuç verir', () {
      expect(urun(calistir(ph: 5.5), 'Yonca').sinirlayiciFaktorler.any((f) => f.contains('düşük')), isTrue);
      final kurak = EcoCropEngine.analiziCalistir(
        ortalamaSicaklik: 12.0,
        sicakDonemSicaklik: 21.0,
        minSicaklik: -9.0,
        maxSicaklik: 33.0,
        yillikYagisMm: 330.0,
        toprakTuru: 'Kireçli',
        alanDonum: 10.0,
      );
      expect(urun(kurak, 'Nohut').uygunlukSkoru, greaterThan(urun(kurak, 'Mısır').uygunlukSkoru));
      expect(urun(kurak, 'Mercimek').uygunlukSkoru, greaterThan(urun(kurak, 'Fasulye').uygunlukSkoru));
    });

    test('Tuz verimi: eşiğe kadar kayıp yok, en az %10 kalır', () {
      expect(EcoCropEngine.tuzVerimi(3, esik: 6, egim: 7.1), 1.0);
      expect(EcoCropEngine.tuzVerimi(8, esik: 6, egim: 7.1), closeTo(0.858, 1e-9));
      expect(EcoCropEngine.tuzVerimi(50, esik: 1.7, egim: 12), 0.1);
    });
  });

  group('Fenoloji Engine Testleri', () {
    test('Zeytin/Üzüm için hasada kalan gün bir yıldan az ve tutarlı', () {
      for (final urun in ['Zeytin', 'Üzüm']) {
        final evre = FenolojiEngine.hesapla(ekilmisUrun: urun);
        expect(evre.kalanGun, inInclusiveRange(0, 365), reason: urun);
        expect(FenolojiEngine.ekimTarihiGerekli(urun), isFalse);
      }
      expect(FenolojiEngine.ekimTarihiGerekli('Buğday'), isTrue);
    });

    test('Buğday 35. günde Kardeşlenme evresinde ve Üre gübre tavsiyesi vermeli', () {
      final now = DateTime.now();
      final ekimTarihi = now.subtract(const Duration(days: 35));

      final evre = FenolojiEngine.hesapla(
        ekilmisUrun: 'Bugday',
        ekimTarihi: ekimTarihi,
      );

      expect(evre.evreAdi, contains('Kardeşlenme'));
      expect(evre.gecenGun, equals(35));
      expect(evre.yapilacakIsler.any((i) => i.baslik.contains('Üre') || i.baslik.contains('Gübreleme')), isTrue);
    });

    test('Mısır 50. günde Tepe Püskülü ve Azot tavsiyesi vermeli', () {
      final now = DateTime.now();
      final ekimTarihi = now.subtract(const Duration(days: 50));

      final evre = FenolojiEngine.hesapla(
        ekilmisUrun: 'Misir',
        ekimTarihi: ekimTarihi,
      );

      expect(evre.evreAdi, anyOf(contains('Tepe Püskülü'), contains('Büyüme')));
      expect(evre.yapilacakIsler.any((i) => i.baslik.contains('Azot') || i.baslik.contains('Boğaz')), isTrue);
    });
  });
}
