import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayin_flutter/core/network/api_client.dart';
import 'package:kayin_flutter/features/auth/oturum.dart';
import 'package:kayin_flutter/features/sync/sync_manager.dart';
import 'package:kayin_flutter/features/sync/sync_provider.dart';
import 'package:kayin_flutter/main.dart';

import 'oturum_test.dart' show BellekOturumDeposu, SahteYerelVeri;

/// Ağa ve veritabanına dokunmayan sahte senkronizasyon.
class _SahteSync extends SyncManager {
  @override
  Future<SyncResult> syncAll() async =>
      SyncResult(status: SyncStatus.offline, timestamp: DateTime.now());
}

Widget _uygulama(BellekOturumDeposu depo) => ProviderScope(
      overrides: [
        syncManagerProvider.overrideWithValue(_SahteSync()),
        oturumDeposuProvider.overrideWithValue(depo),
        yerelVeriProvider.overrideWithValue(SahteYerelVeri()),
      ],
      child: const KayinTarimApp(),
    );

void main() {
  tearDown(() => ApiClient().token = null);

  testWidgets('Giriş yapılmamışsa giriş ekranı açılır', (tester) async {
    await tester.pumpWidget(_uygulama(BellekOturumDeposu()));
    await tester.pump();

    expect(find.text('Cep Telefonu'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Geçersiz numarada sunucuya gitmeden uyarı verilir.
    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.enterText(find.byType(TextField).last, 'gizli123');
    await tester.tap(find.text('GİRİŞ YAP'));
    await tester.pump();
    expect(find.textContaining('Geçerli bir cep telefonu'), findsOneWidget);
  });

  testWidgets('Giriş yapılmışsa uygulama açılır ve 5 sekme görünür', (tester) async {
    final depo = BellekOturumDeposu(
      oturum: Oturum(
        token: 't',
        bitisUtc: DateTime.now().toUtc().add(const Duration(days: 30)),
        kullaniciId: 'a',
        telefon: '5321234567',
        adSoyad: 'Test',
      ),
      sahip: 'a',
    );
    await tester.pumpWidget(_uygulama(depo));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final sekme in ['Parseller', 'İklim', 'Günlük', 'Muhasebe', 'Hastalık']) {
      expect(find.text(sekme), findsOneWidget);
    }

    // İlk sync'i çalıştır, sonra ağacı kaldır ki periyodik zamanlayıcı iptal olsun.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });
}
