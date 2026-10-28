import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/is_gunlugu/data/is_kaydi_model.dart';
import 'package:kayin_flutter/features/is_gunlugu/domain/is_kaydi_entity.dart';

IsKaydiEntity _kayit({
  String parsel = 'p1',
  required DateTime tarih,
  IslemTuru tur = IslemTuru.ilaclama,
  int? bekleme,
  bool silindi = false,
}) =>
    IsKaydiEntity(
      id: '${parsel}_${tarih.toIso8601String()}',
      parselId: parsel,
      islemTarihi: tarih.toUtc(),
      tur: tur,
      urunAdi: 'X',
      hasatBeklemeGun: bekleme,
      createdAtUtc: tarih.toUtc(),
      lastModifiedUtc: tarih.toUtc(),
      isDeleted: silindi,
    );

void main() {
  final bugun = DateTime(2026, 6, 20);

  group('Hasat öncesi bekleme', () {
    test('14 günlük ilaç 10 gün önce atıldıysa 4 gün kalır', () {
      final y = aktifHasatYasaklari([_kayit(tarih: DateTime(2026, 6, 10, 8), bekleme: 14)], bugun);
      expect(y['p1']!.kalanGun, 4);
      expect(y['p1']!.serbestTarih, DateTime(2026, 6, 24));
    });

    test('Bekleme süresinin bittiği gün hasat serbesttir', () {
      final y = aktifHasatYasaklari([_kayit(tarih: DateTime(2026, 6, 6), bekleme: 14)], bugun);
      expect(y, isEmpty);
    });

    test('Aynı tarlada en geç biten bekleme esas alınır', () {
      final y = aktifHasatYasaklari([
        _kayit(tarih: DateTime(2026, 6, 15), bekleme: 7), // 22 Haziran
        _kayit(tarih: DateTime(2026, 6, 12), bekleme: 21), // 3 Temmuz
      ], bugun);
      expect(y['p1']!.serbestTarih, DateTime(2026, 7, 3));
      expect(y['p1']!.kalanGun, 13);
    });

    test('Tarlalar ayrı ayrı hesaplanır', () {
      final y = aktifHasatYasaklari([
        _kayit(parsel: 'a', tarih: DateTime(2026, 6, 19), bekleme: 3),
        _kayit(parsel: 'b', tarih: DateTime(2026, 6, 1), bekleme: 7),
      ], bugun);
      expect(y.keys, ['a']);
    });

    test('Bekleme süresi girilmemiş, silinmiş ya da ilaçlama olmayan kayıt yasak doğurmaz', () {
      final y = aktifHasatYasaklari([
        _kayit(tarih: DateTime(2026, 6, 19)),
        _kayit(tarih: DateTime(2026, 6, 19), bekleme: 14, silindi: true),
        _kayit(tarih: DateTime(2026, 6, 19), bekleme: 14, tur: IslemTuru.gubreleme),
        _kayit(tarih: DateTime(2026, 6, 19), bekleme: 0),
      ], bugun);
      expect(y, isEmpty);
    });

    test('Ay sonundan taşan süre doğru hesaplanır', () {
      final k = _kayit(tarih: DateTime(2026, 1, 25), bekleme: 10);
      expect(k.hasatSerbestTarihi, DateTime(2026, 2, 4));
    });
  });

  test('Satıra yazılıp okununca aynı kalır', () {
    final k = _kayit(tarih: DateTime(2026, 6, 10, 9, 30), bekleme: 14);
    final geri = IsKaydiModel.fromRow(IsKaydiModel.toRow(k));
    expect(geri.tur, IslemTuru.ilaclama);
    expect(geri.hasatBeklemeGun, 14);
    expect(geri.islemTarihi, k.islemTarihi);
    expect(IslemTuru.koddan('Bilinmeyen'), IslemTuru.diger);
  });
}
