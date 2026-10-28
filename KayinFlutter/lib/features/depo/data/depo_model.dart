import '../domain/depo.dart';

class StokKalemiModel {
  static StokKalemiEntity fromRow(Map<String, dynamic> r) => StokKalemiEntity(
        id: r['id'] as String,
        ad: r['ad'] as String? ?? '',
        kategori: StokKategori.koddan(r['kategori'] as String? ?? 'Diger'),
        birim: r['birim'] as String? ?? 'kg',
        kritikSeviye: (r['kritik_seviye'] as num?)?.toDouble(),
        createdAtUtc: DateTime.parse(r['created_at_utc'] as String),
        lastModifiedUtc: DateTime.parse(r['last_modified_utc'] as String),
        isDeleted: r['is_deleted'] == 1,
        isSynced: r['is_synced'] == 1,
      );

  static Map<String, dynamic> toRow(StokKalemiEntity e) => {
        'id': e.id,
        'ad': e.ad,
        'kategori': e.kategori.kod,
        'birim': e.birim,
        'kritik_seviye': e.kritikSeviye,
        'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
        'last_modified_utc': e.lastModifiedUtc.toUtc().toIso8601String(),
        'is_deleted': e.isDeleted ? 1 : 0,
        'is_synced': e.isSynced ? 1 : 0,
      };
}

class StokHareketiModel {
  static StokHareketiEntity fromRow(Map<String, dynamic> r) => StokHareketiEntity(
        id: r['id'] as String,
        kalemId: r['kalem_id'] as String,
        islemTarihi: DateTime.parse(r['islem_tarihi'] as String),
        tur: StokHareketTuru.koddan(r['tur'] as String? ?? 'Giris'),
        miktar: (r['miktar'] as num?)?.toDouble() ?? 0,
        aciklama: r['aciklama'] as String? ?? '',
        isKaydiId: r['is_kaydi_id'] as String?,
        createdAtUtc: DateTime.parse(r['created_at_utc'] as String),
        lastModifiedUtc: DateTime.parse(r['last_modified_utc'] as String),
        isDeleted: r['is_deleted'] == 1,
        isSynced: r['is_synced'] == 1,
      );

  static Map<String, dynamic> toRow(StokHareketiEntity e) => {
        'id': e.id,
        'kalem_id': e.kalemId,
        'islem_tarihi': e.islemTarihi.toUtc().toIso8601String(),
        'tur': e.tur.kod,
        'miktar': e.miktar,
        'aciklama': e.aciklama,
        'is_kaydi_id': e.isKaydiId,
        'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
        'last_modified_utc': e.lastModifiedUtc.toUtc().toIso8601String(),
        'is_deleted': e.isDeleted ? 1 : 0,
        'is_synced': e.isSynced ? 1 : 0,
      };
}
