using KayinBackend.Application.Common.Guvenlik;
using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.HastalikTaramaFeature.Commands;

public record CreateHastalikTaramaCommand(
    Guid Id,
    Guid? ParselId,
    DateTime TaramaTarihi,
    string TeshisAdi,
    double GuvenYuzdesi,
    string TumSinifOlasiliklariJson,
    string FotografYerelYolu,
    string ModelVersionu,
    string AciliyetSeviyesi,
    bool CevrimdisiAnalizYapildi
) : IRequest<Guid>;

public class CreateHastalikTaramaCommandHandler : IRequestHandler<CreateHastalikTaramaCommand, Guid>
{
    private readonly IApplicationDbContext _db;
    public CreateHastalikTaramaCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task<Guid> Handle(CreateHastalikTaramaCommand request, CancellationToken ct)
    {
        await ParselErisimi.KontrolEt(_db, request.ParselId, ct);

        var tarama = new HastalikTarama
        {
            Id = request.Id,
            ParselId = request.ParselId,
            TaramaTarihi = request.TaramaTarihi,
            TeshisAdi = request.TeshisAdi,
            GüvenYüzdesi = request.GuvenYuzdesi,
            TumSinifOlasiliklariJson = request.TumSinifOlasiliklariJson,
            FotografYerelYolu = request.FotografYerelYolu,
            ModelVersionu = request.ModelVersionu,
            AciliyetSeviyesi = request.AciliyetSeviyesi,
            CevrimdisiAnalizYapildi = request.CevrimdisiAnalizYapildi
        };

        _db.HastalikTaramalar.Add(tarama);
        await _db.SaveChangesAsync(ct);
        return tarama.Id;
    }
}
