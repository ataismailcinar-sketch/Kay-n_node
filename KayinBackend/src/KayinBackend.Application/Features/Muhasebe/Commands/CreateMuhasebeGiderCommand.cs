using KayinBackend.Application.Common.Guvenlik;
using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.Muhasebe.Commands;

public record CreateMuhasebeGiderCommand(
    Guid Id,
    Guid? ParselId,
    string? IslemTuru,
    string Kategori,
    string AltKategori,
    decimal Tutar,
    string ParaBirimi,
    DateTime GiderTarihi,
    string? Not
) : IRequest<Guid>;

public class CreateMuhasebeGiderCommandHandler : IRequestHandler<CreateMuhasebeGiderCommand, Guid>
{
    private readonly IApplicationDbContext _db;
    public CreateMuhasebeGiderCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task<Guid> Handle(CreateMuhasebeGiderCommand request, CancellationToken ct)
    {
        await ParselErisimi.KontrolEt(_db, request.ParselId, ct);

        var gider = new MuhasebeGider
        {
            Id = request.Id,
            ParselId = request.ParselId,
            IslemTuru = string.IsNullOrWhiteSpace(request.IslemTuru) ? "Gider" : request.IslemTuru,
            Kategori = request.Kategori,
            AltKategori = request.AltKategori,
            Tutar = request.Tutar,
            ParaBirimi = string.IsNullOrWhiteSpace(request.ParaBirimi) ? "TRY" : request.ParaBirimi,
            GiderTarihi = request.GiderTarihi,
            Not = request.Not
        };

        _db.MuhasebeGiderler.Add(gider);
        await _db.SaveChangesAsync(ct);
        return gider.Id;
    }
}
