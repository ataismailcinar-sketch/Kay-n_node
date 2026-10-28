import '../domain/toprak_analizi.dart';

class ToprakAnaliziModel {
  /// Gün 'yyyy-MM-dd' olarak saklanır (saat dilimi kaymasın).
  static String gunYaz(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static DateTime gunOku(String s) {
    final t = DateTime.parse(s);
    return DateTime(t.year, t.month, t.day);
  }

  static double? _d(Object? v) => (v as num?)?.toDouble();

  static ToprakAnaliziEntity fromRow(Map<String, dynamic> r) => ToprakAnaliziEntity(
        id: r['id'] as String,
        parselId: r['parsel_id'] as String,
        analizTarihi: gunOku(r['analiz_tarihi'] as String),
        laboratuvar: r['laboratuvar'] as String? ?? '',
        saturasyon: _d(r['saturasyon']),
        ph: _d(r['ph']),
        tuzYuzde: _d(r['tuz_yuzde']),
        ec: _d(r['ec']),
        kirecYuzde: _d(r['kirec_yuzde']),
        organikMadde: _d(r['organik_madde']),
        fosfor: _d(r['fosfor']),
        potasyum: _d(r['potasyum']),
        cinko: _d(r['cinko']),
        not: r['not_metni'] as String? ?? '',
        createdAtUtc: DateTime.parse(r['created_at_utc'] as String),
        lastModifiedUtc: DateTime.parse(r['last_modified_utc'] as String),
        isDeleted: r['is_deleted'] == 1,
        isSynced: r['is_synced'] == 1,
      );

  static Map<String, dynamic> toRow(ToprakAnaliziEntity e) => {
        'id': e.id,
        'parsel_id': e.parselId,
        'analiz_tarihi': gunYaz(e.analizTarihi),
        'laboratuvar': e.laboratuvar,
        'saturasyon': e.saturasyon,
        'ph': e.ph,
        'tuz_yuzde': e.tuzYuzde,
        'ec': e.ec,
        'kirec_yuzde': e.kirecYuzde,
        'organik_madde': e.organikMadde,
        'fosfor': e.fosfor,
        'potasyum': e.potasyum,
        'cinko': e.cinko,
        'not_metni': e.not,
        'created_at_utc': e.createdAtUtc.toUtc().toIso8601String(),
        'last_modified_utc': e.lastModifiedUtc.toUtc().toIso8601String(),
        'is_deleted': e.isDeleted ? 1 : 0,
        'is_synced': e.isSynced ? 1 : 0,
      };
}
