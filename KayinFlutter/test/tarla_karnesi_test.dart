import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/is_gunlugu/domain/is_kaydi_entity.dart';
import 'package:kayin_flutter/features/karne/domain/tarla_karnesi.dart';
import 'package:kayin_flutter/features/klavyesiz_muhasebe/domain/entities/gider_entity.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';

final _t = DateTime(2026, 7, 15, 12);

ParselEntity _p(String id, double alan) => ParselEntity(
      id: id,
      ad: id,
      konum: '',
      poligonNoktalar: const [],
      alanDonumCinsinden: alan,
      merkezLat: 0,
      merkezLng: 0,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
    );

GiderEntity _m(double tutar, {String? parsel, bool gelir = false, DateTime? tarih, bool silindi = false}) => GiderEntity(
      id: '$tutar$parsel$gelir',
      parselId: parsel,
      islemTuru: gelir ? 'Gelir' : 'Gider',
      kategori: gelir ? 'Hasat' : 'Mazot',
      altKategori: '',
      tutar: tutar,
      giderTarihi: (tarih ?? _t).toUtc(),
      createdAtUtc: _t,
      lastModifiedUtc: _t,
      isDeleted: silindi,
    );

IsKaydiEntity _hasat(String parsel, double kg, {DateTime? tarih, IslemTuru tur = IslemTuru.hasat}) => IsKaydiEntity(
      id: '$parsel$kg',
      parselId: parsel,
      islemTarihi: (tarih ?? _t).toUtc(),
      tur: tur,
      hasatKg: kg,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
    );

void main() {
  final donem = Donem.yil(2026);

  test('Verim, dönüm başı ve kilo başı maliyet, kâr', () {
    final k = karneHesapla(
      parseller: [_p('a', 100)],
      isKayitlari: [_hasat('a', 30000), _hasat('a', 10000)], // 40 ton, iki günde
      muhasebe: [_m(200000, parsel: 'a'), _m(360000, parsel: 'a', gelir: true)],
      donem: donem,
    );
    final t = k.tarlalar.single;
    expect(t.hasatKg, 40000);
    expect(t.verimKgDa, 400);
    expect(t.maliyetTlDa, 2000);
    expect(t.maliyetTlKg, 5);
    expect(t.netKar, 160000);
    expect(t.karTlDa, 1600);
    expect(t.satisGirilmemis, isFalse);
  });

  test('Genel gider ve gelir tarlalara alan oranında dağıtılır; toplam korunur', () {
    final k = karneHesapla(
      parseller: [_p('a', 75), _p('b', 25)],
      isKayitlari: const [],
      muhasebe: [_m(40000), _m(10000, gelir: true), _m(5000, parsel: 'b')],
      donem: donem,
    );
    final a = k.tarlalar.firstWhere((t) => t.parsel.id == 'a');
    final b = k.tarlalar.firstWhere((t) => t.parsel.id == 'b');
    expect(a.genelGiderPayi, 30000);
    expect(b.genelGiderPayi, 10000);
    expect(b.gider, 15000);
    expect(a.genelGelirPayi, 7500);
    expect(k.toplamGider, 45000);
    expect(k.toplamGelir, 10000);
    expect(a.netKar + b.netKar, k.netKar);
  });

  test('Silinmiş tarlaya ait gider genel sayılır', () {
    final k = karneHesapla(
      parseller: [_p('a', 10)],
      isKayitlari: const [],
      muhasebe: [_m(1000, parsel: 'silinmis')],
      donem: donem,
    );
    expect(k.tarlalar.single.gider, 1000);
  });

  test('Dönem dışı, silinmiş ve hasat olmayan kayıtlar sayılmaz', () {
    final k = karneHesapla(
      parseller: [_p('a', 10)],
      isKayitlari: [
        _hasat('a', 5000, tarih: DateTime(2025, 12, 31, 12)),
        _hasat('a', 999, tur: IslemTuru.sulama),
        _hasat('a', 2000),
      ],
      muhasebe: [_m(500, parsel: 'a', tarih: DateTime(2027, 1, 1, 12)), _m(700, parsel: 'a', silindi: true)],
      donem: donem,
    );
    expect(k.tarlalar.single.hasatKg, 2000);
    expect(k.tarlalar.single.gider, 0);
  });

  test('Hasat yoksa verim ve kilo maliyeti hesaplanmaz; satış yoksa uyarılır', () {
    final bos = karneHesapla(parseller: [_p('a', 10)], isKayitlari: const [], muhasebe: [_m(100, parsel: 'a')], donem: donem);
    expect(bos.tarlalar.single.verimKgDa, isNull);
    expect(bos.tarlalar.single.maliyetTlKg, isNull);

    final satissiz = karneHesapla(parseller: [_p('a', 10)], isKayitlari: [_hasat('a', 3000)], muhasebe: const [], donem: donem);
    expect(satissiz.tarlalar.single.satisGirilmemis, isTrue);
  });

  test('Alanı olmayan çiftlikte genel tutarlar kaybolmaz', () {
    final k = karneHesapla(parseller: [_p('a', 0)], isKayitlari: const [], muhasebe: [_m(800)], donem: donem);
    expect(k.toplamGider, 800);
    expect(k.tarlalar.single.maliyetTlDa, isNull);
  });

  test('Son 12 ay dönemi: bugün dahil, 12 ay önceki gün hariç', () {
    final d = Donem.son12Ay(DateTime(2026, 10, 22));
    expect(d.icerir(DateTime(2026, 10, 22, 23)), isTrue);
    expect(d.icerir(DateTime(2025, 10, 23)), isTrue);
    expect(d.icerir(DateTime(2025, 10, 22)), isFalse);
  });

  test('Miktar metni', () {
    expect(miktarMetni(850), '850 kg');
    expect(miktarMetni(12500), '12,5 ton');
    expect(miktarMetni(40000), '40 ton');
  });
}
