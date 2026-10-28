import '../../../bildirimler/presentation/bildirimler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../is_gunlugu/presentation/is_gunlugu_provider.dart';
import '../../domain/entities/parsel_entity.dart';
import '../providers/parsel_provider.dart';
import '../../../karne/presentation/tarla_karnesi_screen.dart';
import '../widgets/parsel_detay_sheet.dart';
import '../widgets/sulu_secici.dart';
import '../../domain/sulama.dart';
import '../../../akilli_sulama/presentation/providers/sulama_provider.dart';
import 'parsel_harita_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/demo_veri_servisi.dart';
import '../../../sync/sync_status_badge.dart';
import '../../../klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';
import '../../../yaprak_hastalik_ai/presentation/providers/hastalik_tarama_provider.dart';

/// Kayıtlı tüm parselleri gösteren liste ekranı.
class ParselListesiScreen extends ConsumerWidget {
  const ParselListesiScreen({super.key});

  Future<void> _ornekVeriYukle(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
    );

    try {
      await DemoVeriServisi.ornekVerileriYukle();
      ref.invalidate(parselListeProvider);
      ref.invalidate(sulamaListeProvider);
      ref.invalidate(giderListeProvider);
      ref.invalidate(hastalikTaramaListeProvider);

      if (context.mounted) {
        Navigator.pop(context); // close spinner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('3 örnek tarla ve örnek muhasebe kayıtları yüklendi.'),
            backgroundColor: AppTheme.primaryEmerald,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parselAsync = ref.watch(parselListeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Parsellerim'),
        actions: [
          parselAsync.maybeWhen(
            data: (parseller) => parseller.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.assessment_rounded, color: AppTheme.primaryMint),
                    tooltip: 'Çiftlik Karnesi & Bilanço',
                    onPressed: () => TarlaKarnesiScreen.ac(context),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          // Örnek veri yalnızca boş ekranda sunulur: dolu listede yanlışlıkla basılınca tarlalar ikileniyordu.
          const BildirimZili(),
          const SyncStatusBadge(),
        ],
      ),
      body: parselAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryMint),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 48),
              const SizedBox(height: 12),
              Text('Hata: $e', style: const TextStyle(color: AppTheme.dangerColor)),
            ],
          ),
        ),
        data: (parseller) {
          if (parseller.isEmpty) {
            return _buildBosEkran(context, ref);
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(parselListeProvider.future),
            color: AppTheme.primaryMint,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: parseller.length,
              itemBuilder: (ctx, i) => _ParselKart(parsel: parseller[i]),
            ),
          );
        },
      ),

      // Yeni parsel çiz butonu
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ParselHaritaScreen(),
          ),
        ),
        backgroundColor: AppTheme.primaryMint,
        icon: const Icon(Icons.add_location_alt_rounded, size: 28, color: Colors.white),
        label: const Text(
          'Yeni Tarla Çiz',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBosEkran(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Henüz tarla eklenmedi',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aşağıdaki butondan tarlanızı haritada çizebilir\nveya tek dokunuşla hazır örnek verileri yükleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _ornekVeriYukle(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.science_rounded, color: Colors.white),
              label: const Text(
                '🧪 Örnek Çiftlik Verilerini Yükle',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Parsel Kart Widget'ı ─────────────────────────────────────────────────────
class _ParselKart extends ConsumerWidget {
  final ParselEntity parsel;
  const _ParselKart({required this.parsel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool synced = parsel.isSynced;
    final yasak = ref.watch(hasatYasaklariProvider)[parsel.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ParselDetaySheet.show(context, parsel),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık satırı
            Row(
              children: [
                Text(parsel.urunEmoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsel.ad,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Ekili Ürün: ${parsel.ekilmisUrun} • ${parsel.toprakTuru} Toprak${parsel.sulu == null ? '' : ' • ${parsel.suluMetni}'}',
                        style: const TextStyle(color: AppTheme.primaryMint, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Sync durumu rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: synced ? AppTheme.successColor.withOpacity(0.15) : AppTheme.warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    synced ? '☁️ Senkronize' : '📱 Yerel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: synced ? AppTheme.successColor : AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Alan ve konum bilgisi
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _InfoChip(
                  ikon: Icons.square_foot_rounded,
                  metin: parsel.alanMetinsel,
                  renk: AppTheme.primaryMint,
                ),
                _InfoChip(
                  ikon: Icons.event_rounded,
                  metin: parsel.ekimTarihi == null
                      ? 'Ekim tarihi yok'
                      : 'Ekim: ${parsel.ekimTarihi!.day}.${parsel.ekimTarihi!.month}.${parsel.ekimTarihi!.year}',
                  renk: AppTheme.infoColor,
                ),
                if (yasak != null)
                  _InfoChip(
                    ikon: Icons.block_rounded,
                    metin: 'Hasat yasak: ${yasak.kalanGun} gün',
                    renk: AppTheme.dangerColor,
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Eylem butonları (Haritada Gör, Düzenle, Sil)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ParselHaritaScreen(odakParsel: parsel)),
                      );
                    },
                    icon: const Icon(Icons.map_rounded, size: 20, color: Colors.white),
                    label: const Text('Haritada Gör', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryMint,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _duzenleDialog(context, ref),
                  icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryMint),
                  tooltip: 'Düzenle',
                ),
                IconButton(
                  onPressed: () => _silOnayla(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Sil',
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _duzenleDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController(text: parsel.ad);
    String secilenUrun = parsel.ekilmisUrun;
    String secilenToprak = parsel.toprakTuru;
    bool? secilenSulu = parsel.sulu;
    SulamaYontemi? secilenYontem = parsel.sulamaYontemi;
    SuKaynagi? secilenKaynak = parsel.suKaynagi;
    double? secilenSuEc = parsel.suEc;
    const urunSecenekleri = ParselEntity.urunSecenekleri;
    final toprakSecenekleri = ['Tınlı', 'Killi', 'Kumlu', 'Kireçli'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Tarlayı Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: 'Tarla Adı'),
                ),
                const SizedBox(height: 14),
                const Text('Ekilen Ürün:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: urunSecenekleri.map((u) {
                    final isSel = secilenUrun == u;
                    return ChoiceChip(
                      label: Text(u),
                      selected: isSel,
                      selectedColor: AppTheme.primaryMint,
                      onSelected: (_) => setDialogState(() => secilenUrun = u),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Toprak Bünyesi:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: toprakSecenekleri.map((t) {
                    final isSel = secilenToprak == t;
                    return ChoiceChip(
                      label: Text(t),
                      selected: isSel,
                      selectedColor: Colors.amber[800],
                      onSelected: (_) => setDialogState(() => secilenToprak = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Sulama:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SuluSecici(
          deger: secilenSulu,
          degisti: (v) => setDialogState(() => secilenSulu = v),
          yontem: secilenYontem,
          yontemDegisti: (v) => setDialogState(() => secilenYontem = v),
          kaynak: secilenKaynak,
          kaynakDegisti: (v) => setDialogState(() => secilenKaynak = v),
          suEc: secilenSuEc,
          suEcDegisti: (v) => secilenSuEc = v,
        ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dialogCtx);
                final yeniAd = textController.text.trim();
                await ref.read(parselListeProvider.notifier).guncelle(
                      parsel.id,
                      yeniAd: yeniAd.isEmpty ? parsel.ad : yeniAd,
                      yeniUrun: secilenUrun,
                      yeniToprakTuru: secilenToprak,
                      yeniSulu: secilenSulu,
                      yeniSulamaYontemi: secilenYontem,
                      yeniSuKaynagi: secilenKaynak,
                      yeniSuEc: secilenSuEc,
                    );
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ Tarla bilgileri güncellendi!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMint),
              child: const Text('GÜNCELLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _silOnayla(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Parseli Sil'),
        content: Text('"${parsel.ad}" silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              ref.read(parselListeProvider.notifier).sil(parsel.id);
              Navigator.pop(context);
              messenger.showSnackBar(
                SnackBar(content: Text('🗑️ "${parsel.ad}" silindi')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData ikon;
  final String metin;
  final Color renk;
  const _InfoChip({required this.ikon, required this.metin, required this.renk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: renk, size: 16),
          const SizedBox(width: 4),
          Text(
            metin,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: renk),
          ),
        ],
      ),
    );
  }
}
