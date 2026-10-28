import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/parsel_entity.dart';
import '../providers/parsel_provider.dart';
import '../widgets/parsel_detay_sheet.dart';
import '../widgets/sulu_secici.dart';
import '../../domain/sulama.dart';
import '../../../../core/theme/app_theme.dart';

enum HaritaTipi { hibrit, uydu, sokak }

/// Harita üzerinde tarla sınırı (poligon) çizme, otomatik sınır düzeltme ve ürün seçimi ekranı.
class ParselHaritaScreen extends ConsumerStatefulWidget {
  /// Verilirse harita bu tarlaya odaklanarak açılır ("Haritada Gör").
  final ParselEntity? odakParsel;

  const ParselHaritaScreen({super.key, this.odakParsel});

  @override
  ConsumerState<ParselHaritaScreen> createState() => _ParselHaritaScreenState();
}

class _ParselHaritaScreenState extends ConsumerState<ParselHaritaScreen> {
  final MapController _mapController = MapController();
  static const LatLng _turkiyeMerkezi = LatLng(39.1667, 35.6667);
  HaritaTipi _seciliHaritaTipi = HaritaTipi.hibrit;

  @override
  Widget build(BuildContext context) {
    final cizimState = ref.watch(haritaCizimProvider);
    final parsellerAsync = ref.watch(parselListeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Tarla Çiz'),
        actions: [
          if (cizimState.noktalar.isNotEmpty)
            IconButton(
              onPressed: () => ref.read(haritaCizimProvider.notifier).geriAl(),
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Son noktayı geri al',
              iconSize: 28,
            ),
          if (cizimState.noktalar.isNotEmpty)
            IconButton(
              onPressed: () => ref.read(haritaCizimProvider.notifier).temizle(),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Çizimi temizle',
              iconSize: 28,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── HARİTA VE TÜM PARSELLER ─────────────────────────────────────
          parsellerAsync.when(
            data: (kayitliParseller) => _buildMap(cizimState, kayitliParseller),
            loading: () => _buildMap(cizimState, []),
            error: (_, __) => _buildMap(cizimState, []),
          ),

          // ── OTOMATİK POLİGON DÜZELTME & HARİTA TİPİ BUTONLARI (SAĞ ÜST) ─────
          Positioned(
            top: cizimState.noktalar.isNotEmpty ? 60 : 16,
            right: 14,
            child: Column(
              children: [
                if (cizimState.noktalar.length >= 3) ...[
                  FloatingActionButton.extended(
                    heroTag: 'smooth_fab',
                    onPressed: () {
                      ref.read(haritaCizimProvider.notifier).sinirlariDuzelt();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Köşeler yumuşatıldı. Sonuç beğenilmezse geri al tuşuyla tek tek nokta silinebilir.'),
                          backgroundColor: AppTheme.primaryMint,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    backgroundColor: Colors.amber[800],
                    icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.white),
                    label: const Text('Köşeleri Yumuşat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                ],

                FloatingActionButton.small(
                  heroTag: 'map_type_fab',
                  onPressed: _haritaTipiDegistirDialog,
                  backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                  child: const Icon(Icons.layers_rounded, color: AppTheme.primaryMint, size: 24),
                ),
                const SizedBox(height: 10),

                FloatingActionButton.small(
                  heroTag: 'center_fab',
                  onPressed: () {
                    final kayitli = ref.read(parselListeProvider).value ?? [];
                    if (kayitli.isNotEmpty) {
                      _mapController.move(LatLng(kayitli.first.merkezLat, kayitli.first.merkezLng), 14.5);
                    } else {
                      _mapController.move(_turkiyeMerkezi, 6.5);
                    }
                  },
                  // GPS kullanılmıyor; buton ilk kayıtlı tarlaya (yoksa Türkiye geneline) götürür.
                  tooltip: 'Tarlalarıma git',
                  backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                  child: const Icon(Icons.center_focus_strong_rounded, color: AppTheme.primaryMint, size: 24),
                ),
              ],
            ),
          ),

          if (cizimState.noktalar.isNotEmpty) _buildAlanBant(cizimState),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildAltPanel(context, cizimState, isDark),
          ),

          if (cizimState.noktalar.isEmpty) _buildIlkDokunmaBilgisi(),
        ],
      ),
    );
  }

  Widget _buildMap(HaritaCizimState cizimState, List<ParselEntity> kayitliParseller) {
    final List<Polygon> kayitliPoligonlar = kayitliParseller.where((p) => p.poligonNoktalar.length >= 3).map((p) {
      return Polygon(
        points: p.poligonNoktalar.map((pt) => LatLng(pt.lat, pt.lng)).toList(),
        color: AppTheme.primaryMint.withOpacity(0.35),
        borderColor: AppTheme.primaryMint,
        borderStrokeWidth: 3,
        label: '${p.urunEmoji} ${p.ad}',
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      );
    }).toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.odakParsel != null
            ? LatLng(widget.odakParsel!.merkezLat, widget.odakParsel!.merkezLng)
            : (kayitliParseller.isNotEmpty
                ? LatLng(kayitliParseller.first.merkezLat, kayitliParseller.first.merkezLng)
                : _turkiyeMerkezi),
        initialZoom: widget.odakParsel != null ? 15.5 : (kayitliParseller.isNotEmpty ? 14.0 : 6.5),
        maxZoom: 20,
        minZoom: 4,
        onTap: (tapPosition, latLng) {
          Future.microtask(() {
            if (!mounted) return;
            ref.read(haritaCizimProvider.notifier).noktaEkle(
                  LatLngPoint(latLng.latitude, latLng.longitude),
                );
          });
        },
      ),
      children: [
        if (_seciliHaritaTipi == HaritaTipi.sokak)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.kayin.tarim',
          )
        else
          TileLayer(
            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.kayin.tarim',
            maxNativeZoom: 19,
          ),

        if (_seciliHaritaTipi == HaritaTipi.hibrit)
          TileLayer(
            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.kayin.tarim',
            maxNativeZoom: 19,
          ),

        if (kayitliPoligonlar.isNotEmpty) PolygonLayer(polygons: kayitliPoligonlar),

        MarkerLayer(
          markers: kayitliParseller.map((p) {
            return Marker(
              point: LatLng(p.merkezLat, p.merkezLng),
              width: 110,
              height: 54,
              child: GestureDetector(
                onTap: () {
                  Future.microtask(() {
                    if (mounted) ParselDetaySheet.show(context, p);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryMint, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  // Sabit boyutlu işaretçi: telefonun yazı boyutu büyükse içerik taşmak yerine küçülür.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text('${p.urunEmoji} ${p.ad}', maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), overflow: TextOverflow.ellipsis),
                        ),
                        Text('${p.ekilmisUrun} • ${p.alanMetinsel}', maxLines: 1, style: const TextStyle(fontSize: 10, color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        if (cizimState.noktalar.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: cizimState.noktalar.map((p) => LatLng(p.lat, p.lng)).toList(),
                color: AppTheme.primaryMint.withOpacity(0.35),
                borderColor: AppTheme.primaryMint,
                borderStrokeWidth: 3.5,
              ),
            ],
          ),

        if (cizimState.noktalar.isNotEmpty)
          MarkerLayer(
            markers: cizimState.noktalar.asMap().entries.map((entry) {
              final isFirst = entry.key == 0;
              return Marker(
                point: LatLng(entry.value.lat, entry.value.lng),
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: isFirst ? AppTheme.successColor : AppTheme.primaryMint,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),

        // Harita sağlayıcılarının kullanım şartı gereği kaynak belirtimi
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            if (_seciliHaritaTipi == HaritaTipi.sokak)
              const TextSourceAttribution('© OpenStreetMap katkıda bulunanlar')
            else
              const TextSourceAttribution('Uydu: Esri, Maxar, Earthstar Geographics'),
          ],
        ),
      ],
    );
  }

  void _haritaTipiDegistirDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Harita Görünümü Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.map_rounded, color: AppTheme.primaryMint),
              title: const Text('🏷️ Hibrit (Uydu + İl/İlçe/Köy ve Yol İsimleri)', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _seciliHaritaTipi == HaritaTipi.hibrit,
              onTap: () {
                setState(() => _seciliHaritaTipi = HaritaTipi.hibrit);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.satellite_alt_rounded, color: Colors.blue),
              title: const Text('🛰️ Sadece Saf Uydu Görüntüsü'),
              selected: _seciliHaritaTipi == HaritaTipi.uydu,
              onTap: () {
                setState(() => _seciliHaritaTipi = HaritaTipi.uydu);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.alt_route_rounded, color: Colors.green),
              title: const Text('🗺️ Sokak ve Yol Haritası'),
              selected: _seciliHaritaTipi == HaritaTipi.sokak,
              onTap: () {
                setState(() => _seciliHaritaTipi = HaritaTipi.sokak);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlanBant(HaritaCizimState cizimState) {
    final alan = cizimState.alanDonum;
    final alanMetin = alan >= 1 ? '${alan.toStringAsFixed(2)} dönüm' : '${(alan * 1000).toStringAsFixed(0)} m²';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryEmerald.withOpacity(0.95),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Alan: $alanMetin', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${cizimState.noktalar.length} nokta', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildAltPanel(BuildContext context, HaritaCizimState cizimState, bool isDark) {
    final yeterliNokta = cizimState.noktalar.length >= 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Text(
            yeterliNokta
                ? '✅ Sınır hazır — Kaydet\'e basabilirsiniz'
                : 'Haritaya dokunarak tarlanızın köşelerini seçin',
            textAlign: TextAlign.center,
            style: TextStyle(color: yeterliNokta ? AppTheme.successColor : Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: yeterliNokta ? () => _kaydetDialog(context) : null,
              style: ElevatedButton.styleFrom(backgroundColor: yeterliNokta ? AppTheme.primaryMint : Colors.grey[400]),
              icon: const Icon(Icons.save_alt_rounded, size: 26, color: Colors.white),
              label: const Text('Tarlayı & Ürünü Kaydet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIlkDokunmaBilgisi() {
    return Positioned(
      bottom: 145,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            Icon(Icons.map_rounded, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '💡 Köyünüzü bulmak için haritada yakınlaşın. Tarlalarınıza dokunup detayları görün.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PARSEL VE EKİLİ ÜRÜN İSİMLENDİRME DIALOG'U ───────────────────────────
  void _kaydetDialog(BuildContext context) {
    final adSecenekleri = ['Kuzey Tarla', 'Güney Bahçesi', 'Dere Kenarı', 'Ayçiçek Tarlası', 'Zeytinlik', 'Büyük Vadi'];
    const urunSecenekleri = ParselEntity.urunSecenekleri;
    final toprakSecenekleri = ['Tınlı (Orta)', 'Killi (Ağır/Su Tutar)', 'Kumlu (Hafif/Süzek)', 'Kireçli / Taşlı'];

    final textController = TextEditingController();
    String secilenAd = '';
    String secilenUrun = 'Buğday';
    String secilenToprak = 'Tınlı';
    bool? secilenSulu;
    SulamaYontemi? secilenYontem;
    SuKaynagi? secilenKaynak;
    double? secilenSuEc;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDarkModal = Theme.of(ctx).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            decoration: BoxDecoration(
              color: isDarkModal ? AppTheme.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Tarlayı İsimlendirin ve Özelliklerini Seçin', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),

                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: 'Özel Tarla Adı (İsteğe Bağlı)',
                      hintText: 'Örn: Ev Arkası Mısır Tarlası',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.edit),
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        setModalState(() => secilenAd = val.trim());
                      }
                    },
                  ),

                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: adSecenekleri.map((ad) => ActionChip(
                          label: Text(ad, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setModalState(() {
                            textController.text = ad;
                            secilenAd = ad;
                          }),
                        )).toList(),
                  ),

                  const SizedBox(height: 14),
                  const Text('🌾 Ekilen Ürünü Seçin:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: urunSecenekleri.map((urun) {
                      final isSelected = secilenUrun == urun;
                      return ChoiceChip(
                        label: Text(urun),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryMint,
                        onSelected: (_) => setModalState(() => secilenUrun = urun),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  const Text('🌱 Toprak Bünyesi (Toprak Türü):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: toprakSecenekleri.map((t) {
                      final tKisa = t.split(' ').first;
                      final isSelected = secilenToprak == tKisa;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSelected,
                        selectedColor: Colors.amber[800],
                        onSelected: (_) => setModalState(() => secilenToprak = tKisa),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  const Text('💧 Sulama:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SuluSecici(
          deger: secilenSulu,
          degisti: (v) => setModalState(() => secilenSulu = v),
          yontem: secilenYontem,
          yontemDegisti: (v) => setModalState(() => secilenYontem = v),
          kaynak: secilenKaynak,
          kaynakDegisti: (v) => setModalState(() => secilenKaynak = v),
          suEc: secilenSuEc,
          suEcDegisti: (v) => secilenSuEc = v,
        ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        final finalName = textController.text.trim().isNotEmpty ? textController.text.trim() : secilenAd;
                        final hata = await ref.read(haritaCizimProvider.notifier).kaydet(
                              finalName,
                              ekilmisUrun: secilenUrun,
                              toprakTuru: secilenToprak,
                              sulu: secilenSulu,
                              sulamaYontemi: secilenYontem,
                              suKaynagi: secilenKaynak,
                              suEc: secilenSuEc,
                            );
                        if (hata == null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('✅ "$finalName" ($secilenUrun - $secilenToprak Toprak) kaydedildi!'), backgroundColor: AppTheme.successColor),
                          );
                        } else {
                          messenger.showSnackBar(
                            SnackBar(content: Text('❌ $hata'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryMint),
                      icon: const Icon(Icons.check_circle_rounded, size: 26, color: Colors.white),
                      label: const Text('KAYDET VE BİTİR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
