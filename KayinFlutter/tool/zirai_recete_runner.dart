// Elle çalıştırılan deneme betiği: dart run tool/zirai_recete_runner.dart
// ignore_for_file: avoid_print
import 'package:kayin_flutter/features/yaprak_hastalik_ai/domain/zirai_recete_engine.dart';

void main() {
  print('=== 🔬 KAPSAMLI ZİRAİ İLAÇ & TEDAVİ REÇETELERİ TESTİ ===\n');
  print('Toplam Kayıtlı Zirai Reçete Sayısı: ${ZiraiReceteEngine.tumReceteler.length}\n');

  for (final recete in ZiraiReceteEngine.tumReceteler) {
    print('🌾 [${recete.hedefUrunler}] -> ${recete.hastalikAdi}');
    print('   Latince: ${recete.latinceAdi}');
    print('   Tehlike: ${recete.tehlikeSeviyesi} | Kategori: ${recete.kategori}');
    print('   İlaç grupları: ${recete.ilacGerekir ? recete.mucadeleGruplari.join(", ") : "-"}');
    print('   Zaman: ${recete.uygulamaZamani}\n');
  }

  // Akıllı Arama & Eşleşme Testi
  print('--- Akıllı Eşleşme Kontrolü ---');
  final testAramalar = [
    'Sarı Pas',
    'Tuta',
    'Zeytin Sineği',
    'Mildiyö',
    'Septoria',
    'Akar',
    'Külleme',
    'Sağlıklı'
  ];

  for (final t in testAramalar) {
    final sonuc = ZiraiReceteEngine.receteGetir(t);
    print('🔍 "$t" -> Eşleşti: ${sonuc.hastalikAdi}');
  }

  print('\nBitti.');
}
