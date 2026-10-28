import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Sunucu (API) adresi. Varsayılan derlemede verilir (`--dart-define=API_URL`); kullanıcı giriş ekranından
/// değiştirebilir (test/sunum: her başlatışta değişen tünel adresi). Cihazda saklanır, hesap değişince silinmez.
class SunucuAdresi {
  static const _anahtar = 'sunucu_adresi';
  static const _depo = FlutterSecureStorage();

  static String _deger = AppConstants.apiBaseUrl;

  /// Örn. `https://ornek.trycloudflare.com/api`
  static String get api => _deger;
  static bool get varsayilan => _deger == AppConstants.apiBaseUrl;

  /// Uygulama açılışında bir kez.
  static Future<void> yukle() async {
    try {
      final kayitli = await _depo.read(key: _anahtar);
      if (kayitli != null && kayitli.isNotEmpty) _deger = kayitli;
    } catch (_) {}
  }

  /// Kullanıcının yazdığını düzeltir: şema yoksa https eklenir, sondaki "/" atılır, "/api" yoksa eklenir.
  /// Geçersizse null.
  static String? duzelt(String girdi) {
    var s = girdi.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'https://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.endsWith('/api')) s = '$s/api';
    final u = Uri.tryParse(s);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
    return s;
  }

  /// Boş ya da null verilirse varsayılana döner.
  static Future<void> ayarla(String? adres) async {
    final varsay = adres == null || adres == AppConstants.apiBaseUrl;
    _deger = varsay ? AppConstants.apiBaseUrl : adres;
    try {
      varsay ? await _depo.delete(key: _anahtar) : await _depo.write(key: _anahtar, value: adres);
    } catch (_) {
      // Güvenli depo yoksa (test, bozuk anahtar deposu) bu oturumluk geçerli kalır.
    }
  }
}
