import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/zirai_recete_engine.dart';

/// Model teşhis koyamadığında kullanıcının belirtiyi kendisinin seçtiği liste.
/// Seçilen reçeteyi döner; vazgeçilirse null.
class ManuelTeshisSheet extends StatelessWidget {
  final String? urun;
  final String aciklama;

  const ManuelTeshisSheet({super.key, this.urun, required this.aciklama});

  static Future<ZiraiRecete?> show(BuildContext context, {String? urun, required String aciklama}) {
    return showModalBottomSheet<ZiraiRecete>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManuelTeshisSheet(urun: urun, aciklama: aciklama),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receteler = ZiraiReceteEngine.urunIcinReceteler(urun);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              urun == null ? 'Belirtiyi Seçin' : 'Belirtiyi Seçin — $urun',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(aciklama, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            if (receteler.length <= 1)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Bu ürün için kayıtlı hastalık reçetesi yok. Sorun görüyorsanız bir ziraat mühendisine danışın.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ...receteler.map((r) {
              final saglikli = r.hastalikAdi.contains('Sağlıklı');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(saglikli ? '🌿' : '🧪', style: const TextStyle(fontSize: 24)),
                  title: Text(r.hastalikAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    r.aciklama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, r),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Emin değilim — kaydetme'),
            ),
          ],
        ),
      ),
    );
  }
}
