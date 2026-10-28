import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/iklim_servisi.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parsel_harita/domain/entities/parsel_entity.dart';
import '../../../toprak_analizi/domain/toprak_analizi.dart';
import '../../../toprak_analizi/presentation/toprak_analizi_provider.dart';
import '../../domain/ecocrop_engine.dart';

/// Arazi Uygunluk & Mahsul Tavsiye sekmesi.
///
/// Skorlar tarlanın konumunun SON 12 AYLIK gerçek iklim verisine (Open-Meteo / ERA5)
/// dayanır. Veri alınamazsa skor üretilmez (sabit/uydurma iklim kullanılmaz).
/// Tarlanın toprak analizi varsa pH ve tuzluluk da hesaba katılır.
class AraziTavsiyeTab extends ConsumerStatefulWidget {
  final ParselEntity parsel;
  const AraziTavsiyeTab({super.key, required this.parsel});

  @override
  ConsumerState<AraziTavsiyeTab> createState() => _AraziTavsiyeTabState();
}

class _AraziTavsiyeTabState extends ConsumerState<AraziTavsiyeTab> {
  late Future<IklimOzeti> _iklim;

  @override
  void initState() {
    super.initState();
    _iklim = IklimServisi.getir(widget.parsel.merkezLat, widget.parsel.merkezLng);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.parsel.merkezLat == 0 && widget.parsel.merkezLng == 0) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Tarlanın konumu yok. Uygunluk analizi için tarlayı haritada çizin.'),
      );
    }
    final analiz = sonAnaliz(ref.watch(toprakAnalizListeProvider).valueOrNull ?? const [], widget.parsel.id);
    return FutureBuilder<IklimOzeti>(
      future: _iklim,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Bu konumun iklim verisi alınamadı (internet bağlantısı gerekli). '
                  'Uygunluk skoru tahmini iklimle üretilmez.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _iklim = IklimServisi.getir(widget.parsel.merkezLat, widget.parsel.merkezLng);
                  }),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          );
        }
        final i = snap.data!;
        return _AraziTavsiyeIcerik(
          iklim: i,
          toprakTuru: widget.parsel.toprakTuru,
          alanDonum: widget.parsel.alanDonumCinsinden > 0 ? widget.parsel.alanDonumCinsinden : 1.0,
          analiz: analiz,
          sulu: widget.parsel.sulu,
          suEc: widget.parsel.suEc,
        );
      },
    );
  }
}

class _AraziTavsiyeIcerik extends StatelessWidget {
  final IklimOzeti iklim;
  final String toprakTuru;
  final double alanDonum;
  final ToprakAnaliziEntity? analiz;
  final bool? sulu;
  final double? suEc;

  const _AraziTavsiyeIcerik({
    this.suEc,
    required this.iklim,
    required this.toprakTuru,
    required this.alanDonum,
    this.analiz,
    this.sulu,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ph = analiz?.ph;
    final ec = analiz == null ? null : tuzlulukEc(analiz!);
    final analizMetni = analiz == null || (ph == null && ec == null)
        ? 'Toprak analizi girilirse pH ve tuzluluk da hesaba katılır (🧪 Toprak).'
        : 'Toprak analizi (${analiz!.analizTarihi.day}.${analiz!.analizTarihi.month}.${analiz!.analizTarihi.year}) hesaba katıldı: '
            '${[
              if (ph != null) 'pH ${sayiYaz(ph, basamak: 1)}',
              if (ec != null) 'tuzluluk ${sayiYaz(ec, basamak: 1)} dS/m${analiz!.ec == null ? ' (tuz %\'den)' : ''}',
            ].join(', ')}.';

    final sonuclar = EcoCropEngine.analiziCalistir(
      ortalamaSicaklik: iklim.vejetasyonOrtSicaklik,
      sicakDonemSicaklik: iklim.sicakDonemOrtSicaklik,
      minSicaklik: iklim.mutlakMinSicaklik,
      maxSicaklik: iklim.mutlakMaxSicaklik,
      yillikYagisMm: iklim.yillikYagisMm,
      toprakTuru: toprakTuru,
      alanDonum: alanDonum,
      ph: ph,
      tuzlulukEc: ec,
      sulu: sulu,
      suEc: suEc,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bilgi Başlığı
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryEmerald.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryMint.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('🌍', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arazi & Mahsul Uygunluğu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'Son 12 ayın gerçek iklimi: yıllık yağış ${iklim.yillikYagisMm.toStringAsFixed(0)} mm, '
                      'vejetasyon dönemi ort. ${iklim.vejetasyonOrtSicaklik.toStringAsFixed(1)}°C, '
                      'en sıcak 4 ay ort. ${iklim.sicakDonemOrtSicaklik.toStringAsFixed(1)}°C, '
                      'en düşük ${iklim.mutlakMinSicaklik.toStringAsFixed(1)}°C. '
                      '$toprakTuru toprak, ${alanDonum.toStringAsFixed(1)} dönüm, '
                      '${switch (sulu) { true => 'sulu tarım (yağış açığını sulama kapatır${suEc == null ? '' : '; sulama suyu ${sayiYaz(suEc!, basamak: 1)} dS/m'})', false => 'kuru tarım (yalnız yağış)', null => 'sulu/kuru belirtilmedi (tarlayı düzenleyip seçin)' }}.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      analizMetni,
                      style: TextStyle(
                        fontSize: 11,
                        color: analiz == null ? Colors.grey : AppTheme.primaryMint,
                        fontWeight: analiz == null ? null : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Rekolte ve ciro kaba tahmindir; ortalama verim ve sabit varsayım fiyatlarıyla hesaplanır.',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Ürün Listesi
        ...sonuclar.map((s) => _buildMahsulKarti(context, s, isDark)),
      ],
    );
  }

  Widget _buildMahsulKarti(BuildContext context, MahsulUygunlukSonuc s, bool isDark) {
    final (dereceRenk, dereceArkaPlan) = switch (s.derece) {
      'A' => (AppTheme.successColor, AppTheme.successColor.withOpacity(0.15)),
      'B' => (Colors.blue, Colors.blue.withOpacity(0.15)),
      'C' => (Colors.amber[800]!, Colors.amber.withOpacity(0.15)),
      _   => (Colors.red, Colors.red.withOpacity(0.15)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.urunAdi,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${s.kategori}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Text(
                      s.dereceAciklama,
                      style: TextStyle(fontSize: 11, color: dereceRenk, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Derece Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: dereceArkaPlan,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      s.derece,
                      style: TextStyle(color: dereceRenk, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '%${s.uygunlukSkoru.toStringAsFixed(0)}',
                      style: TextStyle(color: dereceRenk, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Rekolte ve Ciro Tahmin Şeridi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  '🌾 Tahmini Rekolte: ${_formatKg(s.toplamTahminiHasatKg)} (${s.tahminiVerimKgDonum.toStringAsFixed(0)} kg/dönüm)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  '💰 ~${_formatTL(s.toplamTahminiCiroTL)} (${s.varsayilanFiyatTLKg.toStringAsFixed(1)} ₺/kg varsayım)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryMint),
                ),
              ],
            ),
          ),

          if (s.sinirlayiciFaktorler.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: s.sinirlayiciFaktorler.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('⚠️ $f', style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatKg(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(1)} Ton';
    }
    return '${kg.toStringAsFixed(0)} kg';
  }

  String _formatTL(double tl) {
    if (tl >= 1000000) {
      return '${(tl / 1000000).toStringAsFixed(2)}M ₺';
    }
    if (tl >= 1000) {
      return '${(tl / 1000).toStringAsFixed(1)}K ₺';
    }
    return '${tl.toStringAsFixed(0)} ₺';
  }
}
