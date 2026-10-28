using KayinBackend.Domain.Common;

namespace KayinBackend.Domain.Entities;

/// <summary>
/// Muhasebe gider kayıt entity'si.
/// Tarım giderleri: mazot, gübre, ilaç, işçilik vb.
/// Zero-Keyboard UI'dan "butonlarla" girilir, TextField YOKTUR.
/// </summary>
public class MuhasebeGider : BaseEntity
{
    /// <summary>
    /// Giderin bağlı olduğu parsel — isteğe bağlı (null ise genel gider).
    /// </summary>
    public Guid? ParselId { get; set; }

    /// <summary>
    /// İşlem türü: "Gider" veya "Gelir" (hasat satışı, destekleme vb.)
    /// </summary>
    public string IslemTuru { get; set; } = "Gider";

    /// <summary>
    /// Gider/Gelir kategorisi — sabit listeden seçilir.
    /// Geçerli değerler: "Mazot", "Gubre", "Ilac", "Iscilik", "Tohum", "Hasat", "Destek", "Diger"
    /// </summary>
    public string Kategori { get; set; } = "Diger";

    /// <summary>
    /// Alt kategori / ürün adı — önceden tanımlı çiplerden seçilir.
    /// Örn: Gübre için "Ure", "DAP", "Kompoze" | İlaç için "Herbisit", "Fungusit"
    /// </summary>
    public string AltKategori { get; set; } = string.Empty;

    /// <summary>
    /// Gider tutarı — Türk Lirası (TRY) cinsinden.
    /// +500, +1000, +5000 butonlarıyla artırılır.
    /// </summary>
    public decimal Tutar { get; set; } = 0m;

    /// <summary>
    /// Para birimi — varsayılan TRY.
    /// </summary>
    public string ParaBirimi { get; set; } = "TRY";

    /// <summary>
    /// Giderin gerçekleştiği tarih.
    /// </summary>
    public DateTime GiderTarihi { get; set; } = DateTime.UtcNow.Date;

    /// <summary>
    /// İsteğe bağlı kısa not — voice-to-text ile eklenebilir (ileride).
    /// </summary>
    public string? Not { get; set; }
}
