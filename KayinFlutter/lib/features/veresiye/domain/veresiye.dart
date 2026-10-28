import 'package:flutter/material.dart';

enum CariTuru {
  bayi('Bayi', 'Bayi', Icons.storefront_rounded),
  tuccar('Tuccar', 'Tüccar', Icons.local_shipping_rounded),
  kooperatif('Kooperatif', 'Kooperatif', Icons.account_balance_rounded),
  kisi('Kisi', 'Kişi', Icons.person_rounded);

  final String kod;
  final String ad;
  final IconData ikon;
  const CariTuru(this.kod, this.ad, this.ikon);

  static CariTuru koddan(String kod) =>
      CariTuru.values.firstWhere((t) => t.kod == kod, orElse: () => CariTuru.bayi);
}

/// Hareket türü. [borcEtkisi]: bakiyeye etkisi (+ = borcum artar / alacağım azalır).
enum HareketTuru {
  veresiye('Veresiye', 'Veresiye aldım', 'Borcum arttı', 1, Icons.shopping_cart_rounded, Color(0xFFDC2626)),
  odeme('Odeme', 'Ödeme yaptım', 'Borcum azaldı', -1, Icons.payments_rounded, Color(0xFF16A34A)),
  satis('Satis', 'Veresiye sattım', 'Alacağım arttı', -1, Icons.sell_rounded, Color(0xFF2563EB)),
  tahsilat('Tahsilat', 'Tahsil ettim', 'Alacağım azaldı', 1, Icons.savings_rounded, Color(0xFF0D9488));

  final String kod;
  final String ad;
  final String aciklama;
  final int borcEtkisi;
  final IconData ikon;
  final Color renk;
  const HareketTuru(this.kod, this.ad, this.aciklama, this.borcEtkisi, this.ikon, this.renk);

  /// Vadesi olabilen (borç ya da alacak doğuran) hareket.
  bool get borcDogurur => this == veresiye || this == satis;

  static HareketTuru koddan(String kod) =>
      HareketTuru.values.firstWhere((t) => t.kod == kod, orElse: () => HareketTuru.veresiye);
}

class CariEntity {
  final String id;
  final String ad;
  final CariTuru tur;
  final String telefon;
  final String not;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const CariEntity({
    required this.id,
    required this.ad,
    this.tur = CariTuru.bayi,
    this.telefon = '',
    this.not = '',
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });
}

class CariHareketEntity {
  final String id;
  final String cariId;
  final DateTime islemTarihi;
  final HareketTuru tur;

  /// Her zaman pozitif; yönü [tur] belirler.
  final double tutar;
  final DateTime? vadeTarihi;
  final String aciklama;

  /// Bu hareketle birlikte açılan muhasebe kaydı (gider/gelir), varsa.
  final String? muhasebeKaydiId;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const CariHareketEntity({
    required this.id,
    required this.cariId,
    required this.islemTarihi,
    required this.tur,
    required this.tutar,
    this.vadeTarihi,
    this.aciklama = '',
    this.muhasebeKaydiId,
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });
}

/// Bir hesabın durumu. [bakiye] > 0: ben borçluyum, < 0: o bana borçlu.
class CariDurumu {
  final double bakiye;

  /// Vadesi geçmiş ve hâlâ ödenmemiş tutar (borç tarafında ya da alacak tarafında).
  final double vadesiGecen;

  /// En yakın gelecek vade (ödenmemiş kısmı olan), yoksa null.
  final DateTime? yaklasanVade;

  const CariDurumu({required this.bakiye, required this.vadesiGecen, this.yaklasanVade});

  bool get borcluyum => bakiye > 0.005;
  bool get alacakliyim => bakiye < -0.005;
}

/// Ödenmemiş kısmı olan vadeli bir borç/alacak.
class AcikVade {
  /// Yerel gün (saat yok).
  final DateTime vade;
  final double acik;

  /// true: ben borçluyum (veresiye aldım), false: bana borçlu (veresiye sattım).
  final bool borcum;
  const AcikVade(this.vade, this.acik, this.borcum);
}

/// Ödenmemiş kısmı kalan vadeli borç ve alacaklar, aynı gündekiler birleştirilmiş, vadeye göre sıralı.
///
/// Ödemeler önce vadesi en erken olan borcu kapatır (vadesiz borçlar en sona); böylece
/// açık kalan = ödemelerle kapanmayan kısım. Alacak tarafı (satış/tahsilat) aynı kuralla ayrıca hesaplanır.
List<AcikVade> acikVadeler(Iterable<CariHareketEntity> hareketler) {
  final aktif = hareketler.where((h) => !h.isDeleted).toList();

  List<AcikVade> taraf(HareketTuru dogan, HareketTuru kapatan) {
    final borclar = aktif.where((h) => h.tur == dogan).toList()
      ..sort((a, b) {
        final va = a.vadeTarihi, vb = b.vadeTarihi;
        if (va == null && vb == null) return a.islemTarihi.compareTo(b.islemTarihi);
        if (va == null) return 1;
        if (vb == null) return -1;
        return va.compareTo(vb);
      });
    var kalanOdeme = aktif.where((h) => h.tur == kapatan).fold(0.0, (s, h) => s + h.tutar);
    final gunler = <DateTime, double>{};
    for (final b in borclar) {
      final kapanan = kalanOdeme >= b.tutar ? b.tutar : kalanOdeme;
      kalanOdeme -= kapanan;
      final acik = b.tutar - kapanan;
      if (acik <= 0.005 || b.vadeTarihi == null) continue;
      final vade = DateUtils.dateOnly(b.vadeTarihi!.toLocal());
      gunler[vade] = (gunler[vade] ?? 0) + acik;
    }
    return [for (final e in gunler.entries) AcikVade(e.key, e.value, dogan == HareketTuru.veresiye)];
  }

  return [
    ...taraf(HareketTuru.veresiye, HareketTuru.odeme),
    ...taraf(HareketTuru.satis, HareketTuru.tahsilat),
  ]..sort((a, b) => a.vade.compareTo(b.vade));
}

/// Hesap durumu: bakiye, vadesi geçen tutar ve en yakın vade (kural için bkz. [acikVadeler]).
CariDurumu cariDurumu(Iterable<CariHareketEntity> hareketler, DateTime bugun) {
  final gun = DateUtils.dateOnly(bugun);
  var bakiye = 0.0;
  for (final h in hareketler.where((h) => !h.isDeleted)) {
    bakiye += h.tur.borcEtkisi * h.tutar;
  }

  var gecen = 0.0;
  DateTime? yaklasan;
  for (final v in acikVadeler(hareketler)) {
    if (v.vade.isBefore(gun)) {
      gecen += v.acik;
    } else {
      yaklasan ??= v.vade;
    }
  }
  return CariDurumu(bakiye: bakiye, vadesiGecen: gecen, yaklasanVade: yaklasan);
}
