import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../depo/domain/depo.dart';
import '../../depo/presentation/depo_provider.dart';
import '../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../domain/is_kaydi_entity.dart';
import 'is_gunlugu_provider.dart';

/// İş kaydı ekleme/düzenleme alt sayfası. Yazı yalnızca ürün adı, miktar ve not için
/// (hepsi isteğe bağlı); geri kalan her şey büyük butonlarla seçilir.
class IsKaydiFormu extends ConsumerStatefulWidget {
  final IsKaydiEntity? duzenlenen;
  final String? baslangicParselId;

  const IsKaydiFormu({super.key, this.duzenlenen, this.baslangicParselId});

  static Future<void> goster(BuildContext context, {IsKaydiEntity? duzenlenen, String? parselId}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => IsKaydiFormu(duzenlenen: duzenlenen, baslangicParselId: parselId),
      );

  @override
  ConsumerState<IsKaydiFormu> createState() => _IsKaydiFormuState();
}

class _IsKaydiFormuState extends ConsumerState<IsKaydiFormu> {
  /// Etiketlerde en sık görülen bekleme süreleri (gün).
  static const _hizliBekleme = [3, 7, 14, 21, 28];

  late String? _parselId = widget.duzenlenen?.parselId ?? widget.baslangicParselId;
  late IslemTuru? _tur = widget.duzenlenen?.tur;
  late DateTime _gun = DateUtils.dateOnly(widget.duzenlenen?.islemTarihi.toLocal() ?? DateTime.now());
  late int? _bekleme = widget.duzenlenen?.hasatBeklemeGun;
  late final _urun = TextEditingController(text: widget.duzenlenen?.urunAdi);
  late final _miktar = TextEditingController(text: widget.duzenlenen?.miktar);
  late final _not = TextEditingController(text: widget.duzenlenen?.not);

  /// Hasat miktarı giriş birimi; kayıt her zaman kg.
  late bool _ton = (widget.duzenlenen?.hasatKg ?? 0) >= 1000;
  late final _hasatMiktar = TextEditingController(text: _miktarMetni(widget.duzenlenen?.hasatKg, _ton));
  bool _kaydediliyor = false;

  /// "Depodan düş": seçilen ürün ve toplam kullanılan miktar (ürünün biriminde).
  String? _depoKalemId;
  final _depoMiktar = TextEditingController();

  @override
  void initState() {
    super.initState();
    final eski = widget.duzenlenen;
    if (eski != null) {
      DepoIsBaglantisi.bagliCikis(eski.id).then((h) {
        if (h != null && mounted) {
          setState(() {
            _depoKalemId = h.kalemId;
            _depoMiktar.text = miktarYaz(h.miktar);
          });
        }
      });
    }
  }

  static String _miktarMetni(double? kg, bool ton) {
    if (kg == null) return '';
    final v = ton ? kg / 1000 : kg;
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');
  }

  /// "12,5" / "12.5" → kg. Geçersiz ya da sıfırsa null.
  double? get _hasatKg {
    final v = double.tryParse(_hasatMiktar.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return _ton ? v * 1000 : v;
  }

  @override
  void dispose() {
    _urun.dispose();
    _miktar.dispose();
    _not.dispose();
    _hasatMiktar.dispose();
    _depoMiktar.dispose();
    super.dispose();
  }

  bool get _hazir => _parselId != null && _tur != null;

  /// Seçili tarlada süren ilaç bekleme süresi (hasat kaydında uyarı için).
  HasatYasagi? get _yasak => _parselId == null ? null : ref.watch(hasatYasaklariProvider)[_parselId];

  /// Bugünse şu anki saat, geçmiş günse öğle (UTC'ye çevrilince gün kaymasın).
  DateTime get _islemZamani {
    final simdi = DateTime.now();
    final eski = widget.duzenlenen;
    if (eski != null && DateUtils.isSameDay(eski.islemTarihi.toLocal(), _gun)) return eski.islemTarihi;
    return DateUtils.isSameDay(_gun, simdi) ? simdi : DateTime(_gun.year, _gun.month, _gun.day, 12);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    await ref.read(isKaydiListeProvider.notifier).kaydet(
          eski: widget.duzenlenen,
          parselId: _parselId!,
          islemTarihi: _islemZamani,
          tur: _tur!,
          urunAdi: _urun.text,
          miktar: _miktar.text,
          hasatBeklemeGun: _bekleme,
          hasatKg: _hasatKg,
          not: _not.text,
          depoKalemId: _depoKalemId,
          depoMiktar: miktarOku(_depoMiktar.text),
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.duzenlenen == null ? '✅ İş kaydedildi' : '✅ Kayıt güncellendi')),
    );
  }

  Future<void> _sil() async {
    final kayit = widget.duzenlenen!;
    final liste = ref.read(isKaydiListeProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await liste.sil(kayit.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: const Text('🗑️ Kayıt silindi'),
      action: SnackBarAction(label: 'Geri Al', onPressed: () => liste.geriAl(kayit.id)),
    ));
  }

  /// İlaçlama/gübreleme/ekimde depodaki üründen kullanılanı düşme. Uygun ürün yoksa gösterilmez.
  Widget _depoBolumu() {
    final kategori = _tur == null ? null : StokKategori.isIcin(_tur!);
    if (kategori == null) return const SizedBox.shrink();
    final kalemler = (ref.watch(stokKalemListeProvider).valueOrNull ?? const <StokKalemiEntity>[])
        .where((k) => k.kategori == kategori)
        .toList();
    if (kalemler.isEmpty) return const SizedBox.shrink();
    final mevcutlar = ref.watch(stokMevcutlariProvider);
    final secili = kalemler.where((k) => k.id == _depoKalemId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Baslik('Depodan düş (isteğe bağlı)'),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Düşme'),
              selected: secili == null,
              selectedColor: AppTheme.primaryMint,
              onSelected: (_) => setState(() => _depoKalemId = null),
            ),
            for (final k in kalemler)
              ChoiceChip(
                avatar: Icon(k.kategori.ikon, size: 18),
                label: Text('${k.ad} (${miktarYaz(mevcutlar[k.id] ?? 0)} ${k.birim})'),
                selected: secili?.id == k.id,
                selectedColor: AppTheme.primaryMint,
                onSelected: (_) => setState(() {
                  _depoKalemId = k.id;
                  // Ürün adını yazmaya gerek kalmasın.
                  if (_urun.text.trim().isEmpty) _urun.text = k.ad;
                }),
              ),
          ],
        ),
        if (secili != null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _depoMiktar,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Bu işte toplam ne kadar kullanıldı?',
              suffixText: secili.birim,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final parseller = ref.watch(parselListeProvider).valueOrNull ?? const [];
    final bugun = DateUtils.dateOnly(DateTime.now());
    final dun = bugun.subtract(const Duration(days: 1));
    final baskaGun = !DateUtils.isSameDay(_gun, bugun) && !DateUtils.isSameDay(_gun, dun);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.duzenlenen == null ? 'İş Ekle' : 'İşi Düzenle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            const _Baslik('1. Hangi tarla?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in parseller)
                  ChoiceChip(
                    label: Text('${p.urunEmoji} ${p.ad}'),
                    selected: _parselId == p.id,
                    selectedColor: AppTheme.primaryMint,
                    onSelected: (_) => setState(() => _parselId = p.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            const _Baslik('2. Ne yapıldı?'),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                for (final t in IslemTuru.values)
                  _TurButonu(tur: t, secili: _tur == t, onTap: () => setState(() => _tur = t)),
              ],
            ),
            const SizedBox(height: 16),

            const _Baslik('3. Ne zaman?'),
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
                  label: Text(baskaGun ? '${_gun.day}.${_gun.month}.${_gun.year}' : 'Başka gün'),
                  selected: baskaGun,
                  selectedColor: AppTheme.primaryMint,
                  onSelected: (_) async {
                    final secilen = await showDatePicker(
                      context: context,
                      initialDate: _gun,
                      firstDate: DateTime(bugun.year - 3),
                      lastDate: bugun,
                      helpText: 'İşin yapıldığı gün',
                    );
                    if (secilen != null) setState(() => _gun = secilen);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_tur != null && _tur != IslemTuru.hasat && _tur != IslemTuru.toprakIsleme) ...[
              const _Baslik('4. Kullanılan ürün (isteğe bağlı)'),
              TextField(
                controller: _urun,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: switch (_tur) {
                    IslemTuru.ilaclama => 'İlacın adı (etiketteki)',
                    IslemTuru.gubreleme => 'ör. Üre, DAP, 20-20-0',
                    IslemTuru.ekim => 'Tohum / çeşit adı',
                    _ => 'Ürün adı',
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _miktar,
                decoration: const InputDecoration(hintText: 'Miktar (ör. 2 L/dekar, 20 kg/dekar)'),
              ),
              const SizedBox(height: 16),
              _depoBolumu(),
            ],

            if (_tur == IslemTuru.ilaclama) ...[
              const _Baslik('Hasat öncesi bekleme süresi (etiketten)'),
              const Text(
                'İlacın etiketinde yazar. Girerseniz, süre dolana kadar bu tarla için "hasat edilemez" uyarısı gösterilir.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: (_bekleme ?? 0) <= 0 ? null : () => setState(() => _bekleme = (_bekleme ?? 0) - 1),
                    icon: const Icon(Icons.remove_rounded),
                    tooltip: 'Bir gün azalt',
                  ),
                  Expanded(
                    child: Text(
                      _bekleme == null ? 'Girilmedi' : '$_bekleme gün',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: (_bekleme ?? 0) >= 120 ? null : () => setState(() => _bekleme = (_bekleme ?? 0) + 1),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Bir gün artır',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final g in _hizliBekleme)
                    ChoiceChip(
                      label: Text('$g gün'),
                      selected: _bekleme == g,
                      selectedColor: AppTheme.dangerColor.withValues(alpha: 0.3),
                      onSelected: (_) => setState(() => _bekleme = g),
                    ),
                  ActionChip(label: const Text('Temizle'), onPressed: () => setState(() => _bekleme = null)),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_tur == IslemTuru.hasat) ...[
              const _Baslik('4. Ne kadar ürün alındı?'),
              const Text(
                'Verim (kg/dönüm) ve kilo başı maliyet bu miktardan hesaplanır. Aynı tarlayı birkaç günde '
                'kaldırıyorsanız her günü ayrı kaydedin; karnede toplanır.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hasatMiktar,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Miktar'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('kg')),
                      ButtonSegment(value: true, label: Text('ton')),
                    ],
                    selected: {_ton},
                    onSelectionChanged: (s) => setState(() {
                      // Yazılan sayıyı koru, yalnızca birimi değiştir.
                      _ton = s.first;
                    }),
                  ),
                ],
              ),
              if (_yasak case final y? when _gun.isBefore(y.serbestTarih)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block_rounded, color: AppTheme.dangerColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu tarlada ilaç bekleme süresi ${y.serbestTarih.day}.${y.serbestTarih.month}.${y.serbestTarih.year} '
                          'tarihinde doluyor${y.kaynak.urunAdi.isEmpty ? '' : ' (${y.kaynak.urunAdi})'}. Bundan önce hasat edilen '
                          'üründe ilaç kalıntısı sınırı aşabilir. Kayıt yine de yapılır.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.dangerColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _not,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Not (isteğe bağlı)'),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _hazir && !_kaydediliyor ? _kaydet : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryMint,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _hazir ? 'KAYDET' : 'Tarla ve işi seçin',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            if (widget.duzenlenen != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _sil,
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerColor),
                label: const Text('Kaydı Sil', style: TextStyle(color: AppTheme.dangerColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(metin, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
}

class _TurButonu extends StatelessWidget {
  final IslemTuru tur;
  final bool secili;
  final VoidCallback onTap;
  const _TurButonu({required this.tur, required this.secili, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secili ? tur.renk : tur.renk.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tur.ikon, color: secili ? Colors.white : tur.renk, size: 28),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tur.ad,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: secili ? Colors.white : tur.renk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
