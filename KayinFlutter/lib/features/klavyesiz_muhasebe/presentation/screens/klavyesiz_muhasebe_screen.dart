import '../../../bildirimler/presentation/bildirimler_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/tutar_tus_takimi.dart';
import '../../../veresiye/presentation/veresiye_provider.dart';
import '../../../veresiye/presentation/veresiye_screen.dart';
import '../../../parsel_harita/presentation/providers/parsel_provider.dart';
import '../../../sync/sync_status_badge.dart';
import '../providers/muhasebe_provider.dart';

final _tlFormat = NumberFormat.decimalPattern('tr');
String _gunMetni(DateTime t) => '${t.day}.${t.month}.${t.year}';

/// Listeden bir kayıt düzenlemeye alınınca sayfanın başına kaydırmak için.
final _ustKey = GlobalKey();

/// ZERO-KEYBOARD Hızlı Muhasebe & Hasat/Kâr Ekranı
class KlavyesizMuhasebeScreen extends ConsumerWidget {
  const KlavyesizMuhasebeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(giderGirisProvider);
    final notifier = ref.read(giderGirisProvider.notifier);
    final giderAsync = ref.watch(giderListeProvider);
    final parsellerAsync = ref.watch(parselListeProvider);
    final parseller = parsellerAsync.value ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tumKayitlar = giderAsync.value ?? [];

    // ── KÂR / ZARAR & DÖNÜM BAŞI HESABI ──────────────────────────────────────
    final secilenParsel = state.secilenParselId != null
        ? parseller.where((p) => p.id == state.secilenParselId).firstOrNull
        : null;

    final ilgiliKayitlar = state.secilenParselId != null
        ? tumKayitlar.where((k) => k.parselId == state.secilenParselId).toList()
        : tumKayitlar;

    double toplamGider = 0;
    double toplamGelir = 0;
    for (final k in ilgiliKayitlar) {
      if (k.islemTuru == 'Gelir') {
        toplamGelir += k.tutar;
      } else {
        toplamGider += k.tutar;
      }
    }
    final netKar = toplamGelir - toplamGider;
    final double donum = secilenParsel != null && secilenParsel.alanDonumCinsinden > 0
        ? secilenParsel.alanDonumCinsinden
        : 0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Muhasebe'),
        actions: const [BildirimZili(), SyncStatusBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 0. KÂR / ZARAR & DÖNÜM BAŞI ÖZET KARTI ────────────────────
            KeyedSubtree(
              key: _ustKey,
              child: _buildNetKarOzetKarti(
                context,
                toplamGelir: toplamGelir,
                toplamGider: toplamGider,
                netKar: netKar,
                donum: donum,
                secilenTarlaAdi: secilenParsel?.ad,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 12),
            VeresiyeOzetKarti(
              ozet: ref.watch(veresiyeOzetiProvider),
              onTap: () => VeresiyeScreen.ac(context),
            ),
            const SizedBox(height: 16),

            if (state.duzenlenen != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber[700]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.amber[800]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kayıt düzenleniyor', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (state.veresiyeBagli)
                            const Text(
                              'Veresiye defterine bağlı: tutar ve tarih orada da güncellenir.',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: notifier.duzenlemeIptal,
                      child: const Text('Vazgeç'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 1. İŞLEM TÜRÜ SEÇİMİ (GİDER VS GELİR) ─────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1A16) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => notifier.islemTuruSec('Gider'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: state.islemTuru == 'Gider' ? AppTheme.dangerColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '💸 Gider / Masraf Ekle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: state.islemTuru == 'Gider' ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => notifier.islemTuruSec('Gelir'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: state.islemTuru == 'Gelir' ? AppTheme.primaryMint : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '🌾 Hasat / Gelir Ekle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: state.islemTuru == 'Gelir' ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. PARSEL SEÇİMİ (İSTEĞE BAĞLI) ───────────────────────────
            if (parseller.isNotEmpty) ...[
              Text(
                '🌾 Hangi Tarla İçin?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('🚜 Genel (Tüm Çiftlik)'),
                      selected: state.secilenParselId == null,
                      selectedColor: AppTheme.primaryMint,
                      onSelected: (_) => notifier.parselSec(null),
                    ),
                    const SizedBox(width: 8),
                    ...parseller.map((p) {
                      final isSelected = state.secilenParselId == p.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${p.urunEmoji} ${p.ad} (${p.alanMetinsel})'),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryMint,
                          onSelected: (_) => notifier.parselSec(p.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 3. KATEGORİ SEÇİMİ ─────────────────────────────────────────
            Text(
              state.islemTuru == 'Gider' ? '1. Gider Kategorisi Seçin' : '1. Gelir Türü Seçin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildDevKategoriGrid(state, notifier, isDark),

            const SizedBox(height: 20),

            // ── 4. ALT KATEGORİ ÇİPLERİ ───────────────────────────────────
            if (state.secilenKategori != null) ...[
              Text(
                '2. ${state.secilenKategori} Detayı Seçin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildAltKategoriCipleri(state, notifier, isDark),
              const SizedBox(height: 20),
            ],

            // ── 5. DEV TUTAR GÖSTERGESİ VE HIZLI EKLEME BUTONLARI ─────────
            Text(
              '3. Tutar Belirleyin (TL)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildDevTutarPaneli(context, state, notifier, isDark),

            const SizedBox(height: 20),

            // ── 6. TARİH ──────────────────────────────────────────────────
            Text(
              '4. Ne Zaman?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildTarihSecimi(context, state, notifier),

            const SizedBox(height: 24),

            // ── 6. DEV KAYDET BUTONU ──────────────────────────────────────
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: state.hazir
                    ? () async {
                        String? hata;
                        try {
                          hata = await notifier.kaydet();
                        } catch (e) {
                          hata = 'Kayıt hatası: $e';
                        }
                        if (hata != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(hata), backgroundColor: Colors.red),
                          );
                        }
                        if (hata == null) {
                          ref.read(giderListeProvider.notifier).yenile();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.duzenlenen != null
                                    ? '✅ Kayıt güncellendi!'
                                    : state.islemTuru == 'Gider'
                                        ? '✅ Masraf kaydedildi!'
                                        : '✅ Gelir kaydedildi!'),
                                backgroundColor: AppTheme.successColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            notifier.sifirla();
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.hazir
                      ? (state.islemTuru == 'Gider' ? AppTheme.dangerColor : AppTheme.primaryMint)
                      : Colors.grey[400],
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 28, color: Colors.white),
                label: Text(
                  state.duzenlenen != null
                      ? 'DEĞİŞİKLİĞİ KAYDET'
                      : state.islemTuru == 'Gider'
                          ? 'GİDERİ KAYDET'
                          : 'GELİRİ KAYDET',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── SON GEÇMİŞ İŞLEMLER LİSTESİ ───────────────────────────────
            Text(
              '📜 Son Kaydedilen İşlemler',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            giderAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryMint)),
              error: (err, _) => Text('Hata: $err', style: const TextStyle(color: Colors.red)),
              data: (_) {
                final giderler = ilgiliKayitlar.take(30).toList();
                if (giderler.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Henüz kaydedilmiş işlem bulunmuyor.', textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: giderler.length,
                  itemBuilder: (ctx, i) {
                    final g = giderler[i];
                    final isGelir = g.islemTuru == 'Gelir';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () {
                          notifier.duzenlemeBaslat(g);
                          final ust = _ustKey.currentContext;
                          if (ust != null) {
                            Scrollable.ensureVisible(ust, duration: const Duration(milliseconds: 300));
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: isGelir
                              ? AppTheme.primaryMint.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          child: Text(g.kategoriEmoji, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${AppConstants.kategoriAdi(g.kategori, islemTuru: g.islemTuru)} - ${g.altKategori}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isGelir ? AppTheme.primaryMint.withOpacity(0.2) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                g.islemTuru,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isGelir ? AppTheme.primaryMint : AppTheme.dangerColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${_gunMetni(g.giderTarihi.toLocal())} ${g.isSynced ? "☁️ Sync" : "📱 Yerel"}',
                          style: TextStyle(color: g.isSynced ? Colors.green : Colors.orange),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isGelir ? "+" : "-"}${g.tutarMetni}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isGelir ? AppTheme.successColor : AppTheme.dangerColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                final liste = ref.read(giderListeProvider.notifier);
                                final veresiyeli = await liste.sil(g.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(veresiyeli
                                          ? '🗑️ Kayıt ve bağlı veresiye hareketi silindi'
                                          : '🗑️ Kayıt silindi'),
                                      action: SnackBarAction(label: 'Geri Al', onPressed: () => liste.geriAl(g.id)),
                                    ),
                                  );
                                }
                              },
                              tooltip: 'Kaydı Sil',
                            ),
                          ],
                        ),
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

  // ── Kâr / Zarar & Dönüm Başı Özet Kartı ──────────────────────────────────────
  Widget _buildNetKarOzetKarti(
    BuildContext context, {
    required double toplamGelir,
    required double toplamGider,
    required double netKar,
    required double donum,
    String? secilenTarlaAdi,
    required bool isDark,
  }) {
    final bool pozitifKar = netKar >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryMint.withOpacity(0.3), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                secilenTarlaAdi != null ? '🌾 $secilenTarlaAdi Kâr / Maliyet' : '📊 Çiftlik Genel Net Bilanço',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pozitifKar ? AppTheme.successColor.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pozitifKar ? 'KÂRDA 📈' : 'ZARARDA 📉',
                  style: TextStyle(
                    color: pozitifKar ? AppTheme.successColor : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Toplam Hasat/Gelir', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${_tlFormat.format(toplamGelir.round())} ₺',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.successColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Toplam Masraf/Gider', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${_tlFormat.format(toplamGider.round())} ₺',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.dangerColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Kâr', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${netKar >= 0 ? "+" : ""}${_tlFormat.format(netKar.round())} ₺',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: pozitifKar ? AppTheme.primaryMint : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (donum > 0) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🌱 Dönüm Başı Masraf: ${(toplamGider / donum).toStringAsFixed(0)} ₺/dönüm',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  '💰 Net Kâr: ${(netKar / donum).toStringAsFixed(0)} ₺/dönüm',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pozitifKar ? AppTheme.primaryMint : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Kategori Butonları ──────────────────────────────────────────────────────
  Widget _buildDevKategoriGrid(GiderGirisState state, GiderGirisNotifier notifier, bool isDark) {
    final List<Map<String, dynamic>> kategoriler = state.islemTuru == 'Gider'
        ? [
            {'ad': 'Mazot', 'emoji': '⛽', 'renk': const Color(0xFFD84315)},
            {'ad': 'Gubre', 'emoji': '🌿', 'renk': const Color(0xFF0F766E)},
            {'ad': 'Ilac', 'emoji': '🧪', 'renk': const Color(0xFF7C3AED)},
            {'ad': 'Tohum', 'emoji': '🌱', 'renk': const Color(0xFF16A34A)},
            {'ad': 'Iscilik', 'emoji': '👷', 'renk': const Color(0xFF2563EB)},
            {'ad': 'Diger', 'emoji': '📦', 'renk': const Color(0xFF64748B)},
          ]
        : [
            {'ad': 'Hasat', 'emoji': '🌾', 'renk': const Color(0xFF16A34A)},
            {'ad': 'Destek', 'emoji': '🏛️', 'renk': const Color(0xFF0D9488)},
            {'ad': 'Diger', 'emoji': '💰', 'renk': const Color(0xFF2563EB)},
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kategoriler.length <= 4 ? 2 : 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: kategoriler.length,
      itemBuilder: (ctx, i) {
        final item = kategoriler[i];
        final ad = item['ad'] as String;
        final emoji = item['emoji'] as String;
        final renk = item['renk'] as Color;
        final isSelected = state.secilenKategori == ad;

        final gorunenAd = switch (ad) {
          'Gubre' => 'Gübre',
          'Ilac' => 'İlaç',
          'Iscilik' => 'İşçilik',
          'Hasat' => 'Hasat Satışı',
          'Destek' => 'Destekleme',
          'Diger' => 'Diğer',
          _ => ad,
        };

        return InkWell(
          onTap: () => notifier.kategoriSec(ad),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? renk : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? renk : (isDark ? const Color(0xFF2A3D36) : Colors.grey[300]!),
                width: isSelected ? 2.5 : 1.2,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: renk.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
                  : [const BoxShadow(color: Colors.black12, blurRadius: 3)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  gorunenAd,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Alt Kategori Çipleri ────────────────────────────────────────────────────
  Widget _buildAltKategoriCipleri(GiderGirisState state, GiderGirisNotifier notifier, bool isDark) {
    final altList = AppConstants.altKategorilerFor(state.secilenKategori!, state.islemTuru);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: altList.map((alt) {
        final isSelected = state.secilenAltKategori == alt;
        return ChoiceChip(
          label: Text(
            alt,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
          selected: isSelected,
          selectedColor: state.islemTuru == 'Gelir' ? AppTheme.primaryMint : AppTheme.dangerColor,
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (_) => notifier.altKategoriSec(alt),
        );
      }).toList(),
    );
  }

  // ── Dev Tutar Göstergesi & Hızlı Ekleme ───────────────────────────────────
  Widget _buildDevTutarPaneli(BuildContext context, GiderGirisState state, GiderGirisNotifier notifier, bool isDark) {
    final tutarRengi = state.islemTuru == 'Gelir' ? AppTheme.primaryMint : AppTheme.dangerColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1A16) : AppTheme.lightBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tutarRengi.withOpacity(0.5), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_tlFormat.format(state.tutar.round())} ₺',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: tutarRengi,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                if (state.tutar > 0)
                  TextButton(
                    onPressed: notifier.tutarSifirla,
                    child: const Text('Temizle', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildTusTakimi(notifier, isDark),
          const SizedBox(height: 14),

          // Hızlı ekleme: yuvarlak tutarlar için tek dokunuş.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: AppConstants.quickAddAmounts.map((miktar) {
              return SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => notifier.tutarEkle(miktar),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E2D27) : Colors.white,
                    foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    elevation: 1,
                    side: BorderSide(color: tutarRengi, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '+${miktar.toStringAsFixed(0)} ₺',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Büyük Tuşlu Sayı Tuş Takımı ─────────────────────────────────────────────
  Widget _buildTusTakimi(GiderGirisNotifier notifier, bool isDark) => TutarTusTakimi(
        onRakam: notifier.rakamEkle,
        onSil: notifier.haneSil,
        onTemizle: notifier.tutarSifirla,
      );

  // ── Tarih Seçimi ────────────────────────────────────────────────────────────
  Widget _buildTarihSecimi(BuildContext context, GiderGirisState state, GiderGirisNotifier notifier) {
    final bugun = DateUtils.dateOnly(DateTime.now());
    final dun = bugun.subtract(const Duration(days: 1));
    final secili = state.tarih ?? bugun;
    final baskaGun = !DateUtils.isSameDay(secili, bugun) && !DateUtils.isSameDay(secili, dun);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Bugün'),
          selected: DateUtils.isSameDay(secili, bugun),
          selectedColor: AppTheme.primaryMint,
          onSelected: (_) => notifier.tarihSec(bugun),
        ),
        ChoiceChip(
          label: const Text('Dün'),
          selected: DateUtils.isSameDay(secili, dun),
          selectedColor: AppTheme.primaryMint,
          onSelected: (_) => notifier.tarihSec(dun),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(baskaGun ? _gunMetni(secili) : 'Başka gün'),
          selected: baskaGun,
          selectedColor: AppTheme.primaryMint,
          onSelected: (_) async {
            final gun = await showDatePicker(
              context: context,
              initialDate: secili,
              firstDate: DateTime(bugun.year - 3),
              lastDate: bugun,
              helpText: 'İşlem tarihi',
            );
            if (gun != null) notifier.tarihSec(gun);
          },
        ),
      ],
    );
  }
}
