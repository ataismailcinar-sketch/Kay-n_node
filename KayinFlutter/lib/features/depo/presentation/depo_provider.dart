import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../data/depo_model.dart';
import '../domain/depo.dart';

final stokKalemListeProvider =
    AsyncNotifierProvider<StokKalemListeNotifier, List<StokKalemiEntity>>(StokKalemListeNotifier.new);
final stokHareketListeProvider =
    AsyncNotifierProvider<StokHareketListeNotifier, List<StokHareketiEntity>>(StokHareketListeNotifier.new);

/// Kalem id → mevcut miktar.
final stokMevcutlariProvider = Provider<Map<String, double>>((ref) {
  final hareketler = ref.watch(stokHareketListeProvider).valueOrNull ?? const [];
  final sonuc = <String, double>{};
  for (final h in hareketler) {
    if (!h.isDeleted) sonuc[h.kalemId] = (sonuc[h.kalemId] ?? 0) + h.etki;
  }
  return sonuc;
});

/// "Azaldı" durumundaki kalem sayısı (rozet için).
final azalanStokSayisiProvider = Provider<int>((ref) {
  final kalemler = ref.watch(stokKalemListeProvider).valueOrNull ?? const [];
  final mevcut = ref.watch(stokMevcutlariProvider);
  return kalemler.where((k) => azaldiMi(k, mevcut[k.id] ?? 0)).length;
});

class StokKalemListeNotifier extends AsyncNotifier<List<StokKalemiEntity>> {
  @override
  Future<List<StokKalemiEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(DatabaseHelper.tableStokKalemi, where: 'is_deleted = 0', orderBy: 'ad COLLATE NOCASE');
    return rows.map(StokKalemiModel.fromRow).toList();
  }

  Future<StokKalemiEntity> kaydet({
    StokKalemiEntity? eski,
    required String ad,
    required StokKategori kategori,
    required String birim,
    double? kritikSeviye,
  }) async {
    final now = DateTime.now().toUtc();
    final k = StokKalemiEntity(
      id: eski?.id ?? const Uuid().v4(),
      ad: ad.trim(),
      kategori: kategori,
      birim: birim,
      kritikSeviye: kritikSeviye,
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    );
    await DatabaseHelper().upsert(DatabaseHelper.tableStokKalemi, StokKalemiModel.toRow(k));
    ref.invalidateSelf();
    return k;
  }

  /// Kalemi ve hareketlerini siler (yumuşak silme).
  Future<void> sil(String kalemId) async {
    final db = await DatabaseHelper().database;
    final silindi = {'is_deleted': 1, 'is_synced': 0, 'last_modified_utc': DateTime.now().toUtc().toIso8601String()};
    await db.transaction((txn) async {
      await txn.update(DatabaseHelper.tableStokHareketi, silindi, where: 'kalem_id = ? AND is_deleted = 0', whereArgs: [kalemId]);
      await txn.update(DatabaseHelper.tableStokKalemi, silindi, where: 'id = ?', whereArgs: [kalemId]);
    });
    ref.invalidateSelf();
    ref.invalidate(stokHareketListeProvider);
  }
}

class StokHareketListeNotifier extends AsyncNotifier<List<StokHareketiEntity>> {
  @override
  Future<List<StokHareketiEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(DatabaseHelper.tableStokHareketi, where: 'is_deleted = 0', orderBy: 'islem_tarihi DESC');
    return rows.map(StokHareketiModel.fromRow).toList();
  }

  Future<void> kaydet({
    StokHareketiEntity? eski,
    required String kalemId,
    required StokHareketTuru tur,
    required double miktar,
    required DateTime islemTarihi,
    String aciklama = '',
  }) async {
    final now = DateTime.now().toUtc();
    final h = StokHareketiEntity(
      id: eski?.id ?? const Uuid().v4(),
      kalemId: kalemId,
      islemTarihi: islemTarihi.toUtc(),
      tur: tur,
      miktar: miktar,
      aciklama: aciklama.trim(),
      isKaydiId: eski?.isKaydiId,
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    );
    await DatabaseHelper().upsert(DatabaseHelper.tableStokHareketi, StokHareketiModel.toRow(h));
    ref.invalidateSelf();
  }

  Future<void> silindiYap(String id, bool silindi) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DatabaseHelper.tableStokHareketi,
      {'is_deleted': silindi ? 1 : 0, 'is_synced': 0, 'last_modified_utc': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }
}

/// İş günlüğü ↔ depo bağlantısı (ilaçlama/gübreleme/ekimde "depodan düş").
class DepoIsBaglantisi {
  /// İş kaydına bağlı çıkış (silinmemiş), yoksa null.
  static Future<StokHareketiEntity?> bagliCikis(String isKaydiId) async {
    final db = await DatabaseHelper().database;
    final r = await db.query(DatabaseHelper.tableStokHareketi,
        where: 'is_kaydi_id = ? AND is_deleted = 0', whereArgs: [isKaydiId], limit: 1);
    return r.isEmpty ? null : StokHareketiModel.fromRow(r.first);
  }

  /// İş kaydının depo çıkışını kurar: [kalemId] ve [miktar] verilmişse oluşturur/günceller,
  /// verilmemişse varsa siler.
  static Future<void> esitle({
    required String isKaydiId,
    required String? kalemId,
    required double? miktar,
    required DateTime islemTarihi,
    required String aciklama,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc();
    final mevcut = await bagliCikis(isKaydiId);
    if (kalemId == null || miktar == null || miktar <= 0) {
      if (mevcut != null) {
        await db.update(DatabaseHelper.tableStokHareketi,
            {'is_deleted': 1, 'is_synced': 0, 'last_modified_utc': now.toIso8601String()},
            where: 'id = ?', whereArgs: [mevcut.id]);
      }
      return;
    }
    final h = StokHareketiEntity(
      id: mevcut?.id ?? const Uuid().v4(),
      kalemId: kalemId,
      islemTarihi: islemTarihi.toUtc(),
      tur: StokHareketTuru.cikis,
      miktar: miktar,
      aciklama: aciklama,
      isKaydiId: isKaydiId,
      createdAtUtc: mevcut?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    );
    await DatabaseHelper().upsert(DatabaseHelper.tableStokHareketi, StokHareketiModel.toRow(h));
  }

  /// İş kaydı silinince/geri alınınca bağlı çıkış da aynı duruma geçer.
  static Future<void> silindiYap(String isKaydiId, bool silindi) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DatabaseHelper.tableStokHareketi,
      {'is_deleted': silindi ? 1 : 0, 'is_synced': 0, 'last_modified_utc': DateTime.now().toUtc().toIso8601String()},
      where: 'is_kaydi_id = ?',
      whereArgs: [isKaydiId],
    );
  }
}
