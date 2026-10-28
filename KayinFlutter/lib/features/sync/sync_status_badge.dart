import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/oturum.dart';
import 'sync_manager.dart';
import 'sync_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

/// AppBar'da gösterilen canlı sync durum göstergesi + Gece/Gündüz Teması Geçiş Butonu.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final lastResult = ref.watch(lastSyncResultProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hesap + tema ayarı (başlığa yer kalsın diye tek butonda)
        IconButton(
          onPressed: () => _HesapSayfasi.goster(context),
          icon: Icon(Icons.account_circle_rounded, color: isDark ? AppTheme.primaryMint : Colors.white),
          tooltip: 'Hesabım ve Ayarlar',
        ),

        // ☁️ Sync Durumu Badge
        GestureDetector(
          onTap: () {
            ref.read(autoSyncProvider.notifier).syncNow();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 Senkronizasyon başlatıldı...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor(status), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusIcon(status: status),
                  const SizedBox(width: 4),
                  Text(
                    _shortLabel(status, lastResult),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(SyncStatus status) => switch (status) {
        SyncStatus.idle     => Colors.grey,
        SyncStatus.syncing  => AppTheme.primaryMint,
        SyncStatus.success  => AppTheme.successColor,
        SyncStatus.error    => AppTheme.dangerColor,
        SyncStatus.offline  => AppTheme.warningColor,
      };

  String _shortLabel(SyncStatus status, SyncResult? result) {
    if (status == SyncStatus.success && result != null) {
      return '↑${result.pushedCount} ↓${result.pulledCount}';
    }
    // Dönen simge yeter; uzun yazı ekran başlığını kesiyordu.
    if (status == SyncStatus.syncing) return '…';
    return status.label;
  }
}

/// Hesap bilgisi ve çıkış.
class _HesapSayfasi extends ConsumerWidget {
  const _HesapSayfasi();

  static void goster(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => const _HesapSayfasi(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oturum = ref.watch(oturumProvider).valueOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryMint,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              title: Text(oturum?.adSoyad ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(oturum?.telefonMetni ?? ''),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_rounded),
              title: const Text('Karanlık Mod'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Lisanslar ve veri kaynakları'),
              onTap: () => showLicensePage(context: context, applicationName: 'Kayın Tarım'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.dangerColor),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => _cikisOnayla(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cikisOnayla(BuildContext context, WidgetRef ref) async {
    final gonderilmemis = await ref.read(yerelVeriProvider).kayitSayisi(sadeceGonderilmemis: true);
    if (!context.mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: Text(
          gonderilmemis > 0
              ? '⚠️ $gonderilmemis kayıt henüz sunucuya gönderilmedi ve çıkışta KAYBOLACAK. '
                  'Önce internete bağlanıp senkronizasyonun bitmesini bekleyin.'
              : 'Bu cihazdaki kayıtlar silinir. Tekrar giriş yapınca hepsi sunucudan geri yüklenir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(gonderilmemis > 0 ? 'Yine de Çık' : 'Çıkış Yap', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    Navigator.pop(context); // alt sayfayı kapat
    await ref.read(oturumProvider.notifier).cikis();
  }
}

class _StatusIcon extends StatefulWidget {
  final SyncStatus status;
  const _StatusIcon({required this.status});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.status == SyncStatus.syncing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_StatusIcon old) {
    super.didUpdateWidget(old);
    if (widget.status == SyncStatus.syncing) {
      _ctrl.repeat();
    } else {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (widget.status) {
      SyncStatus.idle     => Icons.cloud_outlined,
      SyncStatus.syncing  => Icons.sync,
      SyncStatus.success  => Icons.cloud_done_outlined,
      SyncStatus.error    => Icons.cloud_off_outlined,
      SyncStatus.offline  => Icons.wifi_off_rounded,
    };

    final color = switch (widget.status) {
      SyncStatus.idle     => Colors.grey,
      SyncStatus.syncing  => AppTheme.primaryMint,
      SyncStatus.success  => AppTheme.successColor,
      SyncStatus.error    => AppTheme.dangerColor,
      SyncStatus.offline  => AppTheme.warningColor,
    };

    if (widget.status == SyncStatus.syncing) {
      return RotationTransition(
        turns: _ctrl,
        child: Icon(icon, size: 16, color: color),
      );
    }

    return Icon(icon, size: 16, color: color);
  }
}
