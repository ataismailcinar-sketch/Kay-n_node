import 'package:dio/dio.dart';
import 'sunucu_adresi.dart';

/// Uygulama genelinde tek Dio instance'ı — Singleton.
/// SyncManager ve diğer repository'ler bunu kullanır.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Giriş yapılınca OturumNotifier tarafından atanır; her isteğe eklenir.
  String? token;

  /// Sunucu token'ı reddettiğinde (401) çağrılır — oturum süresi dolmuş ya da iptal edilmiş.
  /// Giriş/kayıt isteklerindeki 401 (yanlış şifre) bunu tetiklemez.
  void Function()? onYetkisiz;

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: SunucuAdresi.api,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.addAll([
      // ── Oturum token'ı ───────────────────────────────────────────────
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Adres giriş ekranından değiştirilebilir; her istekte güncel olanı kullan.
          options.baseUrl = SunucuAdresi.api;
          final t = token;
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 && !error.requestOptions.path.startsWith('/auth/')) {
            onYetkisiz?.call();
          }
          handler.next(error);
        },
      ),
      // ── Loglama interceptor (debug) ─────────────────────────────────
      // Gövde ve başlıklar loglanmaz: giriş isteğinde şifre, başlıkta ve yanıtta token bulunur.
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseBody: false, // Büyük pull yanıtları loglanmasın
        logPrint: (obj) => debugLog(obj.toString()),
      ),
      // ── Hata işleme interceptor ──────────────────────────────────────
      InterceptorsWrapper(
        onError: (error, handler) {
          // Bağlantı hatası → offline mod, sessizce devam
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                message: 'Çevrimdışı: ${error.message}',
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            handler.next(error);
          }
        },
      ),
    ]);

  void debugLog(String message) {
    // ignore: avoid_print
    assert(() {
      print('[ApiClient] $message');
      return true;
    }());
  }
}
