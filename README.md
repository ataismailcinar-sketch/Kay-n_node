# Kayın Tarım

Çiftçi için çevrimdışı çalışan (offline-first) tarım yönetim uygulaması ve senkronizasyon sunucusu.

- **Tarla haritası** ve tarla karnesi (hasat, verim, gider/gelir, 1 kg ürün maliyeti)
- **İklim ve sulama**: hava tahmini, toprak nemi, sulama ihtiyacı (yöntem randımanı, su tuzluluğu), ilaçlama penceresi, don uyarısı
- **Toprak analizi**: laboratuvar raporunu fotoğraftan okuma (telefonda OCR), ürün uygunluğu
- **Hastalık Rehberi**: telefonda çalışan yaprak hastalığı modeli (35 sınıf) + ilaç etki grubu önerileri
- **Klavyesiz muhasebe**, veresiye defteri, girdi stoku, iş günlüğü, hatırlatmalar

## Klasörler

| Klasör | İçerik |
|---|---|
| `KayinFlutter/` | Flutter uygulaması (Android + Windows). Ayrıntı: [KayinFlutter/README.md](KayinFlutter/README.md) |
| `KayinBackend/` | .NET 9 Web API (giriş, kullanıcı ayrımı, senkronizasyon, fotoğraf). Sunucuyu çalıştırma: [KayinBackend/sunucu/README.md](KayinBackend/sunucu/README.md) |
| `PLAN.md` | Yapılanlar ve açık işler |

## Hızlı başlangıç

```powershell
# Sunucu (geliştirme, http://localhost:5000)
cd KayinBackend\src\KayinBackend.WebApi
dotnet run --launch-profile http

# Uygulama
cd KayinFlutter
flutter pub get
flutter run
```

Klasör yolunda Türkçe karakter varsa Flutter derlemesi için `KayinFlutter/README.md` içindeki `subst` notuna bakın.

## Güvenlik notları

- `appsettings.Development.json` içindeki JWT anahtarı **yalnız geliştirme** içindir. Üretimde anahtar
  `Jwt__Anahtar` ortam değişkeninden okunur (`sunucu_baslat.ps1` bunu kendisi üretir); yoksa sunucu başlamaz.
- Veritabanı (`*.db`), sunucu fotoğrafları (`App_Data/`), yerel test hesapları (`*.local.txt`) ve
  imza anahtarları (`*.jks`, `key.properties`) depoya girmez (`.gitignore`).

## Lisanslar

Yaprak modeli CC BY 4.0 lisanslı açık veri setleriyle eğitildi; kaynaklar ve atıflar:
[KayinFlutter/tool/model_egitimi/VERI_KAYNAKLARI.md](KayinFlutter/tool/model_egitimi/VERI_KAYNAKLARI.md).
