using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// İş günlüğü kaydı: bir tarlada yapılan iş (ilaçlama, gübreleme, sulama, ekim, hasat...).
/// İlaçlamada çiftçi ürün etiketindeki hasat öncesi bekleme süresini girer; uygulama
/// bu süreye göre "hasat edilemez" uyarısı gösterir.
/// </summary>
public class IsKaydi : BaseEntity
{
    public Guid ParselId { get; set; }
    public Parsel? Parsel { get; set; }

    public DateTime IslemTarihi { get; set; } = DateTime.UtcNow;

    /// <summary>Kod (ASCII): Ilaclama, Gubreleme, Sulama, Ekim, Hasat, ToprakIsleme, Diger.</summary>
    public string IslemTuru { get; set; } = "Diger";

    /// <summary>Kullanılan ürün (ilaç/gübre/tohum adı) — çiftçinin yazdığı serbest metin.</summary>
    public string UrunAdi { get; set; } = string.Empty;

    /// <summary>Miktar / doz — etiketten, serbest metin (ör. "2 L/da", "20 kg/da").</summary>
    public string Miktar { get; set; } = string.Empty;

    /// <summary>Ürün etiketindeki hasat öncesi bekleme süresi (gün). Yalnızca ilaçlamada anlamlı.</summary>
    public int? HasatBeklemeGun { get; set; }

    /// <summary>Hasat edilen ürün miktarı (kg). Yalnızca hasatta anlamlı; verim hesabı bundan yapılır.</summary>
    public double? HasatKg { get; set; }

    public string Not { get; set; } = string.Empty;
}
