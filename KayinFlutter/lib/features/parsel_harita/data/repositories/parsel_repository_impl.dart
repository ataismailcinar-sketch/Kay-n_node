import '../../../../core/database/database_helper.dart';
import '../../domain/entities/parsel_entity.dart';
import '../../domain/repositories/parsel_repository.dart';
import '../models/parsel_model.dart';

/// SQLite tabanlı Parsel repository implementasyonu.
class ParselRepositoryImpl implements ParselRepository {
  final DatabaseHelper _db;
  ParselRepositoryImpl({DatabaseHelper? db}) : _db = db ?? DatabaseHelper();

  @override
  Future<List<ParselEntity>> getAll() async {
    final database = await _db.database;
    final rows = await database.query(
      DatabaseHelper.tableParseller,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'ad ASC',
    );
    return rows.map(ParselModel.fromRow).toList();
  }

  @override
  Future<ParselEntity?> getById(String id) async {
    final database = await _db.database;
    final rows = await database.query(
      DatabaseHelper.tableParseller,
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
      limit: 1,
    );
    return rows.isEmpty ? null : ParselModel.fromRow(rows.first);
  }

  @override
  Future<void> save(ParselEntity parsel) async {
    await _db.upsert(
      DatabaseHelper.tableParseller,
      ParselModel.toRow(parsel),
    );
  }

  @override
  Future<void> delete(String id) async {
    final database = await _db.database;
    // Soft delete — senkronizasyonun silme işlemini yakalaması için
    await database.update(
      DatabaseHelper.tableParseller,
      {
        'is_deleted': 1,
        'is_synced': 0, // Sunucuya da bildirilmesi gerekiyor
        'last_modified_utc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
