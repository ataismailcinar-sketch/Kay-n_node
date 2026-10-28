/// Muhasebe gider domain entity'si.
/// Tüm değerler Zero-Keyboard UI'dan (buton, chip, slider) girilir.
class GiderEntity {
  final String id;
  final String? parselId;
  final String islemTuru; // 'Gider' veya 'Gelir'
  final String kategori;
  final String altKategori;
  final double tutar;
  final String paraBirimi;
  final DateTime giderTarihi;
  final String? notMetni;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const GiderEntity({
    required this.id,
    this.parselId,
    this.islemTuru = 'Gider',
    required this.kategori,
    required this.altKategori,
    required this.tutar,
    this.paraBirimi = 'TRY',
    required this.giderTarihi,
    this.notMetni,
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  /// Tutarı Türkçe para formatında göster
  String get tutarMetni {
    if (tutar >= 1000000) {
      return '${(tutar / 1000000).toStringAsFixed(1)}M ₺';
    }
    if (tutar >= 1000) {
      return '${(tutar / 1000).toStringAsFixed(1)}K ₺';
    }
    return '${tutar.toStringAsFixed(0)} ₺';
  }

  /// Kategori emoji'si
  String get kategoriEmoji => switch (kategori) {
        'Hasat'    => '🌾',
        'Destek'   => '🏛️',
        'Mazot'    => '⛽',
        'Gubre'    => '🌿',
        'Ilac'     => '🧪',
        'Iscilik'  => '👷',
        'Tohum'    => '🌱',
        _          => islemTuru == 'Gelir' ? '💰' : '📦',
      };

  GiderEntity copyWith({
    String? islemTuru,
    String? kategori,
    String? altKategori,
    double? tutar,
    String? notMetni,
    bool? isSynced,
  }) =>
      GiderEntity(
        id: id,
        parselId: parselId,
        islemTuru: islemTuru ?? this.islemTuru,
        kategori: kategori ?? this.kategori,
        altKategori: altKategori ?? this.altKategori,
        tutar: tutar ?? this.tutar,
        paraBirimi: paraBirimi,
        giderTarihi: giderTarihi,
        notMetni: notMetni ?? this.notMetni,
        createdAtUtc: createdAtUtc,
        lastModifiedUtc: DateTime.now().toUtc(),
        isSynced: isSynced ?? this.isSynced,
      );
}
