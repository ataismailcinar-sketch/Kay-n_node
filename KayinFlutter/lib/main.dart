import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/database_helper.dart';
import 'core/network/sunucu_adresi.dart';
import 'core/services/arka_plan_servisi.dart';
import 'core/services/bildirim_servisi.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/giris_ekrani.dart';
import 'features/auth/oturum.dart';
import 'features/akilli_sulama/presentation/screens/akilli_sulama_screen.dart';
import 'features/bildirimler/domain/bildirim.dart';
import 'features/bildirimler/presentation/bildirim_provider.dart';
import 'features/bildirimler/presentation/bildirimler_screen.dart';
import 'features/is_gunlugu/presentation/is_gunlugu_screen.dart';
import 'features/klavyesiz_muhasebe/presentation/screens/klavyesiz_muhasebe_screen.dart';
import 'features/parsel_harita/presentation/screens/parsel_listesi_screen.dart';
import 'features/sync/sync_provider.dart';
import 'features/yaprak_hastalik_ai/data/model_veri_lisanslari.dart';
import 'features/yaprak_hastalik_ai/presentation/screens/yaprak_hastalik_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize SQLite local database
  await DatabaseHelper().database;
  await SunucuAdresi.yukle();
  await BildirimServisi.baslat();
  await ArkaPlanServisi.baslat();
  ModelVeriLisanslari.kaydet();

  runApp(
    const ProviderScope(
      child: KayinTarimApp(),
    ),
  );
}

class KayinTarimApp extends ConsumerWidget {
  const KayinTarimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Kayın Tarım',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // Tarih seçici, saat seçici ve sistem metinleri (Kopyala/Yapıştır, İptal) Türkçe.
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const _OturumKapisi(),
    );
  }
}

/// Oturum yoksa giriş ekranı, varsa ana uygulama.
class _OturumKapisi extends ConsumerWidget {
  const _OturumKapisi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(oturumProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryMint))),
          error: (_, __) => const GirisEkrani(),
          data: (oturum) => oturum == null ? const GirisEkrani() : const AnaNavigasyonKabugu(),
        );
  }
}

/// Main Navigation Shell containing all 4 core features and background sync trigger
class AnaNavigasyonKabugu extends ConsumerStatefulWidget {
  const AnaNavigasyonKabugu({super.key});

  @override
  ConsumerState<AnaNavigasyonKabugu> createState() => _AnaNavigasyonKabuguState();
}

class _AnaNavigasyonKabuguState extends ConsumerState<AnaNavigasyonKabugu> with WidgetsBindingObserver {
  int _seciliIndeks = 0;
  StreamSubscription<void>? _bildirimDokunusu;
  DateTime _donTahminiZamani = DateTime.now();

  final List<Widget> _sayfalar = const [
    ParselListesiScreen(),
    AkilliSulamaScreen(),
    IsGunluguScreen(),
    KlavyesizMuhasebeScreen(),
    YaprakHastalikScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Start background Push & Pull sync timer automatically on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autoSyncProvider);
      BildirimServisi.izinIste();
      if (BildirimServisi.bildirimdenAcildi) {
        BildirimServisi.bildirimdenAcildi = false;
        BildirimlerScreen.ac(context);
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _bildirimDokunusu = BildirimServisi.dokunuldu.stream.listen((_) {
      if (mounted) BildirimlerScreen.ac(context);
    });
    // Uyarılar değiştikçe bildirim planı yeniden kurulur (veri yüklenmeden kurulmaz).
    ref.listenManual<List<Uyari>?>(tumUyarilarProvider, (_, uyarilar) {
      if (uyarilar != null) BildirimServisi.planla(uyarilar);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bildirimDokunusu?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulamaya geri dönülünce don tahmini en fazla saatte bir tazelenir.
    if (state == AppLifecycleState.resumed && DateTime.now().difference(_donTahminiZamani).inHours >= 1) {
      _donTahminiZamani = DateTime.now();
      ref.invalidate(donTahminleriProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _seciliIndeks,
        children: _sayfalar,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: NavigationBar(
          selectedIndex: _seciliIndeks,
          onDestinationSelected: (idx) => setState(() => _seciliIndeks = idx),
          height: 72,
          elevation: 10,
          backgroundColor: isDark ? const Color(0xFF16221E) : Colors.white,
          indicatorColor: AppTheme.primaryMint.withOpacity(0.25),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, size: 28),
              selectedIcon: Icon(Icons.map_rounded, size: 30, color: AppTheme.primaryMint),
              label: 'Parseller',
            ),
            NavigationDestination(
              icon: Icon(Icons.grass_outlined, size: 28),
              selectedIcon: Icon(Icons.grass_rounded, size: 30, color: AppTheme.primaryMint),
              label: 'İklim',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined, size: 28),
              selectedIcon: Icon(Icons.event_note_rounded, size: 30, color: AppTheme.primaryMint),
              label: 'Günlük',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 28),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, size: 30, color: Colors.amber),
              label: 'Muhasebe',
            ),
            NavigationDestination(
              icon: Icon(Icons.eco_outlined, size: 28),
              selectedIcon: Icon(Icons.eco_rounded, size: 30, color: Colors.purpleAccent),
              label: 'Hastalık',
            ),
          ],
        ),
      ),
    );
  }
}
