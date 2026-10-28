import '../../../core/database/table_columns.dart';
import '../domain/is_kaydi_entity.dart';

class IsKaydiModel {
  static IsKaydiEntity fromRow(Map<String, dynamic> row) => IsKaydiEntity(
        id: row[TableColumns.id] as String,
        parselId: row[TableColumns.isParselId] as String,
        islemTarihi: DateTime.parse(row[TableColumns.isTarihi] as String),
        tur: IslemTuru.koddan(row[TableColumns.isTuru] as String? ?? 'Diger'),
        urunAdi: row[TableColumns.isUrunAdi] as String? ?? '',
        miktar: row[TableColumns.isMiktar] as String? ?? '',
        hasatBeklemeGun: row[TableColumns.isHasatBeklemeGun] as int?,
        hasatKg: (row[TableColumns.isHasatKg] as num?)?.toDouble(),
        not: row[TableColumns.isNot] as String? ?? '',
        createdAtUtc: DateTime.parse(row[TableColumns.createdAtUtc] as String),
        lastModifiedUtc: DateTime.parse(row[TableColumns.lastModifiedUtc] as String),
        isDeleted: (row[TableColumns.isDeleted] as int?) == 1,
        isSynced: (row[TableColumns.isSynced] as int?) == 1,
      );

  static Map<String, dynamic> toRow(IsKaydiEntity e) => {
        TableColumns.id: e.id,
        TableColumns.isParselId: e.parselId,
        TableColumns.isTarihi: e.islemTarihi.toUtc().toIso8601String(),
        TableColumns.isTuru: e.tur.kod,
        TableColumns.isUrunAdi: e.urunAdi,
        TableColumns.isMiktar: e.miktar,
        TableColumns.isHasatBeklemeGun: e.hasatBeklemeGun,
        TableColumns.isHasatKg: e.hasatKg,
        TableColumns.isNot: e.not,
        TableColumns.createdAtUtc: e.createdAtUtc.toUtc().toIso8601String(),
        TableColumns.lastModifiedUtc: e.lastModifiedUtc.toUtc().toIso8601String(),
        TableColumns.isDeleted: e.isDeleted ? 1 : 0,
        TableColumns.isSynced: e.isSynced ? 1 : 0,
      };
}
