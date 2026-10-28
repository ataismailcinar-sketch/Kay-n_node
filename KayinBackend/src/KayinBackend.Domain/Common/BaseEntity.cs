namespace KayinBackend.Domain.Common;

/// <summary>
/// Tüm entity'lerin türediği temel sınıf.
/// KURAL: PK zorunlu olarak Guid'dir. Auto-increment YASAK.
/// Senkronizasyon için CreatedAtUtc, LastModifiedUtc ve IsDeleted zorunludur.
/// </summary>
public abstract class BaseEntity
{
    /// <summary>
    /// Birincil anahtar — UUID/Guid. Çakışmasız offline kayıt için client tarafında üretilir.
    /// </summary>
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>
    /// Kaydın sahibi. Sunucu tarafından giriş yapan kullanıcıdan atanır; istemci gönderemez.
    /// Tüm sorgular bu alana göre otomatik filtrelenir (ApplicationDbContext).
    /// </summary>
    public Guid KullaniciId { get; set; }

    /// <summary>
    /// Kaydın sunucuya (UTC) ilk oluşturulma zamanı.
    /// </summary>
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Son güncelleme zamanı (UTC). Last-Write-Wins sync kuralı bu alana dayanır.
    /// </summary>
    public DateTime LastModifiedUtc { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Yumuşak silme (soft delete) bayrağı. Gerçek DELETE yerine bu alan kullanılır
    /// ki senkronizasyonda silme işlemi mobil cihazlara da yansısın.
    /// </summary>
    public bool IsDeleted { get; set; } = false;
}
