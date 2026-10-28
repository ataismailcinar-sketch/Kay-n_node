import 'dart:convert';
import '../../domain/entities/parsel_entity.dart';
import '../../domain/sulama.dart';
import '../../../../core/database/table_columns.dart';

/// SQLite satırı ↔ ParselEntity dönüşümleri.
class ParselModel {
  static ParselEntity fromRow(Map<String, dynamic> row) {
    final List<dynamic> jsonList =
        jsonDecode(row[TableColumns.parselPoligonJson] as String? ?? '[]');

    final noktalar = jsonList
        .map((e) => LatLngPoint(
              (e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble(),
            ))
        .toList();

    return ParselEntity(
      id: row[TableColumns.id] as String,
      ad: row[TableColumns.parselAd] as String? ?? '',
      ekilmisUrun: row[TableColumns.parselEkilmisUrun] as String? ?? 'Buğday',
      toprakTuru: row[TableColumns.parselToprakTuru] as String? ?? 'Tınlı',
      sulu: switch (row[TableColumns.parselSulu]) { 1 => true, 0 => false, _ => null },
      sulamaYontemi: SulamaYontemi.koddan(row[TableColumns.parselSulamaYontemi] as String?),
      suKaynagi: SuKaynagi.koddan(row[TableColumns.parselSuKaynagi] as String?),
      suEc: (row[TableColumns.parselSuEc] as num?)?.toDouble(),
      ekimTarihi: row[TableColumns.parselEkimTarihi] != null
          ? DateTime.tryParse(row[TableColumns.parselEkimTarihi] as String)
          : null,
      konum: row[TableColumns.parselKonum] as String? ?? '',
      poligonNoktalar: noktalar,
      alanDonumCinsinden:
          (row[TableColumns.parselAlanDonum] as num?)?.toDouble() ?? 0.0,
      merkezLat:
          (row[TableColumns.parselMerkezLat] as num?)?.toDouble() ?? 0.0,
      merkezLng:
          (row[TableColumns.parselMerkezLng] as num?)?.toDouble() ?? 0.0,
      createdAtUtc:
          DateTime.parse(row[TableColumns.createdAtUtc] as String),
      lastModifiedUtc:
          DateTime.parse(row[TableColumns.lastModifiedUtc] as String),
      isDeleted: (row[TableColumns.isDeleted] as int?) == 1,
      isSynced: (row[TableColumns.isSynced] as int?) == 1,
    );
  }

  static Map<String, dynamic> toRow(ParselEntity entity) => {
        TableColumns.id: entity.id,
        TableColumns.parselAd: entity.ad,
        TableColumns.parselEkilmisUrun: entity.ekilmisUrun,
        TableColumns.parselToprakTuru: entity.toprakTuru,
        TableColumns.parselSulu: entity.sulu == null ? null : (entity.sulu! ? 1 : 0),
        TableColumns.parselSulamaYontemi: entity.sulamaYontemi?.kod,
        TableColumns.parselSuKaynagi: entity.suKaynagi?.kod,
        TableColumns.parselSuEc: entity.suEc,
        TableColumns.parselEkimTarihi: entity.ekimTarihi?.toIso8601String(),
        TableColumns.parselKonum: entity.konum,
        TableColumns.parselPoligonJson: entity.poligonJson,
        TableColumns.parselAlanDonum: entity.alanDonumCinsinden,
        TableColumns.parselMerkezLat: entity.merkezLat,
        TableColumns.parselMerkezLng: entity.merkezLng,
        TableColumns.createdAtUtc: entity.createdAtUtc.toUtc().toIso8601String(),
        TableColumns.lastModifiedUtc:
            entity.lastModifiedUtc.toUtc().toIso8601String(),
        TableColumns.isDeleted: entity.isDeleted ? 1 : 0,
        TableColumns.isSynced: entity.isSynced ? 1 : 0,
      };
}
