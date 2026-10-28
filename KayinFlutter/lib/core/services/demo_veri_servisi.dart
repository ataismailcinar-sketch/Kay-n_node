import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../features/parsel_harita/data/models/parsel_model.dart';
import '../../features/parsel_harita/domain/entities/parsel_entity.dart';
import '../../features/klavyesiz_muhasebe/data/models/gider_model.dart';
import '../../features/klavyesiz_muhasebe/domain/entities/gider_entity.dart';
import '../../features/yaprak_hastalik_ai/data/models/hastalik_tarama_model.dart';
import '../../features/yaprak_hastalik_ai/domain/entities/hastalik_tarama_entity.dart';

/// "Örnek Çiftlik Verisi Yükle" butonu için örnek kayıtlar.
/// Hastalık taramaları "örnek veri" olarak işaretlenir (gerçek model sonucu değildir).
class DemoVeriServisi {
  static Future<void> ornekVerileriYukle() async {
    final now = DateTime.now().toUtc();
    const uuid = Uuid();

    // ── 1. ÜÇ GERÇEKÇİ TARLA / PARSEL ──────────────────────────────────────
    final p1Id = uuid.v4();
    final p2Id = uuid.v4();
    final p3Id = uuid.v4();

    final p1 = ParselEntity(
      id: p1Id,
      ad: 'Kuzey Tarlası (Büyük Düzlük)',
      ekilmisUrun: 'Buğday',
      toprakTuru: 'Tınlı',
      ekimTarihi: now.subtract(const Duration(days: 42)),
      konum: 'Polatlı / Ankara',
      poligonNoktalar: const [
        LatLngPoint(39.582, 32.140),
        LatLngPoint(39.586, 32.141),
        LatLngPoint(39.585, 32.148),
        LatLngPoint(39.581, 32.146),
      ],
      alanDonumCinsinden: 262.1, // poligondan hesaplanan gerçek alan
      merkezLat: 39.5835,
      merkezLng: 32.1438,
      createdAtUtc: now,
      lastModifiedUtc: now,
      isSynced: false,
    );

    final p2 = ParselEntity(
      id: p2Id,
      ad: 'Büyük Ova Tarlası',
      ekilmisUrun: 'Mısır',
      toprakTuru: 'Killi',
      ekimTarihi: now.subtract(const Duration(days: 28)),
      konum: 'Çumra / Konya',
      poligonNoktalar: const [
        LatLngPoint(37.571, 32.772),
        LatLngPoint(37.575, 32.773),
        LatLngPoint(37.574, 32.779),
        LatLngPoint(37.570, 32.777),
      ],
      alanDonumCinsinden: 230.3,
      merkezLat: 37.5725,
      merkezLng: 32.7752,
      createdAtUtc: now,
      lastModifiedUtc: now,
      isSynced: false,
    );

    final p3 = ParselEntity(
      id: p3Id,
      ad: 'Güney Yamaç Bahçesi',
      ekilmisUrun: 'Ayçiçeği',
      toprakTuru: 'Kireçli',
      ekimTarihi: now.subtract(const Duration(days: 14)),
      konum: 'Hayrabolu / Tekirdağ',
      poligonNoktalar: const [
        LatLngPoint(41.210, 27.110),
        LatLngPoint(41.213, 27.111),
        LatLngPoint(41.212, 27.116),
        LatLngPoint(41.209, 27.114),
      ],
      alanDonumCinsinden: 139.5,
      merkezLat: 41.2110,
      merkezLng: 27.1127, // (eskiden yanlışlıkla 41.1128 yazılmıştı → hava verisi Karadeniz'den geliyordu)
      createdAtUtc: now,
      lastModifiedUtc: now,
      isSynced: false,
    );

    await DatabaseHelper().upsert(DatabaseHelper.tableParseller, ParselModel.toRow(p1));
    await DatabaseHelper().upsert(DatabaseHelper.tableParseller, ParselModel.toRow(p2));
    await DatabaseHelper().upsert(DatabaseHelper.tableParseller, ParselModel.toRow(p3));

    // ── 2. GERÇEKÇİ GELİR VE MASRAFLAR ─────────────────────────────────────
    final giderler = [
      GiderEntity(
        id: uuid.v4(),
        parselId: p1Id,
        islemTuru: 'Gider',
        kategori: 'Mazot',
        altKategori: 'Tarla Sürümü',
        tutar: 36000,
        giderTarihi: now.subtract(const Duration(days: 40)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
      GiderEntity(
        id: uuid.v4(),
        parselId: p1Id,
        islemTuru: 'Gider',
        kategori: 'Gubre',
        altKategori: 'Üre (%46 N)',
        tutar: 48000,
        giderTarihi: now.subtract(const Duration(days: 20)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
      GiderEntity(
        id: uuid.v4(),
        parselId: p1Id,
        islemTuru: 'Gelir',
        kategori: 'Hasat',
        altKategori: 'Buğday Satışı (Ön Satış)',
        tutar: 220000,
        giderTarihi: now.subtract(const Duration(days: 5)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
      GiderEntity(
        id: uuid.v4(),
        parselId: p2Id,
        islemTuru: 'Gider',
        kategori: 'Gubre',
        altKategori: 'DAP Taban Gübresi',
        tutar: 42000,
        giderTarihi: now.subtract(const Duration(days: 26)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
      GiderEntity(
        id: uuid.v4(),
        parselId: p2Id,
        islemTuru: 'Gider',
        kategori: 'Ilac',
        altKategori: 'Herbisit Ot İlacı',
        tutar: 14500,
        giderTarihi: now.subtract(const Duration(days: 10)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
      GiderEntity(
        id: uuid.v4(),
        parselId: p3Id,
        islemTuru: 'Gider',
        kategori: 'Tohum',
        altKategori: 'Sertifikalı Hibrit Tohum',
        tutar: 18000,
        giderTarihi: now.subtract(const Duration(days: 14)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
      GiderEntity(
        id: uuid.v4(),
        parselId: null, // Genel Çiftlik Geliri
        islemTuru: 'Gelir',
        kategori: 'Destek',
        altKategori: 'Mazot/Gübre Desteği',
        tutar: 65000,
        giderTarihi: now.subtract(const Duration(days: 2)),
        createdAtUtc: now,
        lastModifiedUtc: now,
      ),
    ];

    for (final g in giderler) {
      await DatabaseHelper().upsert(DatabaseHelper.tableMuhasebeGider, GiderModel.toRow(g));
    }

    // ── 3. YAPRAK HASTALIK TARAMA KAYDI ────────────────────────────────────
    final t1 = HastalikTaramaEntity(
      id: uuid.v4(),
      parselId: p1Id,
      taramaTarihi: now.subtract(const Duration(days: 3)),
      teshisAdi: 'Sarı Pas & Kahverengi Pas (Puccinia spp.)',
      guvenYuzdesi: 0,
      tumSinifOlasiliklariJson: '[]',
      fotografYerelYolu: '',
      modelVersionu: HastalikTaramaEntity.demoModelVersiyonu,
      aciliyetSeviyesi: 'Kritik',
      createdAtUtc: now,
      lastModifiedUtc: now,
    );

    final t2 = HastalikTaramaEntity(
      id: uuid.v4(),
      parselId: p2Id,
      taramaTarihi: now.subtract(const Duration(days: 1)),
      teshisAdi: 'Sağlıklı Bitki Dokusu',
      guvenYuzdesi: 0,
      tumSinifOlasiliklariJson: '[]',
      fotografYerelYolu: '',
      modelVersionu: HastalikTaramaEntity.demoModelVersiyonu,
      aciliyetSeviyesi: 'Düşük',
      createdAtUtc: now,
      lastModifiedUtc: now,
    );

    await DatabaseHelper().upsert(DatabaseHelper.tableHastalikTarama, HastalikTaramaModel.toRow(t1));
    await DatabaseHelper().upsert(DatabaseHelper.tableHastalikTarama, HastalikTaramaModel.toRow(t2));
  }
}
