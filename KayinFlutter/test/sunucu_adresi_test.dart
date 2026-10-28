import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/constants/app_constants.dart';
import 'package:kayin_flutter/core/network/sunucu_adresi.dart';
import 'package:kayin_flutter/core/theme/app_theme.dart';
import 'package:kayin_flutter/features/auth/giris_ekrani.dart';

void main() {
  testWidgets('Giriş ekranından sunucu adresi değiştirilir ve varsayılana döndürülür', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: AppTheme.lightTheme, home: const GirisEkrani())));

    await tester.tap(find.textContaining('Sunucu:'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'abc-def.trycloudflare.com/');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(SunucuAdresi.api, 'https://abc-def.trycloudflare.com/api');
    expect(find.text('Sunucu: abc-def.trycloudflare.com'), findsOneWidget);

    await tester.tap(find.textContaining('Sunucu:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Varsayılan'));
    await tester.pumpAndSettle();
    expect(SunucuAdresi.api, AppConstants.apiBaseUrl);
  });

  test('Adres düzeltme: şema, sondaki /, /api eklenir; geçersiz reddedilir', () {
    expect(SunucuAdresi.duzelt('ornek.trycloudflare.com'), 'https://ornek.trycloudflare.com/api');
    expect(SunucuAdresi.duzelt(' https://ornek.trycloudflare.com/ '), 'https://ornek.trycloudflare.com/api');
    expect(SunucuAdresi.duzelt('https://a.b/api/'), 'https://a.b/api');
    expect(SunucuAdresi.duzelt('http://192.168.1.20:5000'), 'http://192.168.1.20:5000/api');
    expect(SunucuAdresi.duzelt(''), isNull);
    expect(SunucuAdresi.duzelt('ftp://a.b'), isNull);
  });
}
