import 'package:flutter/material.dart';

/// Sulama yöntemi. [randiman]: verilen suyun bitkiye ulaşan oranı (FAO 24 / 56 tipik değerleri);
/// geri kalanı buharlaşma, rüzgar sürüklenmesi, yüzey akışı ve derine sızmayla kaybolur.
enum SulamaYontemi {
  damla('Damla', 'Damla', 0.90, Icons.water_drop_outlined),
  yagmurlama('Yagmurlama', 'Yağmurlama', 0.75, Icons.shower_rounded),
  salma('Salma', 'Salma (karık / tava)', 0.55, Icons.waves_rounded);

  final String kod;
  final String ad;
  final double randiman;
  final IconData ikon;
  const SulamaYontemi(this.kod, this.ad, this.randiman, this.ikon);

  static SulamaYontemi? koddan(String? kod) => SulamaYontemi.values.where((y) => y.kod == kod).firstOrNull;
}

enum SuKaynagi {
  kuyu('Kuyu', 'Kuyu (sondaj)'),
  kanal('Kanal', 'Kanal (DSİ / sulama birliği)'),
  dere('Dere', 'Dere / ırmak'),
  golet('Golet', 'Gölet / havuz');

  final String kod;
  final String ad;
  const SuKaynagi(this.kod, this.ad);

  static SuKaynagi? koddan(String? kod) => SuKaynagi.values.where((k) => k.kod == kod).firstOrNull;
}

/// Sulama suyu tuzluluğu (FAO 29) sınıfı.
enum SuTuzSinifi {
  sorunsuz('Sorunsuz', 'Kullanımda kısıt yok'),
  hafif('Hafif-orta tuzlu', 'Tuza hassas ürünlerde verim düşebilir; yıkama suyu verin'),
  ciddi('Çok tuzlu', 'Ciddi kısıt: yalnız tuza dayanıklı ürün, bol yıkama ve iyi drenaj');

  final String ad;
  final String aciklama;
  const SuTuzSinifi(this.ad, this.aciklama);

  static SuTuzSinifi icin(double ecw) => ecw < 0.7 ? sorunsuz : (ecw <= 3.0 ? hafif : ciddi);
}

/// Laboratuvar raporları su EC'sini çoğu zaman µS/cm verir (ör. 850); 20'yi aşan değer dS/m'ye çevrilir.
double suEcDuzelt(double ec) => ec > 20 ? ec / 1000 : ec;

/// Bu suyla yıllarca sulanan toprağın ulaşacağı yaklaşık tuzluluk (ECe ≈ 1,5 × ECw; FAO 29,
/// %15-20 yıkama oranında). Toprak analizi bundan yüksekse o geçerlidir.
double beklenenToprakEc(double ecw) => 1.5 * ecw;

/// Yıkama ihtiyacı (FAO 29): suyun bu oranı, tuzu kök bölgesinin altına itmek için fazladan verilmelidir.
/// [esik]: ürünün verim kaybı başlamadan dayanabildiği toprak tuzluluğu (ECe, dS/m),
/// [egim]: eşiğin üstünde her dS/m için verim kaybı (%).
/// Salma/yağmurlama: LR = ECw / (5·eşik − ECw). Damla: LR = ECw / (2·maks ECe), maks ECe = %100 kayıp
/// tuzluluğu (eşik + 100/eğim); damlada tuz ıslak bölgenin kenarına itildiği için ihtiyaç düşüktür.
double yikamaIhtiyaci(double ecw, double esik, double egim, {SulamaYontemi? yontem}) {
  if (ecw <= 0) return 0;
  final payda = yontem == SulamaYontemi.damla ? 2 * (esik + 100 / egim) : 5 * esik - ecw;
  if (payda <= 0) return 0.5;
  return (ecw / payda).clamp(0.0, 0.5);
}

/// Brüt su: toprağa gereken net su ÷ yöntem randımanı. Yöntem bilinmiyorsa net su döner.
double brutSu(double netTonDonum, SulamaYontemi? yontem) => yontem == null ? netTonDonum : netTonDonum / yontem.randiman;

/// Sulama yöntemine ve kaynağa göre kısa uygulama notları.
List<String> sulamaNotlari(SulamaYontemi? yontem, SuKaynagi? kaynak, {double? ruzgarKm, double? maksSicaklik}) {
  final n = <String>[];
  switch (yontem) {
    case SulamaYontemi.damla:
      n.add('Damlada suyu tek seferde değil, 2-3 güne bölerek verin; kök bölgesi sürekli nemli kalır.');
    case SulamaYontemi.yagmurlama:
      if (ruzgarKm != null && ruzgarKm > 15) {
        n.add('Rüzgar ${ruzgarKm.toStringAsFixed(0)} km/s: yağmurlamada su savrulur, akşam ya da sabah erken sulayın.');
      } else if (maksSicaklik != null && maksSicaklik >= 30) {
        n.add('Gündüz sıcağında yağmurlama suyunun bir kısmı buharlaşır; akşam ya da gece sulayın.');
      } else {
        n.add('Yağmurlamayı rüzgarsız saatlerde (akşam / sabah erken) yapın.');
      }
    case SulamaYontemi.salma:
      n.add('Salmada kayıp yüksektir; karık boylarını kısa tutmak ve tesviye suyu ciddi ölçüde azaltır. Basınçlı sulamaya (damla/yağmurlama) geçiş için hibe ve faizsiz kredi programları var; il tarım müdürlüğüne sorun.');
    case null:
      break;
  }
  switch (kaynak) {
    case SuKaynagi.kuyu:
      n.add('Kuyu suyunda tuz birikimi olabilir; suyun tuzluluğunu (EC) yılda bir ölçtürün. Elektrik maliyeti için gece tarifesinde sulayın.');
    case SuKaynagi.kanal:
      n.add('Kanal suyu sulama birliğinin sıra/program günlerine göre gelir; sulamayı su gününüze göre planlayın.');
    case SuKaynagi.dere:
    case SuKaynagi.golet:
      n.add('Yaz sonunda su azalabilir; kritik dönem (çiçeklenme / dane dolumu) için su ayırın.');
    case null:
      break;
  }
  return n;
}
