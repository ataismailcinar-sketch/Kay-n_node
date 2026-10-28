using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Application.Features.Sync.Dtos;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.Sync.Queries;

/// <summary>
/// Pull Sync Handler — SinceUtc'den sonra LastModifiedUtc'si değişen
/// tüm kayıtları sırayla DbContext üzerinden çeker ve döndürür.
///
/// Performans & Concurrency Notları:
///   - DbContext thread-safe değildir; sorgular sırayla (await) çalıştırılır.
///   - Sorgular AsNoTracking() ile çalışır (read-only).
///   - IsDeleted filtresi UYGULANMAZ — silinmiş kayıtlar da döner (mobil uygulasın).
///   - ServerSyncTimestamp, sorgu başlamadan önce alınır (race condition önleme).
/// </summary>
public class PullSyncQueryHandler : IRequestHandler<PullSyncQuery, PullSyncResponseDto>
{
    private readonly IApplicationDbContext _db;

    public PullSyncQueryHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<PullSyncResponseDto> Handle(
        PullSyncQuery request,
        CancellationToken cancellationToken)
    {
        var serverNow = DateTime.UtcNow;
        var since     = request.SinceUtc;

        // EF Core DbContext Concurrency hatasını önlemek için sorguları sırayla await et
        var parseller = await _db.Parseller
            .AsNoTracking()
            .Where(p => p.LastModifiedUtc > since)
            .Select(p => new ParselSyncDto(
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
                p.LastModifiedUtc,
                p.IsDeleted,
                p.Sulu,
                p.SulamaYontemi,
                p.SuKaynagi,
                p.SuEc,
                null))
            .ToListAsync(cancellationToken);

        var sulamalar = await _db.YagisSulamaKayitlari
            .AsNoTracking()
            .Where(y => y.LastModifiedUtc > since)
            .Select(y => new YagisSulamaKayitSyncDto(
                y.Id,
                y.ParselId,
                y.KayitTarihi,
                y.YagisMillimetre,
                y.ToprakNemiYuzde,
                y.KayitTuru,
                y.ManuelSulamaLitre,
                y.AciliyetSeviyesi,
                y.HawaApiHamVeriJson,
                y.CreatedAtUtc,
                y.LastModifiedUtc,
                y.IsDeleted))
            .ToListAsync(cancellationToken);

        var giderler = await _db.MuhasebeGiderler
            .AsNoTracking()
            .Where(m => m.LastModifiedUtc > since)
            .Select(m => new MuhasebeGiderSyncDto(
                m.Id,
                m.ParselId,
                m.IslemTuru,
                m.Kategori,
                m.AltKategori,
                m.Tutar,
                m.ParaBirimi,
                m.GiderTarihi,
                m.Not,
                m.CreatedAtUtc,
                m.LastModifiedUtc,
                m.IsDeleted))
            .ToListAsync(cancellationToken);

        var taramalar = await _db.HastalikTaramalar
            .AsNoTracking()
            .Where(h => h.LastModifiedUtc > since)
            .Select(h => new HastalikTaramaSyncDto(
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
                h.CreatedAtUtc,
                h.LastModifiedUtc,
                h.IsDeleted,
                h.FotografVar))
            .ToListAsync(cancellationToken);

        var isKayitlari = await _db.IsKayitlari
            .AsNoTracking()
            .Where(i => i.LastModifiedUtc > since)
            .Select(i => new IsKaydiSyncDto(
                i.Id,
                i.ParselId,
                i.IslemTarihi,
                i.IslemTuru,
                i.UrunAdi,
                i.Miktar,
                i.HasatBeklemeGun,
                i.Not,
                i.CreatedAtUtc,
                i.LastModifiedUtc,
                i.IsDeleted,
                i.HasatKg))
            .ToListAsync(cancellationToken);

        var cariler = await _db.Cariler
            .AsNoTracking()
            .Where(c => c.LastModifiedUtc > since)
            .Select(c => new CariSyncDto(c.Id, c.Ad, c.Tur, c.Telefon, c.Not, c.CreatedAtUtc, c.LastModifiedUtc, c.IsDeleted))
            .ToListAsync(cancellationToken);

        var cariHareketleri = await _db.CariHareketleri
            .AsNoTracking()
            .Where(h => h.LastModifiedUtc > since)
            .Select(h => new CariHareketSyncDto(
                h.Id, h.CariId, h.IslemTarihi, h.Tur, h.Tutar, h.VadeTarihi, h.Aciklama,
                h.MuhasebeKaydiId, h.CreatedAtUtc, h.LastModifiedUtc, h.IsDeleted))
            .ToListAsync(cancellationToken);

        var stokKalemleri = await _db.StokKalemleri
            .AsNoTracking()
            .Where(k => k.LastModifiedUtc > since)
            .Select(k => new StokKalemiSyncDto(k.Id, k.Ad, k.Kategori, k.Birim, k.KritikSeviye, k.CreatedAtUtc, k.LastModifiedUtc, k.IsDeleted))
            .ToListAsync(cancellationToken);

        var stokHareketleri = await _db.StokHareketleri
            .AsNoTracking()
            .Where(h => h.LastModifiedUtc > since)
            .Select(h => new StokHareketiSyncDto(
                h.Id, h.KalemId, h.IslemTarihi, h.Tur, h.Miktar, h.Aciklama, h.IsKaydiId,
                h.CreatedAtUtc, h.LastModifiedUtc, h.IsDeleted))
            .ToListAsync(cancellationToken);

        var hatirlatmalar = await _db.Hatirlatmalar
            .AsNoTracking()
            .Where(h => h.LastModifiedUtc > since)
            .Select(h => new HatirlatmaSyncDto(
                h.Id, h.Baslik, h.Tur, h.Tarih, h.KacGunOnce, h.HerYil, h.Tamamlandi, h.Not,
                h.CreatedAtUtc, h.LastModifiedUtc, h.IsDeleted))
            .ToListAsync(cancellationToken);

        var toprakAnalizleri = await _db.ToprakAnalizleri
            .AsNoTracking()
            .Where(a => a.LastModifiedUtc > since)
            .Select(a => new ToprakAnaliziSyncDto(
                a.Id, a.ParselId, a.AnalizTarihi, a.Laboratuvar, a.Saturasyon, a.Ph, a.TuzYuzde, a.Ec,
                a.KirecYuzde, a.OrganikMadde, a.Fosfor, a.Potasyum, a.Cinko, a.Not,
                a.CreatedAtUtc, a.LastModifiedUtc, a.IsDeleted))
            .ToListAsync(cancellationToken);

        return new PullSyncResponseDto(
            parseller,
            sulamalar,
            giderler,
            taramalar,
            isKayitlari,
            cariler,
            cariHareketleri,
            stokKalemleri,
            stokHareketleri,
            hatirlatmalar,
            toprakAnalizleri,
            serverNow
        );
    }
}
