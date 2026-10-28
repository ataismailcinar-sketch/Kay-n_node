namespace KayinBackend.Application.Common.Interfaces;

/// <summary>
/// İsteği yapan (JWT ile giriş yapmış) kullanıcı.
/// Arka plan servislerinde ve girişsiz isteklerde KullaniciId null'dır.
/// </summary>
public interface IAktifKullanici
{
    Guid? KullaniciId { get; }
}
