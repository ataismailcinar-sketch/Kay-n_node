import 'package:flutter/material.dart' show DateUtils;
import '../../is_gunlugu/domain/is_kaydi_entity.dart';
import '../../klavyesiz_muhasebe/domain/entities/gider_entity.dart';
import '../../parsel_harita/domain/entities/parsel_entity.dart';

/// Karnenin kapsadığı dönem (yerel tarih, iki uç dahil).
class Donem {
  final String ad;
  final DateTime bas;
  final DateTime son;

  Donem(this.ad, DateTime bas, DateTime son)
      : bas = DateUtils.dateOnly(bas),
        son = DateUtils.dateOnly(son);

  /// Bugün dahil geriye 12 ay — bir ürün döngüsünü (ekimden hasada) çoğunlukla kapsar.
  factory Donem.son12Ay(DateTime bugun) =>
      Donem('Son 12 ay', DateTime(bugun.year - 1, bugun.month, bugun.day + 1), bugun);

  factory Donem.yil(int yil) => Donem('$yil', DateTime(yil, 1, 1), DateTime(yil, 12, 31));

  bool icerir(DateTime an) {
    final gun = DateUtils.dateOnly(an.toLocal());
    return !gun.isBefore(bas) && !gun.isAfter(son);
  }
}

/// Bir tarlanın dönem karnesi. Tutarlar TL.
class TarlaKarnesi {
  final ParselEntity parsel;
  final double hasatKg;

  /// Tarlaya yazılan giderler/gelirler.
  final double dogrudanGider;
  final double dogrudanGelir;

  /// Tarlaya yazılmamış (genel) gider/gelirden alan oranında düşen pay.
  final double genelGiderPayi;
  final double genelGelirPayi;

  const TarlaKarnesi({
    required this.parsel,
    required this.hasatKg,
    required this.dogrudanGider,
    required this.dogrudanGelir,
    required this.genelGiderPayi,
    required this.genelGelirPayi,
  });

  double get alan => parsel.alanDonumCinsinden;
  double get gider => dogrudanGider + genelGiderPayi;
  double get gelir => dogrudanGelir + genelGelirPayi;
  double get netKar => gelir - gider;

  /// kg/dönüm. Hasat ya da alan yoksa null.
  double? get verimKgDa => hasatKg > 0 && alan > 0 ? hasatKg / alan : null;
  double? get maliyetTlDa => alan > 0 ? gider / alan : null;
  double? get karTlDa => alan > 0 ? netKar / alan : null;

  /// 1 kg ürünün maliyeti — satış fiyatıyla kıyaslanacak asıl sayı. Hasat yoksa null.
  double? get maliyetTlKg => hasatKg > 0 ? gider / hasatKg : null;

  /// Hasat var ama satış geliri yok: kâr eksik görünür (ürün depoda olabilir).
  bool get satisGirilmemis => hasatKg > 0 && dogrudanGelir == 0;
}

class CiftlikKarnesi {
  final Donem donem;
  final List<TarlaKarnesi> tarlalar;

  /// Hiçbir tarlaya dağıtılamayan tutarlar (ör. alanı 0 olan tek tarla).
  final double dagitilamayanGider;
  final double dagitilamayanGelir;
  final double genelGider;
  final double genelGelir;

  const CiftlikKarnesi({
    required this.donem,
    required this.tarlalar,
    required this.genelGider,
    required this.genelGelir,
    this.dagitilamayanGider = 0,
    this.dagitilamayanGelir = 0,
  });

  double get toplamAlan => tarlalar.fold(0.0, (s, t) => s + t.alan);
  double get toplamHasatKg => tarlalar.fold(0.0, (s, t) => s + t.hasatKg);
  double get toplamGider => tarlalar.fold(0.0, (s, t) => s + t.gider) + dagitilamayanGider;
  double get toplamGelir => tarlalar.fold(0.0, (s, t) => s + t.gelir) + dagitilamayanGelir;
  double get netKar => toplamGelir - toplamGider;
  double? get maliyetTlDa => toplamAlan > 0 ? toplamGider / toplamAlan : null;
  double? get karTlDa => toplamAlan > 0 ? netKar / toplamAlan : null;
}

/// Karne hesabı.
///
/// - Yalnızca [donem] içindeki silinmemiş kayıtlar sayılır.
/// - Tarlaya bağlı olmayan (ya da silinmiş tarlaya bağlı) gider ve gelirler "genel" sayılır
///   ve tarlalara alanları oranında dağıtılır; böylece tarla kârlarının toplamı çiftlik
///   kârına eşit olur. (Mazot, kira, alan bazlı destek gibi kalemler genelde böyledir.)
/// - Hasat miktarı iş günlüğündeki "Hasat" kayıtlarından toplanır.
CiftlikKarnesi karneHesapla({
  required List<ParselEntity> parseller,
  required Iterable<IsKaydiEntity> isKayitlari,
  required Iterable<GiderEntity> muhasebe,
  required Donem donem,
}) {
  final idler = {for (final p in parseller) p.id};
  final toplamAlan = parseller.fold(0.0, (s, p) => s + p.alanDonumCinsinden);

  final dogrudanGider = <String, double>{};
  final dogrudanGelir = <String, double>{};
  var genelGider = 0.0;
  var genelGelir = 0.0;
  for (final m in muhasebe) {
    if (m.isDeleted || !donem.icerir(m.giderTarihi)) continue;
    final gelirMi = m.islemTuru == 'Gelir';
    final pid = m.parselId;
    if (pid != null && idler.contains(pid)) {
      final hedef = gelirMi ? dogrudanGelir : dogrudanGider;
      hedef[pid] = (hedef[pid] ?? 0) + m.tutar;
    } else if (gelirMi) {
      genelGelir += m.tutar;
    } else {
      genelGider += m.tutar;
    }
  }

  final hasat = <String, double>{};
  for (final k in isKayitlari) {
    final kg = k.hasatKg;
    if (k.isDeleted || k.tur != IslemTuru.hasat || kg == null || !donem.icerir(k.islemTarihi)) continue;
    hasat[k.parselId] = (hasat[k.parselId] ?? 0) + kg;
  }

  final dagitilabilir = toplamAlan > 0;
  return CiftlikKarnesi(
    donem: donem,
    genelGider: genelGider,
    genelGelir: genelGelir,
    dagitilamayanGider: dagitilabilir ? 0 : genelGider,
    dagitilamayanGelir: dagitilabilir ? 0 : genelGelir,
    tarlalar: [
      for (final p in parseller)
        TarlaKarnesi(
          parsel: p,
          hasatKg: hasat[p.id] ?? 0,
          dogrudanGider: dogrudanGider[p.id] ?? 0,
          dogrudanGelir: dogrudanGelir[p.id] ?? 0,
          genelGiderPayi: dagitilabilir ? genelGider * p.alanDonumCinsinden / toplamAlan : 0,
          genelGelirPayi: dagitilabilir ? genelGelir * p.alanDonumCinsinden / toplamAlan : 0,
        ),
    ],
  );
}
