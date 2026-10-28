import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/depo.dart';
import 'depo_provider.dart';

String _tarih(DateTime t) {
  final y = t.toLocal();
  return '${y.day}.${y.month}.${y.year}';
}

/// Depo: elde ne kadar gübre/ilaç/tohum kaldığı.
class DepoScreen extends ConsumerWidget {
  const DepoScreen({super.key});

  static void ac(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepoScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kalemler = ref.watch(stokKalemListeProvider);
    final mevcut = ref.watch(stokMevcutlariProvider);
    final azalan = ref.watch(azalanStokSayisiProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(title: const Text('Depo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final k = await KalemFormu.goster(context);
          if (k != null && context.mounted) KalemDetayScreen.ac(context, k.id);
        },
        backgroundColor: AppTheme.primaryMint,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ürün Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: kalemler.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (liste) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (azalan > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('⚠️ $azalan üründe stok azaldı — sipariş zamanı.',
                    style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold)),
              ),
            if (liste.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.warehouse_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Depo boş', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text(
                      'Elinizdeki gübre, ilaç ve tohumu "Ürün Ekle" ile girin. Günlük\'te ilaçlama ya da '
                      'gübreleme kaydederken "depodan düş" derseniz stok kendiliğinden azalır.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            for (final k in liste) _KalemKarti(kalem: k, mevcut: mevcut[k.id] ?? 0),
          ],
        ),
      ),
    );
  }
}

class _KalemKarti extends StatelessWidget {
  final StokKalemiEntity kalem;
  final double mevcut;
  const _KalemKarti({required this.kalem, required this.mevcut});

  @override
  Widget build(BuildContext context) {
    final azaldi = azaldiMi(kalem, mevcut);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => KalemDetayScreen.ac(context, kalem.id),
        leading: CircleAvatar(
          backgroundColor: kalem.kategori.renk.withValues(alpha: 0.15),
          child: Icon(kalem.kategori.ikon, color: kalem.kategori.renk),
        ),
        title: Text(kalem.ad, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          azaldi
              ? (mevcut < 0 ? 'Eksiye düştü — sayım yapın' : 'Azaldı (uyarı: ${miktarYaz(kalem.kritikSeviye!)} ${kalem.birim})')
              : kalem.kategori.ad,
          style: TextStyle(color: azaldi ? AppTheme.dangerColor : Colors.grey, fontWeight: azaldi ? FontWeight.bold : null),
        ),
        trailing: Text(
          '${miktarYaz(mevcut)} ${kalem.birim}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: azaldi ? AppTheme.dangerColor : null),
        ),
      ),
    );
  }
}

/// Ürün ekleme/düzenleme.
class KalemFormu extends ConsumerStatefulWidget {
  final StokKalemiEntity? eski;
  const KalemFormu({super.key, this.eski});

  static Future<StokKalemiEntity?> goster(BuildContext context, {StokKalemiEntity? eski}) =>
      showModalBottomSheet<StokKalemiEntity>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => KalemFormu(eski: eski),
      );

  @override
  ConsumerState<KalemFormu> createState() => _KalemFormuState();
}

class _KalemFormuState extends ConsumerState<KalemFormu> {
  late final _ad = TextEditingController(text: widget.eski?.ad);
  late final _kritik = TextEditingController(
      text: widget.eski?.kritikSeviye == null ? '' : miktarYaz(widget.eski!.kritikSeviye!));
  late StokKategori _kategori = widget.eski?.kategori ?? StokKategori.gubre;
  late String _birim = widget.eski?.birim ?? 'kg';

  @override
  void dispose() {
    _ad.dispose();
    _kritik.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.eski == null ? 'Ürün Ekle' : 'Ürünü Düzenle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final k in StokKategori.values)
                  ChoiceChip(
                    avatar: Icon(k.ikon, size: 18),
                    label: Text(k.ad),
                    selected: _kategori == k,
                    selectedColor: AppTheme.primaryMint,
                    onSelected: (_) => setState(() {
                      _kategori = k;
                      if (k == StokKategori.ilac || k == StokKategori.mazot) _birim = 'L';
                      if (k == StokKategori.gubre || k == StokKategori.tohum) _birim = 'kg';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ad,
              autofocus: widget.eski == null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(labelText: 'Adı (ör. Üre %46, etiketteki ilaç adı)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('Birim', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final b in stokBirimleri)
                  ChoiceChip(
                    label: Text(b),
                    selected: _birim == b,
                    selectedColor: AppTheme.primaryMint,
                    onSelected: (_) => setState(() => _birim = b),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kritik,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Bu miktarın altına inince uyar (isteğe bağlı)',
                suffixText: _birim,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _ad.text.trim().isEmpty
                    ? null
                    : () async {
                        final k = await ref.read(stokKalemListeProvider.notifier).kaydet(
                              eski: widget.eski,
                              ad: _ad.text,
                              kategori: _kategori,
                              birim: _birim,
                              kritikSeviye: miktarOku(_kritik.text),
                            );
                        if (context.mounted) Navigator.pop(context, k);
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
      ),
    );
  }
}

/// Tek ürünün mevcudu ve hareketleri.
class KalemDetayScreen extends ConsumerWidget {
  final String kalemId;
  const KalemDetayScreen({super.key, required this.kalemId});

  static void ac(BuildContext context, String kalemId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => KalemDetayScreen(kalemId: kalemId)));

  Future<void> _sil(BuildContext context, WidgetRef ref, StokKalemiEntity k) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${k.ad} silinsin mi?'),
        content: const Text('Ürün ve tüm depo hareketleri silinir. İş günlüğü kayıtları silinmez.'),
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
    await ref.read(stokKalemListeProvider.notifier).sil(k.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kalem = (ref.watch(stokKalemListeProvider).valueOrNull ?? const []).where((k) => k.id == kalemId).firstOrNull;
    if (kalem == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)));
    final hareketler =
        (ref.watch(stokHareketListeProvider).valueOrNull ?? const []).where((h) => h.kalemId == kalemId).toList();
    final mevcut = ref.watch(stokMevcutlariProvider)[kalemId] ?? 0;
    final azaldi = azaldiMi(kalem, mevcut);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Text(kalem.ad, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'Ürünü düzenle',
            onPressed: () => KalemFormu.goster(context, eski: kalem),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            tooltip: 'Ürünü sil',
            onPressed: () => _sil(context, ref, kalem),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (azaldi ? AppTheme.dangerColor : kalem.kategori.renk).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Depoda', style: TextStyle(color: Colors.grey[600])),
                Text('${miktarYaz(mevcut)} ${kalem.birim}',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: azaldi ? AppTheme.dangerColor : null)),
                if (kalem.kritikSeviye != null)
                  Text('Uyarı seviyesi: ${miktarYaz(kalem.kritikSeviye!)} ${kalem.birim}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final t in StokHareketTuru.values) ...[
                Expanded(
                  child: Material(
                    color: t.renk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => StokHareketFormu.goster(context, kalem: kalem, tur: t, mevcut: mevcut),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            Icon(t.ikon, color: t.renk, size: 30),
                            const SizedBox(height: 4),
                            Text(t == StokHareketTuru.duzeltme ? 'Sayım' : t.ad,
                                style: TextStyle(fontWeight: FontWeight.bold, color: t.renk)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (t != StokHareketTuru.values.last) const SizedBox(width: 8),
              ],
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
                onTap: h.isKaydiId != null
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bu çıkış Günlük\'teki iş kaydından geliyor; oradan düzenleyin.')))
                    : () => StokHareketFormu.goster(context, kalem: kalem, tur: h.tur, mevcut: mevcut, eski: h),
                leading: CircleAvatar(
                  backgroundColor: h.tur.renk.withValues(alpha: 0.15),
                  child: Icon(h.tur.ikon, color: h.tur.renk),
                ),
                title: Text(h.isKaydiId != null ? 'Günlükten: kullanıldı' : h.tur.ad,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text([_tarih(h.islemTarihi), if (h.aciklama.isNotEmpty) h.aciklama].join(' • '),
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  '${h.etki >= 0 ? '+' : '−'}${miktarYaz(h.etki.abs())} ${kalem.birim}',
                  style: TextStyle(color: h.tur.renk, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Giriş / kullanım / sayım. Sayımda depodaki gerçek miktar girilir; fark kaydedilir.
class StokHareketFormu extends ConsumerStatefulWidget {
  final StokKalemiEntity kalem;
  final StokHareketTuru tur;
  final double mevcut;
  final StokHareketiEntity? eski;

  const StokHareketFormu({super.key, required this.kalem, required this.tur, required this.mevcut, this.eski});

  static Future<void> goster(BuildContext context,
          {required StokKalemiEntity kalem,
          required StokHareketTuru tur,
          required double mevcut,
          StokHareketiEntity? eski}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => StokHareketFormu(kalem: kalem, tur: tur, mevcut: mevcut, eski: eski),
      );

  @override
  ConsumerState<StokHareketFormu> createState() => _StokHareketFormuState();
}

class _StokHareketFormuState extends ConsumerState<StokHareketFormu> {
  bool get _sayim => widget.tur == StokHareketTuru.duzeltme;

  late final _miktar = TextEditingController(
    text: widget.eski == null ? '' : miktarYaz(_sayim ? widget.mevcut : widget.eski!.miktar),
  );
  late final _aciklama = TextEditingController(text: widget.eski?.aciklama);
  late DateTime _gun = DateUtils.dateOnly(widget.eski?.islemTarihi.toLocal() ?? DateTime.now());

  @override
  void dispose() {
    _miktar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  double? get _deger => miktarOku(_miktar.text);

  /// Kaydedilecek miktar: sayımda fark (işaretli), diğerlerinde girilen.
  double? get _kayitMiktari {
    final d = _deger;
    if (d == null || d < 0) return null;
    if (!_sayim) return d > 0 ? d : null;
    // Düzenlenen bir sayımda kendi etkisi mevcuttan çıkarılarak yeniden hesaplanır.
    final oncesi = widget.mevcut - (widget.eski?.miktar ?? 0);
    final fark = sayimFarki(mevcut: oncesi, sayilan: d);
    return fark.abs() < 0.0005 ? null : fark;
  }

  Future<void> _kaydet() async {
    final simdi = DateTime.now();
    final eski = widget.eski;
    final zaman = eski != null && DateUtils.isSameDay(eski.islemTarihi.toLocal(), _gun)
        ? eski.islemTarihi
        : DateUtils.isSameDay(_gun, simdi)
            ? simdi
            : DateTime(_gun.year, _gun.month, _gun.day, 12);
    await ref.read(stokHareketListeProvider.notifier).kaydet(
          eski: eski,
          kalemId: widget.kalem.id,
          tur: widget.tur,
          miktar: _kayitMiktari!,
          islemTarihi: zaman,
          aciklama: _aciklama.text,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sil() async {
    final h = widget.eski!;
    final notifier = ref.read(stokHareketListeProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await notifier.silindiYap(h.id, true);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('🗑️ Hareket silindi'),
      action: SnackBarAction(label: 'Geri Al', onPressed: () => notifier.silindiYap(h.id, false)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tur;
    final k = widget.kalem;
    final bugun = DateUtils.dateOnly(DateTime.now());
    final dun = bugun.subtract(const Duration(days: 1));
    final kayit = _kayitMiktari;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(t.ikon, color: t.renk, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${_sayim ? 'Sayım' : t.ad} • ${k.ad}',
                      style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _sayim
                  ? 'Depoda şu an gerçekte ne kadar var? Kayıttaki: ${miktarYaz(widget.mevcut)} ${k.birim}'
                  : t == StokHareketTuru.giris
                      ? 'Depoya ne kadar girdi? (Parası Muhasebe/Veresiye\'den girilir.)'
                      : 'Ne kadar kullanıldı? (Tarlada kullandıysanız Günlük\'ten girmek daha iyi.)',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _miktar,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: '0', suffixText: k.birim),
              onChanged: (_) => setState(() {}),
            ),
            if (_sayim && _deger != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  kayit == null
                      ? 'Kayıtla aynı, düzeltme gerekmez.'
                      : 'Kayda ${kayit > 0 ? '+' : '−'}${miktarYaz(kayit.abs())} ${k.birim} düzeltme yazılacak.',
                  style: TextStyle(color: kayit == null ? Colors.grey : t.renk, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),
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
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aciklama,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Açıklama (isteğe bağlı)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: kayit == null ? null : _kaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.renk,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(kayit == null ? 'Miktarı girin' : 'KAYDET',
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
