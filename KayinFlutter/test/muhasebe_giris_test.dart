import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/features/klavyesiz_muhasebe/domain/entities/gider_entity.dart';
import 'package:kayin_flutter/features/klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';

void main() {
  late ProviderContainer c;
  GiderGirisNotifier n() => c.read(giderGirisProvider.notifier);
  GiderGirisState s() => c.read(giderGirisProvider);

  setUp(() => c = ProviderContainer());
  tearDown(() => c.dispose());

  test('Tuş takımıyla serbest tutar girilir (3.750 TL)', () {
    for (final r in ['3', '7', '5', '0']) {
      n().rakamEkle(r);
    }
    expect(s().tutar, 3750);
    n().haneSil();
    expect(s().tutar, 375);
    n().rakamEkle('000');
    expect(s().tutar, 375000);
  });

  test('Tutar üst sınırı aşılamaz', () {
    for (var i = 0; i < 12; i++) {
      n().rakamEkle('9');
    }
    expect(s().tutar, 99999999);
  });

  test('Hızlı ekleme tuş takımıyla birlikte çalışır', () {
    n().rakamEkle('250');
    n().tutarEkle(1000);
    expect(s().tutar, 1250);
  });

  test('Geçmiş gün seçilince kayıt o günün öğlesine yazılır', () {
    final dun = DateTime.now().subtract(const Duration(days: 1));
    final z = islemZamani(DateTime(dun.year, dun.month, dun.day)).toLocal();
    expect([z.year, z.month, z.day, z.hour], [dun.year, dun.month, dun.day, 12]);
  });

  test('Bugün seçiliyse şu anki saat kullanılır', () {
    final once = DateTime.now().toUtc();
    expect(islemZamani(null).isBefore(once), isFalse);
  });

  test('Düzenlemeye alınan kayıt forma yüklenir', () {
    final t = DateTime.utc(2026, 3, 5, 9);
    n().duzenlemeBaslat(GiderEntity(
      id: 'g1',
      islemTuru: 'Gider',
      kategori: 'Mazot',
      altKategori: 'Tarla',
      tutar: 4200,
      giderTarihi: t,
      createdAtUtc: t,
      lastModifiedUtc: t,
    ));
    expect(s().duzenlenen?.id, 'g1');
    expect(s().tutar, 4200);
    expect(s().secilenKategori, 'Mazot');
    expect(s().tarih?.day, t.toLocal().day);

    n().duzenlemeIptal();
    expect(s().duzenlenen, isNull);
    expect(s().tutar, 0);
  });
}
