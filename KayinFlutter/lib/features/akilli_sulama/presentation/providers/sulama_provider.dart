import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/table_columns.dart';
import '../../../../core/services/hava_durumu_servisi.dart';
import '../../../arazi_analiz/domain/sezonluk_iklim_motoru.dart';
import '../../../arazi_analiz/domain/zirai_karar_destek_engine.dart';
import '../../../parsel_harita/data/repositories/parsel_repository_impl.dart';
import '../../../parsel_harita/domain/entities/parsel_entity.dart';
import '../../domain/entities/sulama_entity.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final sulamaListeProvider =
    AsyncNotifierProvider<SulamaListeNotifier, List<SulamaEntity>>(
        SulamaListeNotifier.new);

/// Tarlanın Open-Meteo canlı iklim ve ekimden hasada biriken yağış özeti
final parselHavaProvider = FutureProvider.family<TarlaHavaOzeti, ParselEntity>((ref, parsel) async {
  return await HavaDurumuServisi.parselHavaDurumuGetir(parsel);
});

/// Tarlanın İlaçlama Radarı, Gübreleme Yağış Uyarısı ve Toprak Tavı Kararları
final parselZiraiKararProvider = FutureProvider.family<ZiraiKararPaketi, ParselEntity>((ref, parsel) async {
  final hava = await ref.watch(parselHavaProvider(parsel).future);
  return ZiraiKararDestekEngine.kararlariUret(parsel: parsel, hava: hava);
});

/// Tarlanın Ekimden Hasada Gelişme Derece Günleri (GDD) ve Fenolojik Takvimi
final parselSezonlukGelisimProvider = FutureProvider.family<SezonlukGelisimRaporu, ParselEntity>((ref, parsel) async {
  final hava = await ref.watch(parselHavaProvider(parsel).future);
  return SezonlukIklimMotoru.hesapla(parsel: parsel, hava: hava);
});

/// Tüm parsellerin son sulama/nem/verim durumunu SQLite'dan okur.
class SulamaListeNotifier extends AsyncNotifier<List<SulamaEntity>> {
  @override
  Future<List<SulamaEntity>> build() => _yukle();

  Future<List<SulamaEntity>> _yukle() async {
    final db       = DatabaseHelper();
    final database = await db.database;
    final parselRepo = ParselRepositoryImpl();
    final parseller  = await parselRepo.getAll();

    final List<SulamaEntity> sonuclar = [];

    for (final parsel in parseller) {
      // Her parselin en son sulama kaydı
      final rows = await database.query(
        DatabaseHelper.tableYagisSulama,
        where: 'parsel_id = ? AND is_deleted = ?',
        whereArgs: [parsel.id, 0],
        orderBy: 'kayit_tarihi DESC',
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final row = rows.first;
        sonuclar.add(SulamaEntity(
          id: row[TableColumns.id] as String,
          parselId: parsel.id,
          parselAd: parsel.ad,
          alanDonum: parsel.alanDonumCinsinden,
          kayitTarihi: DateTime.parse(
              row[TableColumns.sulamaKayitTarihi] as String),
          yagisMillimetre:
              (row[TableColumns.sulamaYagisMm] as num?)?.toDouble() ?? 0.0,
          toprakNemiYuzde:
              (row[TableColumns.sulamaToprakNemi] as num?)?.toDouble() ?? -1,
          kayitTuru: row[TableColumns.sulamaKayitTuru] as String? ?? 'Otomatik',
          aciliyetSeviyesi:
              row[TableColumns.sulamaAciliyetSeviyesi] as String? ?? 'Normal',
          isSynced: (row[TableColumns.isSynced] as int?) == 1,
        ));
      } else {
        // Henüz hava/nem verisi yok — değer uydurulmaz.
        sonuclar.add(SulamaEntity(
          id: '',
          parselId: parsel.id,
          parselAd: parsel.ad,
          alanDonum: parsel.alanDonumCinsinden,
          kayitTarihi: DateTime.now(),
          yagisMillimetre: 0.0,
          toprakNemiYuzde: -1,
          kayitTuru: 'Otomatik',
          aciliyetSeviyesi: 'Bilinmiyor',
        ));
      }
    }

    // Aciliyete göre sırala (Acil önce)
    sonuclar.sort((a, b) {
      const sira = ['Acil', 'Normal', 'Yeterli', 'Dolu', 'Bilinmiyor'];
      return sira.indexOf(a.aciliyetSeviyesi)
          .compareTo(sira.indexOf(b.aciliyetSeviyesi));
    });

    return sonuclar;
  }

  void yenile() => ref.invalidateSelf();
}
