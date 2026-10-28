import '../domain/veresiye.dart';

class CariModel {
  static CariEntity fromRow(Map<String, dynamic> r) => CariEntity(
        id: r['id'] as String,
        ad: r['ad'] as String? ?? '',
        tur: CariTuru.koddan(r['tur'] as String? ?? 'Bayi'),
        telefon: r['telefon'] as String? ?? '',
        not: r['not_metni'] as String? ?? '',
        createdAtUtc: DateTime.parse(r['created_at_utc'] as String),
        lastModifiedUtc: DateTime.parse(r['last_modified_utc'] as String),
        isDeleted: r['is_deleted'] == 1,
        isSynced: r['is_synced'] == 1,
      );

  static Map<String, dynamic> toRow(CariEntity e) => {
        'id': e.id,
        'ad': e.ad,
        'tur': e.tur.kod,
        'telefon': e.telefon,
        'not_metni': e.not,
        'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
        'last_modified_utc': e.lastModifiedUtc.toUtc().toIso8601String(),
        'is_deleted': e.isDeleted ? 1 : 0,
        'is_synced': e.isSynced ? 1 : 0,
      };
}

class CariHareketModel {
  static CariHareketEntity fromRow(Map<String, dynamic> r) => CariHareketEntity(
        id: r['id'] as String,
        cariId: r['cari_id'] as String,
        islemTarihi: DateTime.parse(r['islem_tarihi'] as String),
        tur: HareketTuru.koddan(r['tur'] as String? ?? 'Veresiye'),
        tutar: (r['tutar'] as num?)?.toDouble() ?? 0,
        vadeTarihi: r['vade_tarihi'] == null ? null : DateTime.parse(r['vade_tarihi'] as String),
        aciklama: r['aciklama'] as String? ?? '',
        muhasebeKaydiId: r['muhasebe_kaydi_id'] as String?,
        createdAtUtc: DateTime.parse(r['created_at_utc'] as String),
        lastModifiedUtc: DateTime.parse(r['last_modified_utc'] as String),
        isDeleted: r['is_deleted'] == 1,
        isSynced: r['is_synced'] == 1,
      );

  static Map<String, dynamic> toRow(CariHareketEntity e) => {
        'id': e.id,
        'cari_id': e.cariId,
        'islem_tarihi': e.islemTarihi.toUtc().toIso8601String(),
        'tur': e.tur.kod,
        'tutar': e.tutar,
        'vade_tarihi': e.vadeTarihi?.toUtc().toIso8601String(),
        'aciklama': e.aciklama,
        'muhasebe_kaydi_id': e.muhasebeKaydiId,
        'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
        'last_modified_utc': e.lastModifiedUtc.toUtc().toIso8601String(),
        'is_deleted': e.isDeleted ? 1 : 0,
        'is_synced': e.isSynced ? 1 : 0,
      };
}
