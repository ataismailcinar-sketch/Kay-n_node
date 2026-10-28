using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Tarla/Parsel entity'si. Kullanıcının haritada çizdiği poligon sınırlarını,
/// dönüm hesabını ve parsel meta verilerini tutar.
/// </summary>
public class Parsel : BaseEntity
{
    /// <summary>
    /// Parsele verilen isim (örn: "Kuzey Tarla", "Bahçe").
    /// </summary>
    public string Ad { get; set; } = string.Empty;

    /// <summary>
    /// Parselin bulunduğu köy/ilçe.
    /// </summary>
    public string Konum { get; set; } = string.Empty;

    /// <summary>
    /// Haritada çizilen poligonun koordinat dizisi.
    /// JSON formatında saklanır: [ {lat, lng}, {lat, lng}, ... ]
    /// Örn: "[{\"lat\":39.92,\"lng\":32.85},{\"lat\":39.93,\"lng\":32.86}]"
    /// </summary>
    public string PoligonKoordinatlariJson { get; set; } = "[]";

    /// <summary>
    /// Hesaplanmış alan — dönüm cinsinden (1 dönüm = 1000 m²).
    /// Poligon kaydedilirken Flutter/sunucu tarafında hesaplanır.
    /// </summary>
    /// <summary>
    /// Tarlaya ekilen ürün türü (Örn: Buğday, Mısır, Ayçiçeği, Pamuk)
    /// </summary>
    public string EkilmisUrun { get; set; } = "Buğday";

    /// <summary>
    /// Toprak bünyesi / türü (Örn: Tınlı, Killi, Kumlu, Kireçli).
    /// Toprak su tutma kapasitesi ve sulama aciliyeti hesabında kullanılır.
    /// </summary>
    public string ToprakTuru { get; set; } = "Tınlı";

    /// <summary>
    /// true: sulu tarım, false: kuru tarım (yalnız yağışla), null: belirtilmedi.
    /// </summary>
    public bool? Sulu { get; set; }

    /// <summary>Sulu tarlada: Damla, Yagmurlama, Salma. Null = belirtilmedi.</summary>
    public string? SulamaYontemi { get; set; }

    /// <summary>Sulu tarlada: Kuyu, Kanal (DSİ / sulama birliği), Dere, Golet. Null = belirtilmedi.</summary>
    public string? SuKaynagi { get; set; }

    /// <summary>Sulama suyunun tuzluluğu (ECw), dS/m. Null = ölçülmedi.</summary>
    public double? SuEc { get; set; }

    /// <summary>
    /// Ürünün ekildiği tarih (fenolojik evre ve takvim hesabı için).
    /// </summary>
    public DateTime? EkimTarihi { get; set; }

    public double AlanDonumCinsinden { get; set; } = 0.0;

    /// <summary>
    /// Parselin merkez koordinatı — enlem (latitude). Harita önizlemesi için.
    /// </summary>
    public double MerkezLat { get; set; } = 0.0;

    /// <summary>
    /// Parselin merkez koordinatı — boylam (longitude). Harita önizlemesi için.
    /// </summary>
    public double MerkezLng { get; set; } = 0.0;

    /// <summary>
    /// Bu parsele ait sulama kayıtları (navigation property).
    /// </summary>
    public ICollection<YagisSulamaKayit> SulamaKayitlari { get; set; } = new List<YagisSulamaKayit>();

    /// <summary>
    /// Bu parsele ait hastalık tarama kayıtları (navigation property).
    /// </summary>
    public ICollection<HastalikTarama> HastalıkTaramalari { get; set; } = new List<HastalikTarama>();
}
