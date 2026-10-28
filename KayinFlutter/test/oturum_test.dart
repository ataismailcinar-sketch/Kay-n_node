import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/network/api_client.dart';
import 'package:kayin_flutter/features/auth/oturum.dart';
import 'package:kayin_flutter/features/sync/sync_manager.dart';
import 'package:kayin_flutter/features/sync/sync_provider.dart';

class BellekOturumDeposu implements OturumDeposu {
  Oturum? oturum;
  String? sahip;
  BellekOturumDeposu({this.oturum, this.sahip});

  @override
  Future<Oturum?> oku() async => oturum;
  @override
  Future<void> yaz(Oturum o) async => oturum = o;
  @override
  Future<void> oturumuSil() async => oturum = null;
  @override
  Future<String?> veriSahibi() async => sahip;
  @override
  Future<void> veriSahibiYaz(String? id) async => sahip = id;
}

class SahteYerelVeri extends YerelVeri {
  int kayit;
  int gonderilmemis;
  int silmeSayisi = 0;
  SahteYerelVeri({this.kayit = 0, this.gonderilmemis = 0});

  @override
  Future<int> kayitSayisi({bool sadeceGonderilmemis = false}) async => sadeceGonderilmemis ? gonderilmemis : kayit;
  @override
  Future<void> tumunuSil() async {
    silmeSayisi++;
    kayit = 0;
    gonderilmemis = 0;
  }
}

class _SahteSync extends SyncManager {
  @override
  Future<SyncResult> syncAll() async => SyncResult(status: SyncStatus.offline, timestamp: DateTime.now());
}

Oturum oturum(String id, {Duration kalan = const Duration(days: 30)}) => Oturum(
      token: 'token-$id',
      bitisUtc: DateTime.now().toUtc().add(kalan),
      kullaniciId: id,
      telefon: '5321234567',
      adSoyad: 'Test',
    );

void main() {
  group('Telefon numarası', () {
    test('farklı yazımlar aynı numaraya iner', () {
      for (final g in ['0532 123 45 67', '05321234567', '+90 532 123 4567', '905321234567', '532-123-45-67']) {
        expect(telefonNormalize(g), '5321234567', reason: g);
      }
    });

    test('geçersiz numaralar reddedilir', () {
      for (final g in ['', '1234', '0212 123 45 67', '0532 123 45 6', '05321234567890']) {
        expect(telefonNormalize(g), isNull, reason: g);
      }
    });

    test('ekranda okunur biçim', () => expect(oturum('a').telefonMetni, '0532 123 45 67'));
  });

  group('Oturum', () {
    late BellekOturumDeposu depo;
    late SahteYerelVeri yerel;
    late ProviderContainer c;

    ProviderContainer kur() => ProviderContainer(overrides: [
          oturumDeposuProvider.overrideWithValue(depo),
          yerelVeriProvider.overrideWithValue(yerel),
          syncManagerProvider.overrideWithValue(_SahteSync()),
        ]);

    tearDown(() {
      c.dispose();
      ApiClient().token = null;
    });

    test('kayıtlı oturum yoksa giriş istenir', () async {
      depo = BellekOturumDeposu();
      yerel = SahteYerelVeri();
      c = kur();
      expect(await c.read(oturumProvider.future), isNull);
    });

    test('süresi dolmuş token ile giriş istenir', () async {
      depo = BellekOturumDeposu(oturum: oturum('a', kalan: const Duration(days: -1)), sahip: 'a');
      yerel = SahteYerelVeri();
      c = kur();
      expect(await c.read(oturumProvider.future), isNull);
      expect(ApiClient().token, isNull);
    });

    test('geçerli oturum açılışta yüklenir ve token isteklere eklenir', () async {
      depo = BellekOturumDeposu(oturum: oturum('a'), sahip: 'a');
      yerel = SahteYerelVeri();
      c = kur();
      expect((await c.read(oturumProvider.future))?.kullaniciId, 'a');
      expect(ApiClient().token, 'token-a');
    });

    test('ilk girişte cihazdaki girişsiz veri silinir (sıfırdan başla)', () async {
      depo = BellekOturumDeposu();
      yerel = SahteYerelVeri(kayit: 5);
      c = kur();
      await c.read(oturumProvider.future);
      final n = c.read(oturumProvider.notifier);

      expect(await n.silinecekKayitSayisi(oturum('a')), 5);
      await n.oturumAc(oturum('a'));
      expect(yerel.silmeSayisi, 1);
      expect(depo.sahip, 'a');
      expect(c.read(oturumProvider).value?.kullaniciId, 'a');
    });

    test('aynı kullanıcı tekrar girince veri silinmez', () async {
      depo = BellekOturumDeposu(sahip: 'a');
      yerel = SahteYerelVeri(kayit: 5, gonderilmemis: 2);
      c = kur();
      await c.read(oturumProvider.future);
      final n = c.read(oturumProvider.notifier);

      expect(await n.silinecekKayitSayisi(oturum('a')), 0);
      await n.oturumAc(oturum('a'));
      expect(yerel.silmeSayisi, 0);
      expect(yerel.gonderilmemis, 2);
    });

    test('başka kullanıcı girince öncekinin verisi silinir', () async {
      depo = BellekOturumDeposu(sahip: 'a');
      yerel = SahteYerelVeri(kayit: 3);
      c = kur();
      await c.read(oturumProvider.future);
      await c.read(oturumProvider.notifier).oturumAc(oturum('b'));
      expect(yerel.silmeSayisi, 1);
      expect(depo.sahip, 'b');
    });

    test('sunucu token\'ı reddedince oturum düşer ama veri korunur', () async {
      depo = BellekOturumDeposu(oturum: oturum('a'), sahip: 'a');
      yerel = SahteYerelVeri(kayit: 4, gonderilmemis: 1);
      c = kur();
      await c.read(oturumProvider.future);

      ApiClient().onYetkisiz!(); // 401 interceptor'ı bunu çağırır
      await Future<void>.delayed(Duration.zero);

      expect(c.read(oturumProvider).value, isNull);
      expect(depo.oturum, isNull);
      expect(depo.sahip, 'a');
      expect(yerel.silmeSayisi, 0);
      expect(ApiClient().token, isNull);
    });

    test('çıkışta veri, oturum ve sahip bilgisi silinir', () async {
      depo = BellekOturumDeposu(oturum: oturum('a'), sahip: 'a');
      yerel = SahteYerelVeri(kayit: 4);
      c = kur();
      await c.read(oturumProvider.future);
      await c.read(oturumProvider.notifier).cikis();

      expect(c.read(oturumProvider).value, isNull);
      expect(yerel.silmeSayisi, 1);
      expect(depo.oturum, isNull);
      expect(depo.sahip, isNull);
      expect(ApiClient().token, isNull);
    });
  });

  test('Sunucu yanıtından oturum okunur (Guid küçük harfe çevrilir)', () {
    final o = Oturum.sunucuYanitindan({
      'token': 't',
      'bitisUtc': '2027-01-20T10:00:00Z',
      'kullanici': {'id': 'ABCD-1', 'telefon': '5321234567', 'adSoyad': 'Ali'},
    });
    expect(o.kullaniciId, 'abcd-1');
    expect(o.bitisUtc.isUtc, isTrue);
    expect(Oturum.fromJson(o.toJson()).token, 't');
  });
}
