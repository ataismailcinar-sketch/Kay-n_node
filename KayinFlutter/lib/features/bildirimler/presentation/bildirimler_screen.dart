import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../veresiye/presentation/cari_detay_screen.dart';
import '../domain/bildirim.dart';
import 'bildirim_provider.dart';

String _tarih(DateTime t) => '${t.day}.${t.month}.${t.year}';

/// Ana sekmelerin üst çubuğundaki zil: zamanı gelmiş uyarı sayısı.
class BildirimZili extends ConsumerWidget {
  const BildirimZili({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uyarilar = ref.watch(aktifUyarilarProvider);
    final acil = uyarilar.any((u) => u.oncelik == 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => BildirimlerScreen.ac(context),
      icon: Badge(
        isLabelVisible: uyarilar.isNotEmpty,
        backgroundColor: acil ? AppTheme.dangerColor : Colors.orange,
        label: Text('${uyarilar.length}'),
        child: Icon(
          uyarilar.isEmpty ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
          color: isDark ? AppTheme.primaryMint : Colors.white,
        ),
      ),
    );
  }
}

/// Don, vade ve başvuru tarihi uyarıları + kullanıcının hatırlatmaları.
class BildirimlerScreen extends ConsumerWidget {
  const BildirimlerScreen({super.key});

  static void ac(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BildirimlerScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uyarilar = ref.watch(aktifUyarilarProvider);
    final hatirlatmalar = ref.watch(hatirlatmaListeProvider).valueOrNull ?? const <HatirlatmaEntity>[];
    final bekleyen = hatirlatmalar.where((h) => !h.tamamlandi).toList();
    final biten = hatirlatmalar.where((h) => h.tamamlandi).toList();
    final donYukleniyor = ref.watch(donTahminleriProvider).isLoading;
    final kapali = ref.watch(bildirimAyarlariProvider).valueOrNull?.kapali ?? const <UyariTuru>{};

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            tooltip: 'Bildirim ayarları',
            onPressed: () => BildirimAyarlariPaneli.goster(context),
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Don tahminini yenile',
            onPressed: () => ref.invalidate(donTahminleriProvider),
            icon: donYukleniyor
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => HatirlatmaFormu.goster(context),
        backgroundColor: AppTheme.primaryMint,
        icon: const Icon(Icons.add_alarm_rounded, color: Colors.white),
        label: const Text('Hatırlatma Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _baslik(context, 'Şimdi'),
          if (kapali.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => BildirimAyarlariPaneli.goster(context),
                child: Text(
                  '🔕 Kapalı: ${kapali.map((t) => t.ad).join(', ')} — açmak için dokunun',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          if (uyarilar.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Şu an uyarı yok. Önümüzdeki 3 gecede don, yaklaşan veresiye vadesi ya da '
                'hatırlatma olursa burada ve telefonun bildirim çubuğunda görünür.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final u in uyarilar) _UyariKarti(uyari: u, hatirlatmalar: hatirlatmalar),
          const SizedBox(height: 16),
          _baslik(context, 'Hatırlatmalarım'),
          const Text(
            'ÇKS, destek başvurusu, TARSİM gibi son tarihleri girin; zamanı gelince haber verelim. '
            'Tarihler her yıl değişebilir: il/ilçe tarım müdürlüğünden ya da e-Devlet\'ten teyit edin.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final h in bekleyen) _HatirlatmaKarti(h: h),
          if (biten.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Tamamlananlar (${biten.length})', style: const TextStyle(color: Colors.grey)),
              children: [for (final h in biten) _HatirlatmaKarti(h: h)],
            ),
        ],
      ),
    );
  }

  Widget _baslik(BuildContext context, String metin) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(metin,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryMint)),
      );
}

class _UyariKarti extends ConsumerWidget {
  final Uyari uyari;
  final List<HatirlatmaEntity> hatirlatmalar;
  const _UyariKarti({required this.uyari, required this.hatirlatmalar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (ikon, renk) = switch (uyari.tur) {
      UyariTuru.don => (Icons.ac_unit_rounded, const Color(0xFF0284C7)),
      UyariTuru.vade => (Icons.payments_rounded, Colors.orange.shade800),
      UyariTuru.hatirlatma => (Icons.alarm_rounded, const Color(0xFF7C3AED)),
    };
    final hatirlatma = uyari.tur == UyariTuru.hatirlatma
        ? hatirlatmalar.where((h) => h.id == uyari.hedefId).firstOrNull
        : null;
    final acil = uyari.oncelik == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: (acil ? AppTheme.dangerColor : renk).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (acil ? AppTheme.dangerColor : renk).withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: switch (uyari.tur) {
          UyariTuru.vade => () => CariDetayScreen.ac(context, uyari.hedefId!),
          UyariTuru.hatirlatma when hatirlatma != null => () => HatirlatmaFormu.goster(context, eski: hatirlatma),
          _ => null,
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, color: acil ? AppTheme.dangerColor : renk, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(uyari.baslik,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16, color: acil ? AppTheme.dangerColor : null)),
                    const SizedBox(height: 4),
                    Text(uyari.metin, style: const TextStyle(fontSize: 13)),
                    if (hatirlatma != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => _yapildi(context, ref, hatirlatma),
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryMint),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Yapıldı'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _yapildi(BuildContext context, WidgetRef ref, HatirlatmaEntity h) async {
  await ref.read(hatirlatmaListeProvider.notifier).yapildi(h);
  if (!context.mounted) return;
  final sonraki = yapildiSonrasi(h);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(h.herYil ? '✅ Yapıldı. Gelecek yıl ${_tarih(sonraki.tarih)} için hatırlatılacak.' : '✅ Yapıldı.'),
  ));
}

class _HatirlatmaKarti extends ConsumerWidget {
  final HatirlatmaEntity h;
  const _HatirlatmaKarti({required this.h});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugun = DateUtils.dateOnly(DateTime.now());
    final kalan = h.gun.difference(bugun).inDays;
    final durum = h.tamamlandi
        ? 'Tamamlandı'
        : kalan < 0
            ? '${-kalan} gün geçti'
            : kalan == 0
                ? 'Bugün son gün'
                : '$kalan gün kaldı';
    return Opacity(
      opacity: h.tamamlandi ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => HatirlatmaFormu.goster(context, eski: h),
          leading: CircleAvatar(
            backgroundColor: h.tur.renk.withValues(alpha: 0.15),
            child: Icon(h.tur.ikon, color: h.tur.renk),
          ),
          title: Text(h.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${_tarih(h.gun)}${h.herYil ? ' • her yıl' : ''} • ${h.kacGunOnce} gün önce uyar',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            durum,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: !h.tamamlandi && kalan <= 0 ? AppTheme.dangerColor : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Uyarı türlerini tek tek açıp kapatma.
class BildirimAyarlariPaneli extends ConsumerWidget {
  const BildirimAyarlariPaneli({super.key});

  static Future<void> goster(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const BildirimAyarlariPaneli(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayarlar = ref.watch(bildirimAyarlariProvider).valueOrNull;
    if (ayarlar == null) return const SizedBox(height: 120);
    Widget satir(UyariTuru t, IconData ikon, String aciklama) => SwitchListTile(
          secondary: Icon(ikon),
          title: Text(t.ad, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(aciklama, style: const TextStyle(fontSize: 12)),
          value: ayarlar.acik(t),
          activeThumbColor: AppTheme.primaryMint,
          onChanged: (v) => ref.read(bildirimAyarlariProvider.notifier).degistir(t, v),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Bildirim Ayarları', style: Theme.of(context).textTheme.titleLarge),
            ),
            satir(UyariTuru.don, Icons.ac_unit_rounded, 'Önümüzdeki 3 gecede don / kırağı (önceki akşam 18:00)'),
            satir(UyariTuru.vade, Icons.payments_rounded, 'Veresiye vadesi: 2 gün önce ve vade sabahı'),
            satir(UyariTuru.hatirlatma, Icons.alarm_rounded, 'ÇKS, destek, TARSİM ve kendi hatırlatmalarınız'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Kapalı türler ne zilde ne bildirim çubuğunda görünür. Ayar bu telefona özeldir.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hatırlatma ekleme/düzenleme.
class HatirlatmaFormu extends ConsumerStatefulWidget {
  final HatirlatmaEntity? eski;
  const HatirlatmaFormu({super.key, this.eski});

  static Future<void> goster(BuildContext context, {HatirlatmaEntity? eski}) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => HatirlatmaFormu(eski: eski),
      );

  @override
  ConsumerState<HatirlatmaFormu> createState() => _HatirlatmaFormuState();
}

class _HatirlatmaFormuState extends ConsumerState<HatirlatmaFormu> {
  static const _onceSecenekleri = [1, 3, 7, 15, 30];

  late final _baslik = TextEditingController(text: widget.eski?.baslik);
  late final _not = TextEditingController(text: widget.eski?.not);
  late HatirlatmaTuru _tur = widget.eski?.tur ?? HatirlatmaTuru.diger;
  late DateTime? _tarih = widget.eski?.gun;
  late int _kacGunOnce = widget.eski?.kacGunOnce ?? 7;
  late bool _herYil = widget.eski?.herYil ?? false;

  @override
  void dispose() {
    _baslik.dispose();
    _not.dispose();
    super.dispose();
  }

  void _sablon(HatirlatmaSablonu s) => setState(() {
        _baslik.text = s.baslik;
        _tur = s.tur;
        _herYil = s.herYil;
        _kacGunOnce = s.kacGunOnce;
      });

  Future<void> _tarihSec() async {
    final bugun = DateUtils.dateOnly(DateTime.now());
    final g = await showDatePicker(
      context: context,
      initialDate: _tarih ?? bugun.add(const Duration(days: 30)),
      firstDate: DateTime(bugun.year - 1),
      lastDate: DateTime(bugun.year + 3),
      helpText: 'Son gün',
    );
    if (g != null) setState(() => _tarih = g);
  }

  Future<void> _sil() async {
    final id = widget.eski!.id;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(hatirlatmaListeProvider.notifier);
    await notifier.silindiYap(id, true);
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('Hatırlatma silindi'),
      action: SnackBarAction(label: 'Geri Al', onPressed: () => notifier.silindiYap(id, false)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hazir = _baslik.text.trim().isNotEmpty && _tarih != null;
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
                  child: Text(widget.eski == null ? 'Hatırlatma Ekle' : 'Hatırlatmayı Düzenle',
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
            if (widget.eski == null) ...[
              const SizedBox(height: 8),
              const Text('Hazır başlıklar', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final s in hatirlatmaSablonlari)
                    ActionChip(
                      avatar: Icon(s.tur.ikon, size: 18, color: s.tur.renk),
                      label: Text(s.baslik),
                      onPressed: () => _sablon(s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _baslik,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(labelText: 'Ne yapılacak?'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in HatirlatmaTuru.values)
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
            OutlinedButton.icon(
              onPressed: _tarihSec,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(_tarih == null ? 'Son günü seçin' : 'Son gün: ${_tarih!.day}.${_tarih!.month}.${_tarih!.year}',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            const Text('Kaç gün önce uyarılsın?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final g in _onceSecenekleri)
                  ChoiceChip(
                    label: Text('$g gün'),
                    selected: _kacGunOnce == g,
                    selectedColor: AppTheme.primaryMint,
                    onSelected: (_) => setState(() => _kacGunOnce = g),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _herYil,
              activeThumbColor: AppTheme.primaryMint,
              title: const Text('Her yıl tekrarla'),
              subtitle: const Text('"Yapıldı" deyince gelecek yıla taşınır', style: TextStyle(fontSize: 12)),
              onChanged: (v) => setState(() => _herYil = v),
            ),
            TextField(
              controller: _not,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Not (isteğe bağlı, ör. poliçe no, hangi tarla)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: !hazir
                    ? null
                    : () async {
                        await ref.read(hatirlatmaListeProvider.notifier).kaydet(
                              eski: widget.eski,
                              baslik: _baslik.text,
                              tur: _tur,
                              tarih: _tarih!,
                              kacGunOnce: _kacGunOnce,
                              herYil: _herYil,
                              not: _not.text,
                            );
                        if (context.mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryMint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_tarih == null ? 'Son günü seçin' : 'KAYDET',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
