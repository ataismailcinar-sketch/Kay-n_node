import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Büyük tuşlu tutar tuş takımı (klavyesiz giriş). Uzun basınca ⌫ tümünü temizler.
class TutarTusTakimi extends StatelessWidget {
  final ValueChanged<String> onRakam;
  final VoidCallback onSil;
  final VoidCallback onTemizle;

  const TutarTusTakimi({super.key, required this.onRakam, required this.onSil, required this.onTemizle});

  /// Görünen tutara rakam ekler; [maks] aşılırsa değişmez.
  static double rakamEkle(double tutar, String rakam, {double maks = 99999999}) {
    final yeni = double.parse('${tutar.toStringAsFixed(0)}$rakam');
    return yeni <= maks ? yeni : tutar;
  }

  static double haneSil(double tutar) {
    final metin = tutar.toStringAsFixed(0);
    return metin.length <= 1 ? 0 : double.parse(metin.substring(0, metin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const tuslar = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: tuslar.map((t) {
        final sil = t == '⌫';
        return Material(
          color: isDark ? const Color(0xFF1E2D27) : AppTheme.lightBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => sil ? onSil() : onRakam(t),
            onLongPress: sil ? onTemizle : null,
            child: Center(
              child: sil
                  ? const Icon(Icons.backspace_rounded, color: Colors.red, size: 26)
                  : Text(
                      t,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
