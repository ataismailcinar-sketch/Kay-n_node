using KayinBackend.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.Parsel.Queries;

// ── Response DTO ─────────────────────────────────────────────────────────────
public record ParselDto(
    Guid   Id,
    string Ad,
    string EkilmisUrun,
    string ToprakTuru,
    DateTime? EkimTarihi,
    string Konum,
    string PoligonKoordinatlariJson,
    double AlanDonumCinsinden,
    double MerkezLat,
    double MerkezLng,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc
);

// ── Tüm aktif parselleri getir ────────────────────────────────────────────────
public record GetParsellerQuery : IRequest<List<ParselDto>>;

public class GetParsellerQueryHandler : IRequestHandler<GetParsellerQuery, List<ParselDto>>
{
    private readonly IApplicationDbContext _db;
    public GetParsellerQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<List<ParselDto>> Handle(GetParsellerQuery request, CancellationToken ct)
        => await _db.Parseller
            .AsNoTracking()
            .Where(p => !p.IsDeleted)
            .OrderBy(p => p.Ad)
            .Select(p => new ParselDto(
                p.Id,
                p.Ad,
                p.EkilmisUrun,
                p.ToprakTuru,
                p.EkimTarihi,
                p.Konum,
                p.PoligonKoordinatlariJson,
                p.AlanDonumCinsinden,
                p.MerkezLat,
                p.MerkezLng,
                p.CreatedAtUtc,
                p.LastModifiedUtc))
            .ToListAsync(ct);
}

// ── Tek parsel getir (ID ile) ─────────────────────────────────────────────────
public record GetParselByIdQuery(Guid Id) : IRequest<ParselDto?>;

public class GetParselByIdQueryHandler : IRequestHandler<GetParselByIdQuery, ParselDto?>
{
    private readonly IApplicationDbContext _db;
    public GetParselByIdQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<ParselDto?> Handle(GetParselByIdQuery request, CancellationToken ct)
        => await _db.Parseller
            .AsNoTracking()
            .Where(p => p.Id == request.Id && !p.IsDeleted)
            .Select(p => new ParselDto(
                p.Id,
                p.Ad,
                p.EkilmisUrun,
                p.ToprakTuru,
                p.EkimTarihi,
                p.Konum,
                p.PoligonKoordinatlariJson,
                p.AlanDonumCinsinden,
                p.MerkezLat,
                p.MerkezLng,
                p.CreatedAtUtc,
                p.LastModifiedUtc))
            .FirstOrDefaultAsync(ct);
}
