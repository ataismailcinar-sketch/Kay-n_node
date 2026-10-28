import 'dart:convert';
import '../sulama.dart';

/// copyWith / guncelle'de "bu alana dokunma" işareti (null ise alanı boşaltır).
const degismedi = Object();

/// Uygulama iç katmanında kullanılan saf Parsel domain entity'si.
class ParselEntity {
  final String id;
  final String ad;
  final String ekilmisUrun;
  final String toprakTuru;

  /// true: sulu tarım, false: kuru tarım (yalnız yağışla), null: belirtilmedi.
  final bool? sulu;

  /// Yalnız sulu tarlada anlamlı; null = belirtilmedi.
  final SulamaYontemi? sulamaYontemi;
  final SuKaynagi? suKaynagi;

  /// Sulama suyunun tuzluluğu (ECw), dS/m; ölçülmediyse null.
  final double? suEc;
  final DateTime? ekimTarihi;
  final String konum;
  final List<LatLngPoint> poligonNoktalar;
  final double alanDonumCinsinden;
  final double merkezLat;
  final double merkezLng;
  final DateTime createdAtUtc;
  final DateTime lastModifiedUtc;
  final bool isDeleted;
  final bool isSynced;

  const ParselEntity({
    required this.id,
    required this.ad,
    this.ekilmisUrun = 'Buğday',
    this.toprakTuru = 'Tınlı',
    this.sulu,
    this.sulamaYontemi,
    this.suKaynagi,
    this.suEc,
    this.ekimTarihi,
    required this.konum,
    required this.poligonNoktalar,
    required this.alanDonumCinsinden,
    required this.merkezLat,
    required this.merkezLng,
    required this.createdAtUtc,
    required this.lastModifiedUtc,
    this.isDeleted = false,
    this.isSynced = false,
  });

  /// Eşitlik id + son değişiklik zamanına göre: Riverpod `family` sağlayıcıları
  /// (hava durumu vb.) parseli anahtar olarak kullanır. Eşitlik tanımlı değilken
  /// liste her yenilendiğinde yeni anahtar oluşuyor ve hava verisi tekrar çekiliyordu.
  @override
  bool operator ==(Object other) =>
      other is ParselEntity && other.id == id && other.lastModifiedUtc == lastModifiedUtc;

  @override
  int get hashCode => Object.hash(id, lastModifiedUtc);

  /// Poligon noktalarını JSON string'e çevirir (SQLite depolama için).
  String get poligonJson => jsonEncode(
        poligonNoktalar.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
      );

  /// Ürün Emoji simgesi
  String get urunEmoji => switch (ekilmisUrun) {
        'Buğday'    => '🌾',
        'Mısır'     => '🌽',
        'Ayçiçeği'  => '🌻',
        'Pamuk'     => '🌿',
        'Arpa'      => '🌾',
        'Domates'   => '🍅',
        'Zeytin'    => '🫒',
        'Üzüm'      => '🍇',
        'Soya'      => '🌱',
        'Şeker Pancarı' => '🥬',
        'Nohut'     => '🫘',
        'Mercimek'  => '🫘',
        'Patates'   => '🥔',
        'Fasulye'   => '🫘',
        'Yonca'     => '☘️',
        _           => '🌾',
      };

  String get suluMetni => switch (sulu) {
        true => sulamaYontemi == null ? 'Sulu' : 'Sulu (${sulamaYontemi!.ad.split(' ').first})',
        false => 'Kuru',
        null => 'Sulu/kuru belirtilmedi',
      };

  /// Tarlaya seçilebilen ürünler (uygunluk motorundaki ürünlerle aynı).
  static const urunSecenekleri = [
    'Buğday', 'Arpa', 'Mısır', 'Ayçiçeği', 'Pamuk', 'Şeker Pancarı', 'Patates', 'Nohut',
    'Mercimek', 'Fasulye', 'Soya', 'Domates', 'Yonca', 'Zeytin', 'Üzüm',
  ];

  /// Dönüm ve m² formatlaması
  String get alanMetinsel {
    if (alanDonumCinsinden >= 1) {
      return '${alanDonumCinsinden.toStringAsFixed(2)} dönüm';
    }
    return '${(alanDonumCinsinden * 1000).toStringAsFixed(0)} m²';
  }

  ParselEntity copyWith({
    String? ad,
    String? ekilmisUrun,
    String? toprakTuru,
    bool? sulu,
    SulamaYontemi? sulamaYontemi,
    SuKaynagi? suKaynagi,
    // null'a çekilebilmesi için (ölçüm silindi): verilmezse mevcut değer kalır.
    Object? suEc = degismedi,
    DateTime? ekimTarihi,
    String? konum,
    List<LatLngPoint>? poligonNoktalar,
    double? alanDonumCinsinden,
    double? merkezLat,
    double? merkezLng,
    bool? isSynced,
  }) =>
      ParselEntity(
        id: id,
        ad: ad ?? this.ad,
        ekilmisUrun: ekilmisUrun ?? this.ekilmisUrun,
        toprakTuru: toprakTuru ?? this.toprakTuru,
        sulu: sulu ?? this.sulu,
        sulamaYontemi: sulamaYontemi ?? this.sulamaYontemi,
        suKaynagi: suKaynagi ?? this.suKaynagi,
        suEc: identical(suEc, degismedi) ? this.suEc : suEc as double?,
        ekimTarihi: ekimTarihi ?? this.ekimTarihi,
        konum: konum ?? this.konum,
        poligonNoktalar: poligonNoktalar ?? this.poligonNoktalar,
        alanDonumCinsinden: alanDonumCinsinden ?? this.alanDonumCinsinden,
        merkezLat: merkezLat ?? this.merkezLat,
        merkezLng: merkezLng ?? this.merkezLng,
        createdAtUtc: createdAtUtc,
        lastModifiedUtc: DateTime.now().toUtc(),
        isDeleted: isDeleted,
        isSynced: isSynced ?? this.isSynced,
      );
}

/// Enlem/Boylam nokta çifti (harita koordinatı)
class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);
}
