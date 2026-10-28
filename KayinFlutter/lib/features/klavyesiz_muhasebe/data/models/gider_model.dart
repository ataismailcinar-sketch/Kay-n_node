import '../../../../core/database/table_columns.dart';
import '../../domain/entities/gider_entity.dart';

class GiderModel {
  static GiderEntity fromRow(Map<String, dynamic> row) => GiderEntity(
        id: row[TableColumns.id] as String,
        parselId: row[TableColumns.giderParselId] as String?,
        islemTuru: row[TableColumns.giderIslemTuru] as String? ?? 'Gider',
        kategori: row[TableColumns.giderKategori] as String? ?? 'Diger',
        altKategori: row[TableColumns.giderAltKategori] as String? ?? '',
        tutar: (row[TableColumns.giderTutar] as num?)?.toDouble() ?? 0.0,
        paraBirimi: row[TableColumns.giderParaBirimi] as String? ?? 'TRY',
        giderTarihi:
            DateTime.parse(row[TableColumns.giderTarihi] as String),
        notMetni: (row[TableColumns.giderNot] as String?)?.isEmpty ?? true ? null : row[TableColumns.giderNot] as String,
        createdAtUtc: DateTime.parse(row[TableColumns.createdAtUtc] as String),
        lastModifiedUtc:
            DateTime.parse(row[TableColumns.lastModifiedUtc] as String),
        isDeleted: (row[TableColumns.isDeleted] as int?) == 1,
        isSynced: (row[TableColumns.isSynced] as int?) == 1,
      );

  static Map<String, dynamic> toRow(GiderEntity e) => {
        TableColumns.id: e.id,
        TableColumns.giderParselId: e.parselId,
        TableColumns.giderIslemTuru: e.islemTuru,
        TableColumns.giderKategori: e.kategori,
        TableColumns.giderAltKategori: e.altKategori,
        TableColumns.giderTutar: e.tutar,
        TableColumns.giderParaBirimi: e.paraBirimi,
        TableColumns.giderTarihi: e.giderTarihi.toIso8601String(),
        // Sütun NOT NULL DEFAULT '' — null gönderilirse SQLite kaydı reddeder.
        TableColumns.giderNot: e.notMetni ?? '',
        TableColumns.createdAtUtc: e.createdAtUtc.toUtc().toIso8601String(),
        TableColumns.lastModifiedUtc:
            e.lastModifiedUtc.toUtc().toIso8601String(),
        TableColumns.isDeleted: e.isDeleted ? 1 : 0,
        TableColumns.isSynced: e.isSynced ? 1 : 0,
      };
}
