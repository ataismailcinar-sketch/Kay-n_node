import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../klavyesiz_muhasebe/data/models/gider_model.dart';
import '../../klavyesiz_muhasebe/domain/entities/gider_entity.dart';
import '../../klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';
import '../data/veresiye_model.dart';
import '../domain/veresiye.dart';

final cariListeProvider = AsyncNotifierProvider<CariListeNotifier, List<CariEntity>>(CariListeNotifier.new);
final cariHareketListeProvider =
    AsyncNotifierProvider<CariHareketListeNotifier, List<CariHareketEntity>>(CariHareketListeNotifier.new);

/// Hesap id → durum (bakiye, vadesi geçen, yaklaşan vade).
final cariDurumlariProvider = Provider<Map<String, CariDurumu>>((ref) {
  final cariler = ref.watch(cariListeProvider).valueOrNull ?? const [];
  final hareketler = ref.watch(cariHareketListeProvider).valueOrNull ?? const [];
  final bugun = DateTime.now();
  return {
    for (final c in cariler) c.id: cariDurumu(hareketler.where((h) => h.cariId == c.id), bugun),
  };
});

class VeresiyeOzeti {
  final double toplamBorc;
  final double toplamAlacak;
  final double vadesiGecen;
  final int vadesiGecenHesap;
  const VeresiyeOzeti(this.toplamBorc, this.toplamAlacak, this.vadesiGecen, this.vadesiGecenHesap);
}

final veresiyeOzetiProvider = Provider<VeresiyeOzeti>((ref) {
  var borc = 0.0, alacak = 0.0, gecen = 0.0, gecenHesap = 0;
  for (final d in ref.watch(cariDurumlariProvider).values) {
    if (d.borcluyum) borc += d.bakiye;
    if (d.alacakliyim) alacak += -d.bakiye;
    if (d.vadesiGecen > 0.005) {
      gecen += d.vadesiGecen;
      gecenHesap++;
    }
  }
  return VeresiyeOzeti(borc, alacak, gecen, gecenHesap);
});

/// Muhasebe ekranından, veresiye hareketiyle açılmış gider/gelir değiştirilince hareketi eşitler.
class VeresiyeBagi {
  static Future<bool> hareketVarMi(String muhasebeId) async {
    final db = await DatabaseHelper().database;
    final r = await db.query(DatabaseHelper.tableCariHareket,
        columns: ['id'], where: 'muhasebe_kaydi_id = ? AND is_deleted = 0', whereArgs: [muhasebeId], limit: 1);
    return r.isNotEmpty;
  }

  /// Bağlı hareketin tutarını ve işlem tarihini kayıttakine eşitler (vade, açıklama değişmez).
  static Future<void> hareketiGuncelle(DatabaseExecutor db, GiderEntity g) => db.update(
        DatabaseHelper.tableCariHareket,
        {
          'tutar': g.tutar,
          'islem_tarihi': g.giderTarihi.toUtc().toIso8601String(),
          'is_synced': 0,
          'last_modified_utc': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'muhasebe_kaydi_id = ? AND is_deleted = 0',
        whereArgs: [g.id],
      );
}

class CariListeNotifier extends AsyncNotifier<List<CariEntity>> {
  @override
  Future<List<CariEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(DatabaseHelper.tableCari, where: 'is_deleted = 0', orderBy: 'ad COLLATE NOCASE');
    return rows.map(CariModel.fromRow).toList();
  }

  Future<CariEntity> kaydet({CariEntity? eski, required String ad, required CariTuru tur, String telefon = ''}) async {
    final now = DateTime.now().toUtc();
    final cari = CariEntity(
      id: eski?.id ?? const Uuid().v4(),
      ad: ad.trim(),
      tur: tur,
      telefon: telefon.trim(),
      not: eski?.not ?? '',
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
    );
    await DatabaseHelper().upsert(DatabaseHelper.tableCari, CariModel.toRow(cari));
    ref.invalidateSelf();
    return cari;
  }

  /// Hesabı, hareketlerini ve hareketlerle açılmış muhasebe kayıtlarını siler (yumuşak silme).
  Future<void> sil(String cariId) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc().toIso8601String();
    final silindi = {'is_deleted': 1, 'is_synced': 0, 'last_modified_utc': now};
    await db.transaction((txn) async {
      final hareketler = await txn.query(DatabaseHelper.tableCariHareket,
          columns: ['muhasebe_kaydi_id'], where: 'cari_id = ? AND is_deleted = 0', whereArgs: [cariId]);
      for (final h in hareketler) {
        final mid = h['muhasebe_kaydi_id'] as String?;
        if (mid != null) await txn.update(DatabaseHelper.tableMuhasebeGider, silindi, where: 'id = ?', whereArgs: [mid]);
      }
      await txn.update(DatabaseHelper.tableCariHareket, silindi, where: 'cari_id = ? AND is_deleted = 0', whereArgs: [cariId]);
      await txn.update(DatabaseHelper.tableCari, silindi, where: 'id = ?', whereArgs: [cariId]);
    });
    ref.invalidateSelf();
    ref.invalidate(cariHareketListeProvider);
    ref.invalidate(giderListeProvider);
  }
}

class CariHareketListeNotifier extends AsyncNotifier<List<CariHareketEntity>> {
  @override
  Future<List<CariHareketEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(DatabaseHelper.tableCariHareket, where: 'is_deleted = 0', orderBy: 'islem_tarihi DESC');
    return rows.map(CariHareketModel.fromRow).toList();
  }

  /// Hareketi kaydeder. Veresiye alış/satışta [muhasebeyeIsle] ise aynı tutarda bir gider
  /// (alış) ya da gelir (satış) kaydı açılır/güncellenir; ödeme ve tahsilat muhasebeye
  /// girmez (masraf alındığı gün yazıldı, ödeme yalnızca borcu kapatır).
  Future<void> kaydet({
    CariHareketEntity? eski,
    required CariEntity cari,
    required HareketTuru tur,
    required double tutar,
    required DateTime islemTarihi,
    DateTime? vadeTarihi,
    String aciklama = '',
    bool muhasebeyeIsle = false,
    String? kategori,
    String? parselId,
  }) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toUtc();
    final isle = muhasebeyeIsle && tur.borcDogurur;

    await db.transaction((txn) async {
      String? muhasebeId = eski?.muhasebeKaydiId;
      if (isle) {
        muhasebeId ??= const Uuid().v4();
        await _muhasebeYaz(
          txn,
          id: muhasebeId,
          gelir: tur == HareketTuru.satis,
          kategori: kategori ?? (tur == HareketTuru.satis ? 'Hasat' : 'Diger'),
          tutar: tutar,
          tarih: islemTarihi,
          parselId: parselId,
          not: 'Veresiye: ${cari.ad}${aciklama.trim().isEmpty ? '' : ' — ${aciklama.trim()}'}',
          now: now,
        );
      } else if (muhasebeId != null) {
        // Artık muhasebeye işlenmiyor (ör. türü ödemeye çevrildi) → bağlı kaydı sil.
        await txn.update(
          DatabaseHelper.tableMuhasebeGider,
          {'is_deleted': 1, 'is_synced': 0, 'last_modified_utc': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [muhasebeId],
        );
        muhasebeId = null;
      }

      final hareket = CariHareketEntity(
        id: eski?.id ?? const Uuid().v4(),
        cariId: cari.id,
        islemTarihi: islemTarihi.toUtc(),
        tur: tur,
        tutar: tutar,
        vadeTarihi: tur.borcDogurur ? vadeTarihi : null,
        aciklama: aciklama.trim(),
        muhasebeKaydiId: muhasebeId,
        createdAtUtc: eski?.createdAtUtc ?? now,
        lastModifiedUtc: now,
      );
      await DatabaseHelper.upsertWith(txn, DatabaseHelper.tableCariHareket, CariHareketModel.toRow(hareket));
    });

    ref.invalidateSelf();
    ref.invalidate(giderListeProvider);
  }

  static Future<void> _muhasebeYaz(
    Transaction txn, {
    required String id,
    required bool gelir,
    required String kategori,
    required double tutar,
    required DateTime tarih,
    required String? parselId,
    required String not,
    required DateTime now,
  }) async {
    final mevcut = await txn.query(DatabaseHelper.tableMuhasebeGider,
        columns: ['created_at_utc'], where: 'id = ?', whereArgs: [id]);
    final kayit = GiderEntity(
      id: id,
      parselId: parselId,
      islemTuru: gelir ? 'Gelir' : 'Gider',
      kategori: kategori,
      altKategori: gelir ? 'Veresiye Satış' : 'Veresiye',
      tutar: tutar,
      giderTarihi: tarih.toUtc(),
      notMetni: not,
      createdAtUtc: mevcut.isEmpty ? now : DateTime.parse(mevcut.first['created_at_utc'] as String),
      lastModifiedUtc: now,
    );
    await DatabaseHelper.upsertWith(txn, DatabaseHelper.tableMuhasebeGider, GiderModel.toRow(kayit));
  }

  /// Hareketi (ve bağlı muhasebe kaydını) siler ya da geri getirir.
  Future<void> silindiYap(CariHareketEntity h, bool silindi) async {
    final db = await DatabaseHelper().database;
    final degisim = {
      'is_deleted': silindi ? 1 : 0,
      'is_synced': 0,
      'last_modified_utc': DateTime.now().toUtc().toIso8601String(),
    };
    await db.transaction((txn) async {
      await txn.update(DatabaseHelper.tableCariHareket, degisim, where: 'id = ?', whereArgs: [h.id]);
      if (h.muhasebeKaydiId != null) {
        await txn.update(DatabaseHelper.tableMuhasebeGider, degisim, where: 'id = ?', whereArgs: [h.muhasebeKaydiId]);
      }
    });
    ref.invalidateSelf();
    ref.invalidate(giderListeProvider);
  }

  /// Bağlı muhasebe kaydının kategorisi ve tarlası (düzenleme formunu doldurmak için).
  Future<({String? kategori, String? parselId})> muhasebeBilgisi(String? muhasebeId) async {
    if (muhasebeId == null) return (kategori: null, parselId: null);
    final db = await DatabaseHelper().database;
    final r = await db.query(DatabaseHelper.tableMuhasebeGider,
        columns: ['kategori', 'parsel_id'], where: 'id = ? AND is_deleted = 0', whereArgs: [muhasebeId]);
    if (r.isEmpty) return (kategori: null, parselId: null);
    return (kategori: r.first['kategori'] as String?, parselId: r.first['parsel_id'] as String?);
  }
}
