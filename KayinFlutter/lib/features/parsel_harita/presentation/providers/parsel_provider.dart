import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/parsel_repository_impl.dart';
import '../../domain/entities/parsel_entity.dart';
import '../../domain/sulama.dart';
import '../../domain/repositories/parsel_repository.dart';
import '../../domain/usecases/parsel_usecases.dart';
import '../../domain/usecases/poligon_duzeltme_usecase.dart';

// ── Repository Provider ──────────────────────────────────────────────────────
final parselRepositoryProvider = Provider<ParselRepository>(
  (_) => ParselRepositoryImpl(),
);

// ── UseCase Provider'ları ────────────────────────────────────────────────────
final getParsellerUseCaseProvider = Provider(
  (ref) => GetParsellerUseCase(ref.read(parselRepositoryProvider)),
);
final saveParselUseCaseProvider = Provider(
  (ref) => SaveParselUseCase(ref.read(parselRepositoryProvider)),
);
final deleteParselUseCaseProvider = Provider(
  (ref) => DeleteParselUseCase(ref.read(parselRepositoryProvider)),
);
final alanHesaplaProvider = Provider((_) => PoligonAlanHesaplaUseCase());
final merkezHesaplaProvider = Provider((_) => PoligonMerkezHesaplaUseCase());
final poligonDuzeltProvider = Provider((_) => PoligonDuzeltmeUseCase());

// ════════════════════════════════════════════════════════════════════════════
// Parsel Listesi — AsyncNotifierProvider
// ════════════════════════════════════════════════════════════════════════════
final parselListeProvider =
    AsyncNotifierProvider<ParselListeNotifier, List<ParselEntity>>(
        ParselListeNotifier.new);

class ParselListeNotifier extends AsyncNotifier<List<ParselEntity>> {
  @override
  Future<List<ParselEntity>> build() =>
      ref.read(getParsellerUseCaseProvider).call();

  /// Yeni parsel kaydet ve listeyi yenile
  Future<void> kaydet(ParselEntity parsel) async {
    await ref.read(saveParselUseCaseProvider).call(parsel);
    ref.invalidateSelf();
  }

  /// Parsel adını, ekili ürününü, toprak türünü ve ekim tarihini güncelle
  Future<void> guncelle(String id,
      {String? yeniAd,
      String? yeniUrun,
      String? yeniToprakTuru,
      bool? yeniSulu,
      SulamaYontemi? yeniSulamaYontemi,
      SuKaynagi? yeniSuKaynagi,
      Object? yeniSuEc = degismedi,
      DateTime? yeniEkimTarihi}) async {
    final repo = ref.read(parselRepositoryProvider);
    final mevcut = await repo.getById(id);
    if (mevcut != null) {
      final guncel = mevcut.copyWith(
        ad: yeniAd ?? mevcut.ad,
        ekilmisUrun: yeniUrun ?? mevcut.ekilmisUrun,
        toprakTuru: yeniToprakTuru ?? mevcut.toprakTuru,
        sulu: yeniSulu,
        sulamaYontemi: yeniSulamaYontemi,
        suKaynagi: yeniSuKaynagi,
        suEc: yeniSuEc,
        ekimTarihi: yeniEkimTarihi ?? mevcut.ekimTarihi,
        isSynced: false,
      );
      await repo.save(guncel);
      ref.invalidateSelf();
    }
  }

  /// Parsel sil ve listeyi yenile
  Future<void> sil(String id) async {
    await ref.read(deleteParselUseCaseProvider).call(id);
    ref.invalidateSelf();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Harita Çizim Durumu — NotifierProvider
// ════════════════════════════════════════════════════════════════════════════
class HaritaCizimState {
  final List<LatLngPoint> noktalar;
  final double alanDonum;
  final bool cizimTamamlandi;

  const HaritaCizimState({
    this.noktalar = const [],
    this.alanDonum = 0.0,
    this.cizimTamamlandi = false,
  });

  HaritaCizimState copyWith({
    List<LatLngPoint>? noktalar,
    double? alanDonum,
    bool? cizimTamamlandi,
  }) =>
      HaritaCizimState(
        noktalar: noktalar ?? this.noktalar,
        alanDonum: alanDonum ?? this.alanDonum,
        cizimTamamlandi: cizimTamamlandi ?? this.cizimTamamlandi,
      );
}

final haritaCizimProvider =
    NotifierProvider<HaritaCizimNotifier, HaritaCizimState>(
        HaritaCizimNotifier.new);

class HaritaCizimNotifier extends Notifier<HaritaCizimState> {
  @override
  HaritaCizimState build() => const HaritaCizimState();

  void noktaEkle(LatLngPoint nokta) {
    if (state.cizimTamamlandi) return;
    final yeniNoktalar = [...state.noktalar, nokta];
    final alan = ref.read(alanHesaplaProvider).call(yeniNoktalar);
    state = state.copyWith(noktalar: yeniNoktalar, alanDonum: alan);
  }

  void geriAl() {
    if (state.noktalar.isEmpty) return;
    final yeniNoktalar = state.noktalar.sublist(0, state.noktalar.length - 1);
    final alan = ref.read(alanHesaplaProvider).call(yeniNoktalar);
    state = state.copyWith(noktalar: yeniNoktalar, alanDonum: alan);
  }

  /// 🪄 Görsel Chaikin Algoritması ile Tarla Sınırlarını Otomatik Düzelt & Pürüzsüzleştir
  void sinirlariDuzelt() {
    if (state.noktalar.length < 3) return;
    final duzeltilmis = ref.read(poligonDuzeltProvider).execute(state.noktalar);
    final yeniAlan = ref.read(alanHesaplaProvider).call(duzeltilmis);
    state = state.copyWith(noktalar: duzeltilmis, alanDonum: yeniAlan);
  }

  void temizle() => state = const HaritaCizimState();

  Future<String?> kaydet(String parselAd, {String ekilmisUrun = 'Buğday', String toprakTuru = 'Tınlı', bool? sulu, SulamaYontemi? sulamaYontemi, SuKaynagi? suKaynagi, double? suEc}) async {
    if (state.noktalar.length < 3) return 'En az 3 nokta gereklidir.';

    try {
      final merkez = ref.read(merkezHesaplaProvider).call(state.noktalar);
      final id = const Uuid().v4();
      final now = DateTime.now().toUtc();

      final parsel = ParselEntity(
        id: id,
        ad: parselAd.trim().isEmpty ? 'Özel Tarla' : parselAd.trim(),
        ekilmisUrun: ekilmisUrun,
        toprakTuru: toprakTuru,
        sulu: sulu,
        sulamaYontemi: sulamaYontemi,
        suKaynagi: suKaynagi,
        suEc: suEc,
        konum: '${merkez.lat.toStringAsFixed(3)}, ${merkez.lng.toStringAsFixed(3)}',
        poligonNoktalar: state.noktalar,
        alanDonumCinsinden: state.alanDonum,
        merkezLat: merkez.lat,
        merkezLng: merkez.lng,
        createdAtUtc: now,
        lastModifiedUtc: now,
        isSynced: false,
      );

      await ref.read(parselListeProvider.notifier).kaydet(parsel);
      state = const HaritaCizimState();
      return null;
    } catch (e) {
      return 'Kaydetme hatası: $e';
    }
  }
}
