import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_manager.dart';
import '../../core/constants/app_constants.dart';
import '../akilli_sulama/presentation/providers/sulama_provider.dart';
import '../bildirimler/presentation/bildirim_provider.dart';
import '../toprak_analizi/presentation/toprak_analizi_provider.dart';
import '../depo/presentation/depo_provider.dart';
import '../is_gunlugu/presentation/is_gunlugu_provider.dart';
import '../veresiye/presentation/veresiye_provider.dart';
import '../klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';
import '../parsel_harita/presentation/providers/parsel_provider.dart';
import '../yaprak_hastalik_ai/presentation/providers/hastalik_tarama_provider.dart';

// ── SyncManager Singleton Provider ──────────────────────────────────────────
final syncManagerProvider = Provider<SyncManager>((ref) => SyncManager());

// ── Anlık Sync Durumu Provider ───────────────────────────────────────────────
/// Mevcut sync durumunu (idle/syncing/success/error/offline) tutar.
final syncStatusProvider =
    StateProvider<SyncStatus>((ref) => SyncStatus.idle);

// ── Son Sync Sonucu Provider ─────────────────────────────────────────────────
final lastSyncResultProvider =
    StateProvider<SyncResult?>((_) => null);

// ════════════════════════════════════════════════════════════════════════════
// AutoSyncNotifier — Arka planda periyodik sync yapan Notifier
//
// Kullanım (main.dart veya AppShell'de):
//   ref.read(autoSyncProvider); // Zamanlayıcıyı başlatır
// ════════════════════════════════════════════════════════════════════════════
class AutoSyncNotifier extends AsyncNotifier<SyncResult?> {
  Timer? _timer;

  /// Aynı anda iki sync çalışmasın. (Eskiden `state is AsyncLoading` kontrol
  /// ediliyordu; build() sırasında state zaten AsyncLoading olduğu için açılıştaki
  /// ilk sync hiç çalışmıyordu.)
  bool _calisiyor = false;

  /// Provider kapatıldıysa (ör. kapsayıcı yok edildi) bekleyen sync ref'e dokunmamalı.
  bool _kapandi = false;

  @override
  Future<SyncResult?> build() async {
    // Widget dispose edildiğinde timer'ı iptal et
    ref.onDispose(() {
      _timer?.cancel();
      _kapandi = true;
    });

    // İlk sync build() bittikten sonra başlar: Riverpod, bir provider kurulurken
    // başka provider'ların (syncStatusProvider) değiştirilmesine izin vermez.
    Future(_runSync);

    // Sonrasında AppConstants.syncIntervalSeconds saniyede bir çalıştır
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.syncIntervalSeconds),
      (_) => _runSync(),
    );

    return null;
  }

  Future<SyncResult?> _runSync() async {
    if (_kapandi) return null;
    if (_calisiyor) return state.value;
    _calisiyor = true;

    try {
      ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

      final manager = ref.read(syncManagerProvider);
      final result  = await manager.syncAll();
      if (_kapandi) return result;

      state = AsyncData(result);
      ref.read(syncStatusProvider.notifier).state = result.status;
      ref.read(lastSyncResultProvider.notifier).state = result;

      // Sunucudan veri geldiyse veya yerel veri gönderildiyse UI'ı tazele
      if (result.status == SyncStatus.success && (result.pulledCount > 0 || result.pushedCount > 0)) {
        ref.invalidate(parselListeProvider);
        ref.invalidate(sulamaListeProvider);
        ref.invalidate(giderListeProvider);
        ref.invalidate(hastalikTaramaListeProvider);
        ref.invalidate(isKaydiListeProvider);
        ref.invalidate(cariListeProvider);
        ref.invalidate(cariHareketListeProvider);
        ref.invalidate(stokKalemListeProvider);
        ref.invalidate(stokHareketListeProvider);
        ref.invalidate(hatirlatmaListeProvider);
        ref.invalidate(toprakAnalizListeProvider);
      }
      return result;
    } finally {
      _calisiyor = false;
    }
  }

  /// Manuel sync tetikleme (örn: kullanıcı "Şimdi Senkronize Et" butonuna basınca).
  Future<void> syncNow() => _runSync();
}

final autoSyncProvider =
    AsyncNotifierProvider<AutoSyncNotifier, SyncResult?>(AutoSyncNotifier.new);

// ── Sync Durum Badge Widget Helper ──────────────────────────────────────────
/// Renk kodu: idle=gri, syncing=sarı, success=yeşil, error=kırmızı, offline=turuncu
extension SyncStatusExtension on SyncStatus {
  String get label => switch (this) {
        SyncStatus.idle     => 'Bekliyor',
        SyncStatus.syncing  => 'Senkronize ediliyor...',
        SyncStatus.success  => 'Senkronize edildi ✓',
        SyncStatus.error    => 'Hata oluştu',
        SyncStatus.offline  => 'Çevrimdışı',
      };

  bool get isOnline => this == SyncStatus.success || this == SyncStatus.syncing;
}
