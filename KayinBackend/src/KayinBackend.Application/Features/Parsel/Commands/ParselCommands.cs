using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Domain.Entities;
using MediatR;

namespace KayinBackend.Application.Features.Parsel.Commands;

// ════════════════════════════════════════════════════════════════════════════
// Yeni Parsel Oluştur
// ════════════════════════════════════════════════════════════════════════════

/// <summary>
/// Yeni bir tarla/parsel oluşturma komutu.
/// ID, Flutter tarafında UUID olarak üretilir ve buraya gönderilir.
/// </summary>
public record CreateParselCommand(
    Guid   Id,
    string Ad,
    string EkilmisUrun,
    string ToprakTuru,
    DateTime? EkimTarihi,
    string Konum,
    string PoligonKoordinatlariJson,
    double AlanDonumCinsinden,
    double MerkezLat,
    double MerkezLng
) : IRequest<Guid>;

public class CreateParselCommandHandler : IRequestHandler<CreateParselCommand, Guid>
{
    private readonly IApplicationDbContext _db;
    public CreateParselCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task<Guid> Handle(CreateParselCommand request, CancellationToken ct)
    {
        var parsel = new Domain.Entities.Parsel
        {
            Id                       = request.Id,
            Ad                       = request.Ad,
            EkilmisUrun              = string.IsNullOrWhiteSpace(request.EkilmisUrun) ? "Buğday" : request.EkilmisUrun,
            ToprakTuru               = string.IsNullOrWhiteSpace(request.ToprakTuru) ? "Tınlı" : request.ToprakTuru,
            EkimTarihi               = request.EkimTarihi,
            Konum                    = request.Konum,
            PoligonKoordinatlariJson = request.PoligonKoordinatlariJson,
            AlanDonumCinsinden       = request.AlanDonumCinsinden,
            MerkezLat                = request.MerkezLat,
            MerkezLng                = request.MerkezLng,
        };

        _db.Parseller.Add(parsel);
        await _db.SaveChangesAsync(ct);
        return parsel.Id;
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Mevcut Parseli Güncelle
// ════════════════════════════════════════════════════════════════════════════

public record UpdateParselCommand(
    Guid   Id,
    string Ad,
    string EkilmisUrun,
    string ToprakTuru,
    DateTime? EkimTarihi,
    string Konum,
    string PoligonKoordinatlariJson,
    double AlanDonumCinsinden,
    double MerkezLat,
    double MerkezLng
) : IRequest;

public class UpdateParselCommandHandler : IRequestHandler<UpdateParselCommand>
{
    private readonly IApplicationDbContext _db;
    public UpdateParselCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task Handle(UpdateParselCommand request, CancellationToken ct)
    {
        var parsel = await _db.Parseller.FindAsync([request.Id], ct)
                    ?? throw new KeyNotFoundException($"Parsel bulunamadı: {request.Id}");

        parsel.Ad                       = request.Ad;
        parsel.EkilmisUrun              = request.EkilmisUrun;
        parsel.ToprakTuru               = request.ToprakTuru;
        parsel.EkimTarihi               = request.EkimTarihi;
        parsel.Konum                    = request.Konum;
        parsel.PoligonKoordinatlariJson = request.PoligonKoordinatlariJson;
        parsel.AlanDonumCinsinden       = request.AlanDonumCinsinden;
        parsel.MerkezLat                = request.MerkezLat;
        parsel.MerkezLng                = request.MerkezLng;

        await _db.SaveChangesAsync(ct);
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Parseli Sil (Soft Delete)
// ════════════════════════════════════════════════════════════════════════════

public record DeleteParselCommand(Guid Id) : IRequest;

public class DeleteParselCommandHandler : IRequestHandler<DeleteParselCommand>
{
    private readonly IApplicationDbContext _db;
    public DeleteParselCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task Handle(DeleteParselCommand request, CancellationToken ct)
    {
        var parsel = await _db.Parseller.FindAsync([request.Id], ct)
                    ?? throw new KeyNotFoundException($"Parsel bulunamadı: {request.Id}");

        parsel.IsDeleted = true; // Hard DELETE değil, soft delete
        await _db.SaveChangesAsync(ct);
    }
}
