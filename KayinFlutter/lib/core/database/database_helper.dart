import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'table_columns.dart';

/// SQLite Veritabanı Yardımcısı — Singleton.
class DatabaseHelper {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // ── Sabitler ──────────────────────────────────────────────────────────
  static const String _dbName = 'kayin_tarim.db';
  static const int _dbVersion = 15;
  // v4: ekim_tarihi ve islem_turu (Gelir/Gider) eklendi
  // v5: aynı gün tekrar eden otomatik hava kayıtları temizlendi, sync_meta tablosu
  // v6: hastalik_taramalar.fotograf_sunucuda (fotoğraf yükleme durumu)
  // v7: is_kayitlari (iş günlüğü)
  // v8: is_kayitlari.hasat_kg (verim hesabı)
  // v9: cariler + cari_hareketleri (veresiye defteri)
  // v10: stok_kalemleri + stok_hareketleri (depo)
  // v11: hatirlatmalar (ÇKS / destek / TARSİM bildirimleri)
  // v12: toprak_analizleri
  // v13: parseller.sulu (sulu / kuru tarım)
  // v14: parseller.sulama_yontemi + su_kaynagi
  // v15: parseller.su_ec (sulama suyu tuzluluğu)

  // Tablo isimleri
  static const String tableParseller = 'parseller';
  static const String tableYagisSulama = 'yagis_sulama_kayitlari';
  static const String tableMuhasebeGider = 'muhasebe_giderler';
  static const String tableHastalikTarama = 'hastalik_taramalar';
  static const String tableIsKaydi = 'is_kayitlari';
  static const String tableCari = 'cariler';
  static const String tableCariHareket = 'cari_hareketleri';
  static const String tableStokKalemi = 'stok_kalemleri';
  static const String tableStokHareketi = 'stok_hareketleri';
  static const String tableHatirlatma = 'hatirlatmalar';
  static const String tableToprakAnalizi = 'toprak_analizleri';

  // ── Veritabanı Erişimi ────────────────────────────────────────────────

  /// Testlerde gerçek dosya yerine bellek içi veritabanı (`inMemoryDatabasePath`) kullanmak için.
  static String? testYolu;

  /// Veritabanı nesnesini döner, yoksa oluşturur (lazy init).
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// SQLite veritabanını başlatır, tabloları oluşturur.
  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = testYolu ?? join(await getDatabasesPath(), _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _createSyncMeta(db);
      },
      // WAL modu: eş zamanlı okuma/yazma performansını artırır
      // Not: Android'de PRAGMA journal_mode bir satır döndürdüğü için execute() hata
      // verebilir; rawQuery ile çalıştırılır.
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode=WAL;');
        } catch (_) {}
        await db.execute('PRAGMA foreign_keys=ON;');
      },
    );
  }

  // ── Tablo Oluşturma ───────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await _createParseller(txn);
      await _createYagisSulama(txn);
      await _createMuhasebeGider(txn);
      await _createHastalikTarama(txn);
      await _createIsKayitlari(txn);
      await _createVeresiye(txn);
      await _createDepo(txn);
      await _createHatirlatmalar(txn);
      await _createToprakAnalizleri(txn);
      await _createSyncMeta(txn);
    });
  }

  /// Senkronizasyon meta tablosu (son pull zamanı vb.)
  Future<void> _createSyncMeta(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE $tableParseller ADD COLUMN ${TableColumns.parselEkilmisUrun} TEXT NOT NULL DEFAULT "Buğday"',
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE $tableParseller ADD COLUMN ${TableColumns.parselToprakTuru} TEXT NOT NULL DEFAULT "Tınlı"',
        );
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE $tableParseller ADD COLUMN ${TableColumns.parselEkimTarihi} TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE $tableMuhasebeGider ADD COLUMN ${TableColumns.giderIslemTuru} TEXT NOT NULL DEFAULT "Gider"',
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // Eski sürüm hava servisi her açılışta yeni bir "Otomatik" kayıt ekliyordu.
      // Her parsel için gün başına yalnızca en son kaydı bırak; fazlası yumuşak silinir
      // (silme bilgisi sunucuya da gider).
      final now = DateTime.now().toUtc().toIso8601String();
      await db.rawUpdate('''
        UPDATE $tableYagisSulama
           SET is_deleted = 1, is_synced = 0, last_modified_utc = ?
         WHERE kayit_turu = 'Otomatik'
           AND is_deleted = 0
           AND rowid NOT IN (
             SELECT MAX(rowid) FROM $tableYagisSulama
              WHERE kayit_turu = 'Otomatik' AND is_deleted = 0
              GROUP BY parsel_id, substr(kayit_tarihi, 1, 10)
           )
      ''', [now]);
      await _createSyncMeta(db);
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE $tableHastalikTarama ADD COLUMN ${TableColumns.taramaFotografSunucuda} INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 7) {
      await _createIsKayitlari(db); // v8 sütunu dahil oluşur
    } else if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE $tableIsKaydi ADD COLUMN ${TableColumns.isHasatKg} REAL');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      await _createVeresiye(db);
    }
    if (oldVersion < 10) {
      await _createDepo(db);
    }
    if (oldVersion < 11) {
      await _createHatirlatmalar(db);
    }
    if (oldVersion < 12) {
      await _createToprakAnalizleri(db);
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE $tableParseller ADD COLUMN ${TableColumns.parselSulu} INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      for (final sutun in [TableColumns.parselSulamaYontemi, TableColumns.parselSuKaynagi]) {
        try {
          await db.execute('ALTER TABLE $tableParseller ADD COLUMN $sutun TEXT');
        } catch (_) {}
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE $tableParseller ADD COLUMN ${TableColumns.parselSuEc} REAL');
      } catch (_) {}
    }
  }

  /// TABLO: toprak_analizleri (laboratuvar raporu; boş bırakılan değerler NULL).
  Future<void> _createToprakAnalizleri(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableToprakAnalizi (
        id                TEXT PRIMARY KEY NOT NULL,
        parsel_id         TEXT NOT NULL,
        analiz_tarihi     TEXT NOT NULL,
        laboratuvar       TEXT NOT NULL DEFAULT '',
        saturasyon        REAL,
        ph                REAL,
        tuz_yuzde         REAL,
        ec                REAL,
        kirec_yuzde       REAL,
        organik_madde     REAL,
        fosfor            REAL,
        potasyum          REAL,
        cinko             REAL,
        not_metni         TEXT NOT NULL DEFAULT '',
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parsel_id) REFERENCES $tableParseller (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_toprak_analizi_parsel ON $tableToprakAnalizi(parsel_id, analiz_tarihi);');
  }

  /// TABLO: hatirlatmalar (ÇKS, destek, TARSİM...). tarih yalnızca gün olarak anlamlıdır (yyyy-MM-dd).
  Future<void> _createHatirlatmalar(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHatirlatma (
        id                TEXT PRIMARY KEY NOT NULL,
        baslik            TEXT NOT NULL DEFAULT '',
        tur               TEXT NOT NULL DEFAULT 'Diger',
        tarih             TEXT NOT NULL,
        kac_gun_once      INTEGER NOT NULL DEFAULT 7,
        her_yil           INTEGER NOT NULL DEFAULT 0,
        tamamlandi        INTEGER NOT NULL DEFAULT 0,
        not_metni         TEXT NOT NULL DEFAULT '',
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  /// TABLOLAR: stok_kalemleri + stok_hareketleri (depo). Mevcut miktar hareketlerden hesaplanır.
  Future<void> _createDepo(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableStokKalemi (
        id                TEXT PRIMARY KEY NOT NULL,
        ad                TEXT NOT NULL DEFAULT '',
        kategori          TEXT NOT NULL DEFAULT 'Diger',
        birim             TEXT NOT NULL DEFAULT 'kg',
        kritik_seviye     REAL,
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableStokHareketi (
        id                TEXT PRIMARY KEY NOT NULL,
        kalem_id          TEXT NOT NULL,
        islem_tarihi      TEXT NOT NULL,
        tur               TEXT NOT NULL DEFAULT 'Giris',
        miktar            REAL NOT NULL DEFAULT 0,
        aciklama          TEXT NOT NULL DEFAULT '',
        is_kaydi_id       TEXT,
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (kalem_id) REFERENCES $tableStokKalemi (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stok_hareketi_kalem ON $tableStokHareketi(kalem_id, islem_tarihi);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stok_hareketi_is ON $tableStokHareketi(is_kaydi_id);');
  }

  /// TABLOLAR: cariler + cari_hareketleri (veresiye defteri). Bakiye saklanmaz, hareketlerden hesaplanır.
  Future<void> _createVeresiye(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCari (
        id                TEXT PRIMARY KEY NOT NULL,
        ad                TEXT NOT NULL DEFAULT '',
        tur               TEXT NOT NULL DEFAULT 'Bayi',
        telefon           TEXT NOT NULL DEFAULT '',
        not_metni         TEXT NOT NULL DEFAULT '',
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCariHareket (
        id                 TEXT PRIMARY KEY NOT NULL,
        cari_id            TEXT NOT NULL,
        islem_tarihi       TEXT NOT NULL,
        tur                TEXT NOT NULL DEFAULT 'Veresiye',
        tutar              REAL NOT NULL DEFAULT 0,
        vade_tarihi        TEXT,
        aciklama           TEXT NOT NULL DEFAULT '',
        muhasebe_kaydi_id  TEXT,
        created_at_utc     TEXT NOT NULL,
        last_modified_utc  TEXT NOT NULL,
        is_deleted         INTEGER NOT NULL DEFAULT 0,
        is_synced          INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cari_id) REFERENCES $tableCari (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cari_hareket_cari ON $tableCariHareket(cari_id, islem_tarihi);');
  }

  /// TABLO: is_kayitlari (iş günlüğü)
  Future<void> _createIsKayitlari(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableIsKaydi (
        id                TEXT PRIMARY KEY NOT NULL,
        parsel_id         TEXT NOT NULL,
        islem_tarihi      TEXT NOT NULL,
        islem_turu        TEXT NOT NULL DEFAULT 'Diger',
        urun_adi          TEXT NOT NULL DEFAULT '',
        miktar            TEXT NOT NULL DEFAULT '',
        hasat_bekleme_gun INTEGER,
        hasat_kg          REAL,
        not_metni         TEXT NOT NULL DEFAULT '',
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parsel_id) REFERENCES $tableParseller (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_is_kayitlari_parsel_tarih
        ON $tableIsKaydi(parsel_id, islem_tarihi);
    ''');
  }

  /// TABLO: parseller
  /// .NET: Parsel entity → Onion Domain katmanı
  Future<void> _createParseller(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableParseller (
        id                         TEXT PRIMARY KEY NOT NULL,
        ad                         TEXT NOT NULL DEFAULT '',
        ekilmis_urun               TEXT NOT NULL DEFAULT 'Buğday',
        toprak_turu                TEXT NOT NULL DEFAULT 'Tınlı',
        sulu                       INTEGER,
        sulama_yontemi             TEXT,
        su_kaynagi                 TEXT,
        su_ec                      REAL,
        ekim_tarihi                TEXT,
        konum                      TEXT NOT NULL DEFAULT '',
        poligon_koordinatlari_json TEXT NOT NULL DEFAULT '[]',
        alan_donum_cinsinden       REAL NOT NULL DEFAULT 0.0,
        merkez_lat                 REAL NOT NULL DEFAULT 0.0,
        merkez_lng                 REAL NOT NULL DEFAULT 0.0,
        created_at_utc             TEXT NOT NULL,
        last_modified_utc          TEXT NOT NULL,
        is_deleted                 INTEGER NOT NULL DEFAULT 0,
        is_synced                  INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Senkronizasyon sorguları için index — IsSynced=0 olan kayıtları hızlı bul
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parseller_is_synced
        ON $tableParseller(is_synced);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parseller_last_modified
        ON $tableParseller(last_modified_utc);
    ''');
  }

  /// TABLO: yagis_sulama_kayitlari
  Future<void> _createYagisSulama(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableYagisSulama (
        id                     TEXT PRIMARY KEY NOT NULL,
        parsel_id              TEXT NOT NULL,
        kayit_tarihi           TEXT NOT NULL,
        yagis_milimetre        REAL NOT NULL DEFAULT 0.0,
        toprak_nemi_yuzde      REAL NOT NULL DEFAULT 50.0,
        kayit_turu             TEXT NOT NULL DEFAULT 'Otomatik',
        manuel_sulama_litre    REAL NOT NULL DEFAULT 0.0,
        aciliyet_seviyesi      TEXT NOT NULL DEFAULT 'Normal',
        hava_api_ham_veri_json TEXT NOT NULL DEFAULT '{}',
        created_at_utc         TEXT NOT NULL,
        last_modified_utc      TEXT NOT NULL,
        is_deleted             INTEGER NOT NULL DEFAULT 0,
        is_synced              INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parsel_id) REFERENCES $tableParseller (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_yagis_sulama_parsel_id
        ON $tableYagisSulama(parsel_id);
    ''');
  }

  /// TABLO: muhasebe_giderler
  Future<void> _createMuhasebeGider(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMuhasebeGider (
        id                TEXT PRIMARY KEY NOT NULL,
        parsel_id         TEXT,
        islem_turu        TEXT NOT NULL DEFAULT 'Gider',
        kategori          TEXT NOT NULL,
        alt_kategori      TEXT NOT NULL DEFAULT '',
        tutar             REAL NOT NULL,
        para_birimi       TEXT NOT NULL DEFAULT 'TRY',
        gider_tarihi      TEXT NOT NULL,
        not_metni         TEXT NOT NULL DEFAULT '',
        created_at_utc    TEXT NOT NULL,
        last_modified_utc TEXT NOT NULL,
        is_deleted        INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_muhasebe_gider_kategori
        ON $tableMuhasebeGider(kategori);
    ''');
  }

  /// TABLO: hastalik_taramalar
  Future<void> _createHastalikTarama(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHastalikTarama (
        id                         TEXT PRIMARY KEY NOT NULL,
        parsel_id                  TEXT,
        tarama_tarihi              TEXT NOT NULL,
        teshis_adi                 TEXT NOT NULL,
        guven_yuzdesi              REAL NOT NULL,
        tum_sinif_olasiliklari_json TEXT NOT NULL DEFAULT '{}',
        fotograf_yerel_yolu        TEXT NOT NULL DEFAULT '',
        fotograf_sunucuda          INTEGER NOT NULL DEFAULT 0,
        model_versiyonu            TEXT NOT NULL DEFAULT '1.0.0',
        aciliyet_seviyesi          TEXT NOT NULL DEFAULT 'Normal',
        cevrimdisi_analiz_yapildi  INTEGER NOT NULL DEFAULT 1,
        created_at_utc             TEXT NOT NULL,
        last_modified_utc          TEXT NOT NULL,
        is_deleted                 INTEGER NOT NULL DEFAULT 0,
        is_synced                  INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  // ── Genel Helper Metodlar ──────────────────────────────────────────────

  /// Kaydı ekler, varsa günceller.
  ///
  /// ÖNEMLİ: `INSERT OR REPLACE` kullanılmaz. REPLACE eski satırı SİLİP yeniden
  /// eklediği için `ON DELETE CASCADE` tetiklenir ve örneğin bir parsel
  /// güncellendiğinde o parselin tüm sulama kayıtları silinirdi.
  Future<void> upsert(String table, Map<String, dynamic> row) async {
    final db = await database;
    await upsertWith(db, table, row);
  }

  Future<void> upsertBatch(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final row in rows) {
        await upsertWith(txn, table, row);
      }
    });
  }

  static Future<void> upsertWith(DatabaseExecutor db, String table, Map<String, dynamic> row) async {
    final guncellenen = await db.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
    if (guncellenen == 0) {
      await db.insert(table, row);
    }
  }

  /// Senkronize edilmemiş tüm kayıtları döner (yeni, güncellenmiş VE silinmiş kayıtlar).
  Future<List<Map<String, dynamic>>> getUnsyncedRows(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) =>
      getUnsyncedRows(table);

  /// Başarıyla push edilen kayıtları is_synced=1 olarak işaretler.
  ///
  /// [gonderilenZamanlar] verilirse (id → gönderilen last_modified_utc), kayıt
  /// gönderildikten sonra yerelde tekrar değiştiyse işaretlenmez; böylece o
  /// değişiklik bir sonraki turda yine gönderilir.
  Future<void> markAsSynced(String table, List<String> ids, {Map<String, String>? gonderilenZamanlar}) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final id in ids) {
      final zaman = gonderilenZamanlar?[id];
      batch.update(
        table,
        {'is_synced': 1},
        where: zaman == null ? 'id = ?' : 'id = ? AND last_modified_utc = ?',
        whereArgs: zaman == null ? [id] : [id, zaman],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Kullanıcının elle girdiği (silinmemiş) kayıt sayısı: tarla, muhasebe, tarama.
  /// Otomatik hava kayıtları sayılmaz. [sadeceGonderilmemis] ise yalnızca sunucuya gitmemiş olanlar.
  Future<int> kayitSayisi({bool sadeceGonderilmemis = false}) async {
    final db = await database;
    var toplam = 0;
    for (final tablo in [
      tableParseller, tableMuhasebeGider, tableHastalikTarama, tableIsKaydi,
      tableCari, tableCariHareket, tableStokKalemi, tableStokHareketi, tableHatirlatma,
      tableToprakAnalizi,
    ]) {
      final sonuc = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM $tablo WHERE is_deleted = 0${sadeceGonderilmemis ? ' AND is_synced = 0' : ''}',
      );
      toplam += sonuc.single['n'] as int;
    }
    return toplam;
  }

  /// Hesap değişince/çıkışta: tüm yerel kayıtları ve senkronizasyon zamanını siler.
  /// (Yumuşak silme değil; bu veriler sunucuya "silindi" olarak gitmemeli.)
  Future<void> tumVerileriSil() async {
    final db = await database;
    await db.transaction((txn) async {
      // Alt tablolar önce (parsellere foreign key ile bağlı).
      for (final tablo in [
        tableYagisSulama, tableHastalikTarama, tableMuhasebeGider, tableIsKaydi,
        tableCariHareket, tableCari, tableStokHareketi, tableStokKalemi, tableHatirlatma, tableToprakAnalizi, tableParseller, 'sync_meta',
      ]) {
        await txn.delete(tablo);
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
