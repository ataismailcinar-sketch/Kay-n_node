# Kayın Tarım

Çevrimdışı çalışan (offline-first) tarım yönetim uygulaması: tarla haritası, otomatik
hava/toprak nemi takibi, sulama-ilaçlama-gübreleme kararları, klavyesiz muhasebe ve
yaprak hastalığı tanıma.

- `lib/` — Flutter uygulaması (Riverpod, SQLite, Open-Meteo)
- `../KayinBackend/` — .NET Web API (senkronizasyon sunucusu)

## Gereksinimler

- Flutter SDK (Dart ≥ 3.3)
- Windows derlemesi için Visual Studio (C++ masaüstü iş yükü)
- Backend için .NET SDK

## Önemli: Türkçe karakterli klasör yolu

Flutter'ın Windows derleyicisi yolda `ü`, `ı` gibi karakterler olunca dosyaları bulamıyor
(`Masaüstü`, `Kayın_node`). Ya projeyi yalnızca İngilizce karakterli bir klasöre taşıyın
ya da klasörü geçici bir sürücü harfine bağlayıp oradan çalışın:

```powershell
subst K: "C:\Users\ata\OneDrive\Masaüstü\Kayın_node"
cd K:\KayinFlutter
flutter build windows --release
subst K: /D
```

Sürücü kökünden (`K:\`) değil, alt klasörden (`K:\KayinFlutter`) derleyin; kökte de
yol hatası oluşuyor. Yol değiştiyse önce `flutter clean` çalıştırın.

## Çalıştırma

```powershell
flutter pub get
flutter run -d windows
```

Çıktı: `build\windows\x64\runner\Release\kayin_flutter.exe`

### Android

```powershell
flutter build apk --debug
```

Çıktı: `build\app\outputs\flutter-apk\app-debug.apk` (uygulama kimliği `com.kayin.tarim`).
Telefon USB'den bağlıysa doğrudan `flutter run` da çalışır.

Sunucu adresi derlemede verilir (verilmezse `http://localhost:5000/api`):

```powershell
# Telefon ve bilgisayar aynı Wi-Fi'de
flutter run --dart-define=API_URL=http://192.168.1.20:5000/api
# Android emülatörü
flutter run --dart-define=API_URL=http://10.0.2.2:5000/api
```

Wi-Fi'den bağlanılacaksa backend'i tüm ağ arayüzlerinde dinlet:
`dotnet run --urls http://0.0.0.0:5000`. Şifresiz `http://` yalnızca debug derlemede
açıktır (`android/app/src/debug/AndroidManifest.xml`); release derlemede sunucu HTTPS olmalı.

### Backend

```powershell
cd ..\KayinBackend\src\KayinBackend.WebApi
dotnet run --launch-profile http
```

`http` profili geliştirme ortamında `http://localhost:5000` adresinde açılır; JWT
anahtarı `appsettings.Development.json` içindedir. Veritabanı şeması açılışta
migration ile kurulur/güncellenir. Şema değişince yeni migration:

```powershell
cd ..\KayinBackend\src
dotnet ef migrations add <Ad> --project KayinBackend.Infrastructure --startup-project KayinBackend.WebApi --output-dir Persistence/Migrations
```

Tarama fotoğrafları sunucuda `App_Data/fotograflar/` altında tutulur (ayar:
`Fotograflar:Klasor`); bu klasör yedeklenmelidir.

Üretimde (Development dışında) sunucu yalnızca HTTPS kabul eder ve JWT anahtarı
ortam değişkeninden okunur; anahtar yoksa sunucu başlamaz:
`Jwt__Anahtar=<en az 32 karakter rastgele>`.

### Giriş ve veri ayrımı

- Telefon + şifre ile kayıt/giriş. Her kullanıcı sunucuda yalnızca kendi tarla,
  muhasebe, sulama ve tarama kayıtlarını görür.
- Token (90 gün) cihazın güvenli deposunda tutulur; ilk girişten sonra uygulama
  internetsiz açılır.
- Cihazda başka hesaba ya da girişsiz kullanıma ait veri varsa girişte kullanıcıya
  sorulup silinir. Çıkışta yerel veri silinir (gönderilmemiş kayıt varsa uyarılır).
- Oturum süresi dolarsa aynı kullanıcı tekrar girince yerel verisi korunur.

Uygulama sunucuyu varsayılan olarak `http://localhost:5000/api` adresinde arar
(`lib/core/constants/app_constants.dart`); giriş ekranındaki "Sunucu: …" satırından
başka adres girilebilir. Sunucu kapalıysa uygulama yerel modda
çalışmaya devam eder; veriler bağlantı gelince senkronize edilir. Telefonla USB
üzerinden denerken: `adb reverse tcp:5000 tcp:5000`.

## Test

```powershell
flutter test
flutter analyze
```

`tool/` klasöründeki betikler test değil, motorların çıktısını elle incelemek içindir:
`dart run tool/zirai_karar_runner.dart`.

## Yaprak hastalık modeli

Model ve sınırlamaları için `assets/models/MODEL_BILGISI.md` dosyasına bakın
(MobileNetV3, 35 sınıf: buğday, arpa, ayçiçeği, pamuk, şeker pancarı, mercimek, domates,
üzüm; mısır, patates, zeytin vb. modelde yok, elle seçilir). Eğitim hattı:
`tool/model_egitimi/`.

## Yol haritası

Yapılacak işler `../PLAN.md` dosyasında.
