import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/toprak_analizi/data/toprak_analizi_model.dart';
import 'package:kayin_flutter/features/toprak_analizi/domain/toprak_analizi.dart';

final _t = DateTime.utc(2026, 1, 1);

ToprakAnaliziEntity _a({
  double? sat,
  double? ph,
  double? tuz,
  double? ec,
  double? kirec,
  double? om,
  double? p,
  double? k,
  double? zn,
  DateTime? tarih,
  String parsel = 'p1',
}) =>
    ToprakAnaliziEntity(
      id: 'a${tarih?.year ?? 0}',
      parselId: parsel,
      analizTarihi: tarih ?? DateTime(2026, 9, 1),
      saturasyon: sat,
      ph: ph,
      tuzYuzde: tuz,
      ec: ec,
      kirecYuzde: kirec,
      organikMadde: om,
      fosfor: p,
      potasyum: k,
      cinko: zn,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
    );

void main() {
  test('Bünye saturasyondan; ağır killi uygulamada Killi, fazla kireç Kireçli', () {
    expect(bunyeSinifi(28), 'Kumlu');
    expect(bunyeSinifi(45), 'Tınlı');
    expect(bunyeSinifi(65), 'Killi');
    expect(bunyeSinifi(80), 'Ağır killi');
    expect(onerilenToprakTuru(_a(sat: 80)), 'Killi');
    expect(onerilenToprakTuru(_a(sat: 45, kirec: 20)), 'Kireçli');
    expect(onerilenToprakTuru(_a(ph: 7)), isNull);
  });

  test('Su sabitleri: killi toprak tınlıdan daha çok su tutar, solma < tarla kapasitesi', () {
    final kum = analizdenSuSabitleri(_a(sat: 25))!;
    final tin = analizdenSuSabitleri(_a(sat: 45))!;
    final kil = analizdenSuSabitleri(_a(sat: 65))!;
    expect(kum.tarlaKapasitesi < tin.tarlaKapasitesi && tin.tarlaKapasitesi < kil.tarlaKapasitesi, isTrue);
    for (final s in [kum, tin, kil]) {
      expect(s.solmaNoktasi, lessThan(s.tarlaKapasitesi));
    }
    // Tınlı (sat 45): TK ≈ 45/2 % × 1,40 = 0,315 m³/m³
    expect(tin.tarlaKapasitesi, closeTo(0.315, 0.001));
    expect(analizdenSuSabitleri(_a(ph: 7)), isNull);
    expect(analizdenSuSabitleri(null), isNull);
  });

  test('Yorum: sınıflar ve durumlar; girilmeyen değer atlanır', () {
    final y = yorumla(_a(ph: 8.1, tuz: 0.4, om: 1.2, p: 4, k: 45, zn: 0.3));
    final m = {for (final e in y) e.ad: e};
    expect(y, hasLength(6));
    expect(m['pH']!.sinif, 'Hafif alkali');
    expect(m['pH']!.durum, Durum.dikkat);
    expect(m['Toplam tuz']!.sinif, 'Orta tuzlu');
    expect(m['Toplam tuz']!.durum, Durum.sorun);
    expect(m['Organik madde']!.sinif, 'Az');
    expect(m['Fosfor (P₂O₅)']!.sinif, 'Az');
    expect(m['Potasyum (K₂O)']!.sinif, 'Yüksek');
    expect(m['Çinko (Zn)']!.durum, Durum.sorun);
  });

  test('Uygunluk için tuzluluk: EC varsa o, yoksa tuz %\'den (saturasyon yoksa %50)', () {
    expect(tuzlulukEc(_a(ec: 850, tuz: 0.5)), closeTo(0.85, 1e-9));
    // 0,064 × EC × 50 / 100 = 0,15 → EC ≈ 4,69
    expect(tuzlulukEc(_a(tuz: 0.15)), closeTo(4.6875, 1e-9));
    expect(tuzlulukEc(_a(tuz: 0.15, sat: 30)), closeTo(7.8125, 1e-9));
    expect(tuzlulukEc(_a(ph: 7)), isNull);
  });

  test('EC µS/cm girilirse dS/m\'ye çevrilir', () {
    expect(ecDuzelt(850), closeTo(0.85, 1e-9));
    expect(ecDuzelt(6), 6);
    expect(yorumla(_a(ec: 5200)).single.sinif, 'Hafif tuzlu');
  });

  test('Öneriler: sorunlu değerler için öneri var, iyi analizde yok', () {
    final o = oneriler(_a(ph: 8.2, tuz: 0.5, om: 1.5, p: 3, k: 15, zn: 0.4), DateTime(2026, 10, 1));
    final metin = o.join('\n');
    for (final kelime in ['Tuzluluk', 'demir', 'Organik madde', 'Fosfor', 'Potasyum', 'Çinko']) {
      expect(metin, contains(kelime));
    }
    expect(oneriler(_a(sat: 45, ph: 7.0, tuz: 0.05, kirec: 3, om: 2.5, p: 8, k: 30, zn: 1.2), DateTime(2026, 10, 1)),
        isEmpty);
  });

  test('Eski analiz için yenileme önerisi; son analiz tarlaya göre seçilir', () {
    expect(oneriler(_a(ph: 7, tarih: DateTime(2020, 5, 1)), DateTime(2026, 10, 1)).single, contains('4 yıldan eski'));
    final liste = [
      _a(ph: 7, tarih: DateTime(2022, 1, 1)),
      _a(ph: 7.5, tarih: DateTime(2025, 1, 1)),
      _a(ph: 6, tarih: DateTime(2026, 1, 1), parsel: 'p2'),
    ];
    expect(sonAnaliz(liste, 'p1')!.ph, 7.5);
    expect(sonAnaliz(liste, 'yok'), isNull);
  });

  test('Sayı okuma/yazma virgüllü; model gün kaydırmadan saklar ve boş değerleri korur', () {
    expect(sayiOku('7,85'), 7.85);
    expect(sayiOku(''), isNull);
    expect(sayiYaz(0.045, basamak: 3), '0,045');
    expect(sayiYaz(12.0), '12');
    final a = _a(ph: 7.85, tarih: DateTime(2026, 3, 31));
    final row = ToprakAnaliziModel.toRow(a);
    expect(row['analiz_tarihi'], '2026-03-31');
    final geri = ToprakAnaliziModel.fromRow(row);
    expect(geri.ph, 7.85);
    expect(geri.saturasyon, isNull);
    expect(geri.analizTarihi, DateTime(2026, 3, 31));
    expect(_a().bos, isTrue);
  });
}
