using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Depodaki girdi (gübre, ilaç, tohum, mazot...). Mevcut miktar saklanmaz; hareketlerden hesaplanır.
/// </summary>
public class StokKalemi : BaseEntity
{
    public string Ad { get; set; } = string.Empty;

    /// <summary>Muhasebe kategori kodlarıyla aynı: Gubre, Ilac, Tohum, Mazot, Diger.</summary>
    public string Kategori { get; set; } = "Diger";

    /// <summary>kg, L, cuval, adet...</summary>
    public string Birim { get; set; } = "kg";

    /// <summary>Mevcut bu değerin altına inince uyarı. Null = uyarı yok.</summary>
    public double? KritikSeviye { get; set; }
}

/// <summary>
/// Stok hareketi. Giris/Cikis'ta miktar pozitif; Duzeltme (sayım) işaretlidir.
/// </summary>
public class StokHareketi : BaseEntity
{
    public Guid KalemId { get; set; }
    public StokKalemi? Kalem { get; set; }

    public DateTime IslemTarihi { get; set; } = DateTime.UtcNow;

    /// <summary>Giris, Cikis, Duzeltme.</summary>
    public string Tur { get; set; } = "Giris";
    public double Miktar { get; set; }
    public string Aciklama { get; set; } = string.Empty;

    /// <summary>Bu çıkışı oluşturan iş günlüğü kaydı (ilaçlama/gübreleme), varsa.</summary>
    public Guid? IsKaydiId { get; set; }
}
