import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/yaprak_hastalik_ai/domain/zirai_recete_engine.dart';

/// Reçeteler ürün adı, doz ve sabit bekleme süresi içermemeli (bkz. ZiraiReceteEngine belgesi).
void main() {
  final tumMetinler = [
    for (final r in ZiraiReceteEngine.tumReceteler) ...[
      r.aciklama,
      r.uygulamaZamani,
      r.dikkatNotu,
      ...r.mucadeleGruplari,
      ...r.kulturelOnlemler,
    ],
  ];

  test('Doz ifadesi yok (ml, gr, g/l, dönüme, 100 lt suya)', () {
    final doz = RegExp(r'\d+\s*(ml|gr|g/l|kg)\b|dönüme\s*\d|100\s*l(itre|t)?\s*suya', caseSensitive: false);
    for (final m in tumMetinler) {
      expect(doz.hasMatch(m), isFalse, reason: m);
    }
  });

  test('Firma / ticari ürün adı yok', () {
    const firmalar = ['Bayer', 'BASF', 'Syngenta', 'Corteva', 'Adama', 'FMC', 'UPL', 'Gowan', 'Nippon', 'Yara', 'Haifa'];
    for (final m in tumMetinler) {
      for (final f in firmalar) {
        expect(m.contains(f), isFalse, reason: '"$f" → $m');
      }
    }
  });

  test('AB\'de onayı sona ermiş bilinen etken maddeler adıyla önerilmiyor', () {
    const maddeler = ['carbendazim', 'epoxiconazole', 'mancozeb', 'chlorothalonil', 'cyproconazole', 'propiconazole', 'phosmet'];
    for (final m in tumMetinler) {
      for (final e in maddeler) {
        expect(m.toLowerCase().contains(e), isFalse, reason: '"$e" → $m');
      }
    }
  });

  test('Her hastalık reçetesi ya ilaç grubu verir ya da ilaçla tedavisi olmadığını söyler', () {
    for (final r in ZiraiReceteEngine.tumReceteler.where((r) => !r.hastalikAdi.contains('Sağlıklı'))) {
      // İlaç grubu boş ve "tedavisi yok" işareti yoksa ekran "İlaçlama gerekmez" der — hastalıkta yanlış.
      expect(r.ilacGerekir || r.ilaclaTedaviYok, isTrue, reason: r.hastalikAdi);
      expect(r.uygulamaZamani, isNotEmpty);
      expect(r.kulturelOnlemler, isNotEmpty, reason: r.hastalikAdi);
    }
    final saglikli = ZiraiReceteEngine.receteBul('Sağlıklı Bitki Dokusu')!;
    expect(saglikli.ilacGerekir, isFalse);
    expect(saglikli.ilaclaTedaviYok, isFalse);
  });

  test('Virüs ve solgunluk reçeteleri tedavi vaat etmiyor', () {
    for (final ad in [
      'Domates Mozaik Virüsü (ToMV)',
      'Domates Sarı Yaprak Kıvırcıklık Virüsü (TYLCV)',
      'Pamuk Verticillium Solgunluğu (Verticillium dahliae)',
      'Pamuk Fusarium Solgunluğu',
    ]) {
      expect(ZiraiReceteEngine.receteBul(ad)?.ilaclaTedaviYok, isTrue, reason: ad);
    }
  });

  test('Hastalık adları benzersiz', () {
    final adlar = ZiraiReceteEngine.tumReceteler.map((r) => r.hastalikAdi).toList();
    expect(adlar.toSet().length, adlar.length);
  });

  test('Hastalık adları değişmedi (model etiketleri ve kayıtlı taramalar bunlara bağlı)', () {
    for (final ad in [
      'Sarı Pas & Kahverengi Pas (Puccinia spp.)',
      'Domates Mildiyösü / Geç Yanıklık (Phytophthora infestans)',
      'Bağ Küllemesi (Uncinula necator)',
      'Sağlıklı Bitki Dokusu',
    ]) {
      expect(ZiraiReceteEngine.receteBul(ad), isNotNull, reason: ad);
    }
    expect(ZiraiReceteEngine.tumReceteler.length, 37);
  });
}
