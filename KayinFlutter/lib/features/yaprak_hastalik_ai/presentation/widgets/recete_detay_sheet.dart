import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/yaprak_etiket_eslestirici.dart';
import '../../domain/zirai_recete_engine.dart';

/// Zirai İlaç & Tedavi Reçetesi Bottom Sheet Modalı
class ReceteDetaySheet extends StatelessWidget {
  final String teshisAdi;
  final double? guvenYuzdesi;

  const ReceteDetaySheet({
    super.key,
    required this.teshisAdi,
    this.guvenYuzdesi,
  });

  static void show(BuildContext context, String teshisAdi, {double? guvenYuzdesi}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceteDetaySheet(teshisAdi: teshisAdi, guvenYuzdesi: guvenYuzdesi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recete = YaprakEtiketEslestirici.teshisReceti(teshisAdi);
    if (recete == null) return _buildReceteYok(context, isDark);
    final isSaglikli = recete.hastalikAdi.contains('Sağlıklı');

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Başlık & Tehlike Rozeti
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSaglikli ? AppTheme.successColor.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(isSaglikli ? '🌿' : '🧪', style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recete.hastalikAdi,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                      Text(
                        recete.latinceAdi,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSaglikli ? AppTheme.successColor : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              recete.tehlikeSeviyesi,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (guvenYuzdesi != null && guvenYuzdesi! > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '%${guvenYuzdesi!.toStringAsFixed(0)} AI Güveni',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryMint),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryMint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.agriculture_rounded, color: AppTheme.primaryMint, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🌾 Hedef Ürünler: ${recete.hedefUrunler}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryEmerald),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              recete.aciklama,
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
            const SizedBox(height: 16),

            // ── 1. NE ZAMAN MÜCADELE EDİLİR ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryEmerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule_rounded, color: AppTheme.primaryMint, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recete.uygulamaZamani, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. MÜCADELEDE KULLANILAN ETKİ GRUPLARI ───────────────────
            if (recete.ilaclaTedaviYok) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.block_rounded, color: AppTheme.dangerColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recete.kategori.startsWith('Belirti')
                            ? 'Bu bir hastalık adı değil, belirti. Sebebi belli olmadan ilaç kullanmayın.'
                            : 'Hastalanmış bitki ilaçla iyileşmez. Mücadele korunma ve kültürel önlemlerle yapılır.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (recete.ilacGerekir) ...[
              _buildBolumBasligi(recete.ilaclaTedaviYok
                  ? 'Korunmada kullanılan ilaç grupları'
                  : 'Mücadelede kullanılan ilaç grupları'),
              const SizedBox(height: 4),
              const Text(
                'Ürün adı ve doz bilerek verilmez — aşağıdaki uyarıya bakın.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              ...recete.mucadeleGruplari.map((g) => _buildMaddeSatiri(g, Icons.science_rounded, Colors.purple)),
              const SizedBox(height: 16),
            ],

            // ── 3. KÜLTÜREL ÖNLEMLER ──────────────────────────────────────
            _buildBolumBasligi('🌾 Kültürel & Koruyucu Önlemler'),
            const SizedBox(height: 6),
            ...recete.kulturelOnlemler.map((ko) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryMint, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ko, style: const TextStyle(fontSize: 12))),
                ],
              ),
            )),

            const SizedBox(height: 12),

            // ── 4. DİKKAT NOTU ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recete.dikkatNotu, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),

            // ── 5. YASAL UYARI: ürün, doz, bekleme süresi ─────────────────
            if (recete.ilacGerekir) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gavel_rounded, color: AppTheme.dangerColor, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ZiraiReceteEngine.yasalUyari,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Teşhis için reçete veritabanında kayıt yoksa: uydurma reçete göstermek yerine bunu söyle.
  Widget _buildReceteYok(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teshisAdi,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Bu teşhis için reçete veritabanında kayıt yok. Doğru ilaç ve doz için '
            'il/ilçe tarım müdürlüğüne veya bir ziraat mühendisine danışın.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBolumBasligi(String baslik) {
    return Text(
      baslik,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    );
  }

  Widget _buildMaddeSatiri(String metin, IconData ikon, Color renk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(ikon, color: renk, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              metin,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: renk.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }
}
