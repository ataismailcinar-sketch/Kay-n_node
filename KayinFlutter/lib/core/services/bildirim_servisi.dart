import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../features/bildirimler/domain/bildirim.dart';
import '../database/database_helper.dart';

/// Telefonun bildirim çubuğuna uyarı düşürür (Android, Windows).
///
/// Uygulama kapalıyken yeni hava tahmini çekilmez: don bildirimi, uygulamanın son açılışında
/// alınan tahmine göre önceden kurulur. Vade ve hatırlatma bildirimleri tarihleri belli olduğu için
/// tam zamanında çıkar.
class BildirimServisi {
  static final _eklenti = FlutterLocalNotificationsPlugin();
  static bool _hazir = false;

  /// Uygulama bir bildirime dokunularak açıldıysa true (Bildirimler ekranı açılır).
  static bool bildirimdenAcildi = false;

  /// Uygulama açıkken bildirime dokunulunca tetiklenir.
  static final dokunuldu = StreamController<void>.broadcast();

  static const _gosterilenAnahtari = 'bildirim_gosterilen';
  static const _enFazlaPlanli = 60;
  static Future<void> _sira = Future.value();

  static const _ayrinti = NotificationDetails(
    android: AndroidNotificationDetails(
      'uyarilar',
      'Uyarılar',
      channelDescription: 'Don, vade ve başvuru tarihi uyarıları',
      importance: Importance.high,
      priority: Priority.high,
      // Simge ve uygulama adı bildirimde uygulamanın yeşiliyle görünür.
      color: Color(0xFF10B981),
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  static Future<void> baslat() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isWindows)) return;
    try {
      tzdata.initializeTimeZones();
      // Uygulama Türkiye için; Türkiye 2016'dan beri yaz saati uygulamıyor (UTC+3).
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      await _eklenti.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_bildirim'),
          windows: WindowsInitializationSettings(
            appName: 'Kayın Tarım',
            appUserModelId: 'Kayin.KayinTarim',
            guid: '0ff5ead5-4b2f-4e61-b870-5d51ca339118',
          ),
        ),
        onDidReceiveNotificationResponse: (_) => dokunuldu.add(null),
      );
      final acilis = await _eklenti.getNotificationAppLaunchDetails();
      bildirimdenAcildi = acilis?.didNotificationLaunchApp ?? false;
      _hazir = true;
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
  }

  /// Android 13+ bildirim izni (ilk seferde sistem sorar).
  static Future<void> izinIste() async {
    if (!_hazir || !Platform.isAndroid) return;
    try {
      await _eklenti
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Planı baştan kurar: ileri tarihli uyarılar zamanlanır; zamanı geçmiş ama hiç gösterilmemiş
  /// olanlar (her konudan en sonuncusu) hemen bir kez gösterilir.
  static Future<void> planla(List<Uyari> tumu) {
    final simdi = DateTime.now();
    return _sira = _sira.then((_) => _planla(tumu, simdi)).catchError((Object e) {
      debugPrint('Bildirim planı kurulamadı: $e');
    });
  }

  static Future<void> _planla(List<Uyari> tumu, DateTime simdi) async {
    if (!_hazir) return;

    // Önceki zamanlanmışları kaldır (gösterilmiş olanlara dokunma).
    for (final p in await _eklenti.pendingNotificationRequests()) {
      await _eklenti.cancel(id: p.id);
    }

    final ileri = tumu.where((u) => u.bildirimZamani.isAfter(simdi)).toList()
      ..sort((a, b) => a.bildirimZamani.compareTo(b.bildirimZamani));
    for (final u in ileri.take(_enFazlaPlanli)) {
      try {
        await _eklenti.zonedSchedule(
          id: bildirimKimligi(u.anahtar),
          title: u.baslik,
          body: u.metin,
          scheduledDate: tz.TZDateTime.from(u.bildirimZamani, tz.local),
          notificationDetails: _ayrinti,
          // Gün düzeyinde uyarı; tam saat izni gerekmesin.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Zamanlanamadı (${u.anahtar}): $e');
      }
    }

    final kayit = await _kayitOku();
    final gosterilen = kayit.gosterilen;
    final damga = simdi.toIso8601String();

    // Önceki planda zamanlanıp o zamandan bu yana çıkmış bildirimleri sistem zaten gösterdi.
    final sonPlan = kayit.sonPlan;
    if (sonPlan != null) {
      for (final u in tumu) {
        if (u.bildirimZamani.isAfter(sonPlan) && !u.bildirimZamani.isAfter(simdi)) gosterilen[u.anahtar] = damga;
      }
    }

    for (final u in aktifUyarilar(tumu, simdi)) {
      if (u.bildirimZamani.isAfter(simdi) || gosterilen.containsKey(u.anahtar)) continue;
      await _eklenti.show(
        id: bildirimKimligi(u.anahtar),
        title: u.baslik,
        body: u.metin,
        notificationDetails: _ayrinti,
      );
      // Aynı konunun daha önceki uyarıları da artık gösterilmiş sayılır.
      for (final o in tumu.where((o) => o.grup == u.grup && !o.bildirimZamani.isAfter(simdi))) {
        gosterilen[o.anahtar] = damga;
      }
    }

    final esik = simdi.subtract(const Duration(days: 90));
    gosterilen.removeWhere((_, t) => DateTime.tryParse(t)?.isBefore(esik) ?? true);
    await _kayitYaz(simdi, gosterilen);
  }

  static Future<({DateTime? sonPlan, Map<String, String> gosterilen})> _kayitOku() async {
    try {
      final db = await DatabaseHelper().database;
      final r = await db.query('sync_meta', where: 'key = ?', whereArgs: [_gosterilenAnahtari]);
      if (r.isEmpty) return (sonPlan: null, gosterilen: <String, String>{});
      final j = jsonDecode(r.first['value'] as String) as Map<String, dynamic>;
      return (
        sonPlan: DateTime.tryParse(j['son'] as String? ?? ''),
        gosterilen: (j['g'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
      );
    } catch (_) {
      return (sonPlan: null, gosterilen: <String, String>{});
    }
  }

  static Future<void> _kayitYaz(DateTime simdi, Map<String, String> gosterilen) async {
    final db = await DatabaseHelper().database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)',
      [_gosterilenAnahtari, jsonEncode({'son': simdi.toIso8601String(), 'g': gosterilen})],
    );
  }
}
