import '../../bildirimler/presentation/bildirimler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../depo/presentation/depo_provider.dart';
import '../../depo/presentation/depo_screen.dart';
import '../../parsel_harita/domain/entities/parsel_entity.dart';
import '../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../../sync/sync_status_badge.dart';
import '../domain/is_kaydi_entity.dart';
import 'is_gunlugu_provider.dart';
import 'is_kaydi_formu.dart';

String _tarihMetni(DateTime t) {
  final y = t.toLocal();
  return '${y.day}.${y.month}.${y.year}';
}

/// Tarlalarda yapılan işlerin günlüğü ve süren hasat yasakları.
class IsGunluguScreen extends ConsumerStatefulWidget {
  const IsGunluguScreen({super.key});

  @override
  ConsumerState<IsGunluguScreen> createState() => _IsGunluguScreenState();
}

class _IsGunluguScreenState extends ConsumerState<IsGunluguScreen> {
  String? _filtreParselId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kayitlarAsync = ref.watch(isKaydiListeProvider);
    final parseller = ref.watch(parselListeProvider).valueOrNull ?? const <ParselEntity>[];
    final parselAdi = {for (final p in parseller) p.id: p.ad};
    final yasaklar = ref.watch(hasatYasaklariProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('İş Günlüğü'),
        actions: [
          IconButton(
            tooltip: 'Depo (gübre, ilaç, tohum)',
            onPressed: () => DepoScreen.ac(context),
            icon: Badge(
              isLabelVisible: ref.watch(azalanStokSayisiProvider) > 0,
              label: Text('${ref.watch(azalanStokSayisiProvider)}'),
              child: Icon(Icons.warehouse_rounded, color: isDark ? AppTheme.primaryMint : Colors.white),
            ),
          ),
          const BildirimZili(),
          const SyncStatusBadge(),
        ],
      ),
      floatingActionButton: parseller.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => IsKaydiFormu.goster(context, parselId: _filtreParselId),
              backgroundColor: AppTheme.primaryMint,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('İş Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
      body: parseller.isEmpty
          ? const _BosEkran(
              ikon: Icons.landscape_rounded,
              baslik: 'Önce tarla ekleyin',
              metin: 'İş kaydı bir tarlaya bağlanır. "Parseller" sekmesinden tarlanızı çizin.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (yasaklar.isNotEmpty) ...[
                  _HasatYasaklariKarti(yasaklar: yasaklar.values.toList(), parselAdi: parselAdi),
                  const SizedBox(height: 16),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tüm tarlalar'),
                        selected: _filtreParselId == null,
                        selectedColor: AppTheme.primaryMint,
                        onSelected: (_) => setState(() => _filtreParselId = null),
                      ),
                      for (final p in parseller) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('${p.urunEmoji} ${p.ad}'),
                          selected: _filtreParselId == p.id,
                          selectedColor: AppTheme.primaryMint,
                          onSelected: (_) => setState(() => _filtreParselId = p.id),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                kayitlarAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
                  error: (e, _) => Text('Hata: $e', style: const TextStyle(color: Colors.red)),
                  data: (kayitlar) {
                    final liste = _filtreParselId == null
                        ? kayitlar
                        : kayitlar.where((k) => k.parselId == _filtreParselId).toList();
                    if (liste.isEmpty) {
                      return const _BosEkran(
                        ikon: Icons.event_note_rounded,
                        baslik: 'Henüz iş kaydı yok',
                        metin: 'İlaçlama, gübreleme, sulama gibi işleri "İş Ekle" ile kaydedin. '
                            'İlaçlamada etiketteki bekleme süresini girerseniz hasat uyarısı alırsınız.',
                      );
                    }
                    return Column(
                      children: [
                        for (final k in liste)
                          _IsKaydiKarti(
                            kayit: k,
                            parselAdi: parselAdi[k.parselId] ?? 'Silinmiş tarla',
                            yasak: yasaklar[k.parselId]?.kaynak.id == k.id ? yasaklar[k.parselId] : null,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _HasatYasaklariKarti extends StatelessWidget {
  final List<HasatYasagi> yasaklar;
  final Map<String, String> parselAdi;
  const _HasatYasaklariKarti({required this.yasaklar, required this.parselAdi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.block_rounded, color: AppTheme.dangerColor),
              SizedBox(width: 8),
              Text('Hasat Edilemez', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.dangerColor)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'İlaç kalıntısı için etiketteki bekleme süresi dolmadı.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          for (final y in yasaklar) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.dangerColor, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${y.kalanGun} gün',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parselAdi[y.parselId] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${_tarihMetni(y.serbestTarih)} tarihinden itibaren hasat edilebilir'
                        '${y.kaynak.urunAdi.isEmpty ? '' : ' • ${y.kaynak.urunAdi}'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IsKaydiKarti extends ConsumerWidget {
  final IsKaydiEntity kayit;
  final String parselAdi;
  final HasatYasagi? yasak;
  const _IsKaydiKarti({required this.kayit, required this.parselAdi, this.yasak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayrintilar = [
      if (kayit.hasatKg != null) 'Hasat: ${miktarMetni(kayit.hasatKg!)}',
      if (kayit.urunAdi.isNotEmpty) kayit.urunAdi,
      if (kayit.miktar.isNotEmpty) kayit.miktar,
      if (kayit.hasatBeklemeGun != null) 'Bekleme: ${kayit.hasatBeklemeGun} gün',
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => IsKaydiFormu.goster(context, duzenlenen: kayit),
        leading: CircleAvatar(
          backgroundColor: kayit.tur.renk.withValues(alpha: 0.15),
          child: Icon(kayit.tur.ikon, color: kayit.tur.renk),
        ),
        title: Text('${kayit.tur.ad} • $parselAdi', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          [_tarihMetni(kayit.islemTarihi), if (ayrintilar.isNotEmpty) ayrintilar].join('\n'),
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: ayrintilar.isNotEmpty,
        trailing: yasak == null
            ? Icon(kayit.isSynced ? Icons.cloud_done_outlined : Icons.phone_android_rounded,
                size: 18, color: kayit.isSynced ? Colors.green : Colors.orange)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.dangerColor, borderRadius: BorderRadius.circular(8)),
                child: Text('${yasak!.kalanGun} gün',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
      ),
    );
  }
}

class _BosEkran extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String metin;
  const _BosEkran({required this.ikon, required this.baslik, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(ikon, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(baslik, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(metin, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
