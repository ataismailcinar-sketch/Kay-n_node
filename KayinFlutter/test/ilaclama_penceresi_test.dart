import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/services/hava_durumu_servisi.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/zirai_karar_destek_engine.dart';

final _bugun = DateTime(2026, 6, 10);

/// [_bugun] 00:00'dan başlayan 48 saatlik tahmin; [saat] fonksiyonu her saatin değerini verir.
TarlaHavaOzeti _hava(SaatlikHava Function(DateTime t) saat) => TarlaHavaOzeti(
      bugunYagisMm: 0,
      bugunMaxSicaklik: 30,
      bugunMinSicaklik: 12,
      bugunRuzgarHiziKm: 25, // günlük en yüksek rüzgar: eski kurala göre "ilaçlama yapma"
      sonYediGun: const [],
      gelecekYediGunTahmin: const [],
      gelecekSaatler: [for (var h = 0; h < 48; h++) saat(_bugun.add(Duration(hours: h)))],
    );

SaatlikHava _s(DateTime t, {double w = 5, double p = 0, double c = 20}) =>
    SaatlikHava(zaman: t, ruzgarKm: w, yagisMm: p, sicaklik: c);

IlaclamaTavsiyesi _karar(TarlaHavaOzeti h) => ZiraiKararDestekEngine.ilaclamaTavsiyesi(h, simdi: _bugun);

void main() {
  test('Öğleden sonra rüzgarlı ama sabah sakinse sabah penceresi önerilir', () {
    final k = _karar(_hava((t) => _s(t, w: t.hour >= 12 ? 25 : 6)));
    expect(k.uygun, isTrue);
    expect(k.idealSaatler, 'Bugün 05:00 – 12:00');
  });

  test('Bugün her saat rüzgarlıysa yarının penceresi gösterilir', () {
    final k = _karar(_hava((t) => _s(t, w: t.day == _bugun.day || t.hour >= 9 ? 25 : 6)));
    expect(k.uygun, isFalse);
    expect(k.idealSaatler, 'Yarın 05:00 – 09:00');
    expect(k.detay, contains('rüzgar'));
  });

  test('Yağıştan hemen önceki saatler uygun sayılmaz (ilaç yıkanır)', () {
    // 08:00'de yağmur: 06:00 ve 07:00 sonraki 2 saatte yağış gördüğü için elenir,
    // 05:00 tek başına kalır (pencere değil); ilk pencere yağmurdan sonra başlar.
    final k = _karar(_hava((t) => _s(t, p: t.day == _bugun.day && t.hour == 8 ? 3 : 0)));
    expect(k.idealSaatler, 'Bugün 09:00 – 21:00');
  });

  test('Tek uygun saat pencere sayılmaz', () {
    final k = _karar(_hava((t) => _s(t, w: t.hour == 6 ? 5 : 25)));
    expect(k.uygun, isFalse);
    expect(k.baslik, contains('2 günde'));
  });

  test('Sıcak saatler elenir', () {
    final k = _karar(_hava((t) => _s(t, c: t.hour >= 10 ? 33 : 18)));
    expect(k.idealSaatler, 'Bugün 05:00 – 10:00');
  });

  test('Saatlik veri yoksa günlük değerlerle karar verilir', () {
    final h = TarlaHavaOzeti(
      bugunYagisMm: 0,
      bugunMaxSicaklik: 22,
      bugunMinSicaklik: 10,
      bugunRuzgarHiziKm: 25,
      sonYediGun: const [],
      gelecekYediGunTahmin: const [],
    );
    expect(_karar(h).uygun, isFalse);
  });
}
