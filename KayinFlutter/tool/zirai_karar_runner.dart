// Elle çalıştırılan deneme betiği: dart run tool/zirai_karar_runner.dart
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/services/hava_durumu_servisi.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/sezonluk_iklim_motoru.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/zirai_karar_destek_engine.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';

void main() {
  test('ZiraiKararDestekEngine - Rüzgar, Yağış ve Gübreleme Kararları', () {
    final now = DateTime.now();
    final parsel = ParselEntity(
      id: 'parsel-1',
      ad: 'Polatlı Ana Tarla',
      ekilmisUrun: 'Buğday',
      toprakTuru: 'Tınlı',
      ekimTarihi: now.subtract(const Duration(days: 40)),
      konum: 'Polatlı',
      poligonNoktalar: const [],
      alanDonumCinsinden: 120.0,
      merkezLat: 39.5835,
      merkezLng: 32.1438,
      createdAtUtc: now,
      lastModifiedUtc: now,
    );

    final hava = TarlaHavaOzeti(
      ekimdenBuguneToplamYagisMm: 145.0,
      ekimdenBeriGecenGun: 40,
      guncelToprakNemiYuzde: 56.0,
      bugunYagisMm: 0.0,
      bugunMaxSicaklik: 21.0,
      bugunMinSicaklik: 9.0,
      bugunRuzgarHiziKm: 8.5,
      sonYediGun: const [],
      gelecekYediGunTahmin: [
        GunlukHavaVerisi(tarih: now, yagisMm: 0, maxSicaklik: 21, minSicaklik: 9, maxRuzgarHizi: 8.5, buharlasmaEt0: 3.5),
        GunlukHavaVerisi(tarih: now.add(const Duration(days: 1)), yagisMm: 0, maxSicaklik: 22, minSicaklik: 10, maxRuzgarHizi: 12.0, buharlasmaEt0: 3.6),
        GunlukHavaVerisi(tarih: now.add(const Duration(days: 2)), yagisMm: 16.0, maxSicaklik: 18, minSicaklik: 8, maxRuzgarHizi: 14.0, buharlasmaEt0: 2.0),
      ],
    );

    final kararlar = ZiraiKararDestekEngine.kararlariUret(parsel: parsel, hava: hava);
    final sezon = SezonlukIklimMotoru.hesapla(parsel: parsel, hava: hava);

    // İlaçlama kararı testi (Rüzgar 8.5 km/s -> Uygun)
    expect(kararlar.ilaclama.uygun, isTrue);
    expect(kararlar.ilaclama.baslik, contains('Mükemmel'));

    // Gübreleme kararı testi (2 gün sonra 16 mm yağmur var -> Alarm)
    expect(kararlar.gubreleme.yagisAlarmiVar, isTrue);
    expect(kararlar.gubreleme.beklenenYagisMm, equals(16.0));
    expect(kararlar.gubreleme.baslik, contains('16 mm Yağış Geliyor'));

    // Toprak tavı testi (%56 nem -> Tavında)
    expect(kararlar.ekimTavi.toprakTavinda, isTrue);

    // Sezonluk gelişim testi
    expect(sezon.ekimdenBeriGecenGun, equals(40));
    expect(sezon.toplamBirikenYagisMm, equals(145.0));
    expect(sezon.mevcutFenolojikEvre, isNotEmpty);

    print('✅ Zirai Karar Destek & İklim Motoru Testi Başarılı:');
    print('   - İlaçlama: ${kararlar.ilaclama.baslik}');
    print('   - Gübreleme: ${kararlar.gubreleme.baslik}');
    print('   - Fenoloji: ${sezon.mevcutFenolojikEvre} (Hasata: ~${sezon.tahminiHasataKalanGun} gün)');
  });
}
