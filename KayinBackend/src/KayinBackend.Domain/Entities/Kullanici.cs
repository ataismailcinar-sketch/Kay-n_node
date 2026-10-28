namespace KayinBackend.Domain.Entities;

/// <summary>
/// Uygulama kullanıcısı (çiftçi). Telefon numarası kullanıcı adıdır.
/// BaseEntity'den türemez: senkronize edilmez ve kendisi bir kullanıcıya ait değildir.
/// </summary>
public class Kullanici
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Normalize edilmiş 10 haneli numara, ör. "5321234567".</summary>
    public string Telefon { get; set; } = string.Empty;

    /// <summary>PBKDF2 özeti (SifreOzeti sınıfının biçiminde). Düz şifre asla saklanmaz.</summary>
    public string SifreOzeti { get; set; } = string.Empty;

    public string AdSoyad { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
