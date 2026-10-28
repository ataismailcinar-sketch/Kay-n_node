import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/database/database_helper.dart';
import 'package:kayin_flutter/core/services/hava_durumu_servisi.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/sezonluk_iklim_motoru.dart';
import 'package:kayin_flutter/features/arazi_analiz/domain/zirai_karar_destek_engine.dart';
import 'package:kayin_flutter/features/klavyesiz_muhasebe/data/models/gider_model.dart';
import 'package:kayin_flutter/features/klavyesiz_muhasebe/domain/entities/gider_entity.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ParselEntity _parsel({String urun = 'Mısır', DateTime? ekim}) {
  final now = DateTime.now();
  return ParselEntity(
    id: 'p1',
    ad: 'Test',
    ekilmisUrun: urun,
    ekimTarihi: ekim,
    konum: '',
    poligonNoktalar: const [],
    alanDonumCinsinden: 10,
    merkezLat: 39.5,
    merkezLng: 32.1,
    createdAtUtc: now,
    lastModifiedUtc: now,
  );
}

TarlaHavaOzeti _hava({double? nem, List<GunlukHavaVerisi> gecmis = const []}) => TarlaHavaOzeti(
      guncelToprakNemiYuzde: nem,
      bugunYagisMm: 0,
      bugunMaxSicaklik: 22,
      bugunMinSicaklik: 10,
      bugunRuzgarHiziKm: 8,
      sonYediGun: const [],
      gelecekYediGunTahmin: const [],
      gecmisGunler: gecmis,
    );

void main() {
  sqfliteFfiInit();

  group('Veritabanı', () {
    test('Parsel güncellemesi sulama kayıtlarını SİLMEZ (REPLACE + CASCADE hatası)', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('PRAGMA foreign_keys=ON');
      await db.execute('CREATE TABLE p (id TEXT PRIMARY KEY, ad TEXT)');
      await db.execute('CREATE TABLE s (id TEXT PRIMARY KEY, parsel_id TEXT NOT NULL, '
          'FOREIGN KEY (parsel_id) REFERENCES p (id) ON DELETE CASCADE)');
      await DatabaseHelper.upsertWith(db, 'p', {'id': '1', 'ad': 'a'});
      await db.insert('s', {'id': 'x', 'parsel_id': '1'});

      await DatabaseHelper.upsertWith(db, 'p', {'id': '1', 'ad': 'b'});

      expect((await db.rawQuery('SELECT COUNT(*) AS n FROM s')).single['n'], 1);
      expect((await db.query('p')).single['ad'], 'b');
      await db.close();
    });

    test('Notu olmayan gider NOT NULL sütununa boş metin olarak yazılır', () {
      final now = DateTime.now().toUtc();
      final row = GiderModel.toRow(GiderEntity(
        id: 'g1',
        kategori: 'Mazot',
        altKategori: 'Tarla',
        tutar: 100,
        giderTarihi: now,
        createdAtUtc: now,
        lastModifiedUtc: now,
      ));
      expect(row['not_metni'], '');
    });
  });

  group('Uydurma veri yok', () {
    test('Ekim tarihi yoksa yağış/gün/ısıl gün üretilmez', () {
      final r = SezonlukIklimMotoru.hesapla(parsel: _parsel(), hava: _hava(nem: 60));
      expect(r.ekimTarihiVar, isFalse);
      expect(r.toplamBirikenYagisMm, isNull);
      expect(r.toplamGddIsilGun, isNull);
    });

    test('Mısır parseline buğday evreleri (süne/kımıl) gösterilmez', () {
      final r = SezonlukIklimMotoru.hesapla(
        parsel: _parsel(ekim: DateTime.now().subtract(const Duration(days: 100))),
        hava: _hava(nem: 60),
      );
      expect(r.mevcutFenolojikEvre.contains('Kardeşlenme'), isFalse);
      expect(r.kritikMevsimselGorev.contains('Süne'), isFalse);
    });

    test('Isıl gün ölçülmüş günlük sıcaklıklardan toplanır', () {
      final ekim = DateTime.now().subtract(const Duration(days: 3));
      final gunler = [
        for (var i = 3; i >= 1; i--)
          GunlukHavaVerisi(
            tarih: DateTime.now().subtract(Duration(days: i)),
            yagisMm: 0,
            maxSicaklik: 25,
            minSicaklik: 15, // ort. 20 → mısır (baz 10) için günde 10
            maxRuzgarHizi: 5,
            buharlasmaEt0: 3,
          ),
      ];
      final r = SezonlukIklimMotoru.hesapla(parsel: _parsel(ekim: ekim), hava: _hava(nem: 60, gecmis: gunler));
      expect(r.toplamGddIsilGun, 30);
    });

    test('Toprak nemi verisi yoksa sulama/tav kararı "veri yok" der', () {
      final k = ZiraiKararDestekEngine.kararlariUret(parsel: _parsel(), hava: _hava(nem: null));
      expect(k.sulama.aciliyet, 'Bilinmiyor');
      expect(k.ekimTavi.toprakTavinda, isFalse);
      expect(k.ekimTavi.durum, contains('VERİ YOK'));
    });

    test('Kullanılabilir su %20 → acil sulama', () {
      final k = ZiraiKararDestekEngine.kararlariUret(parsel: _parsel(), hava: _hava(nem: 20));
      expect(k.sulama.aciliyet, 'Acil');
    });
  });

  test('Aynı parsel (id + değişiklik zamanı) eşit sayılır', () {
    final t = DateTime.utc(2026, 1, 1);
    ParselEntity p() => ParselEntity(
          id: 'a',
          ad: 'x',
          konum: '',
          poligonNoktalar: const [],
          alanDonumCinsinden: 1,
          merkezLat: 1,
          merkezLng: 1,
          createdAtUtc: t,
          lastModifiedUtc: t,
        );
    expect(p(), equals(p()));
    expect(p().hashCode, p().hashCode);
  });
}
