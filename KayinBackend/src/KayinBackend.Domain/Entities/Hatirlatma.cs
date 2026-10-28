using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Çiftçinin kendi girdiği tarihli hatırlatma (ÇKS, destek başvurusu, TARSİM poliçesi...).
/// Bildirim zamanı telefonda hesaplanır.
/// </summary>
public class Hatirlatma : BaseEntity
{
    public string Baslik { get; set; } = string.Empty;

    /// <summary>Cks, Destek, Tarsim, Diger.</summary>
    public string Tur { get; set; } = "Diger";

    /// <summary>Son gün / olay tarihi.</summary>
    public DateTime Tarih { get; set; }

    /// <summary>Kaç gün önceden uyarılsın.</summary>
    public int KacGunOnce { get; set; } = 7;

    /// <summary>Her yıl aynı gün tekrar eder (yapıldı denince bir yıl ileri alınır).</summary>
    public bool HerYil { get; set; }

    public bool Tamamlandi { get; set; }
    public string Not { get; set; } = string.Empty;
}
