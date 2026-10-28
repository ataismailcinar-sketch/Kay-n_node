using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Yağış ve sulama kaydı entity'si.
/// Hem harici hava durumu API'sinden otomatik çekilen yağış verilerini,
/// hem de kullanıcının manuel girdiği sulama bilgilerini tutar.
/// </summary>
public class YagisSulamaKayit : BaseEntity
{
    /// <summary>
    /// Bağlı olduğu parsel — Foreign Key (Guid).
    /// </summary>
    public Guid ParselId { get; set; }

    /// <summary>
    /// Navigation property — bağlı Parsel nesnesi.
    /// </summary>
    public Parsel? Parsel { get; set; }

    /// <summary>
    /// Kaydın ait olduğu tarih (UTC, sadece gün kısmı önemli).
    /// </summary>
    public DateTime KayitTarihi { get; set; } = DateTime.UtcNow.Date;

    /// <summary>
    /// Gün içinde düşen yağış miktarı — milimetre (mm) cinsinden.
    /// 0 = yağış yok. Harici API'den doldurulur.
    /// </summary>
    public double YagisMillimetre { get; set; } = 0.0;

    /// <summary>
    /// Tahmini toprak nemi yüzdesi (0–100).
    /// Hesaplama: Önceki gün nem + yağış katkısı − buharlaşma.
    /// </summary>
    public double ToprakNemiYuzde { get; set; } = 0.0;

    /// <summary>
    /// Kayıt türü: "Otomatik" (API'den) veya "Manuel" (kullanıcı).
    /// </summary>
    public string KayitTuru { get; set; } = "Otomatik";

    /// <summary>
    /// Manuel sulama miktarı — litre cinsinden (yalnızca KayitTuru == "Manuel").
    /// </summary>
    public double ManuelSulamaLitre { get; set; } = 0.0;

    /// <summary>
    /// Sulama aciliyeti seviyesi.
    /// "Acil" = kırmızı uyarı, "Normal" = yeşil, "Yeterli" = mavi.
    /// </summary>
    public string AciliyetSeviyesi { get; set; } = "Normal";

    /// <summary>
    /// Harici hava durumu API'sinin döndürdüğü ham JSON — ileride referans için.
    /// </summary>
    public string HawaApiHamVeriJson { get; set; } = "{}";
}
