import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';
import 'package:kayin_flutter/features/yaprak_hastalik_ai/data/datasources/tflite_yaprak_siniflandirici.dart';
import 'package:kayin_flutter/features/yaprak_hastalik_ai/domain/usecases/tflite_leaf_analyzer_usecase.dart';
import 'package:kayin_flutter/features/yaprak_hastalik_ai/domain/yaprak_etiket_eslestirici.dart';
import 'package:kayin_flutter/features/yaprak_hastalik_ai/domain/zirai_recete_engine.dart';

/// Gerçek model yerine sabit skor döndüren sahte sınıflandırıcı.
class _SahteSiniflandirici implements YaprakSiniflandirici {
  final bool hazir;
  final Map<String, double> skorlar;
  _SahteSiniflandirici(this.skorlar, {this.hazir = true});

  @override
  Future<bool> hazirMi() async => hazir;
  @override
  String? get yuklemeHatasi => hazir ? null : 'test: model yok';
  @override
  String get modelAdi => 'sahte_model';
  @override
  List<String> get etiketler => const [
        'Tomato___Late_blight',
        'Tomato___healthy',
        'Corn_(maize)___Common_rust_',
        'Corn_(maize)___healthy',
      ];
  @override
  Future<List<SinifTahmini>> siniflandir(String fotoYolu) async =>
      [for (final e in etiketler) SinifTahmini(e, skorlar[e] ?? 0)]..sort((a, b) => b.olasilik.compareTo(a.olasilik));
}

void main() {
  group('Teşhis motoru sahte sonuç üretmez', () {
    test('model yoksa teşhis yok, manuel moda düşer', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({}, hazir: false));
      final r = await uc.analyzeImage('x.jpg');
      expect(r.durum, AnalizDurumu.modelYok);
      expect(r.teshisAdi, isNull);
      expect(r.kaydedilebilir, isFalse);
    });

    test('aynı girdi her zaman aynı sonucu verir (rastgelelik yok)', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({'Tomato___Late_blight': 0.95, 'Tomato___healthy': 0.05}));
      final a = await uc.analyzeImage('a.jpg');
      final b = await uc.analyzeImage('baska_yol.jpg');
      expect(a.teshisAdi, b.teshisAdi);
      expect(a.guvenYuzdesi, b.guvenYuzdesi);
    });

    test('yüksek güvenli tahmin doğru reçeteye bağlanır', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({'Tomato___Late_blight': 0.95, 'Tomato___healthy': 0.05}));
      final r = await uc.analyzeImage('x.jpg');
      expect(r.durum, AnalizDurumu.teshis);
      expect(r.recete?.hastalikAdi, contains('Phytophthora'));
      expect(r.aciliyetSeviyesi, 'Kritik');
    });

    test('düşük güven belirsiz sayılır ve kaydedilmez', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({'Tomato___Late_blight': 0.55, 'Tomato___healthy': 0.45}));
      final r = await uc.analyzeImage('x.jpg');
      expect(r.durum, AnalizDurumu.belirsiz);
      expect(r.kaydedilebilir, isFalse);
      expect(r.alternatifler, isNotEmpty);
    });

    test('modelin tanımadığı tarla ürünü (Buğday) için uydurma teşhis yok', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({'Tomato___Late_blight': 0.99}));
      final r = await uc.analyzeImage('x.jpg', ekilmisUrun: 'Buğday');
      expect(r.durum, AnalizDurumu.desteklenmeyenUrun);
    });

    test('tarla ürünüyle uyuşmayan fotoğraf belirsiz sayılır', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({'Tomato___Late_blight': 0.9, 'Corn_(maize)___healthy': 0.1}));
      final r = await uc.analyzeImage('x.jpg', ekilmisUrun: 'Mısır');
      expect(r.durum, AnalizDurumu.belirsiz);
    });

    test('reçetesi olmayan hastalık başka ürünün reçetesine bağlanmaz', () async {
      final uc = TfliteLeafAnalyzerUseCase(_SahteSiniflandirici({'Corn_(maize)___Common_rust_': 0.97}));
      final r = await uc.analyzeImage('x.jpg', ekilmisUrun: 'Mısır');
      expect(r.durum, AnalizDurumu.teshis);
      expect(r.teshisAdi, contains('Mısır Pası'));
      expect(r.recete, isNull, reason: 'Buğday pası reçetesi mısıra önerilmemeli');
    });
  });

  group('Reçete arama', () {
    test('bilinmeyen teşhis için reçete null (Septorya fallback yok)', () {
      expect(ZiraiReceteEngine.receteBul('Tamamen Bilinmeyen Hastalık'), isNull);
      expect(ZiraiReceteEngine.receteBul(''), isNull);
    });

    test('tüm etiket eşleşmeleri gerçek reçete adlarına işaret eder', () {
      for (final e in const ['Tomato___Late_blight', 'Potato___Early_blight', 'Corn_(maize)___Northern_Leaf_Blight',
          'Tomato___Spider_mites Two-spotted_spider_mite', 'Grape___healthy']) {
        final b = YaprakEtiketEslestirici.coz(e);
        expect(YaprakEtiketEslestirici.receteBul(b), isNotNull, reason: e);
      }
    });

    test('paketteki modelin her etiketi uygulamadaki bir ürüne ve Türkçe teşhise bağlı', () {
      final etiketler = File('assets/models/labels.txt')
          .readAsLinesSync()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final siniflar = <String, List<EtiketBilgisi>>{};
      for (final e in etiketler) {
        final b = YaprakEtiketEslestirici.coz(e);
        expect(ParselEntity.urunSecenekleri, contains(b.bitki), reason: '$e tabloda yok ya da ürün adı yanlış');
        expect(b.teshis, isNot(contains('_')), reason: e);
        // Modelin tanıdığı her hastalığın reçetesi olmalı ("reçete yok, mühendise danışın" kalmasın).
        expect(b.receteAdi, isNotNull, reason: '$e için reçete yok');
        if (b.receteAdi != null) {
          expect(YaprakEtiketEslestirici.receteBul(b)?.hastalikAdi, b.receteAdi, reason: e);
          // Kayda teşhis adı yazılır; reçete ekranı reçeteyi o addan bulabilmeli.
          expect(YaprakEtiketEslestirici.teshisReceti(b.teshis)?.hastalikAdi, b.receteAdi, reason: e);
        }
        siniflar.putIfAbsent(b.bitki, () => []).add(b);
      }
      // Ürün başına hem sağlıklı hem hastalık sınıfı olmalı: sağlıklı sınıfı olmayan ürün
      // sağlıklı yaprağa da hastalık der, tek sınıflı ürün her fotoğrafa aynı cevabı verir.
      for (final MapEntry(key: urun, value: liste) in siniflar.entries) {
        expect(liste.any((b) => b.saglikli), isTrue, reason: '$urun: sağlıklı sınıfı yok');
        expect(liste.any((b) => !b.saglikli), isTrue, reason: '$urun: hastalık sınıfı yok');
      }
    });

    test('ürüne göre manuel liste doğru filtrelenir', () {
      final pamuk = ZiraiReceteEngine.urunIcinReceteler('Pamuk');
      expect(pamuk.any((r) => r.hastalikAdi.contains('Zeytin')), isFalse);
      expect(pamuk.last.hastalikAdi, contains('Sağlıklı'));
      final uzum = ZiraiReceteEngine.urunIcinReceteler('Üzüm');
      expect(uzum.any((r) => r.hastalikAdi.contains('Bağ')), isTrue);
    });
  });
}
