using KayinBackend.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.Muhasebe.Queries;

public record MuhasebeGiderDto(
    Guid Id,
    Guid? ParselId,
    string IslemTuru,
    string Kategori,
    string AltKategori,
    decimal Tutar,
    string ParaBirimi,
    DateTime GiderTarihi,
    string? Not,
    DateTime CreatedAtUtc
);

public record GetMuhasebeGiderlerQuery(Guid? ParselId = null) : IRequest<List<MuhasebeGiderDto>>;

public class GetMuhasebeGiderlerQueryHandler : IRequestHandler<GetMuhasebeGiderlerQuery, List<MuhasebeGiderDto>>
{
    private readonly IApplicationDbContext _db;
    public GetMuhasebeGiderlerQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<List<MuhasebeGiderDto>> Handle(GetMuhasebeGiderlerQuery request, CancellationToken ct)
    {
        var query = _db.MuhasebeGiderler
            .AsNoTracking()
            .Where(g => !g.IsDeleted);

        if (request.ParselId.HasValue)
        {
            query = query.Where(g => g.ParselId == request.ParselId.Value);
        }

        return await query
            .OrderByDescending(g => g.GiderTarihi)
            .Select(g => new MuhasebeGiderDto(
                g.Id,
                g.ParselId,
                g.IslemTuru,
                g.Kategori,
                g.AltKategori,
                g.Tutar,
                g.ParaBirimi,
                g.GiderTarihi,
                g.Not,
                g.CreatedAtUtc
            ))
            .ToListAsync(ct);
    }
}
