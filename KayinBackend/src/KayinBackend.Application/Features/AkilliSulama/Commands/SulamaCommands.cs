using KayinBackend.Application.Common.Guvenlik;
using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Domain.Entities;
using MediatR;

namespace KayinBackend.Application.Features.AkilliSulama.Commands;

/// <summary>Kullanıcının manuel sulama girişi.</summary>
public record ManuelSulamaKaydetCommand(
    Guid   ParselId,
    double SulamaLitre,
    DateTime? SulamaTarihi = null
) : IRequest<Guid>;

public class ManuelSulamaKaydetCommandHandler
    : IRequestHandler<ManuelSulamaKaydetCommand, Guid>
{
    private readonly IApplicationDbContext _db;
    public ManuelSulamaKaydetCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task<Guid> Handle(ManuelSulamaKaydetCommand req, CancellationToken ct)
    {
        await ParselErisimi.KontrolEt(_db, req.ParselId, ct);

        var kayit = new YagisSulamaKayit
        {
            Id               = Guid.NewGuid(),
            ParselId         = req.ParselId,
            KayitTarihi      = req.SulamaTarihi?.Date ?? DateTime.UtcNow.Date,
            YagisMillimetre  = 0,
            ToprakNemiYuzde  = 0,  // Bir sonraki cron'da hesaplanacak
            KayitTuru        = "Manuel",
            ManuelSulamaLitre = req.SulamaLitre,
            AciliyetSeviyesi  = "Yeterli", // Manuel sulama → su yeterli
        };

        _db.YagisSulamaKayitlari.Add(kayit);
        await _db.SaveChangesAsync(ct);
        return kayit.Id;
    }
}
