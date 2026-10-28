import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tutar_tus_takimi.dart';
import '../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../domain/veresiye.dart';
import 'veresiye_provider.dart';
import 'veresiye_screen.dart';

/// Tek hesabın durumu ve hareketleri.
class CariDetayScreen extends ConsumerWidget {
  final String cariId;
  const CariDetayScreen({super.key, required this.cariId});

  static void ac(BuildContext context, String cariId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => CariDetayScreen(cariId: cariId)));

  Future<void> _sil(BuildContext context, WidgetRef ref, CariEntity cari) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${cari.ad} silinsin mi?'),
        content: const Text('Hesap, tüm hareketleri ve bu hareketlerle muhasebeye yazılan kayıtlar silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    await ref.read(cariListeProvider.notifier).sil(cari.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cari = (ref.watch(cariListeProvider).valueOrNull ?? const []).where((c) => c.id == cariId).firstOrNull;
    if (cari == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)));

    final hareketler = (ref.watch(cariHareketListeProvider).valueOrNull ?? const [])
        .where((h) => h.cariId == cariId)
        .toList();
    final durum = ref.watch(cariDurumlariProvider)[cariId] ?? const CariDurumu(bakiye: 0, vadesiGecen: 0);
    final (bakiye, renk) = bakiyeMetni(durum);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Text(cari.ad, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'Hesabı düzenle',
            onPressed: () => CariFormu.goster(context, eski: cari),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            tooltip: 'Hesabı sil',
            onPressed: () => _sil(context, ref, cari),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: renk.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cari.tur.ad}${cari.telefon.isEmpty ? '' : ' • ${cari.telefon}'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(bakiye, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: renk)),
                if (durum.vadesiGecen > 0.005)
                  Text('⚠️ ${veresiyePara(durum.vadesiGecen)} vadesi geçmiş',
                      style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold)),
                if (durum.yaklasanVade != null)
                  Text('Sonraki vade: ${veresiyeTarih(durum.yaklasanVade!)}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              for (final t in HareketTuru.values)
                Material(
                  color: t.renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => HareketFormu.goster(context, cari: cari, tur: t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(t.ikon, color: t.renk, size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t.ad, style: TextStyle(fontWeight: FontWeight.bold, color: t.renk, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Hareketler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (hareketler.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Henüz hareket yok.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          for (final h in hareketler)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => HareketFormu.goster(context, cari: cari, tur: h.tur, eski: h),
                leading: CircleAvatar(
                  backgroundColor: h.tur.renk.withValues(alpha: 0.15),
                  child: Icon(h.tur.ikon, color: h.tur.renk),
                ),
                title: Text(h.tur.ad, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  [
                    veresiyeTarih(h.islemTarihi),
                    if (h.vadeTarihi != null) 'Vade: ${veresiyeTarih(h.vadeTarihi!)}',
                    if (h.aciklama.isNotEmpty) h.aciklama,
                    if (h.muhasebeKaydiId != null) 'Muhasebeye işlendi',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '${h.tur.borcEtkisi > 0 ? '+' : '−'}${veresiyePara(h.tutar)}',
                  style: TextStyle(color: h.tur.renk, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hareket ekleme/düzenleme. Tutar tuş takımıyla girilir.
class HareketFormu extends ConsumerStatefulWidget {
  final CariEntity cari;
  final HareketTuru tur;
  final CariHareketEntity? eski;

  const HareketFormu({super.key, required this.cari, required this.tur, this.eski});

  static Future<void> goster(BuildContext context,
          {required CariEntity cari, required HareketTuru tur, CariHareketEntity? eski}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => HareketFormu(cari: cari, tur: tur, eski: eski),
      );

  @override
  ConsumerState<HareketFormu> createState() => _HareketFormuState();
}

class _HareketFormuState extends ConsumerState<HareketFormu> {
  static const _giderKategorileri = ['Gubre', 'Ilac', 'Tohum', 'Mazot', 'Iscilik', 'Diger'];
  static const _gelirKategorileri = ['Hasat', 'Diger'];

  late double _tutar = widget.eski?.tutar ?? 0;
  late DateTime _gun = DateUtils.dateOnly(widget.eski?.islemTarihi.toLocal() ?? DateTime.now());
  late DateTime? _vade = widget.eski?.vadeTarihi?.toLocal();
  late final _aciklama = TextEditingController(text: widget.eski?.aciklama);
  late bool _muhasebeyeIsle = widget.eski == null ? true : widget.eski!.muhasebeKaydiId != null;
  String? _kategori;
  String? _parselId;
  bool _kaydediliyor = false;

  bool get _satis => widget.tur == HareketTuru.satis;

  @override
  void initState() {
    super.initState();
    _kategori = _satis ? 'Hasat' : 'Gubre';
    final mid = widget.eski?.muhasebeKaydiId;
    if (mid != null) {
      ref.read(cariHareketListeProvider.notifier).muhasebeBilgisi(mid).then((b) {
        if (mounted) setState(() {
          _kategori = b.kategori ?? _kategori;
          _parselId = b.parselId;
        });
      });
    }
  }

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  DateTime get _islemZamani {
    final simdi = DateTime.now();
    final eski = widget.eski;
    if (eski != null && DateUtils.isSameDay(eski.islemTarihi.toLocal(), _gun)) return eski.islemTarihi;
    return DateUtils.isSameDay(_gun, simdi) ? simdi : DateTime(_gun.year, _gun.month, _gun.day, 12);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    await ref.read(cariHareketListeProvider.notifier).kaydet(
          eski: widget.eski,
          cari: widget.cari,
          tur: widget.tur,
          tutar: _tutar,
          islemTarihi: _islemZamani,
          vadeTarihi: _vade == null ? null : DateTime(_vade!.year, _vade!.month, _vade!.day, 12),
          aciklama: _aciklama.text,
          muhasebeyeIsle: _muhasebeyeIsle,
          kategori: _kategori,
          parselId: _parselId,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sil() async {
    final h = widget.eski!;
    final notifier = ref.read(cariHareketListeProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await notifier.silindiYap(h, true);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('🗑️ Hareket silindi'),
      action: SnackBarAction(label: 'Geri Al', onPressed: () => notifier.silindiYap(h, false)),
    ));
  }

  Widget _vadeCipi(String ad, DateTime? deger) => ChoiceChip(
        label: Text(ad),
        selected: _vade == null ? deger == null : (deger != null && DateUtils.isSameDay(_vade, deger)),
        selectedColor: AppTheme.primaryMint,
        onSelected: (_) => setState(() => _vade = deger),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.tur;
    final bugun = DateUtils.dateOnly(DateTime.now());
    final dun = bugun.subtract(const Duration(days: 1));
    final baskaGun = !DateUtils.isSameDay(_gun, bugun) && !DateUtils.isSameDay(_gun, dun);
    final hazirVadeler = [1, 3, 6].map((ay) => DateTime(_gun.year, _gun.month + ay, _gun.day)).toList();
    final ozelVade = _vade != null && !hazirVadeler.any((v) => DateUtils.isSameDay(v, _vade));
    final parseller = ref.watch(parselListeProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(t.ikon, color: t.renk, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${t.ad} • ${widget.cari.ad}',
                      style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Text(t.aciklama, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.renk.withValues(alpha: 0.5), width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(veresiyePara(_tutar), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: t.renk)),
              ),
            ),
            const SizedBox(height: 10),
            TutarTusTakimi(
              onRakam: (r) => setState(() => _tutar = TutarTusTakimi.rakamEkle(_tutar, r)),
              onSil: () => setState(() => _tutar = TutarTusTakimi.haneSil(_tutar)),
              onTemizle: () => setState(() => _tutar = 0),
            ),
            const SizedBox(height: 16),

            const Text('Ne zaman?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Bugün'),
                  selected: DateUtils.isSameDay(_gun, bugun),
                  selectedColor: AppTheme.primaryMint,
                  onSelected: (_) => setState(() => _gun = bugun),
                ),
                ChoiceChip(
                  label: const Text('Dün'),
                  selected: DateUtils.isSameDay(_gun, dun),
                  selectedColor: AppTheme.primaryMint,
                  onSelected: (_) => setState(() => _gun = dun),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(baskaGun ? veresiyeTarih(_gun) : 'Başka gün'),
                  selected: baskaGun,
                  selectedColor: AppTheme.primaryMint,
                  onSelected: (_) async {
                    final g = await showDatePicker(
                      context: context,
                      initialDate: _gun,
                      firstDate: DateTime(bugun.year - 5),
                      lastDate: bugun,
                    );
                    if (g != null) setState(() => _gun = g);
                  },
                ),
              ],
            ),

            if (t.borcDogurur) ...[
              const SizedBox(height: 16),
              Text(_satis ? 'Ne zaman ödeyecek? (vade)' : 'Ne zaman ödenecek? (vade)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _vadeCipi('Vade yok', null),
                  _vadeCipi('1 ay', hazirVadeler[0]),
                  _vadeCipi('3 ay', hazirVadeler[1]),
                  _vadeCipi('6 ay', hazirVadeler[2]),
                  ChoiceChip(
                    avatar: const Icon(Icons.event_rounded, size: 18),
                    label: Text(ozelVade ? veresiyeTarih(_vade!) : 'Tarih seç (ör. hasatta)'),
                    selected: ozelVade,
                    selectedColor: AppTheme.primaryMint,
                    onSelected: (_) async {
                      final v = await showDatePicker(
                        context: context,
                        initialDate: _vade ?? hazirVadeler[1],
                        firstDate: DateTime(bugun.year - 1),
                        lastDate: DateTime(bugun.year + 3),
                        helpText: 'Vade tarihi',
                      );
                      if (v != null) setState(() => _vade = v);
                    },
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: _aciklama,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: switch (t) {
                  HareketTuru.veresiye => 'Ne alındı? (ör. 20 çuval üre) — isteğe bağlı',
                  HareketTuru.satis => 'Ne satıldı? (ör. 30 ton buğday) — isteğe bağlı',
                  _ => 'Açıklama (isteğe bağlı)',
                },
              ),
            ),

            if (t.borcDogurur) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _muhasebeyeIsle,
                activeColor: AppTheme.primaryMint,
                onChanged: (v) => setState(() => _muhasebeyeIsle = v),
                title: Text(_satis ? 'Muhasebeye gelir olarak da yaz' : 'Muhasebeye gider olarak da yaz'),
                subtitle: Text(
                  _satis
                      ? 'Satış bugün yapıldı; para sonra gelse de gelir bugünün. Tahsilat ayrıca gelir sayılmaz.'
                      : 'Masraf malı aldığınız gün yapıldı; ödeme ayrıca gider sayılmaz.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_muhasebeyeIsle) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final k in _satis ? _gelirKategorileri : _giderKategorileri)
                      ChoiceChip(
                        label: Text(AppConstants.kategoriAdi(k, islemTuru: _satis ? 'Gelir' : 'Gider')),
                        selected: _kategori == k,
                        selectedColor: AppTheme.primaryMint,
                        onSelected: (_) => setState(() => _kategori = k),
                      ),
                  ],
                ),
                if (parseller.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Hangi tarla için? (isteğe bağlı)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Genel'),
                        selected: _parselId == null,
                        selectedColor: AppTheme.primaryMint,
                        onSelected: (_) => setState(() => _parselId = null),
                      ),
                      for (final p in parseller)
                        ChoiceChip(
                          label: Text('${p.urunEmoji} ${p.ad}'),
                          selected: _parselId == p.id,
                          selectedColor: AppTheme.primaryMint,
                          onSelected: (_) => setState(() => _parselId = p.id),
                        ),
                    ],
                  ),
                ],
              ],
            ],

            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _tutar > 0 && !_kaydediliyor ? _kaydet : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.renk,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_tutar > 0 ? 'KAYDET' : 'Tutarı girin',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            if (widget.eski != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _sil,
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerColor),
                label: const Text('Hareketi Sil', style: TextStyle(color: AppTheme.dangerColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
