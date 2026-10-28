namespace KayinBackend.Application.Common.Interfaces;

/// <summary>
/// Hastalık tarama fotoğraflarının kalıcı deposu (disk, ileride nesne deposu).
/// Erişim kontrolü çağıran tarafta yapılır; depo yalnızca dosyayı saklar.
/// </summary>
public interface IFotografDeposu
{
    Task KaydetAsync(Guid kullaniciId, Guid taramaId, byte[] icerik, CancellationToken ct);

    /// <summary>Fotoğraf yoksa null.</summary>
    Stream? Ac(Guid kullaniciId, Guid taramaId);
}
