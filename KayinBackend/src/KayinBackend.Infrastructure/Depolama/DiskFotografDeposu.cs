using KayinBackend.Application.Common;
using KayinBackend.Application.Common.Interfaces;

namespace KayinBackend.Infrastructure.Depolama;

/// <summary>
/// Fotoğrafları diskte tutar: {kök}/{kullaniciId}/{taramaId}.img
/// Dosya adları yalnızca Guid'lerden oluşur; istemciden gelen ad/yol kullanılmaz.
/// </summary>
public class DiskFotografDeposu(string kokKlasor) : IFotografDeposu
{
    private string Yol(Guid kullaniciId, Guid taramaId) =>
        Path.Combine(kokKlasor, kullaniciId.ToString("N"), taramaId.ToString("N") + ".img");

    public async Task KaydetAsync(Guid kullaniciId, Guid taramaId, byte[] icerik, CancellationToken ct)
    {
        var yol = Yol(kullaniciId, taramaId);
        Directory.CreateDirectory(Path.GetDirectoryName(yol)!);
        // Önce geçici dosyaya yaz, sonra taşı: yarım kalan yükleme eski fotoğrafı bozmasın.
        var gecici = yol + ".tmp";
        await File.WriteAllBytesAsync(gecici, icerik, ct);
        File.Move(gecici, yol, overwrite: true);
    }

    /// <summary>
    /// EXIF temizliğinden önce kaydedilmiş fotoğrafları bir kez temizler (işaret dosyasıyla tekrar etmez).
    /// Döndürülen sayı değişen dosya sayısıdır.
    /// </summary>
    public int EskileriTemizle()
    {
        if (!Directory.Exists(kokKlasor)) return 0;
        var isaret = Path.Combine(kokKlasor, ".meta-temizlendi");
        if (File.Exists(isaret)) return 0;
        var degisen = 0;
        foreach (var yol in Directory.EnumerateFiles(kokKlasor, "*.img", SearchOption.AllDirectories))
        {
            var eski = File.ReadAllBytes(yol);
            var yeni = FotografMetaTemizleyici.Temizle(eski);
            if (yeni.Length == eski.Length && yeni.AsSpan().SequenceEqual(eski)) continue;
            File.WriteAllBytes(yol + ".tmp", yeni);
            File.Move(yol + ".tmp", yol, overwrite: true);
            degisen++;
        }
        File.WriteAllText(isaret, DateTime.UtcNow.ToString("O"));
        return degisen;
    }

    public Stream? Ac(Guid kullaniciId, Guid taramaId)
    {
        var yol = Yol(kullaniciId, taramaId);
        return File.Exists(yol) ? File.OpenRead(yol) : null;
    }
}
