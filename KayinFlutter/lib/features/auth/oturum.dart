import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/api_client.dart';
import '../../core/services/hava_durumu_servisi.dart';
import '../akilli_sulama/presentation/providers/sulama_provider.dart';
import '../bildirimler/presentation/bildirim_provider.dart';
import '../toprak_analizi/presentation/toprak_analizi_provider.dart';
import '../depo/presentation/depo_provider.dart';
import '../is_gunlugu/presentation/is_gunlugu_provider.dart';
import '../veresiye/presentation/veresiye_provider.dart';
import '../klavyesiz_muhasebe/presentation/providers/muhasebe_provider.dart';
import '../parsel_harita/presentation/providers/parsel_provider.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_provider.dart';
import '../yaprak_hastalik_ai/presentation/providers/hastalik_tarama_provider.dart';

/// Giriş yapmış kullanıcı ve sunucunun verdiği token.
class Oturum {
  final String token;
  final DateTime bitisUtc;
  final String kullaniciId;
  final String telefon;
  final String adSoyad;

  const Oturum({
    required this.token,
    required this.bitisUtc,
    required this.kullaniciId,
    required this.telefon,
    required this.adSoyad,
  });

  bool get suresiDoldu => DateTime.now().toUtc().isAfter(bitisUtc);

  /// "5321234567" → "0532 123 45 67"
  String get telefonMetni => telefon.length == 10
      ? '0${telefon.substring(0, 3)} ${telefon.substring(3, 6)} ${telefon.substring(6, 8)} ${telefon.substring(8)}'
      : telefon;

  /// Sunucunun /auth/giris ve /auth/kayit yanıtı.
  factory Oturum.sunucuYanitindan(Map<String, dynamic> j) {
    final k = j['kullanici'] as Map<String, dynamic>;
    return Oturum(
      token: j['token'] as String,
      bitisUtc: DateTime.parse(j['bitisUtc'] as String).toUtc(),
      kullaniciId: (k['id'] as String).toLowerCase(),
      telefon: k['telefon'] as String,
      adSoyad: k['adSoyad'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'bitisUtc': bitisUtc.toIso8601String(),
        'kullaniciId': kullaniciId,
        'telefon': telefon,
        'adSoyad': adSoyad,
      };

  factory Oturum.fromJson(Map<String, dynamic> j) => Oturum(
        token: j['token'] as String,
        bitisUtc: DateTime.parse(j['bitisUtc'] as String).toUtc(),
        kullaniciId: j['kullaniciId'] as String,
        telefon: j['telefon'] as String,
        adSoyad: j['adSoyad'] as String? ?? '',
      );
}

/// Sunucuyla aynı kural (TelefonNumarasi.Normalize): "0532 123 45 67" → "5321234567". Geçersizse null.
String? telefonNormalize(String girdi) {
  var r = girdi.replaceAll(RegExp(r'\D'), '');
  if (r.startsWith('90') && r.length == 12) {
    r = r.substring(2);
  } else if (r.startsWith('0') && r.length == 11) {
    r = r.substring(1);
  }
  return r.length == 10 && r.startsWith('5') ? r : null;
}

// ════════════════════════════════════════════════════════════════════════════
// Kalıcı depolama
// ════════════════════════════════════════════════════════════════════════════

/// Oturum ve "bu cihazdaki verinin sahibi" bilgisi.
abstract class OturumDeposu {
  Future<Oturum?> oku();
  Future<void> yaz(Oturum oturum);
  Future<void> oturumuSil();

  /// Yerel veritabanındaki kayıtların ait olduğu kullanıcı. Token düşse de korunur;
  /// böylece aynı kullanıcı tekrar girince verisi silinmez.
  Future<String?> veriSahibi();
  Future<void> veriSahibiYaz(String? kullaniciId);
}

/// Android Keystore / Windows Kimlik Bilgisi Yöneticisi.
class GuvenliOturumDeposu implements OturumDeposu {
  static const _oturumAnahtari = 'oturum';
  static const _sahipAnahtari = 'veri_sahibi';
  final _depo = const FlutterSecureStorage();

  @override
  Future<Oturum?> oku() async {
    try {
      final metin = await _depo.read(key: _oturumAnahtari);
      return metin == null ? null : Oturum.fromJson(jsonDecode(metin) as Map<String, dynamic>);
    } catch (_) {
      return null; // bozuk/okunamayan kayıt → yeniden giriş
    }
  }

  @override
  Future<void> yaz(Oturum oturum) => _depo.write(key: _oturumAnahtari, value: jsonEncode(oturum.toJson()));

  @override
  Future<void> oturumuSil() => _depo.delete(key: _oturumAnahtari);

  @override
  Future<String?> veriSahibi() => _depo.read(key: _sahipAnahtari);

  @override
  Future<void> veriSahibiYaz(String? kullaniciId) => kullaniciId == null
      ? _depo.delete(key: _sahipAnahtari)
      : _depo.write(key: _sahipAnahtari, value: kullaniciId);
}

final oturumDeposuProvider = Provider<OturumDeposu>((_) => GuvenliOturumDeposu());

// ════════════════════════════════════════════════════════════════════════════
// Sunucu çağrıları
// ════════════════════════════════════════════════════════════════════════════

/// Kullanıcıya gösterilecek giriş/kayıt hatası.
class AuthHatasi implements Exception {
  final String mesaj;
  const AuthHatasi(this.mesaj);
  @override
  String toString() => mesaj;
}

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<Oturum> giris({required String telefon, required String sifre}) =>
      _istek('/auth/giris', {'telefon': telefon, 'sifre': sifre});

  Future<Oturum> kayit({required String adSoyad, required String telefon, required String sifre}) =>
      _istek('/auth/kayit', {'adSoyad': adSoyad, 'telefon': telefon, 'sifre': sifre});

  Future<Oturum> _istek(String yol, Map<String, dynamic> govde) async {
    try {
      final r = await _dio.post(yol, data: govde);
      return Oturum.sunucuYanitindan(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final kod = e.response?.statusCode;
      final baslik = (e.response?.data is Map) ? (e.response!.data as Map)['title'] as String? : null;
      throw AuthHatasi(switch (kod) {
        401 => 'Telefon numarası veya şifre hatalı.',
        429 => 'Çok fazla deneme yapıldı. 1 dakika bekleyip tekrar deneyin.',
        400 => baslik ?? 'Bilgileri kontrol edin.',
        null => 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.',
        _ => 'Sunucu hatası ($kod). Biraz sonra tekrar deneyin.',
      });
    }
  }
}

final authApiProvider = Provider<AuthApi>((_) => AuthApi(ApiClient().dio));

/// Yerel veritabanı işlemleri (testlerde değiştirilebilsin diye provider).
final yerelVeriProvider = Provider<YerelVeri>((_) => YerelVeri());

class YerelVeri {
  Future<int> kayitSayisi({bool sadeceGonderilmemis = false}) =>
      DatabaseHelper().kayitSayisi(sadeceGonderilmemis: sadeceGonderilmemis);
  Future<void> tumunuSil() async {
    await DatabaseHelper().tumVerileriSil();
    // Tarama fotoğrafları da hesaba aittir (hastalik_tarama_provider kalıcı kopyaları).
    try {
      final klasor = Directory(p.join((await getApplicationSupportDirectory()).path, 'tarama_fotograflari'));
      if (await klasor.exists()) await klasor.delete(recursive: true);
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Oturum durumu
// ════════════════════════════════════════════════════════════════════════════

/// null = giriş yapılmamış (giriş ekranı gösterilir).
class OturumNotifier extends AsyncNotifier<Oturum?> {
  OturumDeposu get _depo => ref.read(oturumDeposuProvider);
  YerelVeri get _yerel => ref.read(yerelVeriProvider);

  @override
  Future<Oturum?> build() async {
    ApiClient().onYetkisiz = oturumDustu;
    final oturum = await _depo.oku();
    if (oturum == null || oturum.suresiDoldu) {
      ApiClient().token = null;
      return null;
    }
    ApiClient().token = oturum.token;
    return oturum;
  }

  /// Bu oturum açılırsa silinecek yerel kayıt sayısı (cihazdaki veri başka bir
  /// hesaba ya da girişsiz döneme aitse). 0 ise hiçbir şey silinmez.
  Future<int> silinecekKayitSayisi(Oturum yeni) async {
    if (await _depo.veriSahibi() == yeni.kullaniciId) return 0;
    return _yerel.kayitSayisi();
  }

  /// Giriş/kayıttan dönen oturumu etkinleştirir. Cihazdaki veri bu kullanıcıya ait
  /// değilse silinir; sunucudaki veri sonraki senkronizasyonda iner.
  Future<void> oturumAc(Oturum oturum) async {
    if (await _depo.veriSahibi() != oturum.kullaniciId) {
      await _yerel.tumunuSil();
      await _depo.veriSahibiYaz(oturum.kullaniciId);
    }
    await _depo.yaz(oturum);
    ApiClient().token = oturum.token;
    _ekranlariTazele();
    state = AsyncData(oturum);
    // İlk senkronizasyonu hemen başlat (zamanlayıcıyı beklemeden).
    ref.read(autoSyncProvider.notifier).syncNow();
  }

  /// Çıkış: yerel veri ve oturum silinir.
  Future<void> cikis() async {
    await _yerel.tumunuSil();
    await _depo.veriSahibiYaz(null);
    await _depo.oturumuSil();
    ApiClient().token = null;
    _ekranlariTazele();
    state = const AsyncData(null);
  }

  /// Sunucu token'ı reddetti (süresi doldu). Veri silinmez; aynı kullanıcı tekrar
  /// girince gönderilmemiş kayıtları kaybolmadan senkronize edilir.
  Future<void> oturumDustu() async {
    if (state.valueOrNull == null) return;
    await _depo.oturumuSil();
    ApiClient().token = null;
    state = const AsyncData(null);
  }

  void _ekranlariTazele() {
    HavaDurumuServisi.onbellegiTemizle();
    ref.invalidate(parselListeProvider);
    ref.invalidate(sulamaListeProvider);
    ref.invalidate(giderListeProvider);
    ref.invalidate(giderGirisProvider);
    ref.invalidate(hastalikTaramaListeProvider);
    ref.invalidate(isKaydiListeProvider);
    ref.invalidate(cariListeProvider);
    ref.invalidate(cariHareketListeProvider);
    ref.invalidate(stokKalemListeProvider);
    ref.invalidate(stokHareketListeProvider);
    ref.invalidate(hatirlatmaListeProvider);
    ref.invalidate(bildirimAyarlariProvider); // sync_meta silindi → varsayılana döner
    ref.invalidate(toprakAnalizListeProvider);
    ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    ref.read(lastSyncResultProvider.notifier).state = null;
  }
}

final oturumProvider = AsyncNotifierProvider<OturumNotifier, Oturum?>(OturumNotifier.new);
