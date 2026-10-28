import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/veresiye.dart';
import 'cari_detay_screen.dart';
import 'veresiye_provider.dart';

final _tl = NumberFormat.decimalPattern('tr');
String veresiyePara(double v) => '${_tl.format(v.abs().round())} ₺';
String veresiyeTarih(DateTime t) {
  final y = t.toLocal();
  return '${y.day}.${y.month}.${y.year}';
}

/// "Borcum 30.000 ₺" / "Alacağım 50.000 ₺" / "Hesap kapalı" ve rengi.
(String, Color) bakiyeMetni(CariDurumu d) => d.borcluyum
    ? ('Borcum ${veresiyePara(d.bakiye)}', AppTheme.dangerColor)
    : d.alacakliyim
        ? ('Alacağım ${veresiyePara(d.bakiye)}', const Color(0xFF2563EB))
        : ('Hesap kapalı', Colors.grey);

/// Veresiye defteri: bayi/tüccar hesapları ve toplam borç-alacak.
class VeresiyeScreen extends ConsumerWidget {
  const VeresiyeScreen({super.key});

  static void ac(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const VeresiyeScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cariler = ref.watch(cariListeProvider);
    final durumlar = ref.watch(cariDurumlariProvider);
    final ozet = ref.watch(veresiyeOzetiProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(title: const Text('Veresiye Defteri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final yeni = await CariFormu.goster(context);
          if (yeni != null && context.mounted) CariDetayScreen.ac(context, yeni.id);
        },
        backgroundColor: AppTheme.primaryMint,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('Hesap Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: cariler.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (liste) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            VeresiyeOzetKarti(ozet: ozet),
            const SizedBox(height: 16),
            if (liste.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Henüz hesap yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text(
                      'Gübre, ilaç aldığınız bayiyi ya da ürün verdiğiniz tüccarı "Hesap Ekle" ile açın; '
                      'veresiye aldıklarınızı ve ödemelerinizi oraya yazın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            for (final c in liste)
              _CariKarti(cari: c, durum: durumlar[c.id] ?? const CariDurumu(bakiye: 0, vadesiGecen: 0)),
          ],
        ),
      ),
    );
  }
}

/// Toplam borç / alacak / vadesi geçen. Muhasebe ekranında da kısayol olarak kullanılır.
class VeresiyeOzetKarti extends StatelessWidget {
  final VeresiyeOzeti ozet;
  final VoidCallback? onTap;
  const VeresiyeOzetKarti({super.key, required this.ozet, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppTheme.primaryMint),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Veresiye Defteri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryMint),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Deger('Toplam borcum', veresiyePara(ozet.toplamBorc), AppTheme.dangerColor)),
                  Expanded(child: _Deger('Toplam alacağım', veresiyePara(ozet.toplamAlacak), const Color(0xFF2563EB))),
                ],
              ),
              if (ozet.vadesiGecen > 0.005) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '⚠️ ${ozet.vadesiGecenHesap} hesapta ${veresiyePara(ozet.vadesiGecen)} vadesi geçmiş',
                    style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Deger extends StatelessWidget {
  final String etiket;
  final String deger;
  final Color renk;
  const _Deger(this.etiket, this.deger, this.renk);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(deger, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: renk)),
        ],
      );
}

class _CariKarti extends StatelessWidget {
  final CariEntity cari;
  final CariDurumu durum;
  const _CariKarti({required this.cari, required this.durum});

  @override
  Widget build(BuildContext context) {
    final (metin, renk) = bakiyeMetni(durum);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => CariDetayScreen.ac(context, cari.id),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryMint.withValues(alpha: 0.15),
          child: Icon(cari.tur.ikon, color: AppTheme.primaryMint),
        ),
        title: Text(cari.ad, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          durum.vadesiGecen > 0.005
              ? 'Vadesi geçen: ${veresiyePara(durum.vadesiGecen)}'
              : durum.yaklasanVade != null
                  ? 'Sonraki vade: ${veresiyeTarih(durum.yaklasanVade!)}'
                  : cari.tur.ad,
          style: TextStyle(
            color: durum.vadesiGecen > 0.005 ? AppTheme.dangerColor : Colors.grey,
            fontWeight: durum.vadesiGecen > 0.005 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Text(metin, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}

/// Hesap ekleme/düzenleme. Kaydedilen hesabı döner.
class CariFormu extends ConsumerStatefulWidget {
  final CariEntity? eski;
  const CariFormu({super.key, this.eski});

  static Future<CariEntity?> goster(BuildContext context, {CariEntity? eski}) => showModalBottomSheet<CariEntity>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CariFormu(eski: eski),
      );

  @override
  ConsumerState<CariFormu> createState() => _CariFormuState();
}

class _CariFormuState extends ConsumerState<CariFormu> {
  late final _ad = TextEditingController(text: widget.eski?.ad);
  late final _telefon = TextEditingController(text: widget.eski?.telefon);
  late CariTuru _tur = widget.eski?.tur ?? CariTuru.bayi;

  @override
  void dispose() {
    _ad.dispose();
    _telefon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.eski == null ? 'Hesap Ekle' : 'Hesabı Düzenle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final t in CariTuru.values)
                ChoiceChip(
                  avatar: Icon(t.ikon, size: 18),
                  label: Text(t.ad),
                  selected: _tur == t,
                  selectedColor: AppTheme.primaryMint,
                  onSelected: (_) => setState(() => _tur = t),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ad,
            autofocus: widget.eski == null,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(labelText: 'Adı (ör. Yılmaz Zirai İlaç)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _telefon,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon (isteğe bağlı)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _ad.text.trim().isEmpty
                  ? null
                  : () async {
                      final c = await ref
                          .read(cariListeProvider.notifier)
                          .kaydet(eski: widget.eski, ad: _ad.text, tur: _tur, telefon: _telefon.text);
                      if (context.mounted) Navigator.pop(context, c);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryMint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('KAYDET', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
