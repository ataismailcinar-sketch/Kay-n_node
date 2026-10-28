using KayinBackend.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.AkilliSulama.Queries;

// ── Response DTO ─────────────────────────────────────────────────────────────
public record SulamaKayitDto(
    Guid     Id,
    Guid     ParselId,
    string   ParselAd,
    DateTime KayitTarihi,
    double   YagisMillimetre,
    double   ToprakNemiYuzde,
    string   KayitTuru,
    string   AciliyetSeviyesi
);

/// <summary>Son N günlük sulama/yağış özetini döndürür.</summary>
public record GetSulamaOzetiQuery(
    Guid ParselId,
    int  GunSayisi = 7
) : IRequest<List<SulamaKayitDto>>;

public class GetSulamaOzetiQueryHandler
    : IRequestHandler<GetSulamaOzetiQuery, List<SulamaKayitDto>>
{
    private readonly IApplicationDbContext _db;
    public GetSulamaOzetiQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<List<SulamaKayitDto>> Handle(
        GetSulamaOzetiQuery request, CancellationToken ct)
    {
        var sinirTarih = DateTime.UtcNow.Date.AddDays(-request.GunSayisi);

        return await _db.YagisSulamaKayitlari
            .AsNoTracking()
            .Where(y => y.ParselId == request.ParselId &&
                        !y.IsDeleted &&
                        y.KayitTarihi >= sinirTarih)
            .OrderByDescending(y => y.KayitTarihi)
            .Join(_db.Parseller,
                y => y.ParselId,
                p => p.Id,
                (y, p) => new SulamaKayitDto(
                    y.Id,
                    y.ParselId,
                    p.Ad,
                    y.KayitTarihi,
                    y.YagisMillimetre,
                    y.ToprakNemiYuzde,
                    y.KayitTuru,
                    y.AciliyetSeviyesi))
            .ToListAsync(ct);
    }
}

/// <summary>Tüm parsellerin bugünkü toprak nemi + aciliyetini döndürür (dashboard için).</summary>
public record GetTumParsellerNemDurumuQuery : IRequest<List<ParselNemDurumuDto>>;

public record ParselNemDurumuDto(
    Guid   ParselId,
    string ParselAd,
    double AlanDonum,
    double SonToprakNemi,
    double SonYagis,
    string AciliyetSeviyesi,
    DateTime? SonKayitTarihi
);

public class GetTumParsellerNemDurumuQueryHandler
    : IRequestHandler<GetTumParsellerNemDurumuQuery, List<ParselNemDurumuDto>>
{
    private readonly IApplicationDbContext _db;
    public GetTumParsellerNemDurumuQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<List<ParselNemDurumuDto>> Handle(
        GetTumParsellerNemDurumuQuery request, CancellationToken ct)
    {
        var parseller = await _db.Parseller
            .AsNoTracking()
            .Where(p => !p.IsDeleted)
            .ToListAsync(ct);

        var sonuclar = new List<ParselNemDurumuDto>();

        foreach (var p in parseller)
        {
            var sonKayit = await _db.YagisSulamaKayitlari
                .AsNoTracking()
                .Where(y => y.ParselId == p.Id && !y.IsDeleted)
                .OrderByDescending(y => y.KayitTarihi)
                .FirstOrDefaultAsync(ct);

            sonuclar.Add(new ParselNemDurumuDto(
                p.Id,
                p.Ad,
                p.AlanDonumCinsinden,
                sonKayit?.ToprakNemiYuzde ?? 50.0,
                sonKayit?.YagisMillimetre ?? 0.0,
                sonKayit?.AciliyetSeviyesi ?? "Normal",
                sonKayit?.KayitTarihi));
        }

        // Aciliyete göre sırala (Acil önce)
        return sonuclar
            .OrderBy(r => r.AciliyetSeviyesi switch
            {
                "Acil"    => 0,
                "Normal"  => 1,
                "Yeterli" => 2,
                _         => 3,
            })
            .ToList();
    }
}
