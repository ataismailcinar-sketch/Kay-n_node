import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/hava_durumu_servisi.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../akilli_sulama/presentation/providers/sulama_provider.dart';
import '../../../arazi_analiz/domain/fenoloji_engine.dart';
import '../../../arazi_analiz/domain/zirai_karar_destek_engine.dart';
import '../../../arazi_analiz/presentation/widgets/arazi_tavsiye_tab.dart';
import '../../../arazi_analiz/presentation/widgets/fenolojik_takvim_widget.dart';
import '../../../toprak_analizi/presentation/toprak_sekmesi.dart';
import '../../domain/entities/parsel_entity.dart';
import '../providers/parsel_provider.dart';
import '../../domain/sulama.dart';
import 'sulu_secici.dart';

/// Haritada veya listede tarlaya dokunulduğunda açılan İklim & Nem, Uygunluk,
/// Gelişim Takvimi ve Düzenleme penceresi.
class ParselDetaySheet extends ConsumerStatefulWidget {
  final ParselEntity parsel;

  const ParselDetaySheet({super.key, required this.parsel});

  static void show(BuildContext context, ParselEntity parsel) {
    Future.microtask(() {
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ParselDetaySheet(parsel: parsel),
        );
      }
    });
  }

  @override
  ConsumerState<ParselDetaySheet> createState() => _ParselDetaySheetState();
}

class _ParselDetaySheetState extends ConsumerState<ParselDetaySheet> {
  int _secilenSekme = 0; // 0: İklim & Nem, 1: Uygunluk, 2: Gelişim Takvimi, 3: Toprak analizi
  bool _duzenlemeModu = false;
  late TextEditingController _isimController;
  late String _secilenUrun;
  late String _secilenToprak;
  bool? _secilenSulu;
  SulamaYontemi? _secilenYontem;
  SuKaynagi? _secilenKaynak;
  double? _secilenSuEc;

  static const List<String> _urunSecenekleri = ParselEntity.urunSecenekleri;

  static const List<String> _toprakSecenekleri = [
    'Tınlı (Orta)', 'Killi (Ağır/Su Tutar)', 'Kumlu (Hafif/Süzek)', 'Kireçli / Taşlı'
  ];

  @override
  void initState() {
    super.initState();
    _isimController = TextEditingController(text: widget.parsel.ad);
    _secilenUrun = widget.parsel.ekilmisUrun;
    _secilenToprak = widget.parsel.toprakTuru;
    _secilenSulu = widget.parsel.sulu;
    _secilenYontem = widget.parsel.sulamaYontemi;
    _secilenKaynak = widget.parsel.suKaynagi;
    _secilenSuEc = widget.parsel.suEc;
  }

  @override
  void dispose() {
    _isimController.dispose();
    super.dispose();
  }

  /// Düzenleme sonrası güncel parseli göster (eskiden pencere kapanana kadar eski
  /// ad/ürün görünüyordu).
  ParselEntity _guncelParsel() {
    final liste = ref.watch(parselListeProvider).value;
    return liste?.where((p) => p.id == widget.parsel.id).firstOrNull ?? widget.parsel;
  }

  Future<void> _ekimTarihiSec(ParselEntity parsel) async {
    final simdi = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: parsel.ekimTarihi ?? simdi,
      firstDate: DateTime(simdi.year - 2),
      lastDate: simdi.add(const Duration(days: 60)),
      helpText: 'Ekim tarihini seçin',
    );
    if (secilen != null) {
      await ref.read(parselListeProvider.notifier).guncelle(parsel.id, yeniEkimTarihi: secilen);
    }
  }

  Future<void> _silOnayla(ParselEntity parsel) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarlayı Sil'),
        content: Text('"${parsel.ad}" silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay == true && mounted) {
      Navigator.pop(context);
      await ref.read(parselListeProvider.notifier).sil(parsel.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsel = _guncelParsel();
    final havaAsync = ref.watch(parselHavaProvider(parsel));
    final hava = havaAsync.value;

    final donRiskiVar = hava != null && hava.bugunMinSicaklik <= 0.0;
    final ilac = hava == null ? null : ZiraiKararDestekEngine.ilaclamaTavsiyesi(hava);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // ListView yerine Column: başlık düzenleme formuna dönüşüp boyu birden uzayınca (klavye de
        // açılırken) tembel liste alttaki sekmeleri yeniden yerleştirmiyor, form üstlerine biniyordu.
        child: SingleChildScrollView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            if (donRiskiVar)
              _uyariBandi(
                renk: Colors.blue[900]!,
                kenar: Colors.cyanAccent,
                ikon: Icons.ac_unit_rounded,
                baslik: '🚨 DON UYARISI',
                metin: 'Bu gece sıcaklık ${hava.bugunMinSicaklik.toStringAsFixed(1)}°C\'ye düşecek. Hassas ürünleri koruyun.',
              ),
            if (ilac != null && !ilac.uygun)
              _uyariBandi(
                renk: Colors.orange[900]!,
                kenar: Colors.amberAccent,
                ikon: Icons.air_rounded,
                baslik: 'İLAÇLAMA: ${ilac.durumRozeti}',
                metin: '${ilac.baslik}. ${ilac.detay}',
              ),

            if (!_duzenlemeModu) _baslik(parsel, isDark) else _buildDuzenlemeModu(parsel),

            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1A16) : AppTheme.lightBg,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTabButton(0, '🌦️ İklim & Nem', isDark),
                  _buildTabButton(1, '🌍 Uygunluk', isDark),
                  _buildTabButton(2, '📅 Gelişim', isDark),
                  _buildTabButton(3, '🧪 Toprak', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_secilenSekme == 0)
              havaAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('⚠️ Hava verisi alınamadı: $e', style: const TextStyle(color: Colors.grey)),
                ),
                data: (h) => _iklimSekmesi(h, isDark),
              )
            else if (_secilenSekme == 1)
              AraziTavsiyeTab(key: ValueKey('uygunluk-${parsel.id}-${parsel.toprakTuru}-${parsel.sulu}-${parsel.suEc}'), parsel: parsel)
            else if (_secilenSekme == 3)
              ToprakSekmesi(parsel: parsel)
            else
              FenolojikTakvimWidget(
                ekilmisUrun: parsel.ekilmisUrun,
                ekimTarihi: parsel.ekimTarihi,
                onEkimTarihiDegistir: FenolojiEngine.cokYillik(parsel.ekilmisUrun) ? null : () => _ekimTarihiSec(parsel),
              ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMint, minimumSize: const Size(0, 56)),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Kapat', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => _silOnayla(parsel),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: EdgeInsets.zero),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _uyariBandi({
    required Color renk,
    required Color kenar,
    required IconData ikon,
    required String baslik,
    required String metin,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kenar, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(ikon, color: kenar, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(metin, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _baslik(ParselEntity parsel, bool isDark) {
    return Row(
      children: [
        Text(parsel.urunEmoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parsel.ad,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              Text(
                '${parsel.ekilmisUrun} • ${parsel.toprakTuru} toprak • ${parsel.suluMetni} • ${parsel.alanMetinsel}',
                style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
              if (parsel.konum.isNotEmpty)
                Text(
                  parsel.konum,
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() {
            _isimController.text = parsel.ad;
            _secilenUrun = parsel.ekilmisUrun;
            _secilenToprak = parsel.toprakTuru;
            _secilenSulu = parsel.sulu;
            _secilenYontem = parsel.sulamaYontemi;
            _secilenKaynak = parsel.suKaynagi;
            _secilenSuEc = parsel.suEc;
            _duzenlemeModu = true;
          }),
          icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryMint, size: 32),
          tooltip: 'İsim, Ürün ve Toprak Değiştir',
        ),
      ],
    );
  }

  Widget _iklimSekmesi(TarlaHavaOzeti h, bool isDark) {
    final et0Bugun = h.gelecekYediGunTahmin.isNotEmpty ? h.gelecekYediGunTahmin.first.buharlasmaEt0 : null;
    final nem = h.guncelToprakNemiYuzde;
    final nemDurum = nem == null
        ? 'Veri yok'
        : (h.toprakDoygun ? 'Doygun' : (nem < 30 ? 'Su stresi' : (nem < 50 ? 'Azalıyor' : 'Yeterli')));
    final nemRenk = nem == null
        ? Colors.grey
        : (nem < 30 ? AppTheme.dangerColor : (nem < 50 ? Colors.amber[800]! : AppTheme.successColor));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!h.canliVeri)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '📴 Çevrimdışı — ${h.veriZamani.day}.${h.veriZamani.month}.${h.veriZamani.year} tarihli son veri.',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _buildIklimMetrikKarti(
                'Bugün Sıcaklık',
                '${h.bugunMaxSicaklik.toStringAsFixed(1)}°C',
                'En düşük: ${h.bugunMinSicaklik.toStringAsFixed(1)}°C',
                Icons.thermostat_rounded,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIklimMetrikKarti(
                'Bugün Rüzgar',
                '${h.bugunRuzgarHiziKm.toStringAsFixed(0)} km/s',
                h.bugunRuzgarHiziKm > 15 ? 'İlaçlamaya uygun değil' : 'İlaçlamaya uygun',
                Icons.air_rounded,
                h.bugunRuzgarHiziKm > 15 ? Colors.red : Colors.lightBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildIklimMetrikKarti(
                'Kullanılabilir Su',
                nem == null ? '--' : '%${nem.toStringAsFixed(0)}',
                nemDurum,
                Icons.water_drop_rounded,
                nemRenk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIklimMetrikKarti(
                'Buharlaşma (ET₀)',
                et0Bugun == null ? '--' : '${et0Bugun.toStringAsFixed(1)} mm',
                'Bugün',
                Icons.cloud_upload_rounded,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kullanılabilir su: kök bölgesinde (≈3-27 cm) model toprak neminden, '
          '${h.toprakAnalizinden ? 'tarlanın toprak analizine (saturasyon)' : 'tarlanın toprak türüne'} göre tahmin edilir.'
          '${h.toprakAnalizinden ? '' : ' Toprak analizi girerseniz daha doğru olur (🧪 Toprak).'}',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Text(
          '🌧️ Son 7 Gün Yağış',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (h.sonYediGun.isEmpty)
          const Text('Geçmiş gün verisi yok.', style: TextStyle(color: Colors.grey))
        else
          ...h.sonYediGun.reversed.map((g) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1A16) : AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${g.tarih.day}.${g.tarih.month}.${g.tarih.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      g.yagisMm > 0.1 ? '${g.yagisMm.toStringAsFixed(1)} mm' : 'Yağış yok',
                      style: TextStyle(fontWeight: FontWeight.w600, color: g.yagisMm > 0.1 ? Colors.blue[800] : Colors.grey),
                    ),
                    Text(
                      '${g.minSicaklik.toStringAsFixed(0)}° / ${g.maxSicaklik.toStringAsFixed(0)}°',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildTabButton(int index, String baslik, bool isDark) {
    final isSelected = _secilenSekme == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _secilenSekme = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryMint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              baslik,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIklimMetrikKarti(String baslik, String deger, String altBaslik, IconData ikon, Color renk) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A16) : AppTheme.lightBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renk.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: renk.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(ikon, color: renk, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                Text(deger, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                Text(altBaslik, style: TextStyle(fontSize: 10, color: renk, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuzenlemeModu(ParselEntity parsel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tarla Adı:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _isimController,
          // Çoğu zaman yalnızca ürün/toprak değiştirilir; klavye kendiliğinden açılıp çipleri kapatmasın.
          decoration: InputDecoration(
            hintText: 'Örn: Ayçiçek Tarlası',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Ekilen Ürün:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _urunSecenekleri.map((urun) {
            return ChoiceChip(
              label: Text(urun),
              selected: _secilenUrun == urun,
              selectedColor: AppTheme.primaryMint,
              onSelected: (_) => setState(() => _secilenUrun = urun),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Toprak Bünyesi:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _toprakSecenekleri.map((t) {
            final tKisa = t.split(' ').first;
            return ChoiceChip(
              label: Text(t),
              selected: _secilenToprak == tKisa,
              selectedColor: Colors.amber[800],
              onSelected: (_) => setState(() => _secilenToprak = tKisa),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Sulama:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SuluSecici(
          deger: _secilenSulu,
          degisti: (v) => setState(() => _secilenSulu = v),
          yontem: _secilenYontem,
          yontemDegisti: (v) => setState(() => _secilenYontem = v),
          kaynak: _secilenKaynak,
          kaynakDegisti: (v) => setState(() => _secilenKaynak = v),
          suEc: _secilenSuEc,
          suEcDegisti: (v) => _secilenSuEc = v,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _duzenlemeModu = false),
              child: const Text('İptal'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final yeniAd = _isimController.text.trim();
                if (yeniAd.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tarla adı boş olamaz.')),
                  );
                  return;
                }
                await ref.read(parselListeProvider.notifier).guncelle(
                      parsel.id,
                      yeniAd: yeniAd,
                      yeniUrun: _secilenUrun,
                      yeniToprakTuru: _secilenToprak,
                      yeniSulu: _secilenSulu,
                      yeniSulamaYontemi: _secilenYontem,
                      yeniSuKaynagi: _secilenKaynak,
                      yeniSuEc: _secilenSuEc,
                    );
                if (mounted) setState(() => _duzenlemeModu = false);
              },
              // Tema düğmeleri tam genişlik yapar; satır içinde sonsuz genişlik yerleşimi çökertiyordu.
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMint, minimumSize: const Size(96, 48)),
              child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}
