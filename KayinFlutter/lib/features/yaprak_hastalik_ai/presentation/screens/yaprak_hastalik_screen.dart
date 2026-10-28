import '../../../bildirimler/presentation/bildirimler_screen.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../../../sync/sync_status_badge.dart';
import '../../domain/entities/hastalik_tarama_entity.dart';
import '../../domain/usecases/tflite_leaf_analyzer_usecase.dart';
import '../widgets/tarama_fotografi.dart';
import '../../domain/yaprak_etiket_eslestirici.dart';
import '../providers/hastalik_tarama_provider.dart';
import '../widgets/manuel_teshis_sheet.dart';
import '../widgets/recete_detay_sheet.dart';

/// Edge-AI Yaprak Hastalık Tarama & Zirai Mücadele Rehberi UI
class YaprakHastalikScreen extends ConsumerStatefulWidget {
  const YaprakHastalikScreen({super.key});

  @override
  ConsumerState<YaprakHastalikScreen> createState() => _YaprakHastalikScreenState();
}

class _YaprakHastalikScreenState extends ConsumerState<YaprakHastalikScreen> {
  File? _secilenFoto;
  bool _analizEdiliyor = false;
  HastalikTaramaEntity? _sonSonuc;
  LeafAnalysisResult? _belirsizSonuc;
  String? _sonParselUrunu;
  String? _secilenParselId;
  final ImagePicker _picker = ImagePicker();

  Future<void> _fotografCek(ImageSource source) async {
    // 1600 px model için fazlasıyla yeter (224 px'e küçültülür) ve sunucuya yüklerken
    // kırsaldaki yavaş bağlantıda dosyayı birkaç yüz KB'ta tutar.
    final XFile? photo = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
    if (photo == null) return;

    setState(() {
      _secilenFoto = File(photo.path);
      _analizEdiliyor = true;
      _sonSonuc = null;
      _belirsizSonuc = null;
    });

    try {
      final r = await ref
          .read(hastalikTaramaListeProvider.notifier)
          .fotoAnalizEt(photo.path, parselId: _secilenParselId);
      if (!mounted) return;

      setState(() {
        _analizEdiliyor = false;
        _sonParselUrunu = r.parselUrunu;
      });

      switch (r.sonuc.durum) {
        case AnalizDurumu.teshis:
          setState(() => _sonSonuc = r.kayit);
          if (r.sonuc.recete != null) {
            ReceteDetaySheet.show(context, r.kayit!.teshisAdi, guvenYuzdesi: r.kayit!.guvenYuzdesi);
          } else if (r.sonuc.mesaj.isNotEmpty) {
            _bilgiVer(r.sonuc.mesaj);
          }
        case AnalizDurumu.belirsiz:
          setState(() => _belirsizSonuc = r.sonuc);
        case AnalizDurumu.modelYok:
        case AnalizDurumu.desteklenmeyenUrun:
          await _manuelSec(photo.path, r.sonuc.mesaj);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analizEdiliyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analiz Hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Model teşhis koyamadığında kullanıcıya listeden seçtirir ve kaydeder.
  Future<void> _manuelSec(String fotoYolu, String aciklama) async {
    final secilen = await ManuelTeshisSheet.show(context, urun: _sonParselUrunu, aciklama: aciklama);
    if (secilen == null || !mounted) return;
    final kayit = await ref.read(hastalikTaramaListeProvider.notifier).manuelKaydet(
          fotoYolu: fotoYolu,
          parselId: _secilenParselId,
          recete: secilen,
        );
    if (!mounted) return;
    setState(() {
      _sonSonuc = kayit;
      _belirsizSonuc = null;
    });
    ReceteDetaySheet.show(context, kayit.teshisAdi);
  }

  void _bilgiVer(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  @override
  Widget build(BuildContext context) {
    final gecmisAsync = ref.watch(hastalikTaramaListeProvider);
    final parsellerAsync = ref.watch(parselListeProvider);
    final parseller = parsellerAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modelHazir = ref.watch(yaprakModelHazirProvider).value;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Hastalık Rehberi'),
        actions: const [BildirimZili(), SyncStatusBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── PARSEL SEÇİMİ ───────────────────────────────────────────
            if (parseller.isNotEmpty) ...[
              Text(
                '🌾 Hangi Tarla İçin Taranıyor?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('🌿 Genel Tarama'),
                      selected: _secilenParselId == null,
                      selectedColor: AppTheme.primaryMint,
                      onSelected: (_) => setState(() => _secilenParselId = null),
                    ),
                    const SizedBox(width: 8),
                    ...parseller.map((p) {
                      final isSel = _secilenParselId == p.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${p.urunEmoji} ${p.ad}'),
                          selected: isSel,
                          selectedColor: AppTheme.primaryMint,
                          onSelected: (_) => setState(() => _secilenParselId = p.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── VİZÖR / FOTOĞRAF ALANI ────────────────────────────────────
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1A16) : Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _secilenFoto != null
                    ? Image.file(_secilenFoto!, fit: BoxFit.cover, width: double.infinity)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.center_focus_strong_rounded, size: 68, color: AppTheme.primaryMint),
                          const SizedBox(height: 12),
                          const Text(
                            'Yaprak Vizörü',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            switch (modelHazir) {
                              true => 'Cihaz üzerinde model hazır (çevrimdışı)',
                              false => 'Model yüklü değil — belirtiyi listeden seçeceksiniz',
                              null => 'Model kontrol ediliyor...',
                            },
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 18),

            // ── KAMERA & GALERİ BUTONLARI (DEV TİP) ──────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _analizEdiliyor ? null : () => _fotografCek(ImageSource.camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryMint,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 26, color: Colors.white),
                      label: const Text('FOTOĞRAF ÇEK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _analizEdiliyor ? null : () => _fotografCek(ImageSource.gallery),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                      side: const BorderSide(color: AppTheme.primaryMint, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Icon(Icons.photo_library_rounded, size: 26, color: AppTheme.primaryMint),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── YÜKLENİYOR / BÜYÜK PUNTO ANALİZ SONUCU ─────────────────────
            if (_analizEdiliyor)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryMint, strokeWidth: 4),
                    SizedBox(height: 16),
                    Text(
                      'Fotoğraf cihaz üzerinde analiz ediliyor...',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('⚡ Fotoğraf internete GÖNDERİLMEZ (%100 Çevrimdışı)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),

            if (!_analizEdiliyor && _belirsizSonuc != null && _secilenFoto != null)
              _buildBelirsizKart(_belirsizSonuc!, isDark),

            if (!_analizEdiliyor && _sonSonuc != null) ...[
              _buildSonucKarti(_sonSonuc!),
              const SizedBox(height: 14),
              _buildMucadeleRehberiKart(_sonSonuc!, isDark),
            ],

            const SizedBox(height: 24),

            // ── GEÇMİŞ TARAMA KAYITLARI ──────────────────────────────────
            Text(
              '📜 Geçmiş Hastalık Taramaları',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            gecmisAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
              error: (err, _) => Text('Hata: $err', style: const TextStyle(color: Colors.red)),
              data: (taramalar) {
                if (taramalar.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Henüz kaydedilmiş hastalık taraması yok.', textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: taramalar.length,
                  itemBuilder: (ctx, i) {
                    final t = taramalar[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => ReceteDetaySheet.show(context, t.teshisAdi, guvenYuzdesi: t.guvenYuzdesi),
                        leading: TaramaFotografi(tarama: t),
                        title: Text(t.formatliTeshis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(
                          '${t.taramaTarihi.day}.${t.taramaTarihi.month}.${t.taramaTarihi.year} • Reçeteyi görmek için dokunun 📋',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryMint),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── TEŞHİS SONUÇ KARTI ──────────────────────────────────────────────────
  Widget _buildSonucKarti(HastalikTaramaEntity sonuc) {
    final isCritical = sonuc.aciliyetSeviyesi == 'Kritik';
    final cardColor = isCritical ? const Color(0xFFC62828) : (sonuc.aciliyetSeviyesi == 'Dikkat' ? const Color(0xFFD97706) : const Color(0xFF0F766E));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sonuc.manuelMi ? 'TEŞHİS (MANUEL SEÇİM)' : 'TEŞHİS SONUCU (CİHAZ ÜZERİ MODEL)', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 11)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: const Text('⚡ OFFLINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            sonuc.formatliTeshis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          Text(
            'Aciliyet: ${sonuc.aciliyetSeviyesi.toUpperCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── BELİRSİZ SONUÇ KARTI (model emin değil → kaydetme, kullanıcıya sor) ──
  Widget _buildBelirsizKart(LeafAnalysisResult sonuc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD97706), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤔 Kesin teşhis konamadı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(sonuc.mesaj, style: const TextStyle(fontSize: 13)),
          if (sonuc.alternatifler.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Modelin en olası tahminleri:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ...sonuc.alternatifler.map((a) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${a.bitki} — ${a.teshis}  (%${a.yuzde.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _manuelSec(_secilenFoto!.path, sonuc.mesaj),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Belirtiyi listeden kendim seçeyim'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 🧪 ZİRAİ MÜCADELE VE İLAÇ ÖNERİ REHBERİ KARTI ─────────────────────────
  Widget _buildMucadeleRehberiKart(HastalikTaramaEntity sonuc, bool isDark) {
    final recete = YaprakEtiketEslestirici.teshisReceti(sonuc.teshisAdi);
    if (recete == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.6), width: 2),
        ),
        child: const Text(
          '📋 Bu teşhis için reçete veritabanında kayıt yok. İlaçlama öncesi il/ilçe tarım '
          'müdürlüğüne veya bir ziraat mühendisine danışın.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryMint.withOpacity(0.4), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.medical_services_rounded, color: AppTheme.primaryMint, size: 22),
              SizedBox(width: 8),
              Text('Mücadele Özeti', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recete.ilaclaTedaviYok
                ? 'İlaçla tedavisi yok.'
                : recete.ilacGerekir
                    ? 'İlaç grupları: ${recete.mucadeleGruplari.take(2).join(", ")}'
                    : 'İlaçlama gerekmez.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recete.ilacGerekir && !recete.ilaclaTedaviYok
                ? 'Ürün, doz ve hasat öncesi bekleme süresi için ziraat mühendisine danışın.'
                : recete.uygulamaZamani,
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // REÇETE DETAY BUTONU
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => ReceteDetaySheet.show(context, sonuc.teshisAdi, guvenYuzdesi: sonuc.guvenYuzdesi),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Colors.white),
              label: const Text(
                'TÜM İLAÇ & TEDAVİ REÇETESİNİ GÖR',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
