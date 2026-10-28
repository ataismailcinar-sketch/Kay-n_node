import '../../../../core/database/table_columns.dart';
import '../../domain/entities/hastalik_tarama_entity.dart';

class HastalikTaramaModel {
  static HastalikTaramaEntity fromRow(Map<String, dynamic> row) => HastalikTaramaEntity(
        id: row[TableColumns.id] as String,
        parselId: row[TableColumns.taramaParselId] as String?,
        taramaTarihi: DateTime.parse(row[TableColumns.taramaTarihi] as String),
        teshisAdi: row[TableColumns.taramaTeshisAdi] as String? ?? '',
        guvenYuzdesi: (row[TableColumns.taramaGuvenYuzdesi] as num?)?.toDouble() ?? 0.0,
        tumSinifOlasiliklariJson: row[TableColumns.taramaSinifJson] as String? ?? '[]',
        fotografYerelYolu: row[TableColumns.taramaFotografYolu] as String? ?? '',
        fotografSunucuda: (row[TableColumns.taramaFotografSunucuda] as int?) == 1,
        modelVersionu: row[TableColumns.taramaModelVersiyon] as String? ?? '',
        aciliyetSeviyesi: row[TableColumns.taramaAciliyetSeviyesi] as String? ?? 'Düşük',
        cevrimdisiAnalizYapildi: (row[TableColumns.taramaCevrimdisi] as int?) == 1,
        createdAtUtc: DateTime.parse(row[TableColumns.createdAtUtc] as String),
        lastModifiedUtc: DateTime.parse(row[TableColumns.lastModifiedUtc] as String),
        isDeleted: (row[TableColumns.isDeleted] as int?) == 1,
        isSynced: (row[TableColumns.isSynced] as int?) == 1,
      );

  static Map<String, dynamic> toRow(HastalikTaramaEntity e) => {
        TableColumns.id: e.id,
        TableColumns.taramaParselId: e.parselId,
        TableColumns.taramaTarihi: e.taramaTarihi.toIso8601String(),
        TableColumns.taramaTeshisAdi: e.teshisAdi,
        TableColumns.taramaGuvenYuzdesi: e.guvenYuzdesi,
        TableColumns.taramaSinifJson: e.tumSinifOlasiliklariJson,
        TableColumns.taramaFotografYolu: e.fotografYerelYolu,
        TableColumns.taramaFotografSunucuda: e.fotografSunucuda ? 1 : 0,
        TableColumns.taramaModelVersiyon: e.modelVersionu,
        TableColumns.taramaAciliyetSeviyesi: e.aciliyetSeviyesi,
        TableColumns.taramaCevrimdisi: e.cevrimdisiAnalizYapildi ? 1 : 0,
        TableColumns.createdAtUtc: e.createdAtUtc.toUtc().toIso8601String(),
        TableColumns.lastModifiedUtc: e.lastModifiedUtc.toUtc().toIso8601String(),
        TableColumns.isDeleted: e.isDeleted ? 1 : 0,
        TableColumns.isSynced: e.isSynced ? 1 : 0,
      };
}
