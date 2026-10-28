import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/veresiye/data/veresiye_model.dart';
import 'package:kayin_flutter/features/veresiye/domain/veresiye.dart';

final _bugun = DateTime(2026, 8, 15);
var _sayac = 0;

CariHareketEntity _h(HareketTuru tur, double tutar, {DateTime? vade, DateTime? tarih, bool silindi = false}) {
  final t = (tarih ?? DateTime(2026, 3, 1)).toUtc();
  return CariHareketEntity(
    id: 'h${_sayac++}',
    cariId: 'c',
    islemTarihi: t,
    tur: tur,
    tutar: tutar,
    vadeTarihi: vade?.toUtc(),
    createdAtUtc: t,
    lastModifiedUtc: t,
    isDeleted: silindi,
  );
}

void main() {
  test('Bakiye: veresiye borç artırır, ödeme azaltır', () {
    final d = cariDurumu([_h(HareketTuru.veresiye, 50000), _h(HareketTuru.odeme, 20000)], _bugun);
    expect(d.bakiye, 30000);
    expect(d.borcluyum, isTrue);
  });

  test('Bakiye: veresiye satış alacak doğurur, tahsilat kapatır', () {
    final d = cariDurumu([_h(HareketTuru.satis, 120000), _h(HareketTuru.tahsilat, 70000)], _bugun);
    expect(d.bakiye, -50000);
    expect(d.alacakliyim, isTrue);
  });

  test('Silinmiş hareket sayılmaz', () {
    final d = cariDurumu([_h(HareketTuru.veresiye, 1000), _h(HareketTuru.veresiye, 5000, silindi: true)], _bugun);
    expect(d.bakiye, 1000);
  });

  test('Ödeme önce vadesi en erken borcu kapatır', () {
    final d = cariDurumu([
      _h(HareketTuru.veresiye, 30000, vade: DateTime(2026, 7, 31)), // geçti
      _h(HareketTuru.veresiye, 20000, vade: DateTime(2026, 9, 30)), // gelecek
      _h(HareketTuru.odeme, 10000),
    ], _bugun);
    expect(d.bakiye, 40000);
    expect(d.vadesiGecen, 20000); // 30.000'in 10.000'i ödendi
    expect(d.yaklasanVade, DateTime(2026, 9, 30));
  });

  test('Vadesi geçen borç tamamen ödendiyse uyarı yok', () {
    final d = cariDurumu([
      _h(HareketTuru.veresiye, 30000, vade: DateTime(2026, 7, 31)),
      _h(HareketTuru.odeme, 30000),
    ], _bugun);
    expect(d.vadesiGecen, 0);
    expect(d.bakiye, 0);
    expect(d.borcluyum, isFalse);
  });

  test('Vadesiz borç ödemeyi en son alır, vadesi geçmiş sayılmaz', () {
    final d = cariDurumu([
      _h(HareketTuru.veresiye, 5000), // vadesiz
      _h(HareketTuru.veresiye, 8000, vade: DateTime(2026, 8, 1)),
      _h(HareketTuru.odeme, 8000),
    ], _bugun);
    expect(d.vadesiGecen, 0);
    expect(d.bakiye, 5000);
  });

  test('Vade günü bugünse henüz geçmiş sayılmaz', () {
    final d = cariDurumu([_h(HareketTuru.veresiye, 1000, vade: _bugun)], _bugun);
    expect(d.vadesiGecen, 0);
    expect(d.yaklasanVade, _bugun);
  });

  test('Alacak tarafının vadesi de izlenir (tüccar ödemedi)', () {
    final d = cariDurumu([_h(HareketTuru.satis, 90000, vade: DateTime(2026, 8, 10))], _bugun);
    expect(d.vadesiGecen, 90000);
    expect(d.alacakliyim, isTrue);
  });

  test('Hareket satıra yazılıp okununca aynı kalır', () {
    final h = _h(HareketTuru.veresiye, 1234.5, vade: DateTime(2026, 9, 1, 12));
    final geri = CariHareketModel.fromRow(CariHareketModel.toRow(h));
    expect(geri.tur, HareketTuru.veresiye);
    expect(geri.tutar, 1234.5);
    expect(geri.vadeTarihi, h.vadeTarihi);
    expect(HareketTuru.koddan('?'), HareketTuru.veresiye);
  });
}
