using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Veresiye defterindeki hesap: bayi, tüccar, kooperatif ya da kişi.
/// Bakiye saklanmaz; hareketlerden hesaplanır (senkronizasyonda çakışma olmasın diye).
/// </summary>
public class Cari : BaseEntity
{
    public string Ad { get; set; } = string.Empty;

    /// <summary>Kod: Bayi, Tuccar, Kooperatif, Kisi.</summary>
    public string Tur { get; set; } = "Bayi";

    public string Telefon { get; set; } = string.Empty;
    public string Not { get; set; } = string.Empty;
}

/// <summary>
/// Veresiye hareketi. Tutar her zaman pozitif; yönü <see cref="Tur"/> belirler:
/// Veresiye (aldım, borcum arttı), Odeme (ödedim), Satis (veresiye sattım, alacağım arttı), Tahsilat (tahsil ettim).
/// </summary>
public class CariHareket : BaseEntity
{
    public Guid CariId { get; set; }
    public Cari? Cari { get; set; }

    public DateTime IslemTarihi { get; set; } = DateTime.UtcNow;
    public string Tur { get; set; } = "Veresiye";
    public decimal Tutar { get; set; }

    /// <summary>Ödeme günü (yalnızca Veresiye/Satis). Geçtiyse uygulama uyarır.</summary>
    public DateTime? VadeTarihi { get; set; }

    public string Aciklama { get; set; } = string.Empty;

    /// <summary>Bu hareketle birlikte oluşturulan muhasebe kaydı (gider/gelir), varsa.</summary>
    public Guid? MuhasebeKaydiId { get; set; }
}
