import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/services/hava_durumu_servisi.dart';
import 'package:kayin_flutter/core/theme/app_theme.dart';
import 'package:kayin_flutter/features/akilli_sulama/presentation/providers/sulama_provider.dart';
import 'package:kayin_flutter/features/parsel_harita/domain/entities/parsel_entity.dart';
import 'package:kayin_flutter/features/parsel_harita/presentation/providers/parsel_provider.dart';
import 'package:kayin_flutter/features/parsel_harita/presentation/widgets/parsel_detay_sheet.dart';

final _parsel = ParselEntity(
  id: 'p1',
  ad: 'Büyük Ova Tarlası',
  ekilmisUrun: 'Mısır',
  konum: '',
  poligonNoktalar: const [],
  alanDonumCinsinden: 230.3,
  merkezLat: 0,
  merkezLng: 0,
  createdAtUtc: DateTime.utc(2026),
  lastModifiedUtc: DateTime.utc(2026),
);

class _SabitParseller extends ParselListeNotifier {
  @override
  Future<List<ParselEntity>> build() async => [_parsel];
}

void main() {
  testWidgets('Düzenleme formu (uygulama temasıyla) hatasız çizilir, alttaki sekmeleri aşağı iter, üstlerine binmez (klavye açık)', (tester) async {
    // Test yazı tipi gerçekten geniş; metrik kartlarındaki yatay taşma uyarısı burada önemsiz.
    final eski = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed')) eski?.call(d);
    };
    addTearDown(() => FlutterError.onError = eski);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        parselListeProvider.overrideWith(_SabitParseller.new),
        parselHavaProvider.overrideWith((ref, p) async => TarlaHavaOzeti(
              bugunYagisMm: 0,
              bugunMaxSicaklik: 19.7,
              bugunMinSicaklik: 3.1,
              bugunRuzgarHiziKm: 7,
              sonYediGun: [
                for (var i = 1; i <= 7; i++)
                  GunlukHavaVerisi(
                      tarih: DateTime(2026, 10, 22 - i),
                      yagisMm: 0,
                      maxSicaklik: 18,
                      minSicaklik: 3,
                      maxRuzgarHizi: 7,
                      buharlasmaEt0: 2.5),
              ],
              gelecekYediGunTahmin: const [],
              guncelToprakNemiYuzde: 41,
              canliVeri: false,
            )),
      ],
      child: MaterialApp(
        // Uygulamanın teması şart: tam genişlik düğme teması satır içindeki düğmeyi çökertiyordu.
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(onPressed: () => ParselDetaySheet.show(context, _parsel), child: const Text('aç')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('İsim, Ürün ve Toprak Değiştir'));
    // Klavye açılıyormuş gibi alt boşluk.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final kaydet = tester.getRect(find.text('Kaydet'));
    final sekme = tester.getRect(find.text('🌍 Uygunluk'));
    final sonUrun = tester.getRect(find.text('Üzüm'));
    expect(sonUrun.bottom, lessThanOrEqualTo(kaydet.top), reason: 'ürünler kaydet düğmesinin üstünde');
    expect(kaydet.bottom, lessThanOrEqualTo(sekme.top), reason: 'form sekmelerin üstünde bitmeli');
  });
}
