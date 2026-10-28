import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/widgets/tutar_tus_takimi.dart';
import '../../data/models/gider_model.dart';
import '../../domain/entities/gider_entity.dart';
import '../../../veresiye/presentation/veresiye_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// Yeni Gider Girişi İçin Durum Makinesi
// ════════════════════════════════════════════════════════════════════════════

/// Sıfır-klavye gider giriş ekranının tüm anlık durumu.
class GiderGirisState {
  final String islemTuru; // 'Gider' veya 'Gelir'
  final String? secilenParselId;
  final String? secilenKategori;
  final String? secilenAltKategori;
  final double tutar;
  final bool kaydedildi;

  /// İşlemin yapıldığı gün (yerel saat, gün başı). null = bugün.
  final DateTime? tarih;

  /// Düzenlenen kayıt; null ise yeni kayıt girilir.
  final GiderEntity? duzenlenen;

  /// Düzenlenen kayıt veresiye defterindeki bir alış/satıştan açıldı (değişiklik oraya da yansır).
  final bool veresiyeBagli;

  const GiderGirisState({
    this.islemTuru = 'Gider',
    this.secilenParselId,
    this.secilenKategori,
    this.secilenAltKategori,
    this.tutar = 0,
    this.kaydedildi = false,
    this.tarih,
    this.duzenlenen,
    this.veresiyeBagli = false,
  });

  bool get hazir =>
      secilenKategori != null && secilenAltKategori != null && tutar > 0;

  GiderGirisState copyWith({
    String? islemTuru,
    String? secilenParselId,
    String? secilenKategori,
    String? secilenAltKategori,
    double? tutar,
    bool? kaydedildi,
    DateTime? tarih,
    bool temizleParsel = false,
    bool temizleKategori = false,
    bool temizleAltKategori = false,
  }) =>
      GiderGirisState(
        islemTuru: islemTuru ?? this.islemTuru,
        secilenParselId:
            temizleParsel ? null : (secilenParselId ?? this.secilenParselId),
        secilenKategori:
            temizleKategori ? null : (secilenKategori ?? this.secilenKategori),
        secilenAltKategori: temizleAltKategori
            ? null
            : (secilenAltKategori ?? this.secilenAltKategori),
        tutar: tutar ?? this.tutar,
        kaydedildi: kaydedildi ?? this.kaydedildi,
        tarih: tarih ?? this.tarih,
        duzenlenen: duzenlenen,
        veresiyeBagli: veresiyeBagli,
      );
}

/// Tuş takımıyla girilebilecek en yüksek tutar (yanlışlıkla fazla sıfır basılmasına karşı).
const double _maksTutar = 99999999;

/// Seçilen günü kayıt zamanına çevirir: bugünse şu an, geçmiş bir günse o günün öğlesi
/// (öğle seçilir ki UTC'ye çevrilince tarih bir önceki güne kaymasın).
DateTime islemZamani(DateTime? gun) {
  final simdi = DateTime.now();
  if (gun == null || DateUtils.isSameDay(gun, simdi)) return simdi.toUtc();
  return DateTime(gun.year, gun.month, gun.day, 12).toUtc();
}

// ── Provider ─────────────────────────────────────────────────────────────────
final giderGirisProvider =
    NotifierProvider<GiderGirisNotifier, GiderGirisState>(
        GiderGirisNotifier.new);

class GiderGirisNotifier extends Notifier<GiderGirisState> {
  @override
  GiderGirisState build() => const GiderGirisState();

  void islemTuruSec(String islemTuru) {
    state = state.copyWith(
      islemTuru: islemTuru,
      temizleKategori: true,
      temizleAltKategori: true,
    );
  }

  void parselSec(String? parselId) {
    // copyWith null değeri "değiştirme" diye yorumlar; "Genel" seçimi için temizle.
    state = parselId == null
        ? state.copyWith(temizleParsel: true)
        : state.copyWith(secilenParselId: parselId);
  }

  void kategoriSec(String kategori) {
    state = state.copyWith(
      secilenKategori: kategori,
      temizleAltKategori: true,
    );
  }

  void altKategoriSec(String altKategori) {
    state = state.copyWith(secilenAltKategori: altKategori);
  }

  void tutarEkle(double miktar) {
    state = state.copyWith(tutar: (state.tutar + miktar).clamp(0, _maksTutar).toDouble());
  }

  /// Tuş takımından rakam ("0"-"9" veya "000") ekler.
  void rakamEkle(String rakam) {
    state = state.copyWith(tutar: TutarTusTakimi.rakamEkle(state.tutar, rakam, maks: _maksTutar));
  }

  /// Son haneyi siler.
  void haneSil() {
    state = state.copyWith(tutar: TutarTusTakimi.haneSil(state.tutar));
  }

  void tutarSifirla() {
    state = state.copyWith(tutar: 0);
  }

  void tarihSec(DateTime gun) {
    state = state.copyWith(tarih: DateTime(gun.year, gun.month, gun.day));
  }

  /// Listeden seçilen kaydı forma yükler.
  /// Bağlılık sorgusu bitince tamamlanır (arayüz beklemek zorunda değil).
  Future<void> duzenlemeBaslat(GiderEntity g) {
    final yerel = g.giderTarihi.toLocal();
    state = GiderGirisState(
      islemTuru: g.islemTuru,
      secilenParselId: g.parselId,
      secilenKategori: g.kategori,
      secilenAltKategori: g.altKategori,
      tutar: g.tutar,
      tarih: DateTime(yerel.year, yerel.month, yerel.day),
      duzenlenen: g,
    );
    return VeresiyeBagi.hareketVarMi(g.id).then((bagli) {
      if (bagli && state.duzenlenen?.id == g.id) {
        state = GiderGirisState(
          islemTuru: state.islemTuru,
          secilenParselId: state.secilenParselId,
          secilenKategori: state.secilenKategori,
          secilenAltKategori: state.secilenAltKategori,
          tutar: state.tutar,
          tarih: state.tarih,
          duzenlenen: g,
          veresiyeBagli: true,
        );
      }
    });
  }

  /// Düzenlemeyi bırak, boş forma dön.
  void duzenlemeIptal() => sifirla();

  /// Kayıttan sonra formu temizle; işlem türü, seçili tarla ve tarih korunur
  /// (aynı günün fişleri art arda girilebilsin).
  void sifirla() => state = GiderGirisState(
        islemTuru: state.islemTuru,
        secilenParselId: state.secilenParselId,
        tarih: state.duzenlenen == null ? state.tarih : null,
      );

  Future<String?> kaydet() async {
    if (!state.hazir) return 'Lütfen kategori, alt kategori ve tutar seçin.';
    final duzenlenen = state.duzenlenen;
    if (duzenlenen != null && duzenlenen.islemTuru != state.islemTuru && await VeresiyeBagi.hareketVarMi(duzenlenen.id)) {
      return 'Bu kayıt veresiye defterine bağlı; gelir/gider türünü Veresiye Defteri''nden değiştirin.';
    }

    final now = DateTime.now().toUtc();
    final eski = state.duzenlenen;
    // Düzenlemede gün değişmediyse kaydın orijinal saati korunur.
    final ayniGun = eski != null && state.tarih != null && DateUtils.isSameDay(eski.giderTarihi.toLocal(), state.tarih);
    final gider = GiderEntity(
      id: eski?.id ?? const Uuid().v4(),
      parselId: state.secilenParselId,
      islemTuru: state.islemTuru,
      kategori: state.secilenKategori!,
      altKategori: state.secilenAltKategori!,
      tutar: state.tutar,
      paraBirimi: eski?.paraBirimi ?? 'TRY',
      notMetni: eski?.notMetni,
      giderTarihi: ayniGun ? eski.giderTarihi : islemZamani(state.tarih),
      createdAtUtc: eski?.createdAtUtc ?? now,
      lastModifiedUtc: now,
      isSynced: false,
    );

    final db = await DatabaseHelper().database;
    await db.transaction((txn) async {
      await DatabaseHelper.upsertWith(txn, DatabaseHelper.tableMuhasebeGider, GiderModel.toRow(gider));
      // Veresiyeden açılmış kayıtsa tutar ve tarih bağlı harekete de yazılır (bakiye tutarlı kalsın).
      if (eski != null) await VeresiyeBagi.hareketiGuncelle(txn, gider);
    });
    ref.invalidate(cariHareketListeProvider);

    state = state.copyWith(kaydedildi: true);
    return null;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Gider Listesi Provider (özet görüntüleme ve silme işlemi için)
// ════════════════════════════════════════════════════════════════════════════
final giderListeProvider =
    AsyncNotifierProvider<GiderListeNotifier, List<GiderEntity>>(
        GiderListeNotifier.new);

class GiderListeNotifier extends AsyncNotifier<List<GiderEntity>> {
  @override
  Future<List<GiderEntity>> build() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      DatabaseHelper.tableMuhasebeGider,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'gider_tarihi DESC',
      // Limit yok: kâr/zarar toplamları tüm kayıtlardan hesaplanır
      // (eskiden yalnızca son 50 kayıt toplanıyordu).
    );
    return rows.map(GiderModel.fromRow).toList();
  }

  /// Kaydı siler. Veresiyeden açılmışsa bağlı hareket de silinir (gider yokken borç kalmasın);
  /// bu durumda true döner.
  Future<bool> sil(String id) => _silindiYap(id, true);

  /// Silmeyi geri al (snackbar "Geri Al").
  Future<void> geriAl(String id) => _silindiYap(id, false);

  Future<bool> _silindiYap(String id, bool silindi) async {
    final db = await DatabaseHelper().database;
    final degisim = {
      'is_deleted': silindi ? 1 : 0,
      'is_synced': 0,
      'last_modified_utc': DateTime.now().toUtc().toIso8601String(),
    };
    var bagli = false;
    await db.transaction((txn) async {
      await txn.update(DatabaseHelper.tableMuhasebeGider, degisim, where: 'id = ?', whereArgs: [id]);
      bagli = await txn.update(DatabaseHelper.tableCariHareket, degisim, where: 'muhasebe_kaydi_id = ?', whereArgs: [id]) > 0;
    });
    ref.invalidateSelf();
    if (bagli) ref.invalidate(cariHareketListeProvider);
    return bagli;
  }

  void yenile() => ref.invalidateSelf();
}
