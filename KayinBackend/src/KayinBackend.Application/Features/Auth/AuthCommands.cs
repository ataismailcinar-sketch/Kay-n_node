using KayinBackend.Application.Common;
using KayinBackend.Application.Common.Guvenlik;
using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.Auth;

public record KullaniciDto(Guid Id, string Telefon, string AdSoyad);

// ════════════════════════════════════════════════════════════════════════════
// Kayıt
// ════════════════════════════════════════════════════════════════════════════
public record KayitOlCommand(string AdSoyad, string Telefon, string Sifre) : IRequest<KullaniciDto>;

public class KayitOlCommandHandler(IApplicationDbContext db) : IRequestHandler<KayitOlCommand, KullaniciDto>
{
    public const int MinSifreUzunlugu = 6;

    public async Task<KullaniciDto> Handle(KayitOlCommand request, CancellationToken ct)
    {
        var telefon = TelefonNumarasi.Normalize(request.Telefon)
            ?? throw new IstekHatasi("Geçerli bir cep telefonu numarası girin (ör. 0532 123 45 67).");
        if ((request.Sifre ?? "").Length < MinSifreUzunlugu)
            throw new IstekHatasi($"Şifre en az {MinSifreUzunlugu} karakter olmalı.");
        var adSoyad = (request.AdSoyad ?? "").Trim();
        if (adSoyad.Length == 0)
            throw new IstekHatasi("Adınızı girin.");

        if (await db.Kullanicilar.AnyAsync(k => k.Telefon == telefon, ct))
            throw new IstekHatasi("Bu numarayla zaten kayıt var. Giriş yapın.");

        var kullanici = new Kullanici
        {
            Telefon = telefon,
            AdSoyad = adSoyad.Length > 100 ? adSoyad[..100] : adSoyad,
            SifreOzeti = SifreOzeti.Olustur(request.Sifre!),
        };
        db.Kullanicilar.Add(kullanici);
        await db.SaveChangesAsync(ct);

        return new KullaniciDto(kullanici.Id, kullanici.Telefon, kullanici.AdSoyad);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Giriş
// ════════════════════════════════════════════════════════════════════════════
/// <summary>Başarısızsa null döner; numara mı şifre mi yanlış, ayırt edilmez.</summary>
public record GirisYapCommand(string Telefon, string Sifre) : IRequest<KullaniciDto?>;

public class GirisYapCommandHandler(IApplicationDbContext db) : IRequestHandler<GirisYapCommand, KullaniciDto?>
{
    // Kayıtlı olmayan numarada da aynı süre harcansın (numara var mı, yanıt süresinden anlaşılmasın).
    private static readonly string SahteOzet = SifreOzeti.Olustur(Guid.NewGuid().ToString());

    public async Task<KullaniciDto?> Handle(GirisYapCommand request, CancellationToken ct)
    {
        var telefon = TelefonNumarasi.Normalize(request.Telefon);
        var kullanici = telefon is null
            ? null
            : await db.Kullanicilar.AsNoTracking().FirstOrDefaultAsync(k => k.Telefon == telefon, ct);

        var dogru = SifreOzeti.Dogrula(request.Sifre ?? "", kullanici?.SifreOzeti ?? SahteOzet);
        return kullanici is not null && dogru
            ? new KullaniciDto(kullanici.Id, kullanici.Telefon, kullanici.AdSoyad)
            : null;
    }
}
