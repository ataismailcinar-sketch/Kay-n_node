import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/sunucu_adresi.dart';
import '../../core/theme/app_theme.dart';
import 'oturum.dart';

/// Telefon + şifre ile giriş / kayıt. İlk girişte internet gerekir; sonrasında
/// token cihazda saklandığı için uygulama çevrimdışı açılır.
class GirisEkrani extends ConsumerStatefulWidget {
  const GirisEkrani({super.key});

  @override
  ConsumerState<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends ConsumerState<GirisEkrani> {
  static const _minSifre = 6; // sunucudaki KayitOlCommandHandler.MinSifreUzunlugu ile aynı

  final _adSoyad = TextEditingController();
  final _telefon = TextEditingController();
  final _sifre = TextEditingController();
  bool _kayitModu = false;
  bool _sifreGizli = true;
  bool _bekliyor = false;
  String? _hata;

  @override
  void dispose() {
    _adSoyad.dispose();
    _telefon.dispose();
    _sifre.dispose();
    super.dispose();
  }

  String? _yerelKontrol() {
    if (_kayitModu && _adSoyad.text.trim().isEmpty) return 'Adınızı girin.';
    if (telefonNormalize(_telefon.text) == null) return 'Geçerli bir cep telefonu numarası girin (ör. 0532 123 45 67).';
    if (_sifre.text.length < (_kayitModu ? _minSifre : 1)) {
      return _kayitModu ? 'Şifre en az $_minSifre karakter olmalı.' : 'Şifrenizi girin.';
    }
    return null;
  }

  Future<void> _gonder() async {
    FocusScope.of(context).unfocus();
    final yerelHata = _yerelKontrol();
    if (yerelHata != null) {
      setState(() => _hata = yerelHata);
      return;
    }
    setState(() {
      _bekliyor = true;
      _hata = null;
    });

    try {
      final api = ref.read(authApiProvider);
      final oturum = _kayitModu
          ? await api.kayit(adSoyad: _adSoyad.text.trim(), telefon: _telefon.text, sifre: _sifre.text)
          : await api.giris(telefon: _telefon.text, sifre: _sifre.text);

      final notifier = ref.read(oturumProvider.notifier);
      final silinecek = await notifier.silinecekKayitSayisi(oturum);
      if (silinecek > 0 && !await _silmeOnayi(silinecek)) {
        setState(() => _bekliyor = false);
        return;
      }
      await notifier.oturumAc(oturum);
    } on AuthHatasi catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  Future<bool> _silmeOnayi(int sayi) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu cihazdaki kayıtlar silinecek'),
        content: Text(
          'Bu cihazda başka bir hesaba ya da girişsiz kullanıma ait $sayi kayıt (tarla, muhasebe, tarama) var. '
          'Giriş yapınca bunlar silinir ve hesabınızın kayıtları sunucudan yüklenir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil ve Giriş Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return onay ?? false;
  }

  /// Test/sunum: sunucu adresini değiştir (ör. her başlatışta değişen tünel adresi).
  Future<void> _sunucuDegistir() async {
    final yeni = await showDialog<String>(context: context, builder: (_) => const _SunucuAdresiPenceresi());
    if (yeni == null) return;
    await SunucuAdresi.ayarla(yeni.isEmpty ? null : yeni);
    if (mounted) setState(() => _hata = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const alanStili = TextStyle(fontSize: 18);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.agriculture_rounded, size: 72, color: AppTheme.primaryMint),
                    const SizedBox(height: 8),
                    Text(
                      'Kayın Tarım',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Giriş Yap'), icon: Icon(Icons.login_rounded)),
                        ButtonSegment(value: true, label: Text('Kayıt Ol'), icon: Icon(Icons.person_add_rounded)),
                      ],
                      selected: {_kayitModu},
                      onSelectionChanged: _bekliyor
                          ? null
                          : (s) => setState(() {
                                _kayitModu = s.first;
                                _hata = null;
                              }),
                    ),
                    const SizedBox(height: 20),
                    if (_kayitModu) ...[
                      TextField(
                        controller: _adSoyad,
                        style: alanStili,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Adınız Soyadınız', prefixIcon: Icon(Icons.person_rounded)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _telefon,
                      style: alanStili,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Cep Telefonu',
                        hintText: '0532 123 45 67',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _sifre,
                      style: alanStili,
                      obscureText: _sifreGizli,
                      textInputAction: TextInputAction.done,
                      autofillHints: [_kayitModu ? AutofillHints.newPassword : AutofillHints.password],
                      onSubmitted: (_) => _bekliyor ? null : _gonder(),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        helperText: _kayitModu ? 'En az $_minSifre karakter' : null,
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_sifreGizli ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          tooltip: _sifreGizli ? 'Şifreyi göster' : 'Şifreyi gizle',
                          onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
                        ),
                      ),
                    ),
                    if (_hata != null) ...[
                      const SizedBox(height: 14),
                      Text(_hata!, style: const TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _bekliyor ? null : _gonder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryMint,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _bekliyor
                            ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text(
                                _kayitModu ? 'KAYIT OL' : 'GİRİŞ YAP',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'İlk girişte internet gerekir. Sonra uygulama internetsiz de çalışır; '
                      'kayıtlarınız bağlantı olunca hesabınıza gönderilir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _bekliyor ? null : _sunucuDegistir,
                      icon: const Icon(Icons.dns_rounded, size: 18),
                      label: Text(
                        'Sunucu: ${Uri.tryParse(SunucuAdresi.api)?.host ?? SunucuAdresi.api}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adres girişi + "Bağlantıyı dene". Kaydet: düzeltilmiş adres; "Varsayılan": boş metin döner.
class _SunucuAdresiPenceresi extends StatefulWidget {
  const _SunucuAdresiPenceresi();

  @override
  State<_SunucuAdresiPenceresi> createState() => _SunucuAdresiPenceresiState();
}

class _SunucuAdresiPenceresiState extends State<_SunucuAdresiPenceresi> {
  late final _c = TextEditingController(text: SunucuAdresi.varsayilan ? '' : SunucuAdresi.api);
  String? _durum;
  bool _basarili = false;
  bool _deniyor = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _dene() async {
    final adres = SunucuAdresi.duzelt(_c.text);
    if (adres == null) {
      setState(() => _durum = 'Geçersiz adres.');
      return;
    }
    setState(() {
      _deniyor = true;
      _durum = null;
    });
    try {
      final r = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), validateStatus: (_) => true))
          .get('$adres/auth/ben');
      // Girişsiz istekte 401 = sunucu ayakta ve doğru yerde.
      _basarili = r.statusCode == 401 || r.statusCode == 200;
      _durum = _basarili ? '✅ Sunucuya ulaşıldı.' : 'Yanıt geldi ama Kayın sunucusu değil (${r.statusCode}).';
    } catch (_) {
      _basarili = false;
      _durum = 'Ulaşılamadı. Adres doğru mu, sunucu açık mı?';
    }
    if (mounted) setState(() => _deniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sunucu Adresi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _c,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Adres',
              hintText: 'ornek.trycloudflare.com',
              helperText: 'Varsayılan: ${AppConstants.apiBaseUrl}',
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() => _durum = null),
          ),
          if (_durum != null) ...[
            const SizedBox(height: 10),
            Text(_durum!, style: TextStyle(color: _basarili ? AppTheme.successColor : AppTheme.dangerColor)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Varsayılan')),
        TextButton(onPressed: _deniyor ? null : _dene, child: Text(_deniyor ? 'Deneniyor…' : 'Bağlantıyı dene')),
        FilledButton(
          onPressed: () {
            final adres = SunucuAdresi.duzelt(_c.text);
            if (adres == null) {
              setState(() => _durum = 'Geçersiz adres.');
              return;
            }
            Navigator.pop(context, adres);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}