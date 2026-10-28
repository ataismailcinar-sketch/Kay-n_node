import 'dart:math' as math;
import '../../../core/services/hava_durumu_servisi.dart';
import '../../parsel_harita/domain/entities/parsel_entity.dart';
import 'fenoloji_engine.dart';

class SezonlukGelisimRaporu {
  /// Ekim tarihi girilmemişse false; bu durumda gün/yağış/ısıl gün üretilmez.
  final bool ekimTarihiVar;
  final int? ekimdenBeriGecenGun;
  final int? tahminiHasataKalanGun;
  final double? toplamBirikenYagisMm;

  /// Ölçülmüş günlük sıcaklıklardan hesaplanan büyüme derece günü (GDD).
  final double? toplamGddIsilGun;

  /// Yağış ve GDD toplamlarının kapsadığı gün sayısı; ekimden bugüne tümünü
  /// kapsamıyorsa [tamKapsam] false olur (Open-Meteo en fazla 92 gün geriye gider).
  final int kapsamaGunu;
  final bool tamKapsam;

  final String mevcutFenolojikEvre;
  final double evreTamamlanmaYuzdesi;
  final String kritikMevsimselGorev;

  const SezonlukGelisimRaporu({
    required this.ekimTarihiVar,
    this.ekimdenBeriGecenGun,
    this.tahminiHasataKalanGun,
    this.toplamBirikenYagisMm,
    this.toplamGddIsilGun,
    this.kapsamaGunu = 0,
    this.tamKapsam = false,
    required this.mevcutFenolojikEvre,
    required this.evreTamamlanmaYuzdesi,
    required this.kritikMevsimselGorev,
  });
}

/// Ekimden bugüne biriken yağış, ısıl gün ve ürüne özel gelişim evresini hesaplar.
///
/// Evre ve görevler [FenolojiEngine]'den (ürüne özel) gelir; eskiden her ürüne
/// buğday evreleri gösteriliyordu. Isıl gün eskiden "bugünün sıcaklığı × gün sayısı"
/// ile uyduruluyordu; artık ölçülmüş günlük sıcaklıklardan toplanır.
class SezonlukIklimMotoru {
  /// Ürüne göre gelişim baz sıcaklığı (°C) ve üst sınır.
  static (double baz, double ust) _gddEsikleri(String urun) {
    final u = urun.toLowerCase();
    if (u.contains('buğday') || u.contains('arpa')) return (0.0, 26.0);
    if (u.contains('pamuk')) return (15.6, 32.0);
    if (u.contains('ayçiçe')) return (6.0, 30.0);
    if (u.contains('pancar')) return (3.0, 30.0);
    if (u.contains('nohut') || u.contains('mercimek')) return (0.0, 30.0);
    if (u.contains('patates')) return (7.0, 29.0);
    if (u.contains('yonca')) return (5.0, 30.0);
    return (10.0, 30.0); // Mısır, Domates, Soya, Fasulye, Zeytin, Üzüm
  }

  static SezonlukGelisimRaporu hesapla({
    required ParselEntity parsel,
    required TarlaHavaOzeti hava,
  }) {
    if (parsel.ekimTarihi == null) {
      return const SezonlukGelisimRaporu(
        ekimTarihiVar: false,
        mevcutFenolojikEvre: 'Ekim tarihi girilmemiş',
        evreTamamlanmaYuzdesi: 0,
        kritikMevsimselGorev: 'Gelişim evresi, yağış ve ısıl gün hesabı için tarla detayından ekim tarihini girin.',
      );
    }

    final evre = FenolojiEngine.hesapla(
      ekilmisUrun: parsel.ekilmisUrun,
      ekimTarihi: parsel.ekimTarihi,
    );

    final (baz, ust) = _gddEsikleri(parsel.ekilmisUrun);
    final gdd = hava.gecmisGunler.fold<double>(
      0,
      (s, g) => s + math.max(0.0, math.min(g.ortalamaSicaklik, ust) - baz),
    );
    final gecenGun = hava.ekimdenBeriGecenGun ?? evre.gecenGun;

    return SezonlukGelisimRaporu(
      ekimTarihiVar: true,
      ekimdenBeriGecenGun: gecenGun,
      tahminiHasataKalanGun: evre.kalanGun,
      toplamBirikenYagisMm: hava.ekimdenBuguneToplamYagisMm,
      toplamGddIsilGun: hava.gecmisGunler.isEmpty ? null : double.parse(gdd.toStringAsFixed(0)),
      kapsamaGunu: hava.yagisKapsamaGunu,
      tamKapsam: hava.yagisTamKapsam,
      mevcutFenolojikEvre: evre.evreAdi,
      evreTamamlanmaYuzdesi: evre.ilerlemeYuzdesi,
      kritikMevsimselGorev: evre.yapilacakIsler.isEmpty ? evre.evreAciklama : evre.yapilacakIsler.first.baslik,
    );
  }
}
