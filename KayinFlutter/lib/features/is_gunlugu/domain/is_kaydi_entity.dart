import 'package:flutter/material.dart';

/// İşlem türleri. Kod (ASCII) veritabanında ve sunucuda saklanır, ekranda [ad] gösterilir.
enum IslemTuru {
  ilaclama('Ilaclama', 'İlaçlama', Icons.science_rounded, Color(0xFF7C3AED)),
  gubreleme('Gubreleme', 'Gübreleme', Icons.eco_rounded, Color(0xFF0F766E)),
  sulama('Sulama', 'Sulama', Icons.water_drop_rounded, Color(0xFF0284C7)),
  ekim('Ekim', 'Ekim / Dikim', Icons.grass_rounded, Color(0xFF16A34A)),
  toprakIsleme('ToprakIsleme', 'Toprak İşleme', Icons.agriculture_rounded, Color(0xFF92400E)),
  hasat('Hasat', 'Hasat', Icons.inventory_2_rounded, Color(0xFFD97706)),
  diger('Diger', 'Diğer', Icons.more_horiz_rounded, Color(0xFF64748B));

  final String kod;
  final String ad;
  final IconData ikon;
  final Color renk;
  const IslemTuru(this.kod, this.ad, this.ikon, this.renk);

  static IslemTuru koddan(String kod) =>
      IslemTuru.values.firstWhere((t) => t.kod == kod, orElse: () => IslemTuru.diger);
}

/// İş günlüğü kaydı (bir tarlada yapılan iş).
class IsKaydiEntity {
  final String id;
  final String parselId;

  /// İşin yapıldığı an (UTC).
  final DateTime islemTarihi;
  final IslemTuru tur;

  /// İlaç / gübre / tohum adı — çiftçinin etiketten yazdığı.
  final String urunAdi;

  /// Miktar / doz, serbest metin (ör. "2 L/da").
  final String miktar;

  /// Ürün etiketindeki hasat öncesi bekleme süresi (gün). Yalnızca ilaçlamada.
  final int? hasatBeklemeGun;

  /// Hasat edilen ürün (kg). Yalnızca hasatta.
  final double? hasatKg;
  final String not;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const IsKaydiEntity({
    required this.id,
    required this.parselId,
    required this.islemTarihi,
    required this.tur,
    this.urunAdi = '',
    this.miktar = '',
    this.hasatBeklemeGun,
    this.hasatKg,
    this.not = '',
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  /// Bu ilaçlamadan sonra hasadın yapılabileceği ilk gün (yerel tarih). Bekleme yoksa null.
  DateTime? get hasatSerbestTarihi {
    final gun = hasatBeklemeGun;
    if (tur != IslemTuru.ilaclama || gun == null || gun <= 0) return null;
    final yerel = islemTarihi.toLocal();
    return DateTime(yerel.year, yerel.month, yerel.day + gun);
  }
}

/// 850 → "850 kg", 12500 → "12,5 ton".
String miktarMetni(double kg) {
  if (kg < 1000) return '${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1).replaceAll('.', ',')} kg';
  final ton = kg / 1000;
  return '${ton.toStringAsFixed(ton == ton.roundToDouble() ? 0 : 1).replaceAll('.', ',')} ton';
}

/// Bir tarlada hâlâ süren hasat öncesi bekleme.
class HasatYasagi {
  final String parselId;
  final DateTime serbestTarih;
  final int kalanGun;
  final IsKaydiEntity kaynak;

  const HasatYasagi({
    required this.parselId,
    required this.serbestTarih,
    required this.kalanGun,
    required this.kaynak,
  });
}

/// Her tarla için hâlâ süren en uzun bekleme (son biten). Bekleme bitmiş ya da hiç
/// ilaçlama yoksa o tarla sonuçta yer almaz. [bugun] yerel tarihtir.
Map<String, HasatYasagi> aktifHasatYasaklari(Iterable<IsKaydiEntity> kayitlar, DateTime bugun) {
  final gun = DateUtils.dateOnly(bugun);
  final sonuc = <String, HasatYasagi>{};
  for (final k in kayitlar) {
    if (k.isDeleted) continue;
    final serbest = k.hasatSerbestTarihi;
    if (serbest == null || !serbest.isAfter(gun)) continue;
    final mevcut = sonuc[k.parselId];
    if (mevcut == null || serbest.isAfter(mevcut.serbestTarih)) {
      sonuc[k.parselId] = HasatYasagi(
        parselId: k.parselId,
        serbestTarih: serbest,
        kalanGun: serbest.difference(gun).inDays,
        kaynak: k,
      );
    }
  }
  return sonuc;
}
