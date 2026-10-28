import 'dart:convert';
import '../../../core/database/database_helper.dart';
import '../domain/bildirim.dart';

/// Hangi uyarı türlerinin açık olduğu. Cihaza özeldir (sunucuya gitmez); varsayılan hepsi açık.
class BildirimAyarlari {
  static const _anahtar = 'bildirim_ayarlari';

  final Set<UyariTuru> kapali;
  const BildirimAyarlari({this.kapali = const {}});

  bool acik(UyariTuru t) => !kapali.contains(t);

  BildirimAyarlari degistir(UyariTuru t, bool acik) =>
      BildirimAyarlari(kapali: acik ? ({...kapali}..remove(t)) : {...kapali, t});

  /// Kapalı türlerin uyarılarını çıkarır.
  List<Uyari> suz(List<Uyari> uyarilar) =>
      kapali.isEmpty ? uyarilar : uyarilar.where((u) => acik(u.tur)).toList();

  String kodla() => jsonEncode({'kapali': kapali.map((t) => t.name).toList()});

  static BildirimAyarlari coz(String? json) {
    if (json == null) return const BildirimAyarlari();
    try {
      final adlar = ((jsonDecode(json) as Map<String, dynamic>)['kapali'] as List<dynamic>).cast<String>();
      return BildirimAyarlari(kapali: UyariTuru.values.where((t) => adlar.contains(t.name)).toSet());
    } catch (_) {
      return const BildirimAyarlari();
    }
  }

  static Future<BildirimAyarlari> oku() async {
    try {
      final db = await DatabaseHelper().database;
      final r = await db.query('sync_meta', where: 'key = ?', whereArgs: [_anahtar]);
      return coz(r.isEmpty ? null : r.first['value'] as String);
    } catch (_) {
      return const BildirimAyarlari();
    }
  }

  Future<void> yaz() async {
    final db = await DatabaseHelper().database;
    await db.rawInsert('INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)', [_anahtar, kodla()]);
  }
}
