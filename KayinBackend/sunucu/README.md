# Test ve sunum için sunucuyu bu bilgisayarda çalıştırma

Amaç: hesap, alan adı, modem ayarı gerektirmeden; telefonlar internetten (HTTPS) bağlanabilsin.

## Bir kerelik hazırlık
1. .NET 9 SDK kurulu olmalı (`dotnet --version`).
2. İnternetten erişim isteniyorsa Cloudflare'in `cloudflared.exe` programını
   `%USERPROFILE%\KayinTarimVeri\cloudflared.exe` olarak koyun
   (resmî kaynak: github.com/cloudflare/cloudflared → Releases → `cloudflared-windows-amd64.exe`, adını değiştirin)
   ya da `winget install --id Cloudflare.cloudflared` ile kurun. Hesap gerekmez.

## Başlatma
PowerShell'de:
```
cd KayinBackend\sunucu
.\sunucu_baslat.ps1           # yalnız bu bilgisayar: http://localhost:5000/api
.\sunucu_baslat.ps1 -Tunel    # internetten: https://….trycloudflare.com/api adresini yazar
```
Durdurmak için pencerede Enter.

Tünel adresi **her başlatışta değişir**. Telefonda giriş ekranının altındaki "Sunucu: …" bağlantısına
dokunup yeni adresi girin ("Bağlantıyı dene" ile doğrulayın). Adres `adres.txt` dosyasına da yazılır.
Kalıcı adres için Cloudflare hesabı + alan adı ile "named tunnel" kurulur (sonraki adım).

## Veri nerede?
`%USERPROFILE%\KayinTarimVeri\` (OneDrive dışında; OneDrive açık veritabanını eşitlerken bozabilir):
- `kayin.db` — veritabanı (SQLite)
- `fotograflar\` — hastalık tarama fotoğrafları
- `yedek\` — sunucu açılışından 1 dk sonra ve sonra günde bir: `kayin-YYYYMMDD.db` (son 14 gün) + fotoğraf aynası
- `jwt-anahtar.txt` — oturum imza anahtarı (silinirse herkesin oturumu düşer; **paylaşmayın**)
- `sunucu.log`, `tunel.log`

Yedekten dönmek: sunucuyu durdurun, `kayin.db` (+ varsa `-wal`, `-shm`) dosyalarını kenara alın,
istenen `yedek\kayin-….db` dosyasını `kayin.db` adıyla kopyalayın, sunucuyu başlatın.

## Telefon uygulaması
Sürüm APK'ları `KayinFlutter\build\app\outputs\flutter-apk\`:
- `app-arm64-v8a-release.apk` — günümüz telefonlarının hemen hepsi
- `app-armeabi-v7a-release.apk` — eski / ucuz telefonlar
Sürüm derlemesi yalnız HTTPS'e bağlanır (tünel adresi uygun; `http://192.168…` çalışmaz).
Yerel ağda http ile denemek için geliştirme derlemesi kullanılır.

## Sınırlar (pilot için kabul edilebilir)
- Bilgisayar kapalıyken telefonlar çevrimdışı çalışır, açılınca eşitlenir.
- APK hâlâ geliştirme anahtarıyla imzalı (Play Store'a çıkmadan önce kalıcı anahtar gerekir).
