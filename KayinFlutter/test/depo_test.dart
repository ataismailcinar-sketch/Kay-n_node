import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/depo/data/depo_model.dart';
import 'package:kayin_flutter/features/depo/domain/depo.dart';
import 'package:kayin_flutter/features/is_gunlugu/domain/is_kaydi_entity.dart';

final _t = DateTime.utc(2026, 5, 1);
var _n = 0;

StokHareketiEntity _h(StokHareketTuru tur, double miktar, {bool silindi = false}) => StokHareketiEntity(
      id: 'h${_n++}',
      kalemId: 'k',
      islemTarihi: _t,
      tur: tur,
      miktar: miktar,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
      isDeleted: silindi,
    );

StokKalemiEntity _k({double? kritik}) =>
    StokKalemiEntity(id: 'k', ad: 'Üre', kritikSeviye: kritik, createdAtUtc: _t, lastModifiedUtc: _t);

void main() {
  test('Mevcut: giriş ekler, çıkış düşer, düzeltme işaretli eklenir, silinmiş sayılmaz', () {
    final m = mevcutMiktar([
      _h(StokHareketTuru.giris, 50),
      _h(StokHareketTuru.cikis, 12.5),
      _h(StokHareketTuru.duzeltme, -2.5),
      _h(StokHareketTuru.giris, 100, silindi: true),
    ]);
    expect(m, 35);
  });

  test('Sayım farkı: sayılan − mevcut', () {
    expect(sayimFarki(mevcut: 35, sayilan: 30), -5);
    expect(sayimFarki(mevcut: 35, sayilan: 40), 5);
    expect(sayimFarki(mevcut: 35, sayilan: 35), 0);
  });

  test('Azaldı uyarısı: kritik seviyenin altı ya da eksi stok', () {
    expect(azaldiMi(_k(kritik: 10), 9.9), isTrue);
    expect(azaldiMi(_k(kritik: 10), 10), isFalse);
    expect(azaldiMi(_k(), 1), isFalse); // eşik yok
    expect(azaldiMi(_k(), -1), isTrue); // kayıt hatası: depoda olmayanı kullanmış
  });

  test('İş türüne göre depo kategorisi', () {
    expect(StokKategori.isIcin(IslemTuru.ilaclama), StokKategori.ilac);
    expect(StokKategori.isIcin(IslemTuru.gubreleme), StokKategori.gubre);
    expect(StokKategori.isIcin(IslemTuru.ekim), StokKategori.tohum);
    expect(StokKategori.isIcin(IslemTuru.sulama), isNull);
  });

  test('Miktar okuma/yazma (Türkçe ondalık)', () {
    expect(miktarOku('12,5'), 12.5);
    expect(miktarOku('12.5'), 12.5);
    expect(miktarOku('abc'), isNull);
    expect(miktarYaz(20), '20');
    expect(miktarYaz(12.5), '12,5');
    expect(miktarYaz(0.1 + 0.2), '0,3');
  });

  test('Hareket satıra yazılıp okununca aynı kalır', () {
    final h = StokHareketiEntity(
      id: 'x', kalemId: 'k', islemTarihi: _t, tur: StokHareketTuru.cikis, miktar: 2.5,
      isKaydiId: 'is1', createdAtUtc: _t, lastModifiedUtc: _t,
    );
    final geri = StokHareketiModel.fromRow(StokHareketiModel.toRow(h));
    expect(geri.etki, -2.5);
    expect(geri.isKaydiId, 'is1');
  });
}
