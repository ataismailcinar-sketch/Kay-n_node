import '../../../core/database/database_helper.dart';
import '../../../core/services/hava_durumu_servisi.dart';
import '../../parsel_harita/data/models/parsel_model.dart';
import '../../veresiye/data/veresiye_model.dart';
import '../domain/bildirim.dart';
import '../../parsel_harita/domain/entities/parsel_entity.dart';
import 'bildirim_ayarlari.dart';
import 'hatirlatma_model.dart';

/// Tüm uyarıları doğrudan veritabanından ve hava servisinden üretir (Riverpod yok).
/// Uygulama kapalıyken arka plan görevi bunu kullanır; bildirim planı tümüyle yeniden
/// kurulduğu için don dışındaki uyarılar (vade, hatırlatma) da dahil edilmelidir.
Future<List<Uyari>> tumUyarilariOku({DateTime? simdi}) async {
  final an = simdi ?? DateTime.now();
  final db = await DatabaseHelper().database;
  final ayarlar = await BildirimAyarlari.oku();

  // Don kapalıysa hava tahmini hiç çekilmez.
  final parseller = !ayarlar.acik(UyariTuru.don)
      ? const <ParselEntity>[]
      : (await db.query(DatabaseHelper.tableParseller, where: 'is_deleted = 0'))
          .map(ParselModel.fromRow)
          .where((p) => p.merkezLat != 0 || p.merkezLng != 0);
  final tahminler = <String, List<GunlukHavaVerisi>>{};
  for (final p in parseller) {
    try {
      // İnternet yoksa son kayıtlı tahmin döner; o da yoksa bu tarla atlanır.
      tahminler[p.ad] = (await HavaDurumuServisi.parselHavaDurumuGetir(p, zorla: true)).gelecekYediGunTahmin;
    } catch (_) {}
  }

  final cariler = (await db.query(DatabaseHelper.tableCari, where: 'is_deleted = 0')).map(CariModel.fromRow).toList();
  final hareketler =
      (await db.query(DatabaseHelper.tableCariHareket, where: 'is_deleted = 0')).map(CariHareketModel.fromRow).toList();
  final hatirlatmalar =
      (await db.query(DatabaseHelper.tableHatirlatma, where: 'is_deleted = 0')).map(HatirlatmaModel.fromRow).toList();

  return ayarlar.suz([
    ...donUyarilari(tahminler, an),
    ...vadeUyarilari(cariler, hareketler, an),
    ...hatirlatmaUyarilari(hatirlatmalar, an),
  ]);
}
