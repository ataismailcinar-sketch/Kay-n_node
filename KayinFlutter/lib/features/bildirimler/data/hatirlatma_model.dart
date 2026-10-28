import '../domain/bildirim.dart';

class HatirlatmaModel {
  /// Gün 'yyyy-MM-dd' olarak saklanır (saat dilimi kaymasın).
  static String gunYaz(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static DateTime gunOku(String s) {
    final t = DateTime.parse(s);
    return DateTime(t.year, t.month, t.day);
  }

  static HatirlatmaEntity fromRow(Map<String, dynamic> r) => HatirlatmaEntity(
        id: r['id'] as String,
        baslik: r['baslik'] as String? ?? '',
        tur: HatirlatmaTuru.koddan(r['tur'] as String? ?? 'Diger'),
        tarih: gunOku(r['tarih'] as String),
        kacGunOnce: (r['kac_gun_once'] as num?)?.toInt() ?? 7,
        herYil: r['her_yil'] == 1,
        tamamlandi: r['tamamlandi'] == 1,
        not: r['not_metni'] as String? ?? '',
        createdAtUtc: DateTime.parse(r['created_at_utc'] as String),
        lastModifiedUtc: DateTime.parse(r['last_modified_utc'] as String),
        isDeleted: r['is_deleted'] == 1,
        isSynced: r['is_synced'] == 1,
      );

  static Map<String, dynamic> toRow(HatirlatmaEntity e) => {
        'id': e.id,
        'baslik': e.baslik,
        'tur': e.tur.kod,
        'tarih': gunYaz(e.tarih),
        'kac_gun_once': e.kacGunOnce,
        'her_yil': e.herYil ? 1 : 0,
        'tamamlandi': e.tamamlandi ? 1 : 0,
        'not_metni': e.not,
        'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
        'last_modified_utc': e.lastModifiedUtc.toUtc().toIso8601String(),
        'is_deleted': e.isDeleted ? 1 : 0,
        'is_synced': e.isSynced ? 1 : 0,
      };
}
