import '../entities/parsel_entity.dart';

/// Parsel depolama sözleşmesi — domain katmanı bu interface'e bağımlıdır.
/// Implementasyonu data katmanında (SQLite) yapılır.
abstract class ParselRepository {
  Future<List<ParselEntity>> getAll();
  Future<ParselEntity?> getById(String id);
  Future<void> save(ParselEntity parsel);
  Future<void> delete(String id);
}
