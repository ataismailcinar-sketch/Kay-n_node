import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../is_gunlugu/domain/is_kaydi_entity.dart';
import '../../is_gunlugu/presentation/is_gunlugu_provider.dart';
import '../../klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';
import '../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../domain/tarla_karnesi.dart';

final _tl = NumberFormat.decimalPattern('tr');
String _para(double v) => '${v < 0 ? '−' : ''}${_tl.format(v.abs().round())} ₺';
String _tarih(DateTime t) => '${t.day}.${t.month}.${t.year}';

/// Çiftlik ve tarla karnesi: hasat, verim, maliyet, gerçek kâr (seçilen dönem için).
class TarlaKarnesiScreen extends ConsumerStatefulWidget {
  const TarlaKarnesiScreen({super.key});

  static void ac(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TarlaKarnesiScreen()));

  @override
  ConsumerState<TarlaKarnesiScreen> createState() => _TarlaKarnesiScreenState();
}

class _TarlaKarnesiScreenState extends ConsumerState<TarlaKarnesiScreen> {
  late Donem _donem = Donem.son12Ay(DateTime.now());

  Future<void> _ozelAralik() async {
    final bugun = DateTime.now();
    final secilen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(bugun.year - 5),
      lastDate: bugun,
      initialDateRange: DateTimeRange(start: _donem.bas, end: _donem.son.isAfter(bugun) ? bugun : _donem.son),
      helpText: 'Karne dönemi',
    );
    if (secilen != null) {
      setState(() => _donem = Donem('${_tarih(secilen.start)} – ${_tarih(secilen.end)}', secilen.start, secilen.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parseller = ref.watch(parselListeProvider);
    final isler = ref.watch(isKaydiListeProvider);
    final muhasebe = ref.watch(giderListeProvider);
    final bugun = DateTime.now();

    final yukleniyor = parseller.isLoading || isler.isLoading || muhasebe.isLoading;
    final karne = yukleniyor
        ? null
        : karneHesapla(
            parseller: parseller.valueOrNull ?? const [],
            isKayitlari: isler.valueOrNull ?? const [],
            muhasebe: muhasebe.valueOrNull ?? const [],
            donem: _donem,
          );

    Widget donemCipi(String ad, Donem d) => ChoiceChip(
          label: Text(ad),
          selected: _donem.ad == d.ad,
          selectedColor: AppTheme.primaryMint,
          onSelected: (_) => setState(() => _donem = d),
        );
    final ozelSecili = !{'Son 12 ay', '${bugun.year}', '${bugun.year - 1}'}.contains(_donem.ad);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(title: const Text('Çiftlik Karnesi')),
      body: karne == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    donemCipi('Son 12 ay', Donem.son12Ay(bugun)),
                    donemCipi('${bugun.year}', Donem.yil(bugun.year)),
                    donemCipi('${bugun.year - 1}', Donem.yil(bugun.year - 1)),
                    ChoiceChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(ozelSecili ? _donem.ad : 'Özel aralık'),
                      selected: ozelSecili,
                      selectedColor: AppTheme.primaryMint,
                      onSelected: (_) => _ozelAralik(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_tarih(_donem.bas)} – ${_tarih(_donem.son)} arasındaki kayıtlar',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _CiftlikOzeti(karne: karne),
                if (karne.genelGider > 0 || karne.genelGelir > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tarlaya yazılmamış ${[
                      if (karne.genelGider > 0) '${_para(karne.genelGider)} gider',
                      if (karne.genelGelir > 0) '${_para(karne.genelGelir)} gelir',
                    ].join(' ve ')} (mazot, kira, destek vb.) tarlalara alanları oranında dağıtıldı.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Tarlalar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                for (final t in karne.tarlalar) _TarlaKarti(t: t, isDark: isDark),
              ],
            ),
    );
  }
}

class _CiftlikOzeti extends StatelessWidget {
  final CiftlikKarnesi karne;
  const _CiftlikOzeti({required this.karne});

  @override
  Widget build(BuildContext context) {
    final kar = karne.netKar >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryEmerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${karne.tarlalar.length} tarla • ${_tl.format(karne.toplamAlan.round())} dönüm',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              _Rozet(kar ? 'KÂRDA' : 'ZARARDA', kar ? AppTheme.successColor : AppTheme.dangerColor),
            ],
          ),
          const SizedBox(height: 12),
          _MetrikIzgarasi([
            ('Toplam hasat', karne.toplamHasatKg > 0 ? miktarMetni(karne.toplamHasatKg) : '—', null),
            ('Net kâr', _para(karne.netKar), kar ? AppTheme.primaryMint : AppTheme.dangerColor),
            ('Gider', _para(karne.toplamGider), AppTheme.dangerColor),
            ('Gelir', _para(karne.toplamGelir), AppTheme.successColor),
            ('Dönüm başı maliyet', karne.maliyetTlDa == null ? '—' : _para(karne.maliyetTlDa!), null),
            ('Dönüm başı kâr', karne.karTlDa == null ? '—' : _para(karne.karTlDa!), null),
          ]),
        ],
      ),
    );
  }
}

class _TarlaKarti extends StatelessWidget {
  final TarlaKarnesi t;
  final bool isDark;
  const _TarlaKarti({required this.t, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final kar = t.netKar >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t.parsel.urunEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.parsel.ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                    Text('${t.parsel.ekilmisUrun} • ${t.parsel.alanMetinsel}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                _para(t.netKar),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kar ? AppTheme.primaryMint : AppTheme.dangerColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetrikIzgarasi([
            ('Hasat', t.hasatKg > 0 ? miktarMetni(t.hasatKg) : '—', null),
            ('Verim', t.verimKgDa == null ? '—' : '${_tl.format(t.verimKgDa!.round())} kg/dönüm', null),
            ('Gider', _para(t.gider), AppTheme.dangerColor),
            ('Gelir', _para(t.gelir), AppTheme.successColor),
            ('Dönüm başı maliyet', t.maliyetTlDa == null ? '—' : _para(t.maliyetTlDa!), null),
            ('1 kg ürün maliyeti', t.maliyetTlKg == null ? '—' : '${t.maliyetTlKg!.toStringAsFixed(2).replaceAll('.', ',')} ₺', null),
          ]),
          if (t.genelGiderPayi > 0 || t.genelGelirPayi > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${[
                  if (t.genelGiderPayi > 0) 'Gidere ${_para(t.genelGiderPayi)}',
                  if (t.genelGelirPayi > 0) 'gelire ${_para(t.genelGelirPayi)}',
                ].join(', ')} genel pay dahil.',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          if (t.hasatKg == 0)
            const _Not('Hasat kaydı yok. Verim için Günlük\'ten "Hasat" ekleyip miktarı girin.', Colors.grey)
          else if (t.satisGirilmemis)
            _Not(
              'Hasat var ama bu tarlaya satış geliri girilmemiş; kâr eksik görünür. '
              'Muhasebe\'den "Hasat Satışı" ekleyin (ürün depodaysa sattıkça girin).',
              Colors.amber[800]!,
            ),
        ],
      ),
    );
  }
}

class _MetrikIzgarasi extends StatelessWidget {
  final List<(String, String, Color?)> metrikler;
  const _MetrikIzgarasi(this.metrikler);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Wrap(
        runSpacing: 10,
        children: [
          for (final (etiket, deger, renk) in metrikler)
            SizedBox(
              width: c.maxWidth / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(deger, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: renk)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Rozet extends StatelessWidget {
  final String metin;
  final Color renk;
  const _Rozet(this.metin, this.renk);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(6)),
        child: Text(metin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
      );
}

class _Not extends StatelessWidget {
  final String metin;
  final Color renk;
  const _Not(this.metin, this.renk);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: renk),
            const SizedBox(width: 6),
            Expanded(child: Text(metin, style: TextStyle(fontSize: 12, color: renk))),
          ],
        ),
      );
}
