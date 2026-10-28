import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/hava_durumu_servisi.dart';
import '../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../../veresiye/presentation/veresiye_provider.dart';
import '../data/bildirim_ayarlari.dart';
import '../data/hatirlatma_model.dart';
import '../domain/bildirim.dart';

final hatirlatmaListeProvider =
    AsyncNotifierProvider<HatirlatmaListeNotifier, List<HatirlatmaEntity>>(HatirlatmaListeNotifier.new);

/// Tarla adı → önümüzdeki günlerin tahmini (konumu olan tarlalar). İnternet yoksa son kayıtlı veri.
final donTahminleriProvider = FutureProvider<Map<String, List<GunlukHavaVerisi>>>((ref) async {
  final parseller = await ref.watch(parselListeProvider.future);
  final sonuc = <String, List<GunlukHavaVerisi>>{};
  for (final p in parseller) {
    if (p.merkezLat == 0 && p.merkezLng == 0) continue;
    try {
      final ozet = await HavaDurumuServisi.parselHavaDurumuGetir(p);
      sonuc[p.ad] = ozet.gelecekYediGunTahmin;
    } catch (_) {
      // Bu tarlanın verisi yok; diğerleriyle devam.
    }
  }
  return sonuc;
});

/// Tüm uyarılar (zamanı gelmemişler dahil). Hatırlatma ve veresiye verisi henüz yüklenmediyse null:
/// bildirim planı eksik veriyle kurulmasın.
final tumUyarilarProvider = Provider<List<Uyari>?>((ref) {
  final hatirlatmalar = ref.watch(hatirlatmaListeProvider);
  final cariler = ref.watch(cariListeProvider);
  final hareketler = ref.watch(cariHareketListeProvider);
  final ayarlar = ref.watch(bildirimAyarlariProvider);
  if (!hatirlatmalar.hasValue || !cariler.hasValue || !hareketler.hasValue || !ayarlar.hasValue) return null;
  final a = ayarlar.value!;
  final simdi = DateTime.now();
  // Kapalı türler hiç üretilmez: ne zilde ne bildirim çubuğunda görünür (don kapalıysa hava da çekilmez).
  return [
    if (a.acik(UyariTuru.don)) ...donUyarilari(ref.watch(donTahminleriProvider).valueOrNull ?? const {}, simdi),
    if (a.acik(UyariTuru.vade)) ...vadeUyarilari(cariler.value!, hareketler.value!, simdi),
    if (a.acik(UyariTuru.hatirlatma)) ...hatirlatmaUyarilari(hatirlatmalar.value!, simdi),
  ];
});

final bildirimAyarlariProvider =
    AsyncNotifierProvider<BildirimAyarlariNotifier, BildirimAyarlari>(BildirimAyarlariNotifier.new);

class BildirimAyarlariNotifier extends AsyncNotifier<BildirimAyarlari> {
  @override
  Future<BildirimAyarlari> build() => BildirimAyarlari.oku();

  Future<void> degistir(UyariTuru tur, bool acik) async {
    final yeni = (state.valueOrNull ?? const BildirimAyarlari()).degistir(tur, acik);
    await yeni.yaz();
    state = AsyncData(yeni);
  }
}

/// Bildirimler ekranında ve zil rozetinde gösterilenler.
final aktifUyarilarProvider = Provider<List<Uyari>>((ref) {
  return aktifUyarilar(ref.watch(tumUyarilarProvider) ?? const [], DateTime.now());
});

class HatirlatmaListeNotifier extends AsyncNotifier<List<HatirlatmaEntity>> {
  @override
  Future<List<HatirlatmaEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(DatabaseHelper.tableHatirlatma, where: 'is_deleted = 0', orderBy: 'tarih');
    return rows.map(HatirlatmaModel.fromRow).toList();
  }

  Future<void> kaydet({
    HatirlatmaEntity? eski,
    required String baslik,
    required HatirlatmaTuru tur,
    required DateTime tarih,
    required int kacGunOnce,
    required bool herYil,
    String not = '',
  }) async {
    final now = DateTime.now().toUtc();
    await _yaz(HatirlatmaEntity(
      id: eski?.id ?? const Uuid().v4(),
      baslik: baslik.trim(),
      tur: tur,
      tarih: DateTime(tarih.year, tarih.month, tarih.day),
      kacGunOnce: kacGunOnce,
      herYil: herYil,
      // Tarihi ileri alınan tamamlanmış hatırlatma yeniden açılır.
      tamamlandi: (eski?.tamamlandi ?? false) && !tarih.isAfter(eski!.tarih),
      not: not.trim(),
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    ));
  }

  /// Her yıl tekrarlayan bir yıl ileri alınır, diğeri tamamlandı olur.
  Future<void> yapildi(HatirlatmaEntity h) async {
    final s = yapildiSonrasi(h);
    await _yaz(HatirlatmaEntity(
      id: h.id,
      baslik: h.baslik,
      tur: h.tur,
      tarih: s.tarih,
      kacGunOnce: h.kacGunOnce,
      herYil: h.herYil,
      tamamlandi: s.tamamlandi,
      not: h.not,
      createdAtUtc: h.createdAtUtc,
      lastModifiedUtc: DateTime.now().toUtc(),
    ));
  }

  Future<void> silindiYap(String id, bool silindi) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DatabaseHelper.tableHatirlatma,
      {'is_deleted': silindi ? 1 : 0, 'is_synced': 0, 'last_modified_utc': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }

  Future<void> _yaz(HatirlatmaEntity h) async {
    await DatabaseHelper().upsert(DatabaseHelper.tableHatirlatma, HatirlatmaModel.toRow(h));
    ref.invalidateSelf();
  }
}
