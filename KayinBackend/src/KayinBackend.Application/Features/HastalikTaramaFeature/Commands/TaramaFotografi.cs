using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Application.Common;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.HastalikTaramaFeature.Commands;

public static class TaramaFotografi
{
    public const int MaksBayt = 5 * 1024 * 1024;

    /// <summary>Dosyanın ilk baytlarından tür: "image/jpeg", "image/png" ya da null (kabul edilmez).</summary>
    public static string? IcerikTuru(ReadOnlySpan<byte> b) =>
        b.Length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF ? "image/jpeg"
        : b.Length >= 8 && b[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }) ? "image/png"
        : null;
}

// ════════════════════════════════════════════════════════════════════════════
// Yükleme
// ════════════════════════════════════════════════════════════════════════════
/// <summary>
/// Taramanın fotoğrafını yükler (varsa üzerine yazar). Tarama önce sync ile gönderilmiş olmalı.
/// </summary>
public record TaramaFotografiYukleCommand(Guid TaramaId, byte[] Icerik) : IRequest;

public class TaramaFotografiYukleCommandHandler(
    IApplicationDbContext db, IAktifKullanici aktif, IFotografDeposu depo)
    : IRequestHandler<TaramaFotografiYukleCommand>
{
    public async Task Handle(TaramaFotografiYukleCommand request, CancellationToken ct)
    {
        var kullaniciId = aktif.KullaniciId ?? throw new UnauthorizedAccessException();

        if (request.Icerik.Length == 0 || request.Icerik.Length > TaramaFotografi.MaksBayt)
            throw new IstekHatasi($"Fotoğraf boş ya da {TaramaFotografi.MaksBayt / 1024 / 1024} MB'tan büyük.");
        if (TaramaFotografi.IcerikTuru(request.Icerik) is null)
            throw new IstekHatasi("Yalnızca JPEG veya PNG fotoğraf yüklenebilir.");

        // Sorgu filtresi: başka kullanıcının taraması "bulunamadı" olur.
        var tarama = await db.HastalikTaramalar.FirstOrDefaultAsync(t => t.Id == request.TaramaId, ct)
            ?? throw new KeyNotFoundException("Tarama bulunamadı.");

        // Konum (EXIF GPS) vb. diske hiç yazılmaz.
        await depo.KaydetAsync(kullaniciId, tarama.Id, FotografMetaTemizleyici.Temizle(request.Icerik), ct);

        // LastModifiedUtc SaveChanges'te güncellenir → diğer cihazlar pull ile FotografVar'ı öğrenir.
        tarama.FotografVar = true;
        await db.SaveChangesAsync(ct);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// İndirme
// ════════════════════════════════════════════════════════════════════════════
public record TaramaFotografiDosyasi(Stream Icerik, string IcerikTuru);

public record TaramaFotografiGetirQuery(Guid TaramaId) : IRequest<TaramaFotografiDosyasi?>;

public class TaramaFotografiGetirQueryHandler(
    IApplicationDbContext db, IAktifKullanici aktif, IFotografDeposu depo)
    : IRequestHandler<TaramaFotografiGetirQuery, TaramaFotografiDosyasi?>
{
    public async Task<TaramaFotografiDosyasi?> Handle(TaramaFotografiGetirQuery request, CancellationToken ct)
    {
        var kullaniciId = aktif.KullaniciId ?? throw new UnauthorizedAccessException();
        if (!await db.HastalikTaramalar.AnyAsync(t => t.Id == request.TaramaId, ct))
            return null;

        var akis = depo.Ac(kullaniciId, request.TaramaId);
        if (akis is null) return null;

        var bas = new byte[8];
        var okunan = await akis.ReadAsync(bas, ct);
        akis.Position = 0;
        return new TaramaFotografiDosyasi(akis, TaramaFotografi.IcerikTuru(bas.AsSpan(0, okunan)) ?? "application/octet-stream");
    }
}
