using KayinBackend.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.HastalikTaramaFeature.Queries;

public record HastalikTaramaDto(
    Guid Id,
    Guid? ParselId,
    DateTime TaramaTarihi,
    string TeshisAdi,
    double GuvenYuzdesi,
    string TumSinifOlasiliklariJson,
    string FotografYerelYolu,
    string ModelVersionu,
    string AciliyetSeviyesi,
    bool CevrimdisiAnalizYapildi,
    DateTime CreatedAtUtc
);

public record GetHastalikTaramalarQuery(Guid? ParselId = null) : IRequest<List<HastalikTaramaDto>>;

public class GetHastalikTaramalarQueryHandler : IRequestHandler<GetHastalikTaramalarQuery, List<HastalikTaramaDto>>
{
    private readonly IApplicationDbContext _db;
    public GetHastalikTaramalarQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<List<HastalikTaramaDto>> Handle(GetHastalikTaramalarQuery request, CancellationToken ct)
    {
        var query = _db.HastalikTaramalar
            .AsNoTracking()
            .Where(h => !h.IsDeleted);

        if (request.ParselId.HasValue)
        {
            query = query.Where(h => h.ParselId == request.ParselId.Value);
        }

        return await query
            .OrderByDescending(h => h.TaramaTarihi)
            .Select(h => new HastalikTaramaDto(
                h.Id,
                h.ParselId,
                h.TaramaTarihi,
                h.TeshisAdi,
                h.GüvenYüzdesi,
                h.TumSinifOlasiliklariJson,
                h.FotografYerelYolu,
                h.ModelVersionu,
                h.AciliyetSeviyesi,
                h.CevrimdisiAnalizYapildi,
                h.CreatedAtUtc
            ))
            .ToListAsync(ct);
    }
}
