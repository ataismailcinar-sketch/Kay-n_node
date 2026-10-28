import '../../../bildirimler/presentation/bildirimler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../arazi_analiz/domain/sezonluk_iklim_motoru.dart';
import '../../../arazi_analiz/domain/zirai_karar_destek_engine.dart';
import '../../../../core/services/hava_durumu_servisi.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parsel_harita/domain/entities/parsel_entity.dart';
import '../../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../../../parsel_harita/presentation/widgets/parsel_detay_sheet.dart';
import '../../../sync/sync_status_badge.dart';
import '../providers/sulama_provider.dart';

/// 🌾 Zirai Karar Destek, Otomatik İklim & Sezonluk Yağış Takibi Ekranı
/// Çiftçiden hiçbir manuel yağış/veri girişi istemez; her şeyi Open-Meteo ve koordinattan otomatik işler.
class AkilliSulamaScreen extends ConsumerWidget {
  const AkilliSulamaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsellerAsync = ref.watch(parselListeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('İklim ve Kararlar'),
        actions: const [BildirimZili(), SyncStatusBadge()],
      ),
      body: parsellerAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryMint),
        ),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (parseller) {
          if (parseller.isEmpty) {
            return const _TarlaYokEkrani();
          }

          return RefreshIndicator(
            onRefresh: () async {
              HavaDurumuServisi.onbellegiTemizle();
              ref.invalidate(parselHavaProvider);
              ref.invalidate(parselListeProvider);
              ref.invalidate(sulamaListeProvider);
            },
            color: AppTheme.primaryMint,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // 1. ÜST GENEL BİLGİLENDİRME BANNERI
                _buildUstBilgiBanner(isDark),
                const SizedBox(height: 16),

                // 2. PARSEL BAZLI ZİRAİ KARAR VE İKLİM KARTLARI
                ...parseller.map((p) => _ParselZiraiKararKarti(parsel: p, isDark: isDark)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUstBilgiBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryMint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryMint, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Otomatik İklim & Toprak Nemi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'Yağış, rüzgar, sıcaklık ve model toprak nemi Open-Meteo\'dan tarla koordinatına göre alınır. '
                  'Toprak nemi bir model tahminidir; kritik kararlarda tarlada elle kontrol edin.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParselZiraiKararKarti extends ConsumerWidget {
  final ParselEntity parsel;
  final bool isDark;

  const _ParselZiraiKararKarti({required this.parsel, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final havaAsync = ref.watch(parselHavaProvider(parsel));
    final kararAsync = ref.watch(parselZiraiKararProvider(parsel));
    final sezonAsync = ref.watch(parselSezonlukGelisimProvider(parsel));

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Başlık: Tarla Adı & Alan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(parsel.urunEmoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsel.ad,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${parsel.ekilmisUrun} • ${parsel.alanMetinsel}${parsel.sulu == null ? '' : ' • ${parsel.suluMetni}'}',
                          style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: AppTheme.primaryMint),
                  onPressed: () => ParselDetaySheet.show(context, parsel),
                  tooltip: 'Tarla Detayı & Harita',
                ),
              ],
            ),
            const Divider(height: 24),

            // Canlı Hava & Zirai Karar Verileri
            havaAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryMint),
                ),
              ),
              error: (err, _) => Text(
                '⚠️ Hava verisi alınamadı: $err',
                style: const TextStyle(color: Colors.grey),
              ),
              data: (hava) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hava.canliVeri) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '📴 Çevrimdışı — ${hava.veriZamani.day}.${hava.veriZamani.month} ${hava.veriZamani.hour.toString().padLeft(2, '0')}:${hava.veriZamani.minute.toString().padLeft(2, '0')} tarihli son veri gösteriliyor.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // EKİMDEN BUGÜNE BİRİKEN YAĞIŞ & GDD BİLGİSİ
                    sezonAsync.when(
                      data: (sezon) => _buildSezonlukGelisimBand(sezon),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),

                    // ZİRAİ KARAR RADARI KARTLARI (İLAÇLAMA & GÜBRELEME)
                    kararAsync.when(
                      data: (karar) => Column(
                        children: [
                          _buildSulamaKarti(karar.sulama, parsel.alanDonumCinsinden),
                          const SizedBox(height: 10),
                          // Tav bilgisi yalnızca ekim öncesinde anlamlı.
                          if (parsel.ekimTarihi == null) ...[
                            _buildEkimTaviKarti(karar.ekimTavi),
                            const SizedBox(height: 10),
                          ],
                          _buildKararKartlari(karar),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),

                    // CANLI 7 GÜNLÜK HAVA & YAĞIŞ TAHMİN ŞERİDİ
                    _buildGelecekYediGunSeridi(hava),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSezonlukGelisimBand(SezonlukGelisimRaporu sezon) {
    final dekor = BoxDecoration(
      color: isDark ? const Color(0xFF13221C) : const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.3)),
    );

    if (!sezon.ekimTarihiVar) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: dekor,
        child: Text('📅 ${sezon.kritikMevsimselGorev}', style: const TextStyle(fontSize: 12)),
      );
    }

    final kapsamNotu = sezon.tamKapsam ? '' : ' (son ${sezon.kapsamaGunu} gün)';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: dekor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sezon.toplamBirikenYagisMm == null
                      ? 'Ekimden bugüne yağış: veri yok'
                      : 'Ekimden bugüne yağış: ${sezon.toplamBirikenYagisMm!.toStringAsFixed(0)} mm$kapsamNotu',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Text(
                '${sezon.ekimdenBeriGecenGun}. gün',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryMint),
              ),
            ],
          ),
          if (sezon.toplamGddIsilGun != null) ...[
            const SizedBox(height: 4),
            Text(
              '🌡️ Birikmiş ısıl gün (GDD): ${sezon.toplamGddIsilGun!.toStringAsFixed(0)}$kapsamNotu',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: sezon.evreTamamlanmaYuzdesi,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryMint),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '🌱 ${sezon.mevcutFenolojikEvre}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sezon.tahminiHasataKalanGun != null)
                Text(
                  sezon.tahminiHasataKalanGun == 0 ? 'Hasat dönemi' : 'Hasata ~${sezon.tahminiHasataKalanGun} gün',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('👉 ${sezon.kritikMevsimselGorev}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSulamaKarti(SulamaTavsiyesi sulama, double alanDonum) {
    final renk = switch (sulama.aciliyet) {
      'Acil' => AppTheme.dangerColor,
      'Normal' => Colors.amber[800]!,
      'Yeterli' => AppTheme.successColor,
      _ => Colors.grey,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_rounded, color: renk, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(sulama.baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: renk)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(sulama.detay, style: const TextStyle(fontSize: 12, height: 1.3)),
          if (sulama.sulamaGerekli && sulama.donumBasiTon > 0 && alanDonum > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Tüm tarla (${alanDonum.toStringAsFixed(0)} dönüm): ~${(sulama.donumBasiTon * alanDonum).toStringAsFixed(0)} ton su',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: renk),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEkimTaviKarti(EkimTavTavsiyesi tav) {
    final renk = tav.toprakTavinda ? AppTheme.successColor : Colors.brown;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.agriculture_rounded, color: renk, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Ekim Tavı: ${tav.baslik}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: renk)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tav.detay, style: const TextStyle(fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildKararKartlari(ZiraiKararPaketi karar) {
    final ilac = karar.ilaclama;
    final gubre = karar.gubreleme;

    return Column(
      children: [
        // 1. İlaçlama Radarı
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ilac.uygun ? const Color(0xFF0F766E).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ilac.uygun ? const Color(0xFF0F766E).withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ilac.uygun ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: ilac.uygun ? const Color(0xFF0F766E) : Colors.red,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '💨 İlaçlama Rüzgar Radarı',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ilac.uygun ? const Color(0xFF0F766E) : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ilac.durumRozeti,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ilac.detay, style: const TextStyle(fontSize: 12, height: 1.3)),
                    if (ilac.uygun) ...[
                      const SizedBox(height: 4),
                      Text(
                        '⏰ Uygun Saatler: ${ilac.idealSaatler}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 2. Gübreleme Yağış Alarmı
        if (gubre.yagisAlarmiVar)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_download_rounded, color: Color(0xFF0284C7), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gubre.baslik,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(height: 4),
                      Text(gubre.detay, style: const TextStyle(fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGelecekYediGunSeridi(TarlaHavaOzeti hava) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📅 7 Günlük Yağış & Sıcaklık Tahmini',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: hava.gelecekYediGunTahmin.map((g) {
              final simdi = DateTime.now();
              final isToday = g.tarih.year == simdi.year && g.tarih.month == simdi.month && g.tarih.day == simdi.day;
              final hasRain = g.yagisMm > 0.5;

              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppTheme.primaryMint.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? Border.all(color: AppTheme.primaryMint) : null,
                ),
                child: Column(
                  children: [
                    Text(
                      isToday ? 'Bugün' : '${g.tarih.day}/${g.tarih.month}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppTheme.primaryMint : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      hasRain ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
                      size: 20,
                      color: hasRain ? const Color(0xFF0284C7) : Colors.orange,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${g.maxSicaklik.toStringAsFixed(0)}°',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (hasRain)
                      Text(
                        '${g.yagisMm.toStringAsFixed(0)}mm',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      )
                    else
                      Text(
                        '${g.maxRuzgarHizi.toStringAsFixed(0)}k/s',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TarlaYokEkrani extends StatelessWidget {
  const _TarlaYokEkrani();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.landscape_rounded, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Henüz Eklenmiş Tarla Yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '"Parseller" sekmesinden haritada tarlanızı çizdiğiniz anda tüm geçmiş yağışlar, rüzgar ve toprak verileri otomatik yüklenecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
