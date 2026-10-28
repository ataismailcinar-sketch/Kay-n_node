import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/fenoloji_engine.dart';

/// Fenolojik Takvim & Sezonluk İş Hatırlatıcıları Kartı
class FenolojikTakvimWidget extends StatelessWidget {
  final String ekilmisUrun;
  final DateTime? ekimTarihi;
  final VoidCallback? onEkimTarihiDegistir;

  const FenolojikTakvimWidget({
    super.key,
    required this.ekilmisUrun,
    this.ekimTarihi,
    this.onEkimTarihiDegistir,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sonuc = FenolojiEngine.hesapla(
      ekilmisUrun: ekilmisUrun,
      ekimTarihi: ekimTarihi,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryMint.withOpacity(0.3), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Ekim Tarihi Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryMint, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Bitki Gelişim & İş Takvimi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              if (onEkimTarihiDegistir != null)
                TextButton.icon(
                  onPressed: onEkimTarihiDegistir,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppTheme.primaryMint),
                  label: Text(
                    ekimTarihi != null
                        ? '${ekimTarihi!.day}.${ekimTarihi!.month}.${ekimTarihi!.year}'
                        : 'Ekim Tarihi Seç',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryMint),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (ekimTarihi == null && FenolojiEngine.ekimTarihiGerekli(ekilmisUrun)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '⚠️ Ekim tarihi girilmedi; aşağıdaki evre 60 gün önce ekildiği VARSAYILARAK gösteriliyor. '
                'Doğru takvim için ekim tarihini seçin.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Mevcut Evre Rozeti ve Açıklama
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryEmerald.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sonuc.evreAdi,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryEmerald),
                    ),
                    Text(
                      '🌱 ${sonuc.gecenGun}. Gün',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sonuc.evreAciklama,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
                const SizedBox(height: 8),

                // Gelişim İlerleme Çubuğu
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: sonuc.ilerlemeYuzdesi,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryMint),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '%${(sonuc.ilerlemeYuzdesi * 100).toStringAsFixed(0)} Sezon İlerlemesi',
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Hasada ~${sonuc.kalanGun} gün',
                      style: const TextStyle(fontSize: 10, color: AppTheme.primaryMint, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Yapılacak Kritik İşlemler
          const Text(
            '🚜 Bu Dönemde Yapılması Gerekenler:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),

          ...sonuc.yapilacakIsler.map((islem) => _buildIslemKarti(islem)),
        ],
      ),
    );
  }

  Widget _buildIslemKarti(TarimsalIslem islem) {
    final (oncelikRenk, oncelikBg) = switch (islem.oncelik) {
      'Kritik' || 'Acil' => (Colors.red[700]!, Colors.red.withOpacity(0.12)),
      'Yüksek' || 'Önemli' => (Colors.amber[800]!, Colors.amber.withOpacity(0.12)),
      _                    => (Colors.blue, Colors.blue.withOpacity(0.12)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: oncelikBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: oncelikRenk.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(islem.ikon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      islem.baslik,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: oncelikRenk, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        islem.oncelik,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  islem.aciklama,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
