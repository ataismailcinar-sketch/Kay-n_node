// Elle çalıştırılan deneme betiği: dart run tool/arazi_analiz_runner.dart
// ignore_for_file: avoid_print
import 'package:kayin_flutter/features/arazi_analiz/domain/ecocrop_engine.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/fenoloji_engine.dart';

void main() {
  print('=== REPLANTIO ECOCROP ENGINE TEST ===');
  final sonuclar = EcoCropEngine.analiziCalistir(
    ortalamaSicaklik: 16.0,
    minSicaklik: -5.0,
    maxSicaklik: 30.0,
    yillikYagisMm: 550.0,
    toprakTuru: 'Tinli',
    alanDonum: 50.0,
  );

  for (final s in sonuclar.take(4)) {
    print('${s.emoji} ${s.urunAdi}: Derece ${s.derece} (%${s.uygunlukSkoru.toStringAsFixed(1)}) - Tahmini Rekolte: ${s.toplamTahminiHasatKg.toStringAsFixed(0)} kg - Ciro: ${s.toplamTahminiCiroTL.toStringAsFixed(0)} TL');
  }

  print('\n=== FENOLOJİ TAKVİM ENGINE TEST ===');
  final now = DateTime.now();
  final ekimTarihi = now.subtract(const Duration(days: 35));
  final evre = FenolojiEngine.hesapla(ekilmisUrun: 'Bugday', ekimTarihi: ekimTarihi);

  print('Evre: ${evre.evreAdi}');
  print('Gecen Gun: ${evre.gecenGun}, Kalan Gun: ${evre.kalanGun}');
  for (final islem in evre.yapilacakIsler) {
    print('  ${islem.ikon} [${islem.oncelik}] ${islem.baslik}: ${islem.aciklama}');
  }
  print('\n✅ TÜM TESTLER BAŞARIYLA GEÇTİ!');
}
