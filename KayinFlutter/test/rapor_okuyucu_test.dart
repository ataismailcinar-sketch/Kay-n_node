import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/toprak_analizi/domain/rapor_okuyucu.dart';

void main() {
  test('Tipik toprak raporu: formüllerdeki rakamlar, oranlar ve sınır aralıkları atlanır', () {
    final r = raporuOku([
      'T.C. KONYA İL TARIM VE ORMAN MÜDÜRLÜĞÜ TOPRAK ANALİZ RAPORU',
      'Numune No: 2026/1543   Derinlik: 0-30 cm',
      'Parametre   Sonuç   Birim   Değerlendirme',
      'Saturasyon (%)   58   %   Killi-Tınlı',
      'pH (1:2,5)   7,85   Hafif alkali   6,5-7,5',
      'EC (1:2,5)   0,85   dS/m   Tuzsuz',
      'Toplam Tuz (%)   0,045   %   Tuzsuz',
      'Kireç (CaCO3) %   12,5   Orta kireçli',
      'Organik Madde   1,42   %   Az',
      'Fosfor (P2O5) kg/da   4,2   Az',
      'Potasyum (K2O) kg/da   85   Yüksek',
      'Çinko (Zn) ppm   0,38   Yetersiz',
    ]);
    expect(r[RaporAlani.saturasyon], 58);
    expect(r[RaporAlani.ph], 7.85);
    expect(r[RaporAlani.ec], 0.85);
    expect(r[RaporAlani.tuzYuzde], 0.045);
    expect(r[RaporAlani.kirec], 12.5);
    expect(r[RaporAlani.organikMadde], 1.42);
    expect(r[RaporAlani.fosfor], 4.2);
    expect(r[RaporAlani.potasyum], 85);
    expect(r[RaporAlani.cinko], 0.38);
    expect(r.notlar, isEmpty);
  });

  test('OCR bozuklukları: şapkasız harfler, büyük harf, nokta ondalık', () {
    final r = raporuOku([
      'KIREC   8.2',
      'ORGANIK MADDE %   2.6',
      'CINKO   1.1',
      'PH   8.05',
    ]);
    expect(r[RaporAlani.kirec], 8.2);
    expect(r[RaporAlani.organikMadde], 2.6);
    expect(r[RaporAlani.cinko], 1.1);
    expect(r[RaporAlani.ph], 8.05);
  });

  test('Değer alt satırda (dikey tablo); başka etiket satırına atlanmaz', () {
    final r = raporuOku(['pH', '7,6', 'Organik madde', 'Kireç  15']);
    expect(r[RaporAlani.ph], 7.6);
    expect(r[RaporAlani.organikMadde], isNull);
    expect(r[RaporAlani.kirec], 15);
  });

  test('Fosfor/potasyum ppm ise doldurulmaz, not düşülür; aralık dışı değer alınmaz', () {
    final r = raporuOku(['Fosfor (P) mg/kg   12,4', 'pH   75   7,4']);
    expect(r[RaporAlani.fosfor], isNull);
    expect(r.notlar.single, contains('Fosfor'));
    expect(r[RaporAlani.ph], 7.4); // 75 pH aralığında değil
  });

  test('Su analizi: µS/cm EC okunur; "tuzluluk" satırı tuz % sanılmaz', () {
    final r = raporuOku([
      'SULAMA SUYU ANALİZ RAPORU',
      'EC (µS/cm)   1850',
      'Tuzluluk sınıfı   C3S1',
      'pH   7,9',
      'SAR   1,2',
    ]);
    expect(r[RaporAlani.ec], 1850);
    expect(r[RaporAlani.tuzYuzde], isNull);
    expect(r[RaporAlani.ph], 7.9);
  });

  test('Satırlara dizme: aynı yükseklikteki sütunlar soldan sağa birleşir', () {
    final satirlar = satirlaraDiz(const [
      MetinParcasi(100, 120, 400, '7,85'),
      MetinParcasi(102, 121, 20, 'pH (1:2,5)'),
      MetinParcasi(140, 160, 20, 'Organik Madde'),
      MetinParcasi(141, 159, 400, '1,42'),
    ]);
    expect(satirlar, ['pH (1:2,5)  7,85', 'Organik Madde  1,42']);
    expect(raporuOku(satirlar)[RaporAlani.ph], 7.85);
  });
}
