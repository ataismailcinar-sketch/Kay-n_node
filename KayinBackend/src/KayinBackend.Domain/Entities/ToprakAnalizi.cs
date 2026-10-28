using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Tarlanın laboratuvar toprak analizi sonucu. Boş bırakılan değerler null'dır.
/// </summary>
public class ToprakAnalizi : BaseEntity
{
    public Guid ParselId { get; set; }
    public Parsel? Parsel { get; set; }

    public DateTime AnalizTarihi { get; set; }
    public string Laboratuvar { get; set; } = string.Empty;

    /// <summary>Saturasyon (su ile doyma) %, toprak bünyesini verir.</summary>
    public double? Saturasyon { get; set; }
    public double? Ph { get; set; }

    /// <summary>Toplam tuz %.</summary>
    public double? TuzYuzde { get; set; }

    /// <summary>Elektriksel iletkenlik, dS/m (= mS/cm).</summary>
    public double? Ec { get; set; }

    /// <summary>Kireç (CaCO3) %.</summary>
    public double? KirecYuzde { get; set; }
    public double? OrganikMadde { get; set; }

    /// <summary>Alınabilir fosfor, P2O5 kg/dekar.</summary>
    public double? Fosfor { get; set; }

    /// <summary>Alınabilir potasyum, K2O kg/dekar.</summary>
    public double? Potasyum { get; set; }

    /// <summary>Çinko (DTPA), ppm.</summary>
    public double? Cinko { get; set; }

    public string Not { get; set; } = string.Empty;
}
