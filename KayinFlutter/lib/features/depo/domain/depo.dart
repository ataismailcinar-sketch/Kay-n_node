import 'package:flutter/material.dart';
import '../../is_gunlugu/domain/is_kaydi_entity.dart';

/// Depo kalemi kategorisi (muhasebe kategori kodlarıyla aynı).
enum StokKategori {
  gubre('Gubre', 'Gübre', Icons.eco_rounded, Color(0xFF0F766E)),
  ilac('Ilac', 'İlaç', Icons.science_rounded, Color(0xFF7C3AED)),
  tohum('Tohum', 'Tohum', Icons.grass_rounded, Color(0xFF16A34A)),
  mazot('Mazot', 'Mazot', Icons.local_gas_station_rounded, Color(0xFFD84315)),
  diger('Diger', 'Diğer', Icons.inventory_2_rounded, Color(0xFF64748B));

  final String kod;
  final String ad;
  final IconData ikon;
  final Color renk;
  const StokKategori(this.kod, this.ad, this.ikon, this.renk);

  static StokKategori koddan(String kod) =>
      StokKategori.values.firstWhere((k) => k.kod == kod, orElse: () => StokKategori.diger);

  /// İş günlüğünde bu işlemde kullanılan girdi kategorisi (depodan düşme için). Yoksa null.
  static StokKategori? isIcin(IslemTuru tur) => switch (tur) {
        IslemTuru.ilaclama => StokKategori.ilac,
        IslemTuru.gubreleme => StokKategori.gubre,
        IslemTuru.ekim => StokKategori.tohum,
        _ => null,
      };
}

/// Sık kullanılan birimler. Kod olarak doğrudan saklanır.
const stokBirimleri = ['kg', 'L', 'çuval', 'adet', 'ton'];

enum StokHareketTuru {
  giris('Giris', 'Depoya giriş', Icons.add_circle_rounded, Color(0xFF16A34A)),
  cikis('Cikis', 'Kullandım', Icons.remove_circle_rounded, Color(0xFFDC2626)),
  duzeltme('Duzeltme', 'Sayım düzeltmesi', Icons.fact_check_rounded, Color(0xFF2563EB));

  final String kod;
  final String ad;
  final IconData ikon;
  final Color renk;
  const StokHareketTuru(this.kod, this.ad, this.ikon, this.renk);

  static StokHareketTuru koddan(String kod) =>
      StokHareketTuru.values.firstWhere((t) => t.kod == kod, orElse: () => StokHareketTuru.giris);
}

class StokKalemiEntity {
  final String id;
  final String ad;
  final StokKategori kategori;
  final String birim;

  /// Mevcut bunun altına inince "azaldı" uyarısı. Null = uyarı yok.
  final double? kritikSeviye;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const StokKalemiEntity({
    required this.id,
    required this.ad,
    this.kategori = StokKategori.diger,
    this.birim = 'kg',
    this.kritikSeviye,
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });
}

class StokHareketiEntity {
  final String id;
  final String kalemId;
  final DateTime islemTarihi;
  final StokHareketTuru tur;

  /// Giriş/çıkışta pozitif; düzeltmede işaretli (sayım − mevcut).
  final double miktar;
  final String aciklama;

  /// Bu çıkışı oluşturan iş günlüğü kaydı, varsa.
  final String? isKaydiId;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const StokHareketiEntity({
    required this.id,
    required this.kalemId,
    required this.islemTarihi,
    required this.tur,
    required this.miktar,
    this.aciklama = '',
    this.isKaydiId,
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  /// Mevcut miktara etkisi.
  double get etki => switch (tur) {
        StokHareketTuru.giris => miktar,
        StokHareketTuru.cikis => -miktar,
        StokHareketTuru.duzeltme => miktar,
      };
}

/// Silinmemiş hareketlerden mevcut miktar.
double mevcutMiktar(Iterable<StokHareketiEntity> hareketler) =>
    hareketler.where((h) => !h.isDeleted).fold(0.0, (s, h) => s + h.etki);

/// Sayımda bulunan miktarı mevcuda eşitleyecek düzeltme (işaretli). Fark yoksa 0.
double sayimFarki({required double mevcut, required double sayilan}) => sayilan - mevcut;

/// Kritik seviye tanımlı ve mevcut onun altındaysa (ya da eksiye düştüyse) true.
bool azaldiMi(StokKalemiEntity k, double mevcut) =>
    mevcut < 0 || (k.kritikSeviye != null && mevcut < k.kritikSeviye!);

/// 12.5 → "12,5", 20.0 → "20".
String miktarYaz(double v) {
  final yuvarlak = (v * 100).round() / 100;
  return (yuvarlak == yuvarlak.roundToDouble() ? yuvarlak.toStringAsFixed(0) : yuvarlak.toString()).replaceAll('.', ',');
}

/// "12,5" / "12.5" → 12.5. Geçersizse null.
double? miktarOku(String metin) => double.tryParse(metin.trim().replaceAll(',', '.'));
