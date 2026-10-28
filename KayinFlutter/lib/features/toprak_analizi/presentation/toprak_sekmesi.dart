import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../parsel_harita/domain/entities/parsel_entity.dart';
import '../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../../../core/services/rapor_ocr_servisi.dart';
import '../domain/rapor_okuyucu.dart';
import '../domain/toprak_analizi.dart';
import 'toprak_analizi_provider.dart';

String _tarih(DateTime t) => '${t.day}.${t.month}.${t.year}';

/// Tarla detayındaki "Toprak" sekmesi: son analiz, yorum, öneriler ve geçmiş.
class ToprakSekmesi extends ConsumerWidget {
  final ParselEntity parsel;
  const ToprakSekmesi({super.key, required this.parsel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tumu = ref.watch(toprakAnalizListeProvider).valueOrNull ?? const <ToprakAnaliziEntity>[];
    final analizler = tumu.where((a) => a.parselId == parsel.id).toList()
      ..sort((a, b) => b.analizTarihi.compareTo(a.analizTarihi));
    final son = analizler.firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kutu = isDark ? const Color(0xFF0F1A16) : AppTheme.lightBg;

    final ekleDugmesi = SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => ToprakAnalizFormu.goster(context, parselId: parsel.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryMint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.science_rounded, color: Colors.white),
        label: Text(son == null ? 'Analiz Sonucunu Gir' : 'Yeni Analiz Gir',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );

    if (son == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kutu, borderRadius: BorderRadius.circular(14)),
            child: const Text(
              'Bu tarlanın toprak analizi girilmemiş. Elinizde laboratuvar raporu varsa değerleri girin: '
              'su hesabı (kullanılabilir su, su açığı) tarlanızın gerçek toprağına göre yapılır, '
              'gübre ve toprak düzeltme önerileri çıkar.\n\n'
              'Analizi il/ilçe tarım müdürlükleri, ziraat odaları, ticaret borsaları ve özel laboratuvarlar yapar. '
              'Numune hasattan sonra, gübrelemeden önce, tarlanın 10-15 noktasından 0-30 cm derinlikten alınır.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          ekleDugmesi,
        ],
      );
    }

    final yorumlar = yorumla(son);
    final oneri = oneriler(son, DateTime.now());
    final onerilenTur = onerilenToprakTuru(son);
    final turFarkli = onerilenTur != null &&
        !parsel.toprakTuru.toLowerCase().startsWith(onerilenTur.toLowerCase().substring(0, 3));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Son analiz: ${_tarih(son.analizTarihi)}${son.laboratuvar.isEmpty ? '' : ' • ${son.laboratuvar}'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            TextButton.icon(
              onPressed: () => ToprakAnalizFormu.goster(context, parselId: parsel.id, eski: son),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Düzenle'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final y in yorumlar)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kutu,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: y.durum.renk, width: 4)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(y.ad, style: const TextStyle(fontSize: 13))),
                Text(y.deger, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: Text(y.sinif,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: y.durum.renk, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        if (turFarkli) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Analize göre toprak "$onerilenTur", tarlada "${parsel.toprakTuru}" kayıtlı. '
                    'Ürün uygunluğu toprak türüne göre hesaplanır.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(parselListeProvider.notifier).guncelle(parsel.id, yeniToprakTuru: onerilenTur),
                  child: Text('"$onerilenTur" yap'),
                ),
              ],
            ),
          ),
        ],
        if (son.saturasyon != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '💧 Kullanılabilir su ve su açığı bu analizin saturasyon değerine göre hesaplanıyor.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 14),
        const Text('Öneriler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        if (oneri.isEmpty)
          const Text('Analizde dikkat gerektiren bir değer yok. 👍', style: TextStyle(fontSize: 13))
        else
          for (final o in oneri)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(o, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
        const SizedBox(height: 4),
        const Text(
          'Sınıflar laboratuvarların yaygın kullandığı yaklaşık sınırlardır; raporunuzdaki yorum farklıysa onu esas alın. '
          'Dekara kaç kg gübre verileceğini laboratuvarın önerisi ya da ziraat mühendisi belirler.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        ekleDugmesi,
        if (analizler.length > 1) ...[
          const SizedBox(height: 14),
          const Text('Önceki analizler', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final a in analizler.skip(1))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: Text(_tarih(a.analizTarihi)),
              subtitle: Text(
                [
                  if (a.ph != null) 'pH ${sayiYaz(a.ph!)}',
                  if (a.organikMadde != null) 'OM %${sayiYaz(a.organikMadde!)}',
                  if (a.fosfor != null) 'P ${sayiYaz(a.fosfor!, basamak: 1)}',
                  if (a.potasyum != null) 'K ${sayiYaz(a.potasyum!, basamak: 1)}',
                ].join(' • '),
              ),
              onTap: () => ToprakAnalizFormu.goster(context, parselId: parsel.id, eski: a),
            ),
        ],
      ],
    );
  }
}

/// Analiz raporunu girme/düzenleme. Raporda olmayan değer boş bırakılır.
class ToprakAnalizFormu extends ConsumerStatefulWidget {
  final String parselId;
  final ToprakAnaliziEntity? eski;
  const ToprakAnalizFormu({super.key, required this.parselId, this.eski});

  static Future<void> goster(BuildContext context, {required String parselId, ToprakAnaliziEntity? eski}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ToprakAnalizFormu(parselId: parselId, eski: eski),
      );

  @override
  ConsumerState<ToprakAnalizFormu> createState() => _ToprakAnalizFormuState();
}

class _Alan {
  final String etiket;
  final String birim;
  final String ipucu;
  final double min, max;
  final TextEditingController c;

  /// Fotoğraftan okundu; kullanıcı kontrol etmeli.
  bool okundu = false;
  _Alan(this.etiket, this.birim, this.ipucu, this.min, this.max, double? deger)
      : c = TextEditingController(text: deger == null ? '' : sayiYaz(deger, basamak: 3));

  double? get deger => sayiOku(c.text);
  bool get gecersiz => c.text.trim().isNotEmpty && (deger == null || deger! < min || deger! > max);
}

class _ToprakAnalizFormuState extends ConsumerState<ToprakAnalizFormu> {
  late DateTime _tarih = widget.eski?.analizTarihi ?? DateUtils.dateOnly(DateTime.now());
  late final _lab = TextEditingController(text: widget.eski?.laboratuvar);
  late final _not = TextEditingController(text: widget.eski?.not);

  late final _saturasyon = _Alan('Saturasyon', '%', 'Bünye: ≤30 kumlu, 30-50 tınlı, 50+ killi', 5, 150, widget.eski?.saturasyon);
  late final _ph = _Alan('pH', '', 'Çoğu tarla 7-8 arası', 2, 12, widget.eski?.ph);
  late final _tuz = _Alan('Toplam tuz', '%', 'Raporda "Tuz %" ya da "Toplam tuz"', 0, 10, widget.eski?.tuzYuzde);
  late final _ec = _Alan('EC (tuzluluk)', 'dS/m', 'mS/cm ile aynı; µS/cm ise olduğu gibi yazın, çevrilir', 0, 100000, widget.eski?.ec);
  late final _kirec = _Alan('Kireç (CaCO₃)', '%', '', 0, 90, widget.eski?.kirecYuzde);
  late final _om = _Alan('Organik madde', '%', '', 0, 30, widget.eski?.organikMadde);
  late final _p = _Alan('Fosfor (P₂O₅)', 'kg/da', 'Raporda ppm ise laboratuvarın kg/da değerini girin', 0, 200, widget.eski?.fosfor);
  late final _k = _Alan('Potasyum (K₂O)', 'kg/da', '', 0, 500, widget.eski?.potasyum);
  late final _zn = _Alan('Çinko (Zn)', 'ppm', '', 0, 100, widget.eski?.cinko);

  List<_Alan> get _alanlar => [_saturasyon, _ph, _tuz, _ec, _kirec, _om, _p, _k, _zn];

  @override
  void dispose() {
    _lab.dispose();
    _not.dispose();
    for (final a in _alanlar) {
      a.c.dispose();
    }
    super.dispose();
  }

  ToprakAnaliziEntity _taslak() => ToprakAnaliziEntity(
        id: widget.eski?.id ?? '',
        parselId: widget.parselId,
        analizTarihi: _tarih,
        laboratuvar: _lab.text,
        saturasyon: _saturasyon.deger,
        ph: _ph.deger,
        tuzYuzde: _tuz.deger,
        ec: _ec.deger,
        kirecYuzde: _kirec.deger,
        organikMadde: _om.deger,
        fosfor: _p.deger,
        potasyum: _k.deger,
        cinko: _zn.deger,
        not: _not.text,
        createdAtUtc: DateTime.now(),
        lastModifiedUtc: DateTime.now(),
      );

  bool _okuyor = false;

  Future<void> _fotograftanOku() async {
    setState(() => _okuyor = true);
    RaporOkumaSonucu? sonuc;
    try {
      sonuc = await RaporOcrServisi.raporOku(context);
    } catch (e) {
      // SnackBar açık formun arkasında kalıyordu; pencere formun önünde görünür.
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rapor okunamadı'),
            content: Text('Fotoğraftaki yazı okunamadı. Değerleri elle girebilirsiniz.\n\n($e)'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() => _okuyor = false);
    if (sonuc == null) return;
    final eslesme = {
      RaporAlani.saturasyon: _saturasyon,
      RaporAlani.ph: _ph,
      RaporAlani.tuzYuzde: _tuz,
      RaporAlani.ec: _ec,
      RaporAlani.kirec: _kirec,
      RaporAlani.organikMadde: _om,
      RaporAlani.fosfor: _p,
      RaporAlani.potasyum: _k,
      RaporAlani.cinko: _zn,
    };
    setState(() {
      sonuc!.degerler.forEach((alan, v) {
        final a = eslesme[alan]!;
        a.c.text = sayiYaz(v, basamak: 3);
        a.okundu = true;
      });
    });
    final okunan = sonuc.degerler.keys.map((a) => a.ad).join(', ');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sonuc!.degerler.isEmpty ? 'Değer bulunamadı' : '${sonuc.degerler.length} değer okundu'),
        content: Text([
          if (sonuc.degerler.isEmpty)
            'Fotoğrafta tanıdık bir parametre (pH, EC, kireç, organik madde…) bulunamadı. Daha yakından, düz ve gölgesiz çekmeyi deneyin ya da elle girin.'
          else
            'Okunanlar: $okunan.\n\nTuruncu işaretli alanları rapordaki değerlerle karşılaştırın; yanlışsa düzeltin, sonra kaydedin.',
          ...sonuc.notlar,
        ].join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  Future<void> _sil() async {
    final id = widget.eski!.id;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(toprakAnalizListeProvider.notifier);
    await notifier.silindiYap(id, true);
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('Analiz silindi'),
      action: SnackBarAction(label: 'Geri Al', onPressed: () => notifier.silindiYap(id, false)),
    ));
  }

  Widget _alan(_Alan a) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: a.c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() => a.okundu = false),
          decoration: InputDecoration(
            labelText: a.etiket,
            suffixText: a.birim,
            helperText: a.okundu ? '📷 Fotoğraftan okundu — rapordaki değerle karşılaştırın' : (a.ipucu.isEmpty ? null : a.ipucu),
            helperStyle: a.okundu ? const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600) : null,
            errorText: a.gecersiz ? 'Geçersiz değer' : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final taslak = _taslak();
    final kaydedilebilir = !taslak.bos && !_alanlar.any((a) => a.gecersiz);
    final bugun = DateUtils.dateOnly(DateTime.now());

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.eski == null ? 'Toprak Analizi Gir' : 'Analizi Düzenle',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (widget.eski != null)
                  IconButton(
                    tooltip: 'Sil',
                    onPressed: _sil,
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerColor),
                  ),
              ],
            ),
            const Text('Raporda olmayan değerleri boş bırakın.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            if (RaporOcrServisi.destekleniyor) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _okuyor ? null : _fotograftanOku,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: _okuyor
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_rounded),
                label: Text(_okuyor ? 'Rapor okunuyor…' : 'Rapor fotoğrafından oku'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final g = await showDatePicker(
                  context: context,
                  initialDate: _tarih,
                  firstDate: DateTime(bugun.year - 15),
                  lastDate: bugun,
                  helpText: 'Analiz (numune) tarihi',
                );
                if (g != null) setState(() => _tarih = g);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text('Analiz tarihi: ${_tarih.day}.${_tarih.month}.${_tarih.year}'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lab,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Laboratuvar (isteğe bağlı)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Bünye ve tuzluluk', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final a in [_saturasyon, _ph, _tuz, _ec, _kirec]) _alan(a),
            const SizedBox(height: 4),
            const Text('Besin maddeleri', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final a in [_om, _p, _k, _zn]) _alan(a),
            TextField(
              controller: _not,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: !kaydedilebilir
                    ? null
                    : () async {
                        await ref.read(toprakAnalizListeProvider.notifier).kaydet(taslak, eski: widget.eski);
                        if (context.mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryMint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(taslak.bos ? 'En az bir değer girin' : 'KAYDET',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
