import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/table_columns.dart';
import '../../core/network/api_client.dart';
import '../../core/services/fotograf_meta_temizleyici.dart';

/// Senkronizasyon durumu
enum SyncStatus { idle, syncing, success, error, offline }

/// Tek bir sync döngüsünün sonuç raporu
class SyncResult {
  final SyncStatus status;
  final int pushedCount;
  final int pulledCount;
  final String? errorMessage;
  final DateTime timestamp;

  const SyncResult({
    required this.status,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.errorMessage,
    required this.timestamp,
  });

  @override
  String toString() =>
      'SyncResult(status: $status, pushed: $pushedCount, pulled: $pulledCount)';
}

/// ════════════════════════════════════════════════════════════════════════════
/// SyncManager — Offline-First senkronizasyon motoru
///
/// Akış:
///   1. İnternet var mı? → Yoksa dur (offline mod).
///   2. PUSH: Her tablodan IsSynced=0 kayıtları çek → /api/sync/push → sunucuya gönder.
///   3. Push yanıtındaki AcceptedIds'leri is_synced=1 yap.
///   4. PULL: Son sync zamanını al → /api/sync/pull?sinceUtc=... → delta al.
///   5. Pull gelen kayıtları SQLite'a Upsert et (is_synced=1 olarak).
///   6. Son sync zamanını SharedPreferences'e kaydet.
/// ════════════════════════════════════════════════════════════════════════════
class SyncManager {
  final DatabaseHelper _db;
  final Dio _dio;

  static const String _lastSyncKey = 'last_sync_utc';

  /// Sunucu bir kaydı reddettiyse (sunucudaki sürüm daha yeni) o sürümü
  /// indirebilmek için bu turda tam pull yapılır.
  bool _tamPullGerekli = false;

  SyncManager({
    DatabaseHelper? db,
    Dio? dio,
  })  : _db = db ?? DatabaseHelper(),
        _dio = dio ?? ApiClient().dio;

  // ── Ana Sync Döngüsü ────────────────────────────────────────────────────

  /// Tam bir Push → Pull döngüsü çalıştırır.
  /// İnternet yoksa SyncResult(offline) döner, exception fırlatmaz.
  Future<SyncResult> syncAll() async {
    // 0. Giriş yoksa sunucuya gidilmez (çıkıştan sonra zamanlayıcı çalışmaya devam edebilir).
    if (ApiClient().token == null) {
      return SyncResult(
        status: SyncStatus.offline,
        errorMessage: 'Giriş yapılmadı',
        timestamp: DateTime.now(),
      );
    }

    // 1. Bağlantı kontrolü
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) ||
        connectivity.isEmpty) {
      return SyncResult(
        status: SyncStatus.offline,
        timestamp: DateTime.now(),
      );
    }

    try {
      // 2. Push
      final pushResult = await _push();

      // 3. Pull
      final pullCount = await _pull();

      // 4. Fotoğraflar (kayıt sunucuya gittikten sonra ayrı istekle)
      await fotograflariYukle();

      return SyncResult(
        status: SyncStatus.success,
        pushedCount: pushResult,
        pulledCount: pullCount,
        timestamp: DateTime.now(),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown) {
        return SyncResult(
          status: SyncStatus.offline,
          errorMessage: 'Sunucu kapalı / Yerel mod',
          timestamp: DateTime.now(),
        );
      }
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.response?.statusCode == 401
            ? 'Oturum süresi doldu, tekrar giriş yapın.'
            : (e.message ?? 'HTTP hatası'),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  // ── PUSH ────────────────────────────────────────────────────────────────

  /// IsSynced=0 olan tüm kayıtları sunucuya gönderir.
  /// Başarılı olanları IsSynced=1 yapar.
  /// Returns: Toplam push edilen kayıt sayısı.
  Future<int> _push() async {
    // Tüm tablolardan senkronize edilmemiş kayıtları çek
    final parseller     = await _db.getUnsyncedRecords(DatabaseHelper.tableParseller);
    final sulamalar     = await _db.getUnsyncedRecords(DatabaseHelper.tableYagisSulama);
    final giderler      = await _db.getUnsyncedRecords(DatabaseHelper.tableMuhasebeGider);
    final taramalar     = await _db.getUnsyncedRecords(DatabaseHelper.tableHastalikTarama);
    final isKayitlari   = await _db.getUnsyncedRecords(DatabaseHelper.tableIsKaydi);
    final cariler       = await _db.getUnsyncedRecords(DatabaseHelper.tableCari);
    final hareketler    = await _db.getUnsyncedRecords(DatabaseHelper.tableCariHareket);
    final stokKalemleri = await _db.getUnsyncedRecords(DatabaseHelper.tableStokKalemi);
    final stokHareket   = await _db.getUnsyncedRecords(DatabaseHelper.tableStokHareketi);
    final hatirlatmalar = await _db.getUnsyncedRecords(DatabaseHelper.tableHatirlatma);
    final toprakAnaliz  = await _db.getUnsyncedRecords(DatabaseHelper.tableToprakAnalizi);

    final totalCount = parseller.length + sulamalar.length + giderler.length + taramalar.length +
                       isKayitlari.length + cariler.length + hareketler.length +
                       stokKalemleri.length + stokHareket.length + hatirlatmalar.length +
                       toprakAnaliz.length;

    if (totalCount == 0) return 0; // Gönderilecek bir şey yok

    // Batch'lere böl ve her batch için ayrı istek at
    int pushed = 0;

    // Parseller batch push
    if (parseller.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableParseller,
        records: parseller,
        jsonKey: 'parseller',
        mapRow: _rowToParselDto,
      );
    }

    // YagisSulama batch push
    if (sulamalar.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableYagisSulama,
        records: sulamalar,
        jsonKey: 'yagisSulamaKayitlari',
        mapRow: _rowToYagisSulamaDto,
      );
    }

    // MuhasebeGider batch push
    if (giderler.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableMuhasebeGider,
        records: giderler,
        jsonKey: 'muhasebeGiderler',
        mapRow: _rowToGiderDto,
      );
    }

    // HastalikTarama batch push
    if (taramalar.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableHastalikTarama,
        records: taramalar,
        jsonKey: 'hastalikTaramalar',
        mapRow: _rowToTaramaDto,
      );
    }

    // İş günlüğü batch push
    if (isKayitlari.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableIsKaydi,
        records: isKayitlari,
        jsonKey: 'isKayitlari',
        mapRow: _rowToIsKaydiDto,
      );
    }

    // Veresiye: hesaplar hareketlerden önce (sunucu hareketin hesabını tanısın)
    if (cariler.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableCari,
        records: cariler,
        jsonKey: 'cariler',
        mapRow: _rowToCariDto,
      );
    }
    if (hareketler.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableCariHareket,
        records: hareketler,
        jsonKey: 'cariHareketleri',
        mapRow: _rowToCariHareketDto,
      );
    }

    // Depo: kalemler hareketlerden önce
    if (stokKalemleri.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableStokKalemi,
        records: stokKalemleri,
        jsonKey: 'stokKalemleri',
        mapRow: _rowToStokKalemiDto,
      );
    }
    if (stokHareket.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableStokHareketi,
        records: stokHareket,
        jsonKey: 'stokHareketleri',
        mapRow: _rowToStokHareketiDto,
      );
    }

    if (hatirlatmalar.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableHatirlatma,
        records: hatirlatmalar,
        jsonKey: 'hatirlatmalar',
        mapRow: _rowToHatirlatmaDto,
      );
    }

    // Toprak analizleri parsele bağlı: parseller yukarıda gönderildi.
    if (toprakAnaliz.isNotEmpty) {
      pushed += await _pushBatch(
        table: DatabaseHelper.tableToprakAnalizi,
        records: toprakAnaliz,
        jsonKey: 'toprakAnalizleri',
        mapRow: _rowToToprakAnaliziDto,
      );
    }

    return pushed;
  }

  /// Tek bir tablo için batch push işlemi.
  Future<int> _pushBatch({
    required String table,
    required List<Map<String, dynamic>> records,
    required String jsonKey,
    required Map<String, dynamic> Function(Map<String, dynamic>) mapRow,
  }) async {
    // AppConstants.syncBatchSize kadar parçalara böl
    int totalPushed = 0;

    for (int i = 0; i < records.length; i += AppConstants.syncBatchSize) {
      final batch = records.skip(i).take(AppConstants.syncBatchSize).toList();

      // Body'yi oluştur — yalnızca ilgili tablonun key'ini dolu gönder, diğerleri boş
      final body = {
        'parseller': <Map<String, dynamic>>[],
        'yagisSulamaKayitlari': <Map<String, dynamic>>[],
        'muhasebeGiderler': <Map<String, dynamic>>[],
        'hastalikTaramalar': <Map<String, dynamic>>[],
        'isKayitlari': <Map<String, dynamic>>[],
        'cariler': <Map<String, dynamic>>[],
        'cariHareketleri': <Map<String, dynamic>>[],
        'stokKalemleri': <Map<String, dynamic>>[],
        'stokHareketleri': <Map<String, dynamic>>[],
        'hatirlatmalar': <Map<String, dynamic>>[],
        'toprakAnalizleri': <Map<String, dynamic>>[],
        jsonKey: batch.map(mapRow).toList(),
      };

      final response = await _dio.post('/sync/push', data: body);

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        List<String> idListesi(String key) =>
            (data[key] as List<dynamic>? ?? const []).map((e) => e.toString().toLowerCase()).toList();

        final acceptedIds = idListesi('acceptedIds');
        final rejectedIds = idListesi('rejectedIds');

        // Gönderdiğimiz last_modified değerleri: kayıt bu arada yerelde değiştiyse
        // senkronize işaretlenmesin.
        final zamanlar = <String, String>{
          for (final r in batch) (r[TableColumns.id] as String).toLowerCase(): r[TableColumns.lastModifiedUtc] as String,
        };
        final yerelIdler = {for (final r in batch) (r[TableColumns.id] as String).toLowerCase(): r[TableColumns.id] as String};

        final kabul = acceptedIds.where(yerelIdler.containsKey).toList();
        if (kabul.isNotEmpty) {
          await _db.markAsSynced(
            table,
            kabul.map((id) => yerelIdler[id]!).toList(),
            gonderilenZamanlar: {for (final id in kabul) yerelIdler[id]!: zamanlar[id]!},
          );
          totalPushed += kabul.length;
        }

        // Reddedilenler: sunucu kazandı (Last-Write-Wins). Yerel kopyayı senkronize
        // say ve sunucu sürümünü indirmek için tam pull iste; aksi halde bu kayıtlar
        // her turda tekrar tekrar gönderilirdi.
        final red = rejectedIds.where(yerelIdler.containsKey).map((id) => yerelIdler[id]!).toList();
        if (red.isNotEmpty) {
          await _db.markAsSynced(table, red);
          _tamPullGerekli = true;
        }
      }
    }

    return totalPushed;
  }

  // ── FOTOĞRAF YÜKLEME ────────────────────────────────────────────────────

  /// Bir turda en fazla bu kadar fotoğraf: yavaş bağlantıda sync uzun sürmesin, kalanlar sonraki turda.
  static const int fotografTurBasina = 5;

  /// Sunucudaki TaramaFotografi.MaksBayt ile aynı.
  static const int maksFotografBayt = 5 * 1024 * 1024;

  /// Sunucuda kaydı olan (is_synced=1) ama fotoğrafı yüklenmemiş taramaların fotoğraflarını yükler.
  /// Returns: yüklenen fotoğraf sayısı.
  Future<int> fotograflariYukle() async {
    final db = await _db.database;
    final bekleyen = await db.query(
      DatabaseHelper.tableHastalikTarama,
      columns: [TableColumns.id, TableColumns.taramaFotografYolu],
      where: '${TableColumns.taramaFotografSunucuda} = 0 AND is_synced = 1 AND is_deleted = 0 '
          "AND ${TableColumns.taramaFotografYolu} != ''",
      limit: fotografTurBasina,
    );

    var yuklenen = 0;
    for (final r in bekleyen) {
      final id = r[TableColumns.id] as String;
      final yol = r[TableColumns.taramaFotografYolu] as String;

      Future<void> durumYaz(int durum) => db.update(
            DatabaseHelper.tableHastalikTarama,
            {TableColumns.taramaFotografSunucuda: durum},
            where: 'id = ?',
            whereArgs: [id],
          );

      final dosya = File(yol);
      // Dosya silinmişse ya da sunucu sınırını (5 MB) aşıyorsa tekrar denemenin anlamı yok.
      // (Sınırı aşan istekte sunucu bağlantıyı keser; istemci bunu ağ hatası sanıp sonsuza
      // kadar yeniden denerdi.)
      if (!dosya.existsSync() || dosya.lengthSync() > maksFotografBayt) {
        await durumYaz(-1);
        continue;
      }
      try {
        await _dio.put(
          '/hastaliktarama/$id/fotograf',
          // Bu sürümden önce kaydedilmiş fotoğraflarda konum (EXIF) olabilir; gönderirken temizlenir.
          data: FormData.fromMap({
            'dosya': MultipartFile.fromBytes(fotografMetaTemizle(await dosya.readAsBytes()), filename: p.basename(yol)),
          }),
        );
        await durumYaz(1);
        yuklenen++;
      } on DioException catch (e) {
        final kod = e.response?.statusCode;
        if (kod == 400 || kod == 413) {
          await durumYaz(-1); // geçersiz/çok büyük dosya
        } else if (kod != 404) {
          rethrow; // bağlantı hatası vb. → sync sonucu "çevrimdışı/hata", sonraki turda tekrar
        }
        // 404: kayıt henüz sunucuda değil; sonraki turda tekrar denenir.
      }
    }
    return yuklenen;
  }

  // ── PULL ────────────────────────────────────────────────────────────────

  /// Sunucudan son sync'ten bu yana değişen kayıtları çeker ve SQLite'a upsert eder.
  /// Returns: Pull edilen toplam kayıt sayısı.
  Future<int> _pull() async {
    final sinceUtc = _tamPullGerekli ? DateTime.utc(2000) : await _getLastSyncTime();
    _tamPullGerekli = false;

    final response = await _dio.get(
      '/sync/pull',
      queryParameters: {'sinceUtc': sinceUtc.toUtc().toIso8601String()},
    );

    if (response.statusCode != 200) return 0;

    final data = response.data as Map<String, dynamic>;
    int totalPulled = 0;

    // ── Parseller ──────────────────────────────────────────────
    final parseller = (data['parseller'] as List<dynamic>? ?? [])
        .map((e) => _serverParselToRow(e as Map<String, dynamic>))
        .toList();
    final parsellerUygun = await _cakismaFiltrele(DatabaseHelper.tableParseller, parseller);
    if (parsellerUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableParseller, parsellerUygun);
      totalPulled += parsellerUygun.length;
    }

    // ── YagisSulama ────────────────────────────────────────────
    final sulamalar = (data['yagisSulamaKayitlari'] as List<dynamic>? ?? [])
        .map((e) => _serverSulamaToRow(e as Map<String, dynamic>))
        .toList();
    final sulamalarUygun = await _parseliOlanlar(
        await _cakismaFiltrele(DatabaseHelper.tableYagisSulama, sulamalar));
    if (sulamalarUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableYagisSulama, sulamalarUygun);
      totalPulled += sulamalarUygun.length;
    }

    // ── MuhasebeGider ──────────────────────────────────────────
    final giderler = (data['muhasebeGiderler'] as List<dynamic>? ?? [])
        .map((e) => _serverGiderToRow(e as Map<String, dynamic>))
        .toList();
    final giderlerUygun = await _cakismaFiltrele(DatabaseHelper.tableMuhasebeGider, giderler);
    if (giderlerUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableMuhasebeGider, giderlerUygun);
      totalPulled += giderlerUygun.length;
    }

    // ── HastalikTarama ─────────────────────────────────────────
    final taramalar = (data['hastalikTaramalar'] as List<dynamic>? ?? [])
        .map((e) => _serverTaramaToRow(e as Map<String, dynamic>))
        .toList();
    final taramalarUygun = await _cakismaFiltrele(DatabaseHelper.tableHastalikTarama, taramalar);
    if (taramalarUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableHastalikTarama, taramalarUygun);
      totalPulled += taramalarUygun.length;
    }

    // ── İş Günlüğü (parsellere bağlı → parseli olmayanlar atlanır) ──
    final isKayitlari = (data['isKayitlari'] as List<dynamic>? ?? [])
        .map((e) => _serverIsKaydiToRow(e as Map<String, dynamic>))
        .toList();
    final isKayitlariUygun = await _parseliOlanlar(
        await _cakismaFiltrele(DatabaseHelper.tableIsKaydi, isKayitlari));
    if (isKayitlariUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableIsKaydi, isKayitlariUygun);
      totalPulled += isKayitlariUygun.length;
    }

    // ── Veresiye: önce hesaplar, sonra hesabı cihazda olan hareketler ──
    final cariler = (data['cariler'] as List<dynamic>? ?? [])
        .map((e) => _serverCariToRow(e as Map<String, dynamic>))
        .toList();
    final carilerUygun = await _cakismaFiltrele(DatabaseHelper.tableCari, cariler);
    if (carilerUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableCari, carilerUygun);
      totalPulled += carilerUygun.length;
    }
    final hareketler = (data['cariHareketleri'] as List<dynamic>? ?? [])
        .map((e) => _serverCariHareketToRow(e as Map<String, dynamic>))
        .toList();
    final hareketlerUygun = await _carisiOlanlar(
        await _cakismaFiltrele(DatabaseHelper.tableCariHareket, hareketler));
    if (hareketlerUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableCariHareket, hareketlerUygun);
      totalPulled += hareketlerUygun.length;
    }

    // ── Depo: önce kalemler, sonra kalemi cihazda olan hareketler ──
    final stokKalemleri = (data['stokKalemleri'] as List<dynamic>? ?? [])
        .map((e) => _serverStokKalemiToRow(e as Map<String, dynamic>))
        .toList();
    final stokKalemleriUygun = await _cakismaFiltrele(DatabaseHelper.tableStokKalemi, stokKalemleri);
    if (stokKalemleriUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableStokKalemi, stokKalemleriUygun);
      totalPulled += stokKalemleriUygun.length;
    }
    final stokHareketleri = (data['stokHareketleri'] as List<dynamic>? ?? [])
        .map((e) => _serverStokHareketiToRow(e as Map<String, dynamic>))
        .toList();
    final stokHareketleriUygun = await _ustuOlanlar(
      await _cakismaFiltrele(DatabaseHelper.tableStokHareketi, stokHareketleri),
      ustTablo: DatabaseHelper.tableStokKalemi,
      sutun: 'kalem_id',
    );
    if (stokHareketleriUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableStokHareketi, stokHareketleriUygun);
      totalPulled += stokHareketleriUygun.length;
    }

    final hatirlatmalar = (data['hatirlatmalar'] as List<dynamic>? ?? [])
        .map((e) => _serverHatirlatmaToRow(e as Map<String, dynamic>))
        .toList();
    final hatirlatmalarUygun = await _cakismaFiltrele(DatabaseHelper.tableHatirlatma, hatirlatmalar);
    if (hatirlatmalarUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableHatirlatma, hatirlatmalarUygun);
      totalPulled += hatirlatmalarUygun.length;
    }

    final toprakAnalizleri = (data['toprakAnalizleri'] as List<dynamic>? ?? [])
        .map((e) => _serverToprakAnaliziToRow(e as Map<String, dynamic>))
        .toList();
    final toprakAnalizleriUygun = await _parseliOlanlar(
        await _cakismaFiltrele(DatabaseHelper.tableToprakAnalizi, toprakAnalizleri));
    if (toprakAnalizleriUygun.isNotEmpty) {
      await _db.upsertBatch(DatabaseHelper.tableToprakAnalizi, toprakAnalizleriUygun);
      totalPulled += toprakAnalizleriUygun.length;
    }

    // Son sync zamanını güncelle
    final serverTimestamp = data['serverSyncTimestamp'] as String?;
    if (serverTimestamp != null) {
      final t = _utc(serverTimestamp);
      if (t != null) await _saveLastSyncTime(t);
    }

    return totalPulled;
  }

  /// Pull çakışma kuralı (sunucudaki Last-Write-Wins'in istemci tarafı):
  /// Yerelde henüz gönderilmemiş (is_synced=0) ve sunucudakinden daha yeni bir
  /// kayıt varsa sunucu sürümü yazılmaz; yerel değişiklik bir sonraki push'ta gider.
  Future<List<Map<String, dynamic>>> _cakismaFiltrele(String table, List<Map<String, dynamic>> gelen) async {
    if (gelen.isEmpty) return gelen;
    final db = await _db.database;
    final bekleyen = await db.query(table, columns: ['id', 'last_modified_utc'], where: 'is_synced = ?', whereArgs: [0]);
    if (bekleyen.isEmpty) return gelen;
    final yerel = {
      for (final r in bekleyen) (r['id'] as String).toLowerCase(): _utc(r['last_modified_utc'] as String?),
    };
    return gelen.where((row) {
      final yerelZaman = yerel[(row[TableColumns.id] as String).toLowerCase()];
      if (yerelZaman == null) return true;
      final sunucuZaman = _utc(row[TableColumns.lastModifiedUtc] as String?);
      return sunucuZaman != null && !sunucuZaman.isBefore(yerelZaman);
    }).toList();
  }

  /// Sulama kayıtları parsel tablosuna foreign key ile bağlı; yerelde parseli
  /// olmayan kayıt eklenirse tüm pull işlemi hata verir.
  Future<List<Map<String, dynamic>>> _parseliOlanlar(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return rows;
    final db = await _db.database;
    final parselIdler = (await db.query(DatabaseHelper.tableParseller, columns: ['id']))
        .map((r) => (r['id'] as String).toLowerCase())
        .toSet();
    return rows.where((r) => parselIdler.contains((r[TableColumns.sulamaParselId] as String?)?.toLowerCase())).toList();
  }

  /// Hareketler hesaba foreign key ile bağlı; hesabı cihazda olmayan hareket atlanır.
  Future<List<Map<String, dynamic>>> _carisiOlanlar(List<Map<String, dynamic>> rows) =>
      _ustuOlanlar(rows, ustTablo: DatabaseHelper.tableCari, sutun: 'cari_id');

  /// [sutun] ile [ustTablo]'ya foreign key bağlı satırlardan, bağlı kaydı cihazda olanlar.
  Future<List<Map<String, dynamic>>> _ustuOlanlar(List<Map<String, dynamic>> rows,
      {required String ustTablo, required String sutun}) async {
    if (rows.isEmpty) return rows;
    final db = await _db.database;
    final idler = (await db.query(ustTablo, columns: ['id']))
        .map((r) => (r['id'] as String).toLowerCase())
        .toSet();
    return rows.where((r) => idler.contains((r[sutun] as String?)?.toLowerCase())).toList();
  }

  /// Sunucu tarihleri bazen saat dilimi eki (Z) olmadan gelir; hepsi UTC kabul edilir.
  static DateTime? _utc(String? s) {
    if (s == null || s.isEmpty) return null;
    final ekli = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s);
    return DateTime.tryParse(ekli ? s : '${s}Z')?.toUtc();
  }

  static String? _utcIso(dynamic v) => v == null ? null : _utc(v.toString())?.toIso8601String();

  // ── Son Sync Zamanı Yönetimi ────────────────────────────────────────────

  /// Son başarılı pull zamanını SQLite meta tablosundan okur.
  Future<DateTime> _getLastSyncTime() async {
    final db = await _db.database;
    // Meta bilgileri saklamak için basit bir key-value sorgusu
    // İlk sync'te DateTime.utc(2000) döndür (tüm kayıtlar gelsin)
    try {
      final rows = await db.rawQuery(
        'SELECT value FROM sync_meta WHERE key = ?',
        [_lastSyncKey],
      );
      if (rows.isEmpty) return DateTime.utc(2000);
      return DateTime.parse(rows.first['value'] as String);
    } catch (_) {
      return DateTime.utc(2000);
    }
  }

  /// Son sync zamanını SQLite'a kaydeder.
  Future<void> _saveLastSyncTime(DateTime time) async {
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute(
      'INSERT OR REPLACE INTO sync_meta (key, value) VALUES (?, ?)',
      [_lastSyncKey, time.toUtc().toIso8601String()],
    );
  }

  // ── Row → DTO Mapper'ları (SQLite → API JSON) ───────────────────────────

  Map<String, dynamic> _rowToParselDto(Map<String, dynamic> row) => {
        'id': row[TableColumns.id],
        'ad': row[TableColumns.parselAd],
        'ekilmisUrun': row[TableColumns.parselEkilmisUrun] ?? 'Buğday',
        'toprakTuru': row[TableColumns.parselToprakTuru] ?? 'Tınlı',
        'sulu': switch (row[TableColumns.parselSulu]) { 1 => true, 0 => false, _ => null },
        'sulamaYontemi': row[TableColumns.parselSulamaYontemi],
        'suKaynagi': row[TableColumns.parselSuKaynagi],
        'suEc': row[TableColumns.parselSuEc],
        // Sunucu bu işaretle boş (null) sulama alanlarını "silindi" sayar; eski sürüm kayıtlarında korur.
        'semaSurumu': 2,
        'ekimTarihi': row[TableColumns.parselEkimTarihi],
        'konum': row[TableColumns.parselKonum],
        'poligonKoordinatlariJson': row[TableColumns.parselPoligonJson],
        'alanDonumCinsinden': row[TableColumns.parselAlanDonum],
        'merkezLat': row[TableColumns.parselMerkezLat],
        'merkezLng': row[TableColumns.parselMerkezLng],
        'createdAtUtc': row[TableColumns.createdAtUtc],
        'lastModifiedUtc': row[TableColumns.lastModifiedUtc],
        'isDeleted': row[TableColumns.isDeleted] == 1,
      };

  Map<String, dynamic> _rowToYagisSulamaDto(Map<String, dynamic> row) => {
        'id': row[TableColumns.id],
        'parselId': row[TableColumns.sulamaParselId],
        'kayitTarihi': row[TableColumns.sulamaKayitTarihi],
        'yagisMillimetre': row[TableColumns.sulamaYagisMm],
        'toprakNemiYuzde': row[TableColumns.sulamaToprakNemi],
        'kayitTuru': row[TableColumns.sulamaKayitTuru],
        'manuelSulamaLitre': row[TableColumns.sulamaManuelLitre],
        'aciliyetSeviyesi': row[TableColumns.sulamaAciliyetSeviyesi],
        'hawaApiHamVeriJson': row[TableColumns.sulamaHavaApiJson],
        'createdAtUtc': row[TableColumns.createdAtUtc],
        'lastModifiedUtc': row[TableColumns.lastModifiedUtc],
        'isDeleted': row[TableColumns.isDeleted] == 1,
      };

  Map<String, dynamic> _rowToGiderDto(Map<String, dynamic> row) => {
        'id': row[TableColumns.id],
        'parselId': row[TableColumns.giderParselId],
        'islemTuru': row[TableColumns.giderIslemTuru] ?? 'Gider',
        'kategori': row[TableColumns.giderKategori],
        'altKategori': row[TableColumns.giderAltKategori],
        'tutar': row[TableColumns.giderTutar],
        'paraBirimi': row[TableColumns.giderParaBirimi],
        'giderTarihi': row[TableColumns.giderTarihi],
        'not': row[TableColumns.giderNot],
        'createdAtUtc': row[TableColumns.createdAtUtc],
        'lastModifiedUtc': row[TableColumns.lastModifiedUtc],
        'isDeleted': row[TableColumns.isDeleted] == 1,
      };

  Map<String, dynamic> _rowToTaramaDto(Map<String, dynamic> row) => {
        'id': row[TableColumns.id],
        'parselId': row[TableColumns.taramaParselId],
        'taramaTarihi': row[TableColumns.taramaTarihi],
        'teshisAdi': row[TableColumns.taramaTeshisAdi],
        'guvenYuzdesi': row[TableColumns.taramaGuvenYuzdesi],
        'tumSinifOlasiliklariJson': row[TableColumns.taramaSinifJson],
        'fotografYerelYolu': row[TableColumns.taramaFotografYolu],
        'modelVersionu': row[TableColumns.taramaModelVersiyon],
        'aciliyetSeviyesi': row[TableColumns.taramaAciliyetSeviyesi],
        'cevrimdisiAnalizYapildi': row[TableColumns.taramaCevrimdisi] == 1,
        'createdAtUtc': row[TableColumns.createdAtUtc],
        'lastModifiedUtc': row[TableColumns.lastModifiedUtc],
        'isDeleted': row[TableColumns.isDeleted] == 1,
      };

  Map<String, dynamic> _rowToIsKaydiDto(Map<String, dynamic> row) => {
        'id': row[TableColumns.id],
        'parselId': row[TableColumns.isParselId],
        'islemTarihi': row[TableColumns.isTarihi],
        'islemTuru': row[TableColumns.isTuru],
        'urunAdi': row[TableColumns.isUrunAdi],
        'miktar': row[TableColumns.isMiktar],
        'hasatBeklemeGun': row[TableColumns.isHasatBeklemeGun],
        'hasatKg': row[TableColumns.isHasatKg],
        'not': row[TableColumns.isNot],
        'createdAtUtc': row[TableColumns.createdAtUtc],
        'lastModifiedUtc': row[TableColumns.lastModifiedUtc],
        'isDeleted': row[TableColumns.isDeleted] == 1,
      };

  Map<String, dynamic> _rowToCariDto(Map<String, dynamic> r) => {
        'id': r['id'],
        'ad': r['ad'],
        'tur': r['tur'],
        'telefon': r['telefon'],
        'not': r['not_metni'],
        'createdAtUtc': r['created_at_utc'],
        'lastModifiedUtc': r['last_modified_utc'],
        'isDeleted': r['is_deleted'] == 1,
      };

  Map<String, dynamic> _rowToCariHareketDto(Map<String, dynamic> r) => {
        'id': r['id'],
        'cariId': r['cari_id'],
        'islemTarihi': r['islem_tarihi'],
        'tur': r['tur'],
        'tutar': r['tutar'],
        'vadeTarihi': r['vade_tarihi'],
        'aciklama': r['aciklama'],
        'muhasebeKaydiId': r['muhasebe_kaydi_id'],
        'createdAtUtc': r['created_at_utc'],
        'lastModifiedUtc': r['last_modified_utc'],
        'isDeleted': r['is_deleted'] == 1,
      };

  Map<String, dynamic> _rowToStokKalemiDto(Map<String, dynamic> r) => {
        'id': r['id'],
        'ad': r['ad'],
        'kategori': r['kategori'],
        'birim': r['birim'],
        'kritikSeviye': r['kritik_seviye'],
        'createdAtUtc': r['created_at_utc'],
        'lastModifiedUtc': r['last_modified_utc'],
        'isDeleted': r['is_deleted'] == 1,
      };

  Map<String, dynamic> _rowToStokHareketiDto(Map<String, dynamic> r) => {
        'id': r['id'],
        'kalemId': r['kalem_id'],
        'islemTarihi': r['islem_tarihi'],
        'tur': r['tur'],
        'miktar': r['miktar'],
        'aciklama': r['aciklama'],
        'isKaydiId': r['is_kaydi_id'],
        'createdAtUtc': r['created_at_utc'],
        'lastModifiedUtc': r['last_modified_utc'],
        'isDeleted': r['is_deleted'] == 1,
      };

  Map<String, dynamic> _rowToHatirlatmaDto(Map<String, dynamic> r) => {
        'id': r['id'],
        'baslik': r['baslik'],
        'tur': r['tur'],
        // Gün, UTC gece yarısı olarak gider; geri gelince aynı gün okunur.
        'tarih': '${r['tarih']}T00:00:00Z',
        'kacGunOnce': r['kac_gun_once'],
        'herYil': r['her_yil'] == 1,
        'tamamlandi': r['tamamlandi'] == 1,
        'not': r['not_metni'],
        'createdAtUtc': r['created_at_utc'],
        'lastModifiedUtc': r['last_modified_utc'],
        'isDeleted': r['is_deleted'] == 1,
      };

  Map<String, dynamic> _rowToToprakAnaliziDto(Map<String, dynamic> r) => {
        'id': r['id'],
        'parselId': r['parsel_id'],
        'analizTarihi': '${r['analiz_tarihi']}T00:00:00Z',
        'laboratuvar': r['laboratuvar'],
        'saturasyon': r['saturasyon'],
        'ph': r['ph'],
        'tuzYuzde': r['tuz_yuzde'],
        'ec': r['ec'],
        'kirecYuzde': r['kirec_yuzde'],
        'organikMadde': r['organik_madde'],
        'fosfor': r['fosfor'],
        'potasyum': r['potasyum'],
        'cinko': r['cinko'],
        'not': r['not_metni'],
        'createdAtUtc': r['created_at_utc'],
        'lastModifiedUtc': r['last_modified_utc'],
        'isDeleted': r['is_deleted'] == 1,
      };

  // ── Server JSON → SQLite Row Mapper'ları (API JSON → SQLite) ────────────

  Map<String, dynamic> _serverToprakAnaliziToRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'parsel_id': j['parselId'],
        'analiz_tarihi': _utcIso(j['analizTarihi'])!.substring(0, 10),
        'laboratuvar': j['laboratuvar'] ?? '',
        'saturasyon': (j['saturasyon'] as num?)?.toDouble(),
        'ph': (j['ph'] as num?)?.toDouble(),
        'tuz_yuzde': (j['tuzYuzde'] as num?)?.toDouble(),
        'ec': (j['ec'] as num?)?.toDouble(),
        'kirec_yuzde': (j['kirecYuzde'] as num?)?.toDouble(),
        'organik_madde': (j['organikMadde'] as num?)?.toDouble(),
        'fosfor': (j['fosfor'] as num?)?.toDouble(),
        'potasyum': (j['potasyum'] as num?)?.toDouble(),
        'cinko': (j['cinko'] as num?)?.toDouble(),
        'not_metni': j['not'] ?? '',
        'created_at_utc': _utcIso(j['createdAtUtc']),
        'last_modified_utc': _utcIso(j['lastModifiedUtc']),
        'is_deleted': (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        'is_synced': 1,
      };

  Map<String, dynamic> _serverHatirlatmaToRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'baslik': j['baslik'] ?? '',
        'tur': j['tur'] ?? 'Diger',
        'tarih': _utcIso(j['tarih'])!.substring(0, 10),
        'kac_gun_once': (j['kacGunOnce'] as num? ?? 7).toInt(),
        'her_yil': (j['herYil'] as bool? ?? false) ? 1 : 0,
        'tamamlandi': (j['tamamlandi'] as bool? ?? false) ? 1 : 0,
        'not_metni': j['not'] ?? '',
        'created_at_utc': _utcIso(j['createdAtUtc']),
        'last_modified_utc': _utcIso(j['lastModifiedUtc']),
        'is_deleted': (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        'is_synced': 1,
      };

  Map<String, dynamic> _serverStokKalemiToRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'ad': j['ad'] ?? '',
        'kategori': j['kategori'] ?? 'Diger',
        'birim': j['birim'] ?? 'kg',
        'kritik_seviye': (j['kritikSeviye'] as num?)?.toDouble(),
        'created_at_utc': _utcIso(j['createdAtUtc']),
        'last_modified_utc': _utcIso(j['lastModifiedUtc']),
        'is_deleted': (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        'is_synced': 1,
      };

  Map<String, dynamic> _serverStokHareketiToRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'kalem_id': j['kalemId'],
        'islem_tarihi': _utcIso(j['islemTarihi']),
        'tur': j['tur'] ?? 'Giris',
        'miktar': (j['miktar'] as num? ?? 0).toDouble(),
        'aciklama': j['aciklama'] ?? '',
        'is_kaydi_id': (j['isKaydiId'] as String?)?.toLowerCase(),
        'created_at_utc': _utcIso(j['createdAtUtc']),
        'last_modified_utc': _utcIso(j['lastModifiedUtc']),
        'is_deleted': (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        'is_synced': 1,
      };

  Map<String, dynamic> _serverCariToRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'ad': j['ad'] ?? '',
        'tur': j['tur'] ?? 'Bayi',
        'telefon': j['telefon'] ?? '',
        'not_metni': j['not'] ?? '',
        'created_at_utc': _utcIso(j['createdAtUtc']),
        'last_modified_utc': _utcIso(j['lastModifiedUtc']),
        'is_deleted': (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        'is_synced': 1,
      };

  Map<String, dynamic> _serverCariHareketToRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'cari_id': j['cariId'],
        'islem_tarihi': _utcIso(j['islemTarihi']),
        'tur': j['tur'] ?? 'Veresiye',
        'tutar': (j['tutar'] as num? ?? 0).toDouble(),
        'vade_tarihi': _utcIso(j['vadeTarihi']),
        'aciklama': j['aciklama'] ?? '',
        'muhasebe_kaydi_id': (j['muhasebeKaydiId'] as String?)?.toLowerCase(),
        'created_at_utc': _utcIso(j['createdAtUtc']),
        'last_modified_utc': _utcIso(j['lastModifiedUtc']),
        'is_deleted': (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        'is_synced': 1,
      };

  Map<String, dynamic> _serverIsKaydiToRow(Map<String, dynamic> j) => {
        TableColumns.id: j['id'],
        TableColumns.isParselId: j['parselId'],
        TableColumns.isTarihi: _utcIso(j['islemTarihi']),
        TableColumns.isTuru: j['islemTuru'] ?? 'Diger',
        TableColumns.isUrunAdi: j['urunAdi'] ?? '',
        TableColumns.isMiktar: j['miktar'] ?? '',
        TableColumns.isHasatBeklemeGun: (j['hasatBeklemeGun'] as num?)?.toInt(),
        TableColumns.isHasatKg: (j['hasatKg'] as num?)?.toDouble(),
        TableColumns.isNot: j['not'] ?? '',
        TableColumns.createdAtUtc: _utcIso(j['createdAtUtc']),
        TableColumns.lastModifiedUtc: _utcIso(j['lastModifiedUtc']),
        TableColumns.isDeleted: (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        TableColumns.isSynced: 1,
      };

  Map<String, dynamic> _serverParselToRow(Map<String, dynamic> j) => {
        TableColumns.id: j['id'],
        TableColumns.parselAd: j['ad'] ?? '',
        TableColumns.parselEkilmisUrun: j['ekilmisUrun'] ?? 'Buğday',
        TableColumns.parselToprakTuru: j['toprakTuru'] ?? 'Tınlı',
        TableColumns.parselSulu: switch (j['sulu']) { true => 1, false => 0, _ => null },
        TableColumns.parselSulamaYontemi: j['sulamaYontemi'],
        TableColumns.parselSuKaynagi: j['suKaynagi'],
        TableColumns.parselSuEc: (j['suEc'] as num?)?.toDouble(),
        TableColumns.parselEkimTarihi: j['ekimTarihi'],
        TableColumns.parselKonum: j['konum'] ?? '',
        TableColumns.parselPoligonJson: j['poligonKoordinatlariJson'] ?? '[]',
        TableColumns.parselAlanDonum: (j['alanDonumCinsinden'] ?? 0.0).toDouble(),
        TableColumns.parselMerkezLat: (j['merkezLat'] ?? 0.0).toDouble(),
        TableColumns.parselMerkezLng: (j['merkezLng'] ?? 0.0).toDouble(),
        TableColumns.createdAtUtc: _utcIso(j['createdAtUtc']),
        TableColumns.lastModifiedUtc: _utcIso(j['lastModifiedUtc']),
        TableColumns.isDeleted: (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        TableColumns.isSynced: 1, // Sunucudan geldi → zaten senkronize
      };

  Map<String, dynamic> _serverSulamaToRow(Map<String, dynamic> j) => {
        TableColumns.id: j['id'],
        TableColumns.sulamaParselId: j['parselId'],
        TableColumns.sulamaKayitTarihi: _utcIso(j['kayitTarihi']),
        TableColumns.sulamaYagisMm: (j['yagisMillimetre'] ?? 0.0).toDouble(),
        TableColumns.sulamaToprakNemi: (j['toprakNemiYuzde'] ?? 0.0).toDouble(),
        TableColumns.sulamaKayitTuru: j['kayitTuru'] ?? 'Otomatik',
        TableColumns.sulamaManuelLitre: (j['manuelSulamaLitre'] ?? 0.0).toDouble(),
        TableColumns.sulamaAciliyetSeviyesi: j['aciliyetSeviyesi'] ?? 'Normal',
        TableColumns.sulamaHavaApiJson: j['hawaApiHamVeriJson'] ?? '{}',
        TableColumns.createdAtUtc: _utcIso(j['createdAtUtc']),
        TableColumns.lastModifiedUtc: _utcIso(j['lastModifiedUtc']),
        TableColumns.isDeleted: (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        TableColumns.isSynced: 1,
      };

  Map<String, dynamic> _serverGiderToRow(Map<String, dynamic> j) => {
        TableColumns.id: j['id'],
        TableColumns.giderParselId: j['parselId'],
        TableColumns.giderIslemTuru: j['islemTuru'] ?? 'Gider',
        TableColumns.giderKategori: j['kategori'] ?? 'Diger',
        TableColumns.giderAltKategori: j['altKategori'] ?? '',
        TableColumns.giderTutar: (j['tutar'] ?? 0.0).toDouble(),
        TableColumns.giderParaBirimi: j['paraBirimi'] ?? 'TRY',
        TableColumns.giderTarihi: _utcIso(j['giderTarihi']),
        TableColumns.giderNot: j['not'] ?? '',
        TableColumns.createdAtUtc: _utcIso(j['createdAtUtc']),
        TableColumns.lastModifiedUtc: _utcIso(j['lastModifiedUtc']),
        TableColumns.isDeleted: (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        TableColumns.isSynced: 1,
      };

  Map<String, dynamic> _serverTaramaToRow(Map<String, dynamic> j) => {
        TableColumns.id: j['id'],
        TableColumns.taramaParselId: j['parselId'],
        TableColumns.taramaTarihi: _utcIso(j['taramaTarihi']),
        TableColumns.taramaTeshisAdi: j['teshisAdi'] ?? '',
        TableColumns.taramaGuvenYuzdesi: (j['guvenYuzdesi'] ?? 0.0).toDouble(),
        TableColumns.taramaSinifJson: j['tumSinifOlasiliklariJson'] ?? '[]',
        TableColumns.taramaFotografYolu: j['fotografYerelYolu'] ?? '',
        TableColumns.taramaFotografSunucuda: (j['fotografVar'] as bool? ?? false) ? 1 : 0,
        TableColumns.taramaModelVersiyon: j['modelVersionu'] ?? '',
        TableColumns.taramaAciliyetSeviyesi: j['aciliyetSeviyesi'] ?? 'Düşük',
        TableColumns.taramaCevrimdisi:
            (j['cevrimdisiAnalizYapildi'] as bool? ?? true) ? 1 : 0,
        TableColumns.createdAtUtc: _utcIso(j['createdAtUtc']),
        TableColumns.lastModifiedUtc: _utcIso(j['lastModifiedUtc']),
        TableColumns.isDeleted: (j['isDeleted'] as bool? ?? false) ? 1 : 0,
        TableColumns.isSynced: 1,
      };
}
