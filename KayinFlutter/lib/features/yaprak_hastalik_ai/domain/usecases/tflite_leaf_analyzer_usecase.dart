import 'dart:convert';

import '../../data/datasources/tflite_yaprak_siniflandirici.dart';
import '../yaprak_etiket_eslestirici.dart';
import '../zirai_recete_engine.dart';

enum AnalizDurumu {
  /// Model güvenilir bir teşhis üretti.
  teshis,

  /// Model çalıştı ama emin değil (düşük güven veya tarla ürünüyle uyuşmuyor).
  belirsiz,

  /// Model dosyası yok / yüklenemedi → kullanıcı manuel seçmeli.
  modelYok,

  /// Tarladaki ürün modelin tanıdığı bitkiler arasında değil → manuel seçim.
  desteklenmeyenUrun,
}

class LeafAnalysisResult {
  final AnalizDurumu durum;
  final String? tespitEdilenBitki;
  final String? teshisAdi;
  final double guvenYuzdesi;
  final String aciliyetSeviyesi;
  final ZiraiRecete? recete;
  final String olasiliklarJson;
  final String modelVersionu;

  /// Kullanıcıya gösterilecek açıklama (neden belirsiz / neden manuel vb.).
  final String mesaj;

  /// En olası ilk 3 teşhis (belirsiz durumda kullanıcıya gösterilir).
  final List<({String teshis, String bitki, double yuzde})> alternatifler;

  const LeafAnalysisResult({
    required this.durum,
    this.tespitEdilenBitki,
    this.teshisAdi,
    this.guvenYuzdesi = 0,
    this.aciliyetSeviyesi = 'Dikkat',
    this.recete,
    this.olasiliklarJson = '[]',
    this.modelVersionu = '',
    this.mesaj = '',
    this.alternatifler = const [],
  });

  bool get kaydedilebilir => durum == AnalizDurumu.teshis;
}

/// Cihaz üzerinde (offline) yaprak fotoğrafından hastalık teşhisi.
/// Model yoksa veya emin değilse ASLA uydurma teşhis üretmez.
class TfliteLeafAnalyzerUseCase {
  /// Bu güvenin altındaki tahminler "belirsiz" sayılır.
  /// Not: Sınıflandırıcı yaprak olmayan fotoğraflara da bir sınıf atar (ör. oda fotoğrafı
  /// → %60 "Domates Erken Yanıklık"). Bu yüzden eşik yüksek tutuldu.
  static const double minGuven = 0.80;

  /// Tarla ürünü verildiğinde, olasılığın en az bu kadarı o ürüne ait sınıflarda olmalı.
  static const double minUrunKitlesi = 0.50;

  final YaprakSiniflandirici _siniflandirici;

  TfliteLeafAnalyzerUseCase([YaprakSiniflandirici? s])
      : _siniflandirici = s ?? TfliteYaprakSiniflandirici.instance;

  Future<bool> modelHazirMi() => _siniflandirici.hazirMi();
  String? get modelHatasi => _siniflandirici.yuklemeHatasi;

  Future<LeafAnalysisResult> analyzeImage(String imagePath, {String? ekilmisUrun}) async {
    if (!await _siniflandirici.hazirMi()) {
      return LeafAnalysisResult(
        durum: AnalizDurumu.modelYok,
        mesaj: 'Cihazda teşhis modeli yüklü değil. Belirtiyi listeden kendiniz seçebilirsiniz.\n'
            '(${_siniflandirici.yuklemeHatasi ?? 'bilinmeyen hata'})',
      );
    }

    final urun = (ekilmisUrun == null || ekilmisUrun.trim().isEmpty) ? null : ekilmisUrun.trim();
    if (urun != null) {
      final destekli = YaprakEtiketEslestirici.destekliBitkiler(_siniflandirici.etiketler);
      if (!destekli.any((b) => YaprakEtiketEslestirici.ayniBitki(urun, b))) {
        return LeafAnalysisResult(
          durum: AnalizDurumu.desteklenmeyenUrun,
          mesaj: 'Mevcut model "$urun" hastalıklarını tanımıyor '
              '(desteklenenler: ${destekli.join(', ')}). Belirtiyi listeden seçebilirsiniz.',
        );
      }
    }

    final tahminler = await _siniflandirici.siniflandir(imagePath);
    final olasiliklarJson = jsonEncode([
      for (final t in tahminler.take(5)) {'label': t.etiket, 'score': t.olasilik},
    ]);

    // Tarla ürünü biliniyorsa sadece o ürünün sınıflarını değerlendir.
    var adaylar = tahminler;
    var kitle = 1.0;
    if (urun != null) {
      adaylar = tahminler
          .where((t) => YaprakEtiketEslestirici.ayniBitki(urun, YaprakEtiketEslestirici.coz(t.etiket).bitki))
          .toList();
      kitle = adaylar.fold<double>(0, (a, t) => a + t.olasilik);
    }

    final alternatifler = [
      for (final t in (urun != null && kitle >= minUrunKitlesi ? adaylar : tahminler).take(3))
        (
          teshis: YaprakEtiketEslestirici.coz(t.etiket).teshis,
          bitki: YaprakEtiketEslestirici.coz(t.etiket).bitki,
          yuzde: (urun != null && kitle >= minUrunKitlesi ? t.olasilik / kitle : t.olasilik) * 100,
        ),
    ];

    if (urun != null && kitle < minUrunKitlesi) {
      final enIyi = YaprakEtiketEslestirici.coz(tahminler.first.etiket);
      return LeafAnalysisResult(
        durum: AnalizDurumu.belirsiz,
        olasiliklarJson: olasiliklarJson,
        modelVersionu: _siniflandirici.modelAdi,
        mesaj: 'Fotoğraf "$urun" yaprağına benzemiyor (model ${enIyi.bitki} olarak gördü). '
            'Tek bir yaprağı yakından, düz zeminde ve gün ışığında tekrar çekin.',
        alternatifler: alternatifler,
      );
    }

    final enIyi = adaylar.first;
    final guven = enIyi.olasilik / kitle;
    final bilgi = YaprakEtiketEslestirici.coz(enIyi.etiket);

    if (guven < minGuven) {
      return LeafAnalysisResult(
        durum: AnalizDurumu.belirsiz,
        tespitEdilenBitki: bilgi.bitki,
        olasiliklarJson: olasiliklarJson,
        modelVersionu: _siniflandirici.modelAdi,
        guvenYuzdesi: guven * 100,
        mesaj: 'Model emin değil (%${(guven * 100).toStringAsFixed(0)}). '
            'Tek bir yaprağı yakından ve net çekip tekrar deneyin.',
        alternatifler: alternatifler,
      );
    }

    final recete = YaprakEtiketEslestirici.receteBul(bilgi);
    return LeafAnalysisResult(
      durum: AnalizDurumu.teshis,
      tespitEdilenBitki: bilgi.bitki,
      teshisAdi: bilgi.teshis,
      guvenYuzdesi: guven * 100,
      aciliyetSeviyesi: aciliyetHesapla(saglikli: bilgi.saglikli, recete: recete),
      recete: recete,
      olasiliklarJson: olasiliklarJson,
      modelVersionu: _siniflandirici.modelAdi,
      mesaj: recete == null && !bilgi.saglikli
          ? 'Bu hastalık için reçete veritabanında kayıt yok; ilaçlama öncesi ziraat mühendisine danışın.'
          : '',
      alternatifler: alternatifler,
    );
  }

  static String aciliyetHesapla({required bool saglikli, ZiraiRecete? recete}) {
    if (saglikli) return 'Düşük';
    final t = recete?.tehlikeSeviyesi ?? '';
    if (t.contains('Yüksek') || t.contains('Kritik') || t.contains('Acil')) return 'Kritik';
    return 'Dikkat';
  }
}
