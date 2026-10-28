/// Akıllı sulama ekranı için domain entity.
class SulamaEntity {
  final String id;
  final String parselId;
  final String parselAd;
  final double alanDonum;
  final DateTime kayitTarihi;
  final double yagisMillimetre;
  final double toprakNemiYuzde;
  final String kayitTuru;
  final String aciliyetSeviyesi;
  final bool isSynced;

  const SulamaEntity({
    required this.id,
    required this.parselId,
    required this.parselAd,
    required this.alanDonum,
    required this.kayitTarihi,
    required this.yagisMillimetre,
    required this.toprakNemiYuzde,
    required this.kayitTuru,
    required this.aciliyetSeviyesi,
    this.isSynced = false,
  });

  /// Aciliyet enum'una göre renk kodu
  AciliyetRenk get aciliyetRenk => switch (aciliyetSeviyesi) {
        'Acil'    => AciliyetRenk.kirmizi,
        'Normal'  => AciliyetRenk.sari,
        'Yeterli' => AciliyetRenk.yesil,
        'Dolu'    => AciliyetRenk.mavi,
        _         => AciliyetRenk.gri,
      };

  /// Toprak nemini görsel çubuk yüzdesine çevir (0.0 - 1.0)
  double get nemOrani => (toprakNemiYuzde / 100.0).clamp(0.0, 1.0);

  /// Yağış metni
  String get yagisMetni => yagisMillimetre > 0
      ? '${yagisMillimetre.toStringAsFixed(1)} mm yağış'
      : 'Yağış yok';

  /// Nem verisi var mı? (Negatif değer = veri yok)
  bool get nemBilinir => toprakNemiYuzde >= 0;

  /// Nem metni (kök bölgesinde tahmini kullanılabilir su)
  String get nemMetni => nemBilinir ? '%${toprakNemiYuzde.toStringAsFixed(0)} kullanılabilir su' : 'Nem verisi yok';
}

enum AciliyetRenk { kirmizi, sari, yesil, mavi, gri }
