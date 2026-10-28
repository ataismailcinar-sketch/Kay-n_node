import 'dart:convert';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';

/// Bir konumun son 12 aylık gerçek (ölçülmüş/yeniden analiz) iklim özeti.
class IklimOzeti {
  /// Günlük ortalaması 5°C üzerindeki günlerin ortalama sıcaklığı (vejetasyon dönemi).
  final double vejetasyonOrtSicaklik;

  /// Yılın en sıcak 120 gününün ortalaması — yazlık (dona dayanıksız) ürünlerin
  /// yetiştiği dönemi temsil eder.
  final double sicakDonemOrtSicaklik;
  final double yillikYagisMm;
  final double mutlakMinSicaklik;
  final double mutlakMaxSicaklik;
  final DateTime baslangic;
  final DateTime bitis;

  const IklimOzeti({
    required this.vejetasyonOrtSicaklik,
    required this.sicakDonemOrtSicaklik,
    required this.yillikYagisMm,
    required this.mutlakMinSicaklik,
    required this.mutlakMaxSicaklik,
    required this.baslangic,
    required this.bitis,
  });

  Map<String, dynamic> toJson() => {
        'v': vejetasyonOrtSicaklik,
        'y': sicakDonemOrtSicaklik,
        'p': yillikYagisMm,
        'tn': mutlakMinSicaklik,
        'tx': mutlakMaxSicaklik,
        'b': baslangic.toIso8601String(),
        'e': bitis.toIso8601String(),
      };

  static IklimOzeti fromJson(Map<String, dynamic> j) => IklimOzeti(
        vejetasyonOrtSicaklik: (j['v'] as num).toDouble(),
        sicakDonemOrtSicaklik: (j['y'] as num).toDouble(),
        yillikYagisMm: (j['p'] as num).toDouble(),
        mutlakMinSicaklik: (j['tn'] as num).toDouble(),
        mutlakMaxSicaklik: (j['tx'] as num).toDouble(),
        baslangic: DateTime.parse(j['b'] as String),
        bitis: DateTime.parse(j['e'] as String),
      );
}

/// Open-Meteo Historical Weather (ERA5) API'sinden son 365 günü çekip özetler.
/// Sonuç cihazda saklanır (iklim bir yılda değişmez; 30 günde bir yenilenir).
class IklimServisi {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static String _anahtar(double lat, double lng) => 'iklim:${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  static Future<IklimOzeti> getir(double lat, double lng) async {
    final db = await DatabaseHelper().database;
    final anahtar = _anahtar(lat, lng);

    IklimOzeti? kayitli;
    DateTime? kayitZamani;
    try {
      final rows = await db.query('sync_meta', where: 'key = ?', whereArgs: [anahtar]);
      if (rows.isNotEmpty) {
        final j = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
        kayitli = IklimOzeti.fromJson(j['ozet'] as Map<String, dynamic>);
        kayitZamani = DateTime.parse(j['alinma'] as String);
      }
    } catch (_) {}

    if (kayitli != null && kayitZamani != null && DateTime.now().difference(kayitZamani).inDays < 30) {
      return kayitli;
    }

    try {
      final ozet = await _canliGetir(lat, lng);
      await db.rawInsert(
        'INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)',
        [anahtar, jsonEncode({'ozet': ozet.toJson(), 'alinma': DateTime.now().toIso8601String()})],
      );
      return ozet;
    } catch (e) {
      if (kayitli != null) return kayitli; // eski ama gerçek veri
      rethrow;
    }
  }

  static Future<IklimOzeti> _canliGetir(double lat, double lng) async {
    // ERA5 verisi ~5 gün gecikmeli yayınlanır.
    final bitis = DateTime.now().subtract(const Duration(days: 7));
    final baslangic = bitis.subtract(const Duration(days: 364));
    String g(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final r = await _dio.get(
      'https://archive-api.open-meteo.com/v1/archive',
      queryParameters: {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'start_date': g(baslangic),
        'end_date': g(bitis),
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum',
        'timezone': 'auto',
      },
    );

    final daily = (r.data as Map<String, dynamic>)['daily'] as Map<String, dynamic>;
    List<double?> seri(String k) => (daily[k] as List<dynamic>).map((e) => (e as num?)?.toDouble()).toList();
    final tx = seri('temperature_2m_max');
    final tn = seri('temperature_2m_min');
    final p = seri('precipitation_sum');

    final ortalamalar = <double>[];
    var mn = double.infinity;
    var mx = -double.infinity;
    var yagis = 0.0;
    var gecerliGun = 0;
    for (var i = 0; i < tx.length; i++) {
      final a = tx[i];
      final b = tn.elementAtOrNull(i);
      if (a == null || b == null) continue;
      gecerliGun++;
      ortalamalar.add((a + b) / 2);
      if (b < mn) mn = b;
      if (a > mx) mx = a;
      yagis += p.elementAtOrNull(i) ?? 0;
    }
    if (gecerliGun < 300) {
      throw StateError('İklim verisi eksik ($gecerliGun gün).');
    }
    final vej = ortalamalar.where((t) => t > 5).toList();
    final vejOrt = vej.isEmpty ? 0.0 : vej.reduce((a, b) => a + b) / vej.length;
    final sicak = ([...ortalamalar]..sort((a, b) => b.compareTo(a))).take(120).toList();
    final sicakOrt = sicak.reduce((a, b) => a + b) / sicak.length;

    return IklimOzeti(
      vejetasyonOrtSicaklik: double.parse(vejOrt.toStringAsFixed(1)),
      sicakDonemOrtSicaklik: double.parse(sicakOrt.toStringAsFixed(1)),
      yillikYagisMm: double.parse((yagis * 365 / gecerliGun).toStringAsFixed(0)),
      mutlakMinSicaklik: mn,
      mutlakMaxSicaklik: mx,
      baslangic: baslangic,
      bitis: bitis,
    );
  }
}
