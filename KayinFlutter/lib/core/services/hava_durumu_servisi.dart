import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../database/table_columns.dart';
import '../../features/parsel_harita/domain/entities/parsel_entity.dart';
import '../../features/toprak_analizi/data/toprak_analizi_model.dart';
import '../../features/toprak_analizi/domain/toprak_analizi.dart';

class GunlukHavaVerisi {
  final DateTime tarih;
  final double yagisMm;
  final double maxSicaklik;
  final double minSicaklik;
  final double maxRuzgarHizi;
  final double buharlasmaEt0;

  const GunlukHavaVerisi({
    required this.tarih,
    required this.yagisMm,
    required this.maxSicaklik,
    required this.minSicaklik,
    required this.maxRuzgarHizi,
    required this.buharlasmaEt0,
  });

  double get ortalamaSicaklik => (maxSicaklik + minSicaklik) / 2;

  Map<String, dynamic> toJson() => {
        't': _gun(tarih),
        'p': yagisMm,
        'tx': maxSicaklik,
        'tn': minSicaklik,
        'w': maxRuzgarHizi,
        'et': buharlasmaEt0,
      };

  static GunlukHavaVerisi fromJson(Map<String, dynamic> j) => GunlukHavaVerisi(
        tarih: DateTime.parse(j['t'] as String),
        yagisMm: (j['p'] as num).toDouble(),
        maxSicaklik: (j['tx'] as num).toDouble(),
        minSicaklik: (j['tn'] as num).toDouble(),
        maxRuzgarHizi: (j['w'] as num).toDouble(),
        buharlasmaEt0: (j['et'] as num).toDouble(),
      );
}

/// Saatlik tahmin (yerel saat) — ilaçlama penceresi hesabı için.
class SaatlikHava {
  final DateTime zaman;
  final double ruzgarKm;
  final double yagisMm;
  final double sicaklik;

  const SaatlikHava({
    required this.zaman,
    required this.ruzgarKm,
    required this.yagisMm,
    required this.sicaklik,
  });

  Map<String, dynamic> toJson() => {
        't': zaman.toIso8601String(),
        'w': ruzgarKm,
        'p': yagisMm,
        'c': sicaklik,
      };

  static SaatlikHava fromJson(Map<String, dynamic> j) => SaatlikHava(
        zaman: DateTime.parse(j['t'] as String),
        ruzgarKm: (j['w'] as num).toDouble(),
        yagisMm: (j['p'] as num).toDouble(),
        sicaklik: (j['c'] as num).toDouble(),
      );
}

/// Toprak türüne göre tarla kapasitesi (FC) ve solma noktası (WP), hacimsel m³/m³.
/// Tipik değerlerdir; tarlanın gerçek toprak analizi varsa o kullanılmalı.
class ToprakSuSabitleri {
  final double tarlaKapasitesi;
  final double solmaNoktasi;
  const ToprakSuSabitleri(this.tarlaKapasitesi, this.solmaNoktasi);

  static ToprakSuSabitleri icin(String toprakTuru) {
    final t = toprakTuru.toLowerCase();
    if (t.startsWith('kum')) return const ToprakSuSabitleri(0.15, 0.06);
    if (t.startsWith('kil')) return const ToprakSuSabitleri(0.38, 0.22);
    return const ToprakSuSabitleri(0.27, 0.12); // Tınlı / Kireçli
  }

  /// Tarlanın saturasyonu girilmiş en son toprak analizinden; yoksa toprak türünden.
  static Future<(ToprakSuSabitleri, bool analizden)> tarlaIcin(ParselEntity parsel) async {
    try {
      final db = await DatabaseHelper().database;
      final r = await db.query(
        DatabaseHelper.tableToprakAnalizi,
        where: 'parsel_id = ? AND is_deleted = 0 AND saturasyon IS NOT NULL',
        whereArgs: [parsel.id],
        orderBy: 'analiz_tarihi DESC',
        limit: 1,
      );
      if (r.isNotEmpty) {
        final s = analizdenSuSabitleri(ToprakAnaliziModel.fromRow(r.first));
        if (s != null) return (s, true);
      }
    } catch (_) {}
    return (icin(parsel.toprakTuru), false);
  }
}

class TarlaHavaOzeti {
  /// Ekimden bugüne ölçülmüş yağış. Ekim tarihi girilmemişse null.
  final double? ekimdenBuguneToplamYagisMm;

  /// Ekimden bu yana geçen gün. Ekim tarihi girilmemişse null.
  final int? ekimdenBeriGecenGun;

  /// Yağış toplamının kapsadığı gün sayısı (Open-Meteo en fazla 92 gün geriye gider).
  final int yagisKapsamaGunu;

  /// Kök bölgesindeki (≈0-27 cm) tahmini kullanılabilir su, % (0 = solma noktası,
  /// 100 = tarla kapasitesi). Veri yoksa null.
  final double? guncelToprakNemiYuzde;

  /// Toprak tarla kapasitesinin üzerinde (çamur / doygun).
  final bool toprakDoygun;

  /// Tarla kapasitesine kadar doldurmak için gereken su, ton/dönüm (m³/dönüm).
  final double? suAcigiTonDonum;

  /// Model toprak nemi (3-27 cm ortalaması), hacimsel m³/m³.
  final double? hacimselNem;

  final double bugunYagisMm;
  final double bugunMaxSicaklik;
  final double bugunMinSicaklik;
  final double bugunRuzgarHiziKm;
  final List<GunlukHavaVerisi> sonYediGun;
  final List<GunlukHavaVerisi> gelecekYediGunTahmin;

  /// Ekimden (veya kapsanan ilk günden) bugüne tüm geçmiş günler — ısıl gün hesabı için.
  final List<GunlukHavaVerisi> gecmisGunler;

  /// Şu andan itibaren ~48 saatlik saatlik tahmin. Eski önbellek kayıtlarında boş olabilir.
  final List<SaatlikHava> gelecekSaatler;

  /// false ise internet yok; gösterilen veri [veriZamani] tarihindeki son kayıttır.
  final bool canliVeri;
  final DateTime veriZamani;

  /// Su hesabı tarlanın toprak analizinden (saturasyon) yapıldıysa true; değilse toprak türünden.
  final bool toprakAnalizinden;

  TarlaHavaOzeti({
    this.toprakAnalizinden = false,
    this.ekimdenBuguneToplamYagisMm,
    this.ekimdenBeriGecenGun,
    this.yagisKapsamaGunu = 0,
    this.guncelToprakNemiYuzde,
    this.toprakDoygun = false,
    this.suAcigiTonDonum,
    this.hacimselNem,
    required this.bugunYagisMm,
    required this.bugunMaxSicaklik,
    required this.bugunMinSicaklik,
    required this.bugunRuzgarHiziKm,
    required this.sonYediGun,
    required this.gelecekYediGunTahmin,
    this.gecmisGunler = const [],
    this.gelecekSaatler = const [],
    this.canliVeri = true,
    DateTime? veriZamani,
  }) : veriZamani = veriZamani ?? DateTime.now();

  /// Yağış toplamı ekimden bugüne tüm dönemi kapsıyor mu?
  bool get yagisTamKapsam =>
      ekimdenBeriGecenGun != null && yagisKapsamaGunu >= ekimdenBeriGecenGun!;
}

/// Hava verisi alınamadığında (çevrimdışı ve daha önce kaydedilmiş veri yok).
class HavaVerisiYokHatasi implements Exception {
  final String mesaj;
  const HavaVerisiYokHatasi(this.mesaj);
  @override
  String toString() => mesaj;
}

/// Open-Meteo üzerinden tarlanın geçmiş/gelecek hava ve toprak nemi verisini çeken servis.
///
/// İlke: Veri yoksa UYDURULMAZ. İnternet yoksa son kaydedilen gerçek veri
/// (`canliVeri = false` ile) gösterilir; o da yoksa [HavaVerisiYokHatasi] fırlatılır.
class HavaDurumuServisi {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Aynı parsel için kısa sürede tekrar tekrar istek atılmasın.
  static const Duration _onbellekSuresi = Duration(minutes: 30);
  static final Map<String, (DateTime, TarlaHavaOzeti)> _onbellek = {};

  /// Kullanıcı "yenile" dediğinde önbelleği boşalt.
  static void onbellegiTemizle() => _onbellek.clear();

  static String _anahtar(ParselEntity p) =>
      '${p.id}|${p.merkezLat.toStringAsFixed(4)}|${p.merkezLng.toStringAsFixed(4)}|${p.ekimTarihi?.toIso8601String()}|${p.toprakTuru}';

  static Future<TarlaHavaOzeti> parselHavaDurumuGetir(ParselEntity parsel, {bool zorla = false}) async {
    if (parsel.merkezLat == 0 && parsel.merkezLng == 0) {
      throw const HavaVerisiYokHatasi('Tarlanın konumu yok; hava verisi için tarlayı haritada çizin.');
    }

    final toprak = await ToprakSuSabitleri.tarlaIcin(parsel);
    final anahtar = '${_anahtar(parsel)}|${toprak.$1.tarlaKapasitesi}|${toprak.$1.solmaNoktasi}';
    final kayitli = _onbellek[anahtar];
    if (!zorla && kayitli != null && DateTime.now().difference(kayitli.$1) < _onbellekSuresi) {
      return kayitli.$2;
    }

    try {
      final ozet = await _canliGetir(parsel, toprak);
      _onbellek[anahtar] = (DateTime.now(), ozet);
      await _gunlukKaydet(parsel, ozet);
      return ozet;
    } on DioException {
      final yerel = await _sonKayittanOku(parsel, toprak);
      if (yerel != null) return yerel;
      throw const HavaVerisiYokHatasi('İnternet yok ve bu tarla için kaydedilmiş hava verisi bulunmuyor.');
    }
  }

  static Future<TarlaHavaOzeti> _canliGetir(ParselEntity parsel, (ToprakSuSabitleri, bool) toprak) async {
    final now = DateTime.now();
    final bugun = DateTime(now.year, now.month, now.day);
    final ekim = parsel.ekimTarihi == null
        ? null
        : DateTime(parsel.ekimTarihi!.year, parsel.ekimTarihi!.month, parsel.ekimTarihi!.day);
    final gecenGun = ekim == null ? null : math.max(0, bugun.difference(ekim).inDays);
    final pastDays = (gecenGun ?? 14).clamp(14, 92);

    final response = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': parsel.merkezLat.toStringAsFixed(4),
        'longitude': parsel.merkezLng.toStringAsFixed(4),
        'daily': 'precipitation_sum,temperature_2m_max,temperature_2m_min,wind_speed_10m_max,et0_fao_evapotranspiration',
        'hourly': 'soil_moisture_3_to_9cm,soil_moisture_9_to_27cm,temperature_2m,precipitation,wind_speed_10m',
        'timezone': 'auto',
        'past_days': pastDays,
        'forecast_days': 7,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>?;
    if (daily == null) throw const HavaVerisiYokHatasi('Hava servisi günlük veri döndürmedi.');

    List<double?> seri(String k) =>
        (daily[k] as List<dynamic>? ?? const []).map((e) => (e as num?)?.toDouble()).toList();
    final times = (daily['time'] as List<dynamic>? ?? const []).cast<String>();
    final p = seri('precipitation_sum');
    final tx = seri('temperature_2m_max');
    final tn = seri('temperature_2m_min');
    final w = seri('wind_speed_10m_max');
    final et = seri('et0_fao_evapotranspiration');

    final gunler = <GunlukHavaVerisi>[];
    for (var i = 0; i < times.length; i++) {
      // Eksik günü uydurmak yerine atla.
      if (i >= tx.length || tx[i] == null || tn[i] == null) continue;
      gunler.add(GunlukHavaVerisi(
        tarih: DateTime.parse(times[i]),
        yagisMm: p.elementAtOrNull(i) ?? 0.0,
        maxSicaklik: tx[i]!,
        minSicaklik: tn[i]!,
        maxRuzgarHizi: w.elementAtOrNull(i) ?? 0.0,
        buharlasmaEt0: et.elementAtOrNull(i) ?? 0.0,
      ));
    }

    final hourly = data['hourly'] as Map<String, dynamic>?;
    final nem = _toprakNemi(hourly, now);
    return _ozetOlustur(
      parsel: parsel,
      gunler: gunler,
      hacimselNem: nem,
      saatler: _saatlikTahmin(hourly, now),
      canli: true,
      zaman: now,
      toprak: toprak,
    );
  }

  /// Şu anki saatten başlayarak 48 saatlik rüzgar/yağış/sıcaklık. Eksik saat atlanır.
  static List<SaatlikHava> _saatlikTahmin(Map<String, dynamic>? hourly, DateTime now) {
    if (hourly == null) return const [];
    final times = (hourly['time'] as List<dynamic>? ?? const []).cast<String>();
    double? deger(String k, int i) => ((hourly[k] as List<dynamic>?)?.elementAtOrNull(i) as num?)?.toDouble();
    final baslangic = DateTime(now.year, now.month, now.day, now.hour);
    final sonuc = <SaatlikHava>[];
    for (var i = 0; i < times.length && sonuc.length < 48; i++) {
      final t = DateTime.tryParse(times[i]);
      if (t == null || t.isBefore(baslangic)) continue;
      final w = deger('wind_speed_10m', i);
      final c = deger('temperature_2m', i);
      if (w == null || c == null) continue;
      sonuc.add(SaatlikHava(zaman: t, ruzgarKm: w, yagisMm: deger('precipitation', i) ?? 0.0, sicaklik: c));
    }
    return sonuc;
  }

  /// Saatlik toprak nemi serisinden şu ana en yakın geçerli değer (3-27 cm ortalaması), m³/m³.
  static double? _toprakNemi(Map<String, dynamic>? hourly, DateTime now) {
    if (hourly == null) return null;
    final times = (hourly['time'] as List<dynamic>? ?? const []).cast<String>();
    final a = (hourly['soil_moisture_3_to_9cm'] as List<dynamic>? ?? const []);
    final b = (hourly['soil_moisture_9_to_27cm'] as List<dynamic>? ?? const []);
    double? sonuc;
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.tryParse(times[i]);
      if (t == null || t.isAfter(now)) break;
      final va = (a.elementAtOrNull(i) as num?)?.toDouble();
      final vb = (b.elementAtOrNull(i) as num?)?.toDouble();
      if (va != null && vb != null) {
        sonuc = (va + vb) / 2;
      } else if (va != null || vb != null) {
        sonuc = va ?? vb;
      }
    }
    return sonuc;
  }

  static TarlaHavaOzeti _ozetOlustur({
    required ParselEntity parsel,
    required List<GunlukHavaVerisi> gunler,
    required double? hacimselNem,
    List<SaatlikHava> saatler = const [],
    required bool canli,
    required DateTime zaman,
    required (ToprakSuSabitleri, bool) toprak,
  }) {
    final now = DateTime.now();
    final buSaat = DateTime(now.year, now.month, now.day, now.hour);
    final bugunTarih = DateTime(now.year, now.month, now.day);
    final gecmis = gunler.where((g) => g.tarih.isBefore(bugunTarih)).toList();
    final bugunVeSonrasi = gunler.where((g) => !g.tarih.isBefore(bugunTarih)).toList();
    final bugun = bugunVeSonrasi.isNotEmpty ? bugunVeSonrasi.first : (gunler.isNotEmpty ? gunler.last : null);
    if (bugun == null) throw const HavaVerisiYokHatasi('Hava verisi boş.');

    // Ekimden bugüne ölçülmüş yağış (yalnızca gerçekten elimizde olan günler).
    final ekim = parsel.ekimTarihi == null
        ? null
        : DateTime(parsel.ekimTarihi!.year, parsel.ekimTarihi!.month, parsel.ekimTarihi!.day);
    final gecenGun = ekim == null ? null : math.max(0, bugunTarih.difference(ekim).inDays);
    final ekimSonrasi = ekim == null ? gecmis : gecmis.where((g) => !g.tarih.isBefore(ekim)).toList();
    final ekimdenYagis = ekim == null ? null : ekimSonrasi.fold<double>(0, (s, g) => s + g.yagisMm);

    // Kullanılabilir su (%), su açığı (ton/dönüm ≈ m³/dönüm, 30 cm kök bölgesi).
    double? kullanilabilir;
    double? acik;
    var doygun = false;
    if (hacimselNem != null) {
      final s = toprak.$1;
      kullanilabilir = ((hacimselNem - s.solmaNoktasi) / (s.tarlaKapasitesi - s.solmaNoktasi) * 100).clamp(0.0, 100.0);
      doygun = hacimselNem > s.tarlaKapasitesi * 1.05;
      acik = math.max(0.0, (s.tarlaKapasitesi - hacimselNem) * 0.30 * 1000);
    }

    return TarlaHavaOzeti(
      ekimdenBuguneToplamYagisMm: ekimdenYagis == null ? null : double.parse(ekimdenYagis.toStringAsFixed(1)),
      ekimdenBeriGecenGun: gecenGun,
      yagisKapsamaGunu: ekimSonrasi.length,
      guncelToprakNemiYuzde: kullanilabilir == null ? null : double.parse(kullanilabilir.toStringAsFixed(1)),
      toprakDoygun: doygun,
      suAcigiTonDonum: acik == null ? null : double.parse(acik.toStringAsFixed(0)),
      hacimselNem: hacimselNem,
      bugunYagisMm: bugun.yagisMm,
      bugunMaxSicaklik: bugun.maxSicaklik,
      bugunMinSicaklik: bugun.minSicaklik,
      bugunRuzgarHiziKm: bugun.maxRuzgarHizi,
      sonYediGun: gecmis.length > 7 ? gecmis.sublist(gecmis.length - 7) : gecmis,
      gelecekYediGunTahmin: bugunVeSonrasi.take(7).toList(),
      gecmisGunler: ekimSonrasi,
      // Çevrimdışı önbellekten okunurken geçmiş saatler elenir.
      gelecekSaatler: saatler.where((s) => !s.zaman.isBefore(buSaat)).toList(),
      canliVeri: canli,
      veriZamani: zaman,
      toprakAnalizinden: toprak.$2,
    );
  }

  /// Her parsel için günde TEK kayıt tutulur (id parsel+gün'den türetilir).
  /// Eskiden her açılışta yeni satır ekleniyordu.
  static Future<void> _gunlukKaydet(ParselEntity parsel, TarlaHavaOzeti ozet) async {
    try {
      final now = DateTime.now().toUtc();
      final gun = _gun(DateTime.now());
      final id = const Uuid().v5(Uuid.NAMESPACE_URL, 'kayin:hava:${parsel.id}:$gun');
      final nem = ozet.guncelToprakNemiYuzde;
      final aciliyet = nem == null ? 'Bilinmiyor' : (nem < 30 ? 'Acil' : (nem < 50 ? 'Normal' : 'Yeterli'));

      // Ham yanıt yerine yalnızca günlük özet saklanır (sunucuya da bu gider).
      final ozJson = jsonEncode({
        'surum': 2,
        'gunler': [...ozet.gecmisGunler, ...ozet.gelecekYediGunTahmin].map((g) => g.toJson()).toList(),
        'saatler': ozet.gelecekSaatler.map((s) => s.toJson()).toList(),
        'hacimselNem': ozet.hacimselNem,
        'kullanilabilirSu': ozet.guncelToprakNemiYuzde,
        'alinma': now.toIso8601String(),
      });

      final db = await DatabaseHelper().database;
      final mevcut = await db.query(DatabaseHelper.tableYagisSulama, columns: ['created_at_utc'], where: 'id = ?', whereArgs: [id]);
      await DatabaseHelper().upsert(DatabaseHelper.tableYagisSulama, {
        TableColumns.id: id,
        TableColumns.sulamaParselId: parsel.id,
        TableColumns.sulamaKayitTarihi: now.toIso8601String(),
        TableColumns.sulamaYagisMm: ozet.bugunYagisMm,
        TableColumns.sulamaToprakNemi: nem ?? -1,
        TableColumns.sulamaKayitTuru: 'Otomatik',
        TableColumns.sulamaManuelLitre: 0.0,
        TableColumns.sulamaAciliyetSeviyesi: aciliyet,
        TableColumns.sulamaHavaApiJson: ozJson,
        TableColumns.createdAtUtc: mevcut.isEmpty ? now.toIso8601String() : mevcut.first['created_at_utc'],
        TableColumns.lastModifiedUtc: now.toIso8601String(),
        TableColumns.isDeleted: 0,
        TableColumns.isSynced: 0,
      });
    } catch (_) {
      // Kayıt başarısız olsa da ekrandaki canlı veri etkilenmesin.
    }
  }

  /// Çevrimdışıyken bu parselin son kaydedilmiş gerçek verisinden özet üretir.
  static Future<TarlaHavaOzeti?> _sonKayittanOku(ParselEntity parsel, (ToprakSuSabitleri, bool) toprak) async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        DatabaseHelper.tableYagisSulama,
        where: 'parsel_id = ? AND is_deleted = 0 AND kayit_turu = ?',
        whereArgs: [parsel.id, 'Otomatik'],
        orderBy: 'kayit_tarihi DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final j = jsonDecode(rows.first[TableColumns.sulamaHavaApiJson] as String? ?? '{}') as Map<String, dynamic>;
      if (j['surum'] != 2) return null; // eski biçim (ham yanıt) — güvenilir şekilde okunamaz
      final gunler = (j['gunler'] as List<dynamic>).map((e) => GunlukHavaVerisi.fromJson(e as Map<String, dynamic>)).toList();
      final hacimsel = (j['hacimselNem'] as num?)?.toDouble();
      final saatler = (j['saatler'] as List<dynamic>? ?? const [])
          .map((e) => SaatlikHava.fromJson(e as Map<String, dynamic>))
          .toList();
      return _ozetOlustur(
        parsel: parsel,
        gunler: gunler,
        hacimselNem: hacimsel,
        saatler: saatler,
        canli: false,
        zaman: DateTime.parse(j['alinma'] as String).toLocal(),
        toprak: toprak,
      );
    } catch (_) {
      return null;
    }
  }
}

String _gun(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
