import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/services/hava_durumu_servisi.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/ecocrop_engine.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/zirai_karar_destek_engine.dart';
import 'package:kayin_flutter/features/parsel_harita/data/models/parsel_model.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/sulama.dart';

final _t = DateTime.utc(2026, 1, 1);

ParselEntity _parsel(bool? sulu) => ParselEntity(
      id: 'p',
      ad: 'Tarla',
      sulu: sulu,
      konum: '',
      poligonNoktalar: const [],
      alanDonumCinsinden: 10,
      merkezLat: 0,
      merkezLng: 0,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
    );

TarlaHavaOzeti _hava(double nem) => TarlaHavaOzeti(
      guncelToprakNemiYuzde: nem,
      suAcigiTonDonum: 40,
      bugunYagisMm: 0,
      bugunMaxSicaklik: 25,
      bugunMinSicaklik: 10,
      bugunRuzgarHiziKm: 5,
      sonYediGun: const [],
      gelecekYediGunTahmin: const [],
    );

/// Kurak İç Anadolu (330 mm).
List<MahsulUygunlukSonuc> _kurak(bool? sulu) => EcoCropEngine.analiziCalistir(
      ortalamaSicaklik: 12.0,
      sicakDonemSicaklik: 22.0,
      minSicaklik: -9.0,
      maxSicaklik: 34.0,
      yillikYagisMm: 330.0,
      toprakTuru: 'Tınlı',
      alanDonum: 10.0,
      sulu: sulu,
    );

MahsulUygunlukSonuc _urun(List<MahsulUygunlukSonuc> l, String ad) => l.firstWhere((s) => s.urunAdi == ad);

void main() {
  group('Uygunluk', () {
    test('Sulu tarlada yağış açığı kapanır: mısır ve patates yükselir, uyarı kalkar', () {
      final belirsiz = _kurak(null), sulu = _kurak(true);
      for (final ad in ['Mısır', 'Patates', 'Şeker Pancarı']) {
        expect(_urun(sulu, ad).uygunlukSkoru, greaterThan(_urun(belirsiz, ad).uygunlukSkoru), reason: ad);
        expect(_urun(sulu, ad).sinirlayiciFaktorler.any((f) => f.contains('yağış') || f.contains('Yağış')), isFalse,
            reason: ad);
      }
    });

    test('Kuru tarlada sulama isteyen ürün belirgin düşer; kuruya uygun ürünün skoru değişmez', () {
      final belirsiz = _kurak(null), kuru = _kurak(false);
      final misir = _urun(kuru, 'Mısır');
      expect(misir.uygunlukSkoru, closeTo(_urun(belirsiz, 'Mısır').uygunlukSkoru * 0.35, 0.01));
      expect(misir.sinirlayiciFaktorler, contains('Kuru tarımda yetiştirilmez — bu ürün yazın sulama ister'));
      expect(_urun(belirsiz, 'Mısır').sinirlayiciFaktorler, contains('Doğal yağış yetersiz — sulama gerekir'));
      expect(_urun(kuru, 'Nohut').uygunlukSkoru, _urun(belirsiz, 'Nohut').uygunlukSkoru);
      // Arpa 330 mm'de yetişir (alt sınır 280), yalnızca verim uyarısı alır.
      final arpa = _urun(kuru, 'Arpa').sinirlayiciFaktorler;
      expect(arpa, contains('Kuru tarımda yağış yetersiz — verim düşük kalır'));
      expect(arpa.any((f) => f.contains('yetişmez')), isFalse);
    });

    test('Kuru tarlada nohut mısırın önünde, sulu tarlada mısır öne geçer', () {
      expect(_urun(_kurak(false), 'Nohut').uygunlukSkoru, greaterThan(_urun(_kurak(false), 'Mısır').uygunlukSkoru));
      expect(_urun(_kurak(true), 'Mısır').uygunlukSkoru, greaterThan(_urun(_kurak(false), 'Mısır').uygunlukSkoru));
    });
  });

  test('Yağışlı bölgede bile (550 mm) kuru tarlada şeker pancarı "A" çıkmaz', () {
    final kuru = EcoCropEngine.analiziCalistir(
      ortalamaSicaklik: 15.6,
      sicakDonemSicaklik: 22.8,
      minSicaklik: -9.1,
      maxSicaklik: 34.0,
      yillikYagisMm: 554.0,
      toprakTuru: 'Tınlı',
      alanDonum: 10.0,
      sulu: false,
    );
    expect(_urun(kuru, 'Şeker Pancarı').derece, 'D');
    expect(_urun(kuru, 'Buğday').derece, 'A');
  });

  group('Öneriler', () {
    test('Kuru tarlaya sulama önerilmez, nem koruma önerilir', () {
      final s = ZiraiKararDestekEngine.kararlariUret(parsel: _parsel(false), hava: _hava(20)).sulama;
      expect(s.sulamaGerekli, isFalse);
      expect(s.donumBasiTon, 0);
      expect(s.baslik, contains('Kuru Tarım'));
      expect(s.detay, contains('çapa'));
    });

    test('Sulu ve belirtilmemiş tarlada su stresinde sulama önerilir', () {
      for (final sulu in [true, null]) {
        final s = ZiraiKararDestekEngine.kararlariUret(parsel: _parsel(sulu), hava: _hava(20)).sulama;
        expect(s.sulamaGerekli, isTrue, reason: '$sulu');
        expect(s.donumBasiTon, 40);
      }
    });

    test('Kuruya ekimde can suyu yerine tav beklenir', () {
      expect(ZiraiKararDestekEngine.kararlariUret(parsel: _parsel(false), hava: _hava(30)).ekimTavi.detay,
          isNot(contains('can suyu')));
      expect(ZiraiKararDestekEngine.kararlariUret(parsel: _parsel(true), hava: _hava(30)).ekimTavi.detay,
          contains('can suyu'));
    });
  });

  group('Sulama yöntemi', () {
    ParselEntity sulu(SulamaYontemi? y, {SuKaynagi? k}) => ParselEntity(
          id: 'p',
          ad: 'Tarla',
          sulu: true,
          sulamaYontemi: y,
          suKaynagi: k,
          konum: '',
          poligonNoktalar: const [],
          alanDonumCinsinden: 10,
          merkezLat: 0,
          merkezLng: 0,
          createdAtUtc: _t,
          lastModifiedUtc: _t,
        );
    SulamaTavsiyesi tavsiye(ParselEntity p, {double ruzgar = 5}) => ZiraiKararDestekEngine.kararlariUret(
          parsel: p,
          hava: TarlaHavaOzeti(
            guncelToprakNemiYuzde: 20,
            suAcigiTonDonum: 45,
            bugunYagisMm: 0,
            bugunMaxSicaklik: 25,
            bugunMinSicaklik: 10,
            bugunRuzgarHiziKm: ruzgar,
            sonYediGun: const [],
            gelecekYediGunTahmin: const [],
          ),
        ).sulama;

    test('Brüt su = net / randıman: damla < yağmurlama < salma; yöntem yoksa net', () {
      expect(tavsiye(sulu(null)).donumBasiTon, 45);
      expect(tavsiye(sulu(SulamaYontemi.damla)).donumBasiTon, closeTo(50, 0.01));
      expect(tavsiye(sulu(SulamaYontemi.yagmurlama)).donumBasiTon, closeTo(60, 0.01));
      expect(tavsiye(sulu(SulamaYontemi.salma)).donumBasiTon, closeTo(81.8, 0.1));
      expect(tavsiye(sulu(SulamaYontemi.salma)).detay, contains('~82 ton verin'));
    });

    test('Yöntem ve kaynağa göre notlar: rüzgarlı günde yağmurlama, kuyuda tuz ölçümü', () {
      expect(tavsiye(sulu(SulamaYontemi.yagmurlama), ruzgar: 22).detay, contains('su savrulur'));
      expect(tavsiye(sulu(SulamaYontemi.damla)).detay, contains('2-3 güne bölerek'));
      expect(tavsiye(sulu(SulamaYontemi.salma, k: SuKaynagi.kuyu)).detay, contains('tuzluluğunu (EC)'));
      expect(tavsiye(sulu(null, k: SuKaynagi.kanal)).detay, contains('sulama birliği'));
    });

    test('Kuru tarlada kayıtlı yöntem kullanılmaz', () {
      final p = sulu(SulamaYontemi.salma).copyWith(sulu: false);
      expect(tavsiye(p).sulamaGerekli, isFalse);
      expect(tavsiye(p).donumBasiTon, 0);
    });

    test('Model yöntem ve kaynağı saklar; bilinmeyen kod null olur', () {
      final row = ParselModel.toRow(sulu(SulamaYontemi.damla, k: SuKaynagi.golet));
      expect(row['sulama_yontemi'], 'Damla');
      expect(row['su_kaynagi'], 'Golet');
      final geri = ParselModel.fromRow(row);
      expect(geri.sulamaYontemi, SulamaYontemi.damla);
      expect(geri.suKaynagi, SuKaynagi.golet);
      expect(geri.suluMetni, 'Sulu (Damla)');
      expect(ParselModel.fromRow({...row, 'sulama_yontemi': 'Bilinmeyen'}).sulamaYontemi, isNull);
    });
  });

  group('Sulama suyu tuzluluğu', () {
    ParselEntity misir({double? ec, SulamaYontemi? y = SulamaYontemi.salma, String urun = 'Mısır'}) => ParselEntity(
          id: 'p',
          ad: 'Tarla',
          ekilmisUrun: urun,
          sulu: true,
          sulamaYontemi: y,
          suEc: ec,
          konum: '',
          poligonNoktalar: const [],
          alanDonumCinsinden: 10,
          merkezLat: 0,
          merkezLng: 0,
          createdAtUtc: _t,
          lastModifiedUtc: _t,
        );
    SulamaTavsiyesi tavsiye(ParselEntity p, {double nem = 20}) => ZiraiKararDestekEngine.kararlariUret(
          parsel: p,
          hava: TarlaHavaOzeti(
            guncelToprakNemiYuzde: nem,
            suAcigiTonDonum: 44,
            bugunYagisMm: 0,
            bugunMaxSicaklik: 25,
            bugunMinSicaklik: 10,
            bugunRuzgarHiziKm: 5,
            sonYediGun: const [],
            gelecekYediGunTahmin: const [],
          ),
        ).sulama;

    test('Su sınıfı (FAO 29) ve µS/cm çevirisi', () {
      expect(SuTuzSinifi.icin(0.5), SuTuzSinifi.sorunsuz);
      expect(SuTuzSinifi.icin(1.8), SuTuzSinifi.hafif);
      expect(SuTuzSinifi.icin(3.5), SuTuzSinifi.ciddi);
      expect(suEcDuzelt(850), closeTo(0.85, 1e-9));
      expect(suEcDuzelt(2.4), 2.4);
    });

    test('Yıkama ihtiyacı: mısır (eşik 1,7) için 2 dS/m su; damlada daha az', () {
      // Salma: 2 / (5·1,7 − 2) = 0,308
      expect(yikamaIhtiyaci(2, 1.7, 12), closeTo(0.308, 0.001));
      // Damla: 2 / (2 · (1,7 + 100/12)) = 0,0997
      expect(yikamaIhtiyaci(2, 1.7, 12, yontem: SulamaYontemi.damla), closeTo(0.0997, 0.001));
      expect(yikamaIhtiyaci(0, 1.7, 12), 0);
      expect(yikamaIhtiyaci(10, 1.7, 12), 0.5); // çok tuzlu: üst sınır
    });

    test('Tuzlu suda verilecek su yıkama payıyla artar ve uyarı yazılır', () {
      final temiz = tavsiye(misir());
      final tuzlu = tavsiye(misir(ec: 2));
      // 44 / 0,55 = 80; yıkama ile 80 / (1 − 0,308) ≈ 115,6
      expect(temiz.donumBasiTon, closeTo(80, 0.1));
      expect(tuzlu.donumBasiTon, closeTo(115.6, 0.5));
      expect(tuzlu.detay, contains('yıkama payıyla'));
      expect(tuzlu.detay, contains('Hafif-orta tuzlu'));
      expect(tuzlu.detay, contains('3,0 dS/m\'ye tuzlanır'));
    });

    test('Tuza dayanıklı ürün (arpa) aynı suya dayanır; nem yeterliyken de tuz uyarısı görünür', () {
      expect(tavsiye(misir(ec: 2, urun: 'Arpa')).detay, contains('Arpa bu tuzluluğa dayanır'));
      final yeterli = tavsiye(misir(ec: 3.5), nem: 70);
      expect(yeterli.sulamaGerekli, isFalse);
      expect(yeterli.detay, contains('Çok tuzlu'));
    });

    test('Uygunluk: tuzlu su toprağın beklenen tuzluluğunu yükseltir, mısır düşer, arpa etkilenmez', () {
      List<MahsulUygunlukSonuc> calistir(double? suEc, {double? toprakEc}) => EcoCropEngine.analiziCalistir(
            ortalamaSicaklik: 16,
            sicakDonemSicaklik: 24,
            minSicaklik: -5,
            maxSicaklik: 34,
            yillikYagisMm: 550,
            toprakTuru: 'Tınlı',
            alanDonum: 10,
            sulu: true,
            suEc: suEc,
            tuzlulukEc: toprakEc,
          );
      final temiz = calistir(null), tuzlu = calistir(2.0);
      final m = _urun(tuzlu, 'Mısır');
      // Beklenen ECe 3,0 → mısır (1,7 / %12) ~%15,6 kayıp
      expect(m.uygunlukSkoru, closeTo(_urun(temiz, 'Mısır').uygunlukSkoru * 0.844, 0.05));
      expect(m.sinirlayiciFaktorler, contains(startsWith('Sulama suyu (2,0 dS/m) toprağı zamanla ~3,0')));
      expect(_urun(tuzlu, 'Arpa').uygunlukSkoru, _urun(temiz, 'Arpa').uygunlukSkoru);
      // Toprak analizi sudan beklenenden kötüyse toprak geçerli, mesaj toprağı söyler.
      final toprakKotu = _urun(calistir(1.0, toprakEc: 5), 'Mısır');
      expect(toprakKotu.sinirlayiciFaktorler, contains(startsWith('Tuzluluk (5,0 dS/m)')));
    });

    test('copyWith: EC verilmezse korunur, null verilirse silinir', () {
      final p = misir(ec: 2);
      expect(p.copyWith(ad: 'x').suEc, 2);
      expect(p.copyWith(suEc: 1.1).suEc, 1.1);
      expect(p.copyWith(suEc: null).suEc, isNull);
    });

    test('Model suEc saklar', () {
      expect(ParselModel.fromRow(ParselModel.toRow(misir(ec: 1.25))).suEc, 1.25);
      expect(ParselModel.fromRow(ParselModel.toRow(misir())).suEc, isNull);
    });
  });

  test('Model: sulu 1/0/NULL olarak saklanır ve geri okunur', () {
    for (final sulu in [true, false, null]) {
      final row = ParselModel.toRow(_parsel(sulu));
      expect(row['sulu'], switch (sulu) { true => 1, false => 0, null => null });
      expect(ParselModel.fromRow(row).sulu, sulu);
    }
    expect(_parsel(false).copyWith(ad: 'x').sulu, isFalse);
  });
}
