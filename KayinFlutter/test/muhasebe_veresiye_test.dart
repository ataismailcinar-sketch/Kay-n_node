import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/database/database_helper.dart';
import 'package:kayin_flutter/features/klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';
import 'package:kayin_flutter/features/veresiye/domain/veresiye.dart';
import 'package:kayin_flutter/features/veresiye/presentation/veresiye_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late ProviderContainer c;
  late CariEntity bayi;

  setUp(() async {
    DatabaseHelper.testYolu = inMemoryDatabasePath;
    final db = await DatabaseHelper().database;
    for (final t in [DatabaseHelper.tableCariHareket, DatabaseHelper.tableCari, DatabaseHelper.tableMuhasebeGider]) {
      await db.delete(t);
    }
    c = ProviderContainer();
    bayi = await c.read(cariListeProvider.notifier).kaydet(ad: 'Yılmaz Tarım', tur: CariTuru.bayi);
    // Veresiye gübre alışı, muhasebeye gider olarak işlenir.
    await c.read(cariHareketListeProvider.notifier).kaydet(
          cari: bayi,
          tur: HareketTuru.veresiye,
          tutar: 10000,
          islemTarihi: DateTime(2026, 10, 1, 12),
          vadeTarihi: DateTime(2027, 1, 1),
          muhasebeyeIsle: true,
          kategori: 'Gubre',
        );
  });
  tearDown(() => c.dispose());

  Future<CariHareketEntity> hareket() async => (await c.read(cariHareketListeProvider.future)).single;
  Future<double> bakiye() async => cariDurumu(await c.read(cariHareketListeProvider.future), DateTime(2026, 10, 23)).bakiye;

  test('Muhasebeden tutar ve tarih değişince veresiye hareketi ve bakiye de değişir', () async {
    final gider = (await c.read(giderListeProvider.future)).single;
    expect(await bakiye(), 10000);

    final n = c.read(giderGirisProvider.notifier);
    await n.duzenlemeBaslat(gider);
    expect(c.read(giderGirisProvider).veresiyeBagli, isTrue);
    n
      ..tutarSifirla()
      ..rakamEkle('8')
      ..rakamEkle('500')
      ..tarihSec(DateTime(2026, 10, 5));
    expect(await n.kaydet(), isNull);

    final h = await hareket();
    expect(h.tutar, 8500);
    expect(h.islemTarihi.toLocal().day, 5);
    expect(h.vadeTarihi, isNotNull); // vade korunur
    expect(await bakiye(), 8500);
  });

  test('Bağlı kaydın gelir/gider türü muhasebeden değiştirilemez', () async {
    final gider = (await c.read(giderListeProvider.future)).single;
    final n = c.read(giderGirisProvider.notifier)
      ..duzenlemeBaslat(gider)
      ..islemTuruSec('Gelir')
      ..kategoriSec('Hasat')
      ..altKategoriSec('Buğday');
    expect(await n.kaydet(), contains('Veresiye Defteri'));
    expect((await hareket()).tutar, 10000);
  });

  test('Muhasebeden silinince bağlı hareket de silinir, geri alınca ikisi de döner', () async {
    final gider = (await c.read(giderListeProvider.future)).single;
    final liste = c.read(giderListeProvider.notifier);
    expect(await liste.sil(gider.id), isTrue);
    expect(await c.read(cariHareketListeProvider.future), isEmpty);
    expect(await bakiye(), 0);

    await liste.geriAl(gider.id);
    expect((await hareket()).tutar, 10000);
    expect(await c.read(giderListeProvider.future), hasLength(1));
  });

  test('Bağsız gider silinince veresiye etkilenmez', () async {
    final n = c.read(giderGirisProvider.notifier)
      ..kategoriSec('Mazot')
      ..altKategoriSec('Tarla')
      ..rakamEkle('750');
    expect(await n.kaydet(), isNull);
    final mazot = (await c.read(giderListeProvider.future)).firstWhere((g) => g.kategori == 'Mazot');
    expect(await c.read(giderListeProvider.notifier).sil(mazot.id), isFalse);
    expect((await hareket()).tutar, 10000);
  });
}
