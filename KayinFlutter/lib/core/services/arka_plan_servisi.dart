import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../../features/bildirimler/data/uyari_kaynagi.dart';
import '../../features/bildirimler/domain/bildirim.dart';
import 'bildirim_servisi.dart';

const _donKontrolu = 'don-kontrolu';

/// Arka plan görevi giriş noktası (ayrı isolate'te çalışır; Riverpod ve arayüz yok).
@pragma('vm:entry-point')
void arkaPlanGorevi() {
  Workmanager().executeTask((gorev, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await BildirimServisi.baslat();
      final uyarilar = await tumUyarilariOku();
      await BildirimServisi.planla(uyarilar);
      debugPrint('Arka plan görevi ($gorev): ${uyarilar.length} uyarı, '
          '${uyarilar.where((u) => u.tur == UyariTuru.don).length} don.');
      return true;
    } catch (e) {
      debugPrint('Arka plan görevi ($gorev) başarısız: $e');
      return false; // WorkManager yeniden dener
    }
  });
}

/// Uygulama kapalıyken de birkaç saatte bir hava tahminini çekip don bildirimlerini yeniler.
/// Yalnız Android; Windows'ta uygulama açıkken yapılan kontrol yeterli.
class ArkaPlanServisi {
  /// Android periyodik görevleri en sık 15 dakikada bir çalıştırır; don için 4 saat yeterli
  /// (bildirim önceki akşam 18:00'de çıkar, tahmin gün içinde birkaç kez güncellenir).
  static const kontrolAraligi = Duration(hours: 4);

  static Future<void> baslat() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await Workmanager().initialize(arkaPlanGorevi);
      await Workmanager().registerPeriodicTask(
        _donKontrolu,
        _donKontrolu,
        frequency: kontrolAraligi,
        constraints: Constraints(networkType: NetworkType.connected),
        // Uygulama her açıldığında sayaç sıfırlanmasın.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );    } catch (e) {
      debugPrint('Arka plan görevi kaydedilemedi: $e');
    }
  }
}
