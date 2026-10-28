import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/table_columns.dart';
import '../../depo/domain/depo.dart';
import '../../depo/presentation/depo_provider.dart';
import '../data/is_kaydi_model.dart';
import '../domain/is_kaydi_entity.dart';

final isKaydiListeProvider =
    AsyncNotifierProvider<IsKaydiListeNotifier, List<IsKaydiEntity>>(IsKaydiListeNotifier.new);

/// Tarla id → hâlâ süren hasat öncesi bekleme.
final hasatYasaklariProvider = Provider<Map<String, HasatYasagi>>((ref) {
  final kayitlar = ref.watch(isKaydiListeProvider).valueOrNull ?? const [];
  return aktifHasatYasaklari(kayitlar, DateTime.now());
});

class IsKaydiListeNotifier extends AsyncNotifier<List<IsKaydiEntity>> {
  @override
  Future<List<IsKaydiEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      DatabaseHelper.tableIsKaydi,
      where: 'is_deleted = 0',
      orderBy: '${TableColumns.isTarihi} DESC',
    );
    return rows.map(IsKaydiModel.fromRow).toList();
  }

  /// Yeni kayıt ekler ya da [eski] verilmişse onu günceller.
  Future<void> kaydet({
    IsKaydiEntity? eski,
    required String parselId,
    required DateTime islemTarihi,
    required IslemTuru tur,
    String urunAdi = '',
    String miktar = '',
    int? hasatBeklemeGun,
    double? hasatKg,
    String not = '',
    String? depoKalemId,
    double? depoMiktar,
  }) async {
    final now = DateTime.now().toUtc();
    final kayit = IsKaydiEntity(
      id: eski?.id ?? const Uuid().v4(),
      parselId: parselId,
      islemTarihi: islemTarihi.toUtc(),
      tur: tur,
      urunAdi: urunAdi.trim(),
      miktar: miktar.trim(),
      // Bekleme süresi yalnızca ilaçlamada saklanır.
      hasatBeklemeGun: tur == IslemTuru.ilaclama ? hasatBeklemeGun : null,
      hasatKg: tur == IslemTuru.hasat ? hasatKg : null,
      not: not.trim(),
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    );
    await DatabaseHelper().upsert(DatabaseHelper.tableIsKaydi, IsKaydiModel.toRow(kayit));

    // Depodan düşme: yalnızca girdi kullanan işlerde; diğer türlerde (ya da seçilmediyse) bağlı çıkış kaldırılır.
    final depoli = StokKategori.isIcin(tur) != null;
    await DepoIsBaglantisi.esitle(
      isKaydiId: kayit.id,
      kalemId: depoli ? depoKalemId : null,
      miktar: depoli ? depoMiktar : null,
      islemTarihi: kayit.islemTarihi,
      aciklama: tur.ad,
    );
    ref.invalidateSelf();
    ref.invalidate(stokHareketListeProvider);
  }

  Future<void> sil(String id) => _silindiYap(id, true);

  /// Silmeyi geri al (snackbar "Geri Al").
  Future<void> geriAl(String id) => _silindiYap(id, false);

  Future<void> _silindiYap(String id, bool silindi) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DatabaseHelper.tableIsKaydi,
      {
        'is_deleted': silindi ? 1 : 0,
        'is_synced': 0,
        'last_modified_utc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await DepoIsBaglantisi.silindiYap(id, silindi);
    ref.invalidateSelf();
    ref.invalidate(stokHareketListeProvider);
  }
}
