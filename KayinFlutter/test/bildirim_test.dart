import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/services/hava_durumu_servisi.dart';
import 'package:kayin_flutter/features/bildirimler/data/bildirim_ayarlari.dart';
import 'package:kayin_flutter/features/bildirimler/data/hatirlatma_model.dart';
import 'package:kayin_flutter/features/bildirimler/domain/bildirim.dart';
import 'package:kayin_flutter/features/veresiye/domain/veresiye.dart';

final _t = DateTime.utc(2026, 1, 1);
var _n = 0;

GunlukHavaVerisi _gun(DateTime tarih, double min) => GunlukHavaVerisi(
    tarih: tarih, yagisMm: 0, maxSicaklik: min + 10, minSicaklik: min, maxRuzgarHizi: 5, buharlasmaEt0: 1);

HatirlatmaEntity _hat(DateTime tarih, {int once = 7, bool herYil = false, bool tamam = false}) => HatirlatmaEntity(
      id: 'h${_n++}',
      baslik: 'ÇKS',
      tur: HatirlatmaTuru.cks,
      tarih: tarih,
      kacGunOnce: once,
      herYil: herYil,
      tamamlandi: tamam,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
    );

CariHareketEntity _cari(HareketTuru tur, double tutar, {DateTime? vade}) => CariHareketEntity(
      id: 'c${_n++}',
      cariId: 'bayi',
      islemTarihi: DateTime(2026, 3, 1),
      tur: tur,
      tutar: tutar,
      vadeTarihi: vade,
      createdAtUtc: _t,
      lastModifiedUtc: _t,
    );

void main() {
  final simdi = DateTime(2026, 4, 10, 12);

  group('Don', () {
    test('3 gün içindeki ≤2 °C geceler; tarlalar aynı günde birleşir, bildirim önceki akşam 18:00', () {
      final u = donUyarilari({
        'Kuzey': [_gun(DateTime(2026, 4, 11), -3), _gun(DateTime(2026, 4, 12), 5), _gun(DateTime(2026, 4, 15), -5)],
        'Güney': [_gun(DateTime(2026, 4, 11), 1)],
      }, simdi);
      expect(u, hasLength(1)); // 15'i 3 günden uzak, 12'si sıcak
      expect(u.first.baslik, contains('Kuvvetli don'));
      expect(u.first.metin, contains('Kuzey, Güney')); // en soğuk önce
      expect(u.first.bildirimZamani, DateTime(2026, 4, 10, 18));
      expect(u.first.oncelik, 0);
    });

    test('Don, bildirimi gelmeden ekranda görünür; geçmiş gün gösterilmez', () {
      final u = donUyarilari({'K': [_gun(DateTime(2026, 4, 12), 1.5)]}, simdi);
      expect(u.single.baslik, contains('kırağı'));
      expect(aktifUyarilar(u, simdi), hasLength(1));
      expect(aktifUyarilar(u, DateTime(2026, 4, 13, 8)), isEmpty);
    });
  });

  group('Vade', () {
    test('Ödeme en erken vadeyi kapatır; kalan vade için 2 gün önce ve vade sabahı uyarı', () {
      final hareketler = [
        _cari(HareketTuru.veresiye, 1000, vade: DateTime(2026, 4, 1)),
        _cari(HareketTuru.veresiye, 3000, vade: DateTime(2026, 4, 20)),
        _cari(HareketTuru.odeme, 1500),
      ];
      final vadeler = acikVadeler(hareketler);
      expect(vadeler.single.vade, DateTime(2026, 4, 20));
      expect(vadeler.single.acik, 2500);

      final cari = CariEntity(id: 'bayi', ad: 'Yılmaz Tarım', createdAtUtc: _t, lastModifiedUtc: _t);
      final u = vadeUyarilari([cari], hareketler, simdi);
      expect(u.map((e) => e.bildirimZamani), [DateTime(2026, 4, 18, 9), DateTime(2026, 4, 20, 9)]);
      expect(u.first.metin, contains('2.500 ₺'));
      expect(aktifUyarilar(u, simdi), isEmpty);
      // Vade geçince grubun son uyarısı "vadesi geçti" olarak kalır.
      final sonra = vadeUyarilari([cari], hareketler, DateTime(2026, 4, 25));
      final aktif = aktifUyarilar(sonra, DateTime(2026, 4, 25));
      expect(aktif.single.baslik, contains('vadesi geçti'));
      expect(aktif.single.oncelik, 0);
    });

    test('cariDurumu acikVadeler ile aynı sonucu verir', () {
      final d = cariDurumu([
        _cari(HareketTuru.veresiye, 1000, vade: DateTime(2026, 4, 1)),
        _cari(HareketTuru.satis, 400, vade: DateTime(2026, 5, 1)),
      ], simdi);
      expect(d.vadesiGecen, 1000);
      expect(d.yaklasanVade, DateTime(2026, 5, 1));
      expect(d.bakiye, 600);
    });
  });

  group('Hatırlatma', () {
    test('Kaç gün önce ve son gün; ileri kurulan bildirim o günün gözüyle yazılır', () {
      final u = hatirlatmaUyarilari([_hat(DateTime(2026, 5, 1), once: 15)], simdi);
      expect(u.map((e) => e.bildirimZamani), [DateTime(2026, 4, 16, 9), DateTime(2026, 5, 1, 9)]);
      expect(u.first.baslik, 'ÇKS (15 gün kaldı)');
      expect(u.last.baslik, 'ÇKS (bugün son gün)');
    });

    test('Tamamlanan uyarı vermez; tarihi geçen acil görünür', () {
      expect(hatirlatmaUyarilari([_hat(DateTime(2026, 4, 1), tamam: true)], simdi), isEmpty);
      final aktif = aktifUyarilar(hatirlatmaUyarilari([_hat(DateTime(2026, 4, 5))], simdi), simdi);
      expect(aktif.single.baslik, contains('tarihi geçti'));
      expect(aktif.single.oncelik, 0);
    });

    test('Yapıldı: her yıl olan bir yıl ileri (29 Şubat → 28 Şubat), diğeri tamamlanır', () {
      expect(yapildiSonrasi(_hat(DateTime(2028, 2, 29), herYil: true)), (tarih: DateTime(2029, 2, 28), tamamlandi: false));
      expect(yapildiSonrasi(_hat(DateTime(2026, 4, 5))).tamamlandi, isTrue);
    });

    test('Gün saat dilimiyle kaymadan saklanır', () {
      final h = _hat(DateTime(2026, 11, 30));
      final geri = HatirlatmaModel.fromRow(HatirlatmaModel.toRow(h));
      expect(HatirlatmaModel.toRow(h)['tarih'], '2026-11-30');
      expect(geri.gun, DateTime(2026, 11, 30));
    });
  });

  test('Ekranda önce acil olanlar, sonra güne göre', () {
    final u = aktifUyarilar([
      ...hatirlatmaUyarilari([_hat(DateTime(2026, 4, 12))], simdi),
      ...donUyarilari({'K': [_gun(DateTime(2026, 4, 11), -1)]}, simdi),
    ], simdi);
    expect(u.map((e) => e.tur), [UyariTuru.don, UyariTuru.hatirlatma]);
  });

  group('Bildirim ayarları', () {
    test('Varsayılan hepsi açık; kapatılan tür süzülür, tekrar açılabilir', () {
      const a = BildirimAyarlari();
      expect(UyariTuru.values.every(a.acik), isTrue);
      final uyarilar = [
        ...donUyarilari({'K': [_gun(DateTime(2026, 4, 11), -1)]}, simdi),
        ...hatirlatmaUyarilari([_hat(DateTime(2026, 4, 12))], simdi),
      ];
      final donKapali = a.degistir(UyariTuru.don, false);
      expect(donKapali.suz(uyarilar).map((u) => u.tur).toSet(), {UyariTuru.hatirlatma});
      expect(donKapali.degistir(UyariTuru.don, true).suz(uyarilar), hasLength(uyarilar.length));
    });

    test('Kodlama gidip gelir; bozuk ya da boş kayıt varsayılana döner', () {
      final a = const BildirimAyarlari().degistir(UyariTuru.vade, false).degistir(UyariTuru.don, false);
      expect(BildirimAyarlari.coz(a.kodla()).kapali, {UyariTuru.vade, UyariTuru.don});
      expect(BildirimAyarlari.coz(null).kapali, isEmpty);
      expect(BildirimAyarlari.coz('bozuk').kapali, isEmpty);
      expect(BildirimAyarlari.coz('{"kapali":["bilinmeyen","vade"]}').kapali, {UyariTuru.vade});
    });
  });

  test('Bildirim kimliği kararlı ve pozitif', () {
    expect(bildirimKimligi('don:2026-04-11'), bildirimKimligi('don:2026-04-11'));
    expect(bildirimKimligi('a'), isNot(bildirimKimligi('b')));
    expect(bildirimKimligi('x' * 200), greaterThanOrEqualTo(0));
  });
}
