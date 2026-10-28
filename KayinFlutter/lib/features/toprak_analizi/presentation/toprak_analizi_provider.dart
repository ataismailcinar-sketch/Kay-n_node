import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../akilli_sulama/presentation/providers/sulama_provider.dart';
import '../data/toprak_analizi_model.dart';
import '../domain/toprak_analizi.dart';

final toprakAnalizListeProvider =
    AsyncNotifierProvider<ToprakAnalizListeNotifier, List<ToprakAnaliziEntity>>(ToprakAnalizListeNotifier.new);

class ToprakAnalizListeNotifier extends AsyncNotifier<List<ToprakAnaliziEntity>> {
  @override
  Future<List<ToprakAnaliziEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(DatabaseHelper.tableToprakAnalizi, where: 'is_deleted = 0', orderBy: 'analiz_tarihi DESC');
    return rows.map(ToprakAnaliziModel.fromRow).toList();
  }

  Future<void> kaydet(ToprakAnaliziEntity a, {ToprakAnaliziEntity? eski}) async {
    final now = DateTime.now().toUtc();
    final kayit = ToprakAnaliziEntity(
      id: eski?.id ?? const Uuid().v4(),
      parselId: a.parselId,
      analizTarihi: DateTime(a.analizTarihi.year, a.analizTarihi.month, a.analizTarihi.day),
      laboratuvar: a.laboratuvar.trim(),
      saturasyon: a.saturasyon,
      ph: a.ph,
      tuzYuzde: a.tuzYuzde,
      ec: a.ec,
      kirecYuzde: a.kirecYuzde,
      organikMadde: a.organikMadde,
      fosfor: a.fosfor,
      potasyum: a.potasyum,
      cinko: a.cinko,
      not: a.not.trim(),
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    );
    await DatabaseHelper().upsert(DatabaseHelper.tableToprakAnalizi, ToprakAnaliziModel.toRow(kayit));
    _tazele();
  }

  Future<void> silindiYap(String id, bool silindi) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DatabaseHelper.tableToprakAnalizi,
      {'is_deleted': silindi ? 1 : 0, 'is_synced': 0, 'last_modified_utc': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    _tazele();
  }

  /// Su hesabı (kullanılabilir su, su açığı) yeni analize göre yeniden yapılsın.
  void _tazele() {
    ref.invalidateSelf();
    ref.invalidate(parselHavaProvider);
  }
}
