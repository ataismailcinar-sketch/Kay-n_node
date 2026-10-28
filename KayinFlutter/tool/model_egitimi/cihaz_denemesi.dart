// Paketteki yaprak modelini gerçek cihazda/emülatörde, uygulamanın kendi
// sınıflandırıcısıyla çalıştırır ve sonuçları log'a yazar.
//
// Hazırlık: adb push <klasör>/. /data/local/tmp/kayin_test/  (dosya adı = beklenen etiket)
// Çalıştırma: flutter run -t tool/model_egitimi/cihaz_denemesi.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kayin_flutter/features/yaprak_hastalik_ai/data/datasources/tflite_yaprak_siniflandirici.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Model denemesi…')))));

  final s = TfliteYaprakSiniflandirici.instance;
  if (!await s.hazirMi()) {
    debugPrint('DENEME HATA ${s.yuklemeHatasi}');
    exit(1);
  }
  final dosyalar = Directory('/data/local/tmp/kayin_test').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  var dogru = 0;
  final sure = Stopwatch()..start();
  for (final f in dosyalar) {
    final beklenen = f.uri.pathSegments.last.replaceAll('.jpg', '');
    final t = (await s.siniflandir(f.path)).first;
    if (t.etiket == beklenen) dogru++;
    debugPrint('DENEME ${t.etiket == beklenen ? 'OK ' : 'YANLIS'} $beklenen -> ${t.etiket} '
        '%${(t.olasilik * 100).toStringAsFixed(1)}');
  }
  debugPrint('DENEME SONUC ${s.modelAdi}: $dogru/${dosyalar.length} doğru, '
      'foto başı ${sure.elapsedMilliseconds ~/ dosyalar.length} ms');
  exit(0);
}
