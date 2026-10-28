import 'package:flutter/material.dart';
import '../../../core/services/hava_durumu_servisi.dart';

class ToprakAnaliziEntity {
  final String id;
  final String parselId;

  /// Yalnızca gün anlamlıdır.
  final DateTime analizTarihi;
  final String laboratuvar;

  /// Saturasyon (su ile doyma) %.
  final double? saturasyon;
  final double? ph;

  /// Toplam tuz %.
  final double? tuzYuzde;

  /// Elektriksel iletkenlik, dS/m (= mS/cm).
  final double? ec;

  /// Kireç (CaCO₃) %.
  final double? kirecYuzde;
  final double? organikMadde;

  /// P₂O₅ kg/dekar.
  final double? fosfor;

  /// K₂O kg/dekar.
  final double? potasyum;

  /// Çinko (DTPA) ppm.
  final double? cinko;
  final String not;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const ToprakAnaliziEntity({
    required this.id,
    required this.parselId,
    required this.analizTarihi,
    this.laboratuvar = '',
    this.saturasyon,
    this.ph,
    this.tuzYuzde,
    this.ec,
    this.kirecYuzde,
    this.organikMadde,
    this.fosfor,
    this.potasyum,
    this.cinko,
    this.not = '',
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  /// Hiç değer girilmemişse true.
  bool get bos => [saturasyon, ph, tuzYuzde, ec, kirecYuzde, organikMadde, fosfor, potasyum, cinko]
      .every((v) => v == null);
}

/// iyi: sorun yok, dikkat: izlenmeli/ürüne göre önlem, sorun: müdahale gerekir.
enum Durum {
  iyi(Color(0xFF16A34A)),
  dikkat(Color(0xFFD97706)),
  sorun(Color(0xFFDC2626));

  final Color renk;
  const Durum(this.renk);
}

class ParametreYorumu {
  final String ad;
  final String deger;
  final String sinif;
  final Durum durum;
  const ParametreYorumu(this.ad, this.deger, this.sinif, this.durum);
}

/// 12.5 → "12,5"; en fazla [basamak] ondalık.
String sayiYaz(double v, {int basamak = 2}) {
  var s = v.toStringAsFixed(basamak);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

/// "7,8" / "7.8" → 7.8; boş ya da geçersizse null.
double? sayiOku(String metin) => double.tryParse(metin.trim().replaceAll(',', '.'));

/// Bazı raporlar EC'yi µS/cm verir (ör. 850). dS/m'de 50'yi aşan değer gerçekçi değildir; çevrilir.
double ecDuzelt(double ec) => ec > 50 ? ec / 1000 : ec;

/// Ürün uygunluğu için tuzluluk (ECe, dS/m). EC girilmişse o; yoksa toplam tuz %'den
/// laboratuvarların kullandığı bağıntıyla (Tuz % = 0,064 × EC × Saturasyon / 100) geri hesaplanır.
/// Saturasyon yoksa tınlı toprak (%50) varsayılır.
double? tuzlulukEc(ToprakAnaliziEntity a) {
  if (a.ec != null) return ecDuzelt(a.ec!);
  final tuz = a.tuzYuzde;
  if (tuz == null) return null;
  final sat = a.saturasyon ?? 50;
  return tuz * 100 / (0.064 * sat);
}

/// Saturasyona göre bünye sınıfı.
String bunyeSinifi(double saturasyon) => saturasyon <= 30
    ? 'Kumlu'
    : saturasyon <= 50
        ? 'Tınlı'
        : saturasyon <= 70
            ? 'Killi'
            : 'Ağır killi';

/// Uygulamadaki tarla toprak türü karşılığı (Kumlu / Tınlı / Killi / Kireçli). Saturasyon yoksa null.
String? onerilenToprakTuru(ToprakAnaliziEntity a) {
  if ((a.kirecYuzde ?? 0) >= 15) return 'Kireçli';
  final s = a.saturasyon;
  if (s == null) return null;
  final b = bunyeSinifi(s);
  return b == 'Ağır killi' ? 'Killi' : b;
}

/// Saturasyondan su sabitleri (hacimsel, m³/m³).
///
/// Yaygın yaklaşım: tarla kapasitesi ≈ saturasyon / 2, solma noktası ≈ tarla kapasitesi / 2
/// (ağırlıkça %). Hacme çevirmek için bünyeye göre tipik hacim ağırlığı kullanılır.
ToprakSuSabitleri? analizdenSuSabitleri(ToprakAnaliziEntity? a) {
  final s = a?.saturasyon;
  if (s == null || s < 10 || s > 120) return null;
  final hacimAgirligi = switch (bunyeSinifi(s)) {
    'Kumlu' => 1.55,
    'Tınlı' => 1.40,
    'Killi' => 1.30,
    _ => 1.25,
  };
  final tk = (s / 2 / 100 * hacimAgirligi).clamp(0.08, 0.50);
  final sn = (s / 4 / 100 * hacimAgirligi).clamp(0.03, tk - 0.04);
  return ToprakSuSabitleri(tk, sn);
}

/// Laboratuvarların yaygın kullandığı yaklaşık sınıflara göre yorum (girilmemiş değerler atlanır).
List<ParametreYorumu> yorumla(ToprakAnaliziEntity a) {
  final y = <ParametreYorumu>[];

  final sat = a.saturasyon;
  if (sat != null) {
    y.add(ParametreYorumu('Bünye (saturasyon)', '%${sayiYaz(sat, basamak: 0)}', bunyeSinifi(sat),
        sat <= 30 || sat > 70 ? Durum.dikkat : Durum.iyi));
  }

  final ph = a.ph;
  if (ph != null) {
    final (sinif, durum) = ph < 4.5
        ? ('Kuvvetli asit', Durum.sorun)
        : ph < 5.5
            ? ('Orta asit', Durum.sorun)
            : ph < 6.5
                ? ('Hafif asit', Durum.iyi)
                : ph <= 7.5
                    ? ('Nötr', Durum.iyi)
                    : ph <= 8.5
                        ? ('Hafif alkali', Durum.dikkat)
                        : ('Kuvvetli alkali', Durum.sorun);
    y.add(ParametreYorumu('pH', sayiYaz(ph), sinif, durum));
  }

  final tuz = a.tuzYuzde;
  if (tuz != null) {
    final (sinif, durum) = tuz < 0.15
        ? ('Tuzsuz', Durum.iyi)
        : tuz < 0.35
            ? ('Hafif tuzlu', Durum.dikkat)
            : tuz < 0.65
                ? ('Orta tuzlu', Durum.sorun)
                : ('Çok tuzlu', Durum.sorun);
    y.add(ParametreYorumu('Toplam tuz', '%${sayiYaz(tuz, basamak: 3)}', sinif, durum));
  }

  final ec = a.ec == null ? null : ecDuzelt(a.ec!);
  if (ec != null) {
    final (sinif, durum) = ec < 4
        ? ('Tuzsuz', Durum.iyi)
        : ec < 8
            ? ('Hafif tuzlu', Durum.dikkat)
            : ec < 15
                ? ('Orta tuzlu', Durum.sorun)
                : ('Çok tuzlu', Durum.sorun);
    y.add(ParametreYorumu('Tuzluluk (EC)', '${sayiYaz(ec)} dS/m', sinif, durum));
  }

  final kirec = a.kirecYuzde;
  if (kirec != null) {
    final (sinif, durum) = kirec < 1
        ? ('Az kireçli', Durum.iyi)
        : kirec < 5
            ? ('Kireçli', Durum.iyi)
            : kirec < 15
                ? ('Orta kireçli', Durum.iyi)
                : kirec < 25
                    ? ('Fazla kireçli', Durum.dikkat)
                    : ('Çok fazla kireçli', Durum.sorun);
    y.add(ParametreYorumu('Kireç', '%${sayiYaz(kirec, basamak: 1)}', sinif, durum));
  }

  final om = a.organikMadde;
  if (om != null) {
    final (sinif, durum) = om < 1
        ? ('Çok az', Durum.sorun)
        : om < 2
            ? ('Az', Durum.dikkat)
            : om < 3
                ? ('Orta', Durum.iyi)
                : om < 4
                    ? ('İyi', Durum.iyi)
                    : ('Yüksek', Durum.iyi);
    y.add(ParametreYorumu('Organik madde', '%${sayiYaz(om)}', sinif, durum));
  }

  final p = a.fosfor;
  if (p != null) {
    final (sinif, durum) = p < 3
        ? ('Çok az', Durum.sorun)
        : p < 6
            ? ('Az', Durum.dikkat)
            : p < 9
                ? ('Orta', Durum.iyi)
                : p < 12
                    ? ('Yüksek', Durum.iyi)
                    : ('Çok yüksek', Durum.iyi);
    y.add(ParametreYorumu('Fosfor (P₂O₅)', '${sayiYaz(p, basamak: 1)} kg/da', sinif, durum));
  }

  final k = a.potasyum;
  if (k != null) {
    final (sinif, durum) = k < 20
        ? ('Az', Durum.dikkat)
        : k < 40
            ? ('Yeterli', Durum.iyi)
            : ('Yüksek', Durum.iyi);
    y.add(ParametreYorumu('Potasyum (K₂O)', '${sayiYaz(k, basamak: 1)} kg/da', sinif, durum));
  }

  final zn = a.cinko;
  if (zn != null) {
    final (sinif, durum) = zn < 0.5
        ? ('Eksik', Durum.sorun)
        : zn < 1
            ? ('Sınırda', Durum.dikkat)
            : ('Yeterli', Durum.iyi);
    y.add(ParametreYorumu('Çinko (Zn)', '${sayiYaz(zn)} ppm', sinif, durum));
  }
  return y;
}

/// Analize göre pratik öneriler. Kesin gübre miktarı vermez; o laboratuvarın/ziraat mühendisinin işi.
List<String> oneriler(ToprakAnaliziEntity a, DateTime bugun) {
  final o = <String>[];
  final ec = a.ec == null ? null : ecDuzelt(a.ec!);
  final tuzlu = (a.tuzYuzde ?? 0) >= 0.35 || (ec ?? 0) >= 8;
  final hafifTuzlu = !tuzlu && ((a.tuzYuzde ?? 0) >= 0.15 || (ec ?? 0) >= 4);

  if (tuzlu) {
    o.add('Tuzluluk verimi düşürür: tuza dayanıklı ürün (arpa, pamuk, şeker pancarı) seçin; '
        'bol suyla yıkama sulaması ve drenaj gerekir. Tuzlu kuyu suyuyla sulamayın.');
  } else if (hafifTuzlu) {
    o.add('Hafif tuzluluk: fasulye, mısır ve sebzelerde verim düşebilir. Sulamayı az ve sık değil, '
        'derin yapın; tuz birikimini izleyin.');
  }

  final ph = a.ph;
  if (ph != null && ph < 5.5) {
    o.add('Asit toprak: tarım kireci ile kireçleme gerekebilir; miktarı için laboratuvara danışın.');
  } else if (ph != null && ph > 8.5) {
    o.add('Kuvvetli alkali toprak: sodyum sorunu olabilir; jips (alçı taşı) uygulaması için ziraat mühendisine danışın.');
  }
  if ((ph != null && ph > 7.5) || (a.kirecYuzde ?? 0) >= 15) {
    o.add('Kireçli/alkali toprakta demir ve çinko alımı zorlaşır. Yapraklarda damarlar arası sararma görülürse '
        'demirli/çinkolu yaprak gübresi verin; azotta amonyum sülfat gibi asit karakterli gübreler daha uygundur.');
  }

  final om = a.organikMadde;
  if (om != null && om < 2) {
    o.add('Organik madde düşük: yanmış ahır gübresi verin, anızı yakmayıp toprağa karıştırın, '
        'baklagil (fiğ, nohut) ile ekim nöbeti yapın. Toprak suyu daha iyi tutar.');
  }

  final p = a.fosfor;
  if (p != null && p < 6) {
    o.add('Fosfor eksik: ekimle birlikte fosforlu taban gübresi (DAP, TSP ya da 20-20-0) verin.');
  } else if (p != null && p >= 12) {
    o.add('Fosfor bol: bu sezon fosforlu gübreyi azaltabilirsiniz, masraf düşer.');
  }

  final k = a.potasyum;
  if (k != null && k < 20) {
    o.add('Potasyum düşük: potasyumlu gübre (15-15-15, potasyum sülfat) verin; özellikle sebze, meyve ve pamukta önemli.');
  }

  final zn = a.cinko;
  if (zn != null && zn < 0.5) {
    o.add('Çinko eksik: çinkolu gübre (çinko sülfat ya da çinkolu kompoze) verin; buğday ve mısırda verimi belirgin artırır.');
  }

  if (bugun.difference(a.analizTarihi).inDays > 4 * 365) {
    o.add('Bu analiz 4 yıldan eski; toprak analizini 3-4 yılda bir yeniletin.');
  }
  return o;
}

/// Tarlanın en son tarihli analizi.
ToprakAnaliziEntity? sonAnaliz(Iterable<ToprakAnaliziEntity> analizler, String parselId) {
  ToprakAnaliziEntity? son;
  for (final a in analizler) {
    if (a.isDeleted || a.parselId != parselId) continue;
    if (son == null || a.analizTarihi.isAfter(son.analizTarihi)) son = a;
  }
  return son;
}
