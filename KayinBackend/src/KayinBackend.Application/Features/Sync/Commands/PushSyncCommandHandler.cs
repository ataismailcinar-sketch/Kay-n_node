using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Application.Features.Sync.Dtos;
using KayinBackend.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Features.Sync.Commands;

/// <summary>
/// Push Sync Handler — Last-Write-Wins senkronizasyon motorunun kalbi.
///
/// Algoritma (her entity türü için aynı mantık):
///   1. Gelen ID listesini tek sorguda veritabanından çek (N+1 önleme).
///   2. Her kayıt için:
///      a. Sunucuda YOKSA → yeni kayıt ekle, AcceptedIds'e ekle.
///      b. Sunucuda VARSA ve client.LastModifiedUtc > server.LastModifiedUtc
///         → sunucu kaydını güncelle (client kazanır), AcceptedIds'e ekle.
///      c. Sunucuda VARSA ve server.LastModifiedUtc >= client.LastModifiedUtc
///         → reddet (server kazanır), RejectedIds'e ekle.
///   3. Tek bir SaveChangesAsync ile tüm değişiklikleri commit et.
///
/// Sahiplik: Mevcut kayıtlar sorgu filtresi atlanarak aranır; ID başka bir kullanıcıya
/// aitse kayıt Errors'a düşer (aksi halde filtre yüzünden "yok" sanılıp eklenmeye
/// çalışılır ve tüm parti birincil anahtar hatasıyla başarısız olurdu). Alt kayıtlar
/// (sulama, gider, tarama) yalnızca kullanıcının kendi parseline bağlanabilir.
/// </summary>
public class PushSyncCommandHandler : IRequestHandler<PushSyncCommand, PushSyncResultDto>
{
    private const string BaskasininKaydi = "Bu kayıt başka bir kullanıcıya ait.";
    private const string BaskasininParseli = "Bağlı olduğu tarla bu kullanıcıya ait değil.";

    private readonly IApplicationDbContext _db;
    private readonly IAktifKullanici _aktifKullanici;

    /// <summary>Kullanıcının parselleri + bu push'ta kabul edilen yeni parseller.</summary>
    private HashSet<Guid>? _parselIdleri;
    private readonly List<Guid> _kabulEdilenParseller = [];

    public PushSyncCommandHandler(IApplicationDbContext db, IAktifKullanici aktifKullanici)
    {
        _db = db;
        _aktifKullanici = aktifKullanici;
    }

    private Guid KullaniciId => _aktifKullanici.KullaniciId
        ?? throw new UnauthorizedAccessException("Senkronizasyon için giriş gerekli.");

    private async Task<bool> ParselSahibiMi(Guid? parselId, CancellationToken ct)
    {
        if (parselId is null) return true;
        if (_parselIdleri is null)
        {
            _parselIdleri = (await _db.Parseller.Select(p => p.Id).ToListAsync(ct)).ToHashSet();
            _parselIdleri.UnionWith(_kabulEdilenParseller);
        }
        return _parselIdleri.Contains(parselId.Value);
    }

    public async Task<PushSyncResultDto> Handle(
        PushSyncCommand request,
        CancellationToken cancellationToken)
    {
        _ = KullaniciId; // girişsiz istekte erken hata
        var accepted = new List<Guid>();
        var rejected = new List<Guid>();
        var errors   = new Dictionary<Guid, string>();

        // ── 1. Parseller ─────────────────────────────────────────────────
        await SyncParseller(request.Parseller, accepted, rejected, errors, cancellationToken);

        // ── 2. Yağış/Sulama Kayıtları ─────────────────────────────────────
        await SyncYagisSulama(request.YagisSulamaKayitlari, accepted, rejected, errors, cancellationToken);

        // ── 3. Muhasebe Giderler ─────────────────────────────────────────
        await SyncMuhasebeGider(request.MuhasebeGiderler, accepted, rejected, errors, cancellationToken);

        // ── 4. Hastalık Taramalar ─────────────────────────────────────────
        await SyncHastalikTarama(request.HastalikTaramalar, accepted, rejected, errors, cancellationToken);

        // ── 5. İş Günlüğü ─────────────────────────────────────────────────
        await SyncIsKayitlari(request.IsKayitlari ?? [], accepted, rejected, errors, cancellationToken);

        // ── 6. Veresiye defteri (önce hesaplar, sonra onlara bağlı hareketler) ──
        await SyncCariler(request.Cariler ?? [], accepted, rejected, errors, cancellationToken);
        await SyncCariHareketleri(request.CariHareketleri ?? [], accepted, rejected, errors, cancellationToken);

        // ── 7. Depo (önce kalemler, sonra hareketleri) ───────────────────
        await SyncStokKalemleri(request.StokKalemleri ?? [], accepted, rejected, errors, cancellationToken);
        await SyncStokHareketleri(request.StokHareketleri ?? [], accepted, rejected, errors, cancellationToken);

        // ── 8. Hatırlatmalar ─────────────────────────────────────────────
        await SyncHatirlatmalar(request.Hatirlatmalar ?? [], accepted, rejected, errors, cancellationToken);

        // ── 9. Toprak analizleri (parsele bağlı) ─────────────────────────
        await SyncToprakAnalizleri(request.ToprakAnalizleri ?? [], accepted, rejected, errors, cancellationToken);

        // ── 10. Tüm değişiklikleri tek seferde kaydet (Hata İzolasyonlu) ──
        try
        {
            await _db.SaveChangesAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            // Veritabanı toplu kaydetme hatasında accepted listesindeki ID'ler için genel hata kaydı düş
            foreach (var id in accepted.ToList())
            {
                errors[id] = ex.Message;
            }
            accepted.Clear();
        }

        return new PushSyncResultDto(accepted, rejected, errors);
    }

    // ════════════════════════════════════════════════════════════════════════
    // Parsel Sync
    // ════════════════════════════════════════════════════════════════════════
    private async Task SyncParseller(
        List<ParselSyncDto> dtos,
        List<Guid> accepted,
        List<Guid> rejected,
        Dictionary<Guid, string> errors,
        CancellationToken ct)
    {
        if (!dtos.Any()) return;

        // Tek sorguda tüm ilgili kayıtları çek (N+1 önleme)
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.Parseller
            .IgnoreQueryFilters()
            .Where(p => ids.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var serverRecord);
                if (serverRecord is not null && serverRecord.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (serverRecord is null)
                {
                    // Sunucuda yok → yeni kayıt
                    _db.Parseller.Add(MapToParsel(dto));
                    accepted.Add(dto.Id);
                    _kabulEdilenParseller.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > serverRecord.LastModifiedUtc)
                {
                    // Client daha yeni → LWW: client kazanır
                    ApplyParselUpdate(serverRecord, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    // Server daha yeni veya eşit → LWW: server kazanır
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // YagisSulama Sync
    // ════════════════════════════════════════════════════════════════════════
    private async Task SyncYagisSulama(
        List<YagisSulamaKayitSyncDto> dtos,
        List<Guid> accepted,
        List<Guid> rejected,
        Dictionary<Guid, string> errors,
        CancellationToken ct)
    {
        if (!dtos.Any()) return;

        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.YagisSulamaKayitlari
            .IgnoreQueryFilters()
            .Where(y => ids.Contains(y.Id))
            .ToDictionaryAsync(y => y.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var serverRecord);
                if (serverRecord is not null && serverRecord.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await ParselSahibiMi(dto.ParselId, ct))
                {
                    errors[dto.Id] = BaskasininParseli;
                }
                else if (serverRecord is null)
                {
                    _db.YagisSulamaKayitlari.Add(MapToYagisSulama(dto));
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > serverRecord.LastModifiedUtc)
                {
                    ApplyYagisSulamaUpdate(serverRecord, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // MuhasebeGider Sync
    // ════════════════════════════════════════════════════════════════════════
    private async Task SyncMuhasebeGider(
        List<MuhasebeGiderSyncDto> dtos,
        List<Guid> accepted,
        List<Guid> rejected,
        Dictionary<Guid, string> errors,
        CancellationToken ct)
    {
        if (!dtos.Any()) return;

        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.MuhasebeGiderler
            .IgnoreQueryFilters()
            .Where(m => ids.Contains(m.Id))
            .ToDictionaryAsync(m => m.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var serverRecord);
                if (serverRecord is not null && serverRecord.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await ParselSahibiMi(dto.ParselId, ct))
                {
                    errors[dto.Id] = BaskasininParseli;
                }
                else if (serverRecord is null)
                {
                    _db.MuhasebeGiderler.Add(MapToMuhasebeGider(dto));
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > serverRecord.LastModifiedUtc)
                {
                    ApplyMuhasebeGiderUpdate(serverRecord, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // HastalikTarama Sync
    // ════════════════════════════════════════════════════════════════════════
    private async Task SyncHastalikTarama(
        List<HastalikTaramaSyncDto> dtos,
        List<Guid> accepted,
        List<Guid> rejected,
        Dictionary<Guid, string> errors,
        CancellationToken ct)
    {
        if (!dtos.Any()) return;

        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.HastalikTaramalar
            .IgnoreQueryFilters()
            .Where(h => ids.Contains(h.Id))
            .ToDictionaryAsync(h => h.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var serverRecord);
                if (serverRecord is not null && serverRecord.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await ParselSahibiMi(dto.ParselId, ct))
                {
                    errors[dto.Id] = BaskasininParseli;
                }
                else if (serverRecord is null)
                {
                    _db.HastalikTaramalar.Add(MapToHastalikTarama(dto));
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > serverRecord.LastModifiedUtc)
                {
                    ApplyHastalikTaramaUpdate(serverRecord, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Veresiye Defteri Sync
    // ════════════════════════════════════════════════════════════════════════
    private const string BaskasininCarisi = "Bağlı olduğu hesap bu kullanıcıya ait değil.";

    /// <summary>Kullanıcının cari hesapları + bu push'ta kabul edilen yeni hesaplar.</summary>
    private HashSet<Guid>? _cariIdleri;
    private readonly List<Guid> _kabulEdilenCariler = [];

    private async Task<bool> CariSahibiMi(Guid cariId, CancellationToken ct)
    {
        if (_cariIdleri is null)
        {
            _cariIdleri = (await _db.Cariler.Select(c => c.Id).ToListAsync(ct)).ToHashSet();
            _cariIdleri.UnionWith(_kabulEdilenCariler);
        }
        return _cariIdleri.Contains(cariId);
    }

    private async Task SyncCariler(
        List<CariSyncDto> dtos, List<Guid> accepted, List<Guid> rejected,
        Dictionary<Guid, string> errors, CancellationToken ct)
    {
        if (!dtos.Any()) return;
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.Cariler.IgnoreQueryFilters()
            .Where(c => ids.Contains(c.Id)).ToDictionaryAsync(c => c.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var server);
                if (server is not null && server.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (server is null)
                {
                    _db.Cariler.Add(new Cari
                    {
                        Id = dto.Id, Ad = dto.Ad ?? "", Tur = string.IsNullOrWhiteSpace(dto.Tur) ? "Bayi" : dto.Tur,
                        Telefon = dto.Telefon ?? "", Not = dto.Not ?? "",
                        CreatedAtUtc = dto.CreatedAtUtc, LastModifiedUtc = dto.LastModifiedUtc, IsDeleted = dto.IsDeleted,
                    });
                    accepted.Add(dto.Id);
                    _kabulEdilenCariler.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > server.LastModifiedUtc)
                {
                    server.Ad = dto.Ad ?? "";
                    server.Tur = string.IsNullOrWhiteSpace(dto.Tur) ? server.Tur : dto.Tur;
                    server.Telefon = dto.Telefon ?? "";
                    server.Not = dto.Not ?? "";
                    server.LastModifiedUtc = dto.LastModifiedUtc;
                    server.IsDeleted = dto.IsDeleted;
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private async Task SyncCariHareketleri(
        List<CariHareketSyncDto> dtos, List<Guid> accepted, List<Guid> rejected,
        Dictionary<Guid, string> errors, CancellationToken ct)
    {
        if (!dtos.Any()) return;
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.CariHareketleri.IgnoreQueryFilters()
            .Where(h => ids.Contains(h.Id)).ToDictionaryAsync(h => h.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var server);
                if (server is not null && server.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await CariSahibiMi(dto.CariId, ct))
                {
                    errors[dto.Id] = BaskasininCarisi;
                }
                else if (server is null)
                {
                    var yeni = new CariHareket { Id = dto.Id, CreatedAtUtc = dto.CreatedAtUtc };
                    HareketUygula(yeni, dto);
                    _db.CariHareketleri.Add(yeni);
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > server.LastModifiedUtc)
                {
                    HareketUygula(server, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private static void HareketUygula(CariHareket h, CariHareketSyncDto dto)
    {
        h.CariId          = dto.CariId;
        h.IslemTarihi     = dto.IslemTarihi;
        h.Tur             = string.IsNullOrWhiteSpace(dto.Tur) ? "Veresiye" : dto.Tur;
        h.Tutar           = dto.Tutar;
        h.VadeTarihi      = dto.VadeTarihi;
        h.Aciklama        = dto.Aciklama ?? "";
        h.MuhasebeKaydiId = dto.MuhasebeKaydiId;
        h.LastModifiedUtc = dto.LastModifiedUtc;
        h.IsDeleted       = dto.IsDeleted;
    }

    // ════════════════════════════════════════════════════════════════════════
    // Depo Sync
    // ════════════════════════════════════════════════════════════════════════
    private const string BaskasininKalemi = "Bağlı olduğu depo kalemi bu kullanıcıya ait değil.";

    private HashSet<Guid>? _kalemIdleri;
    private readonly List<Guid> _kabulEdilenKalemler = [];

    private async Task<bool> KalemSahibiMi(Guid kalemId, CancellationToken ct)
    {
        if (_kalemIdleri is null)
        {
            _kalemIdleri = (await _db.StokKalemleri.Select(k => k.Id).ToListAsync(ct)).ToHashSet();
            _kalemIdleri.UnionWith(_kabulEdilenKalemler);
        }
        return _kalemIdleri.Contains(kalemId);
    }

    private async Task SyncStokKalemleri(
        List<StokKalemiSyncDto> dtos, List<Guid> accepted, List<Guid> rejected,
        Dictionary<Guid, string> errors, CancellationToken ct)
    {
        if (!dtos.Any()) return;
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.StokKalemleri.IgnoreQueryFilters()
            .Where(k => ids.Contains(k.Id)).ToDictionaryAsync(k => k.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var server);
                if (server is not null && server.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (server is null)
                {
                    var yeni = new StokKalemi { Id = dto.Id, CreatedAtUtc = dto.CreatedAtUtc };
                    KalemUygula(yeni, dto);
                    _db.StokKalemleri.Add(yeni);
                    accepted.Add(dto.Id);
                    _kabulEdilenKalemler.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > server.LastModifiedUtc)
                {
                    KalemUygula(server, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private static void KalemUygula(StokKalemi k, StokKalemiSyncDto dto)
    {
        k.Ad              = dto.Ad ?? "";
        k.Kategori        = string.IsNullOrWhiteSpace(dto.Kategori) ? "Diger" : dto.Kategori;
        k.Birim           = string.IsNullOrWhiteSpace(dto.Birim) ? "kg" : dto.Birim;
        k.KritikSeviye    = dto.KritikSeviye;
        k.LastModifiedUtc = dto.LastModifiedUtc;
        k.IsDeleted       = dto.IsDeleted;
    }

    private async Task SyncStokHareketleri(
        List<StokHareketiSyncDto> dtos, List<Guid> accepted, List<Guid> rejected,
        Dictionary<Guid, string> errors, CancellationToken ct)
    {
        if (!dtos.Any()) return;
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.StokHareketleri.IgnoreQueryFilters()
            .Where(h => ids.Contains(h.Id)).ToDictionaryAsync(h => h.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var server);
                if (server is not null && server.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await KalemSahibiMi(dto.KalemId, ct))
                {
                    errors[dto.Id] = BaskasininKalemi;
                }
                else if (server is null)
                {
                    var yeni = new StokHareketi { Id = dto.Id, CreatedAtUtc = dto.CreatedAtUtc };
                    StokHareketUygula(yeni, dto);
                    _db.StokHareketleri.Add(yeni);
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > server.LastModifiedUtc)
                {
                    StokHareketUygula(server, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private static void StokHareketUygula(StokHareketi h, StokHareketiSyncDto dto)
    {
        h.KalemId         = dto.KalemId;
        h.IslemTarihi     = dto.IslemTarihi;
        h.Tur             = string.IsNullOrWhiteSpace(dto.Tur) ? "Giris" : dto.Tur;
        h.Miktar          = dto.Miktar;
        h.Aciklama        = dto.Aciklama ?? "";
        h.IsKaydiId       = dto.IsKaydiId;
        h.LastModifiedUtc = dto.LastModifiedUtc;
        h.IsDeleted       = dto.IsDeleted;
    }

    private async Task SyncHatirlatmalar(
        List<HatirlatmaSyncDto> dtos, List<Guid> accepted, List<Guid> rejected,
        Dictionary<Guid, string> errors, CancellationToken ct)
    {
        if (!dtos.Any()) return;
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.Hatirlatmalar.IgnoreQueryFilters()
            .Where(h => ids.Contains(h.Id)).ToDictionaryAsync(h => h.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var server);
                if (server is not null && server.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (server is null)
                {
                    var yeni = new Hatirlatma { Id = dto.Id, CreatedAtUtc = dto.CreatedAtUtc };
                    HatirlatmaUygula(yeni, dto);
                    _db.Hatirlatmalar.Add(yeni);
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > server.LastModifiedUtc)
                {
                    HatirlatmaUygula(server, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private async Task SyncToprakAnalizleri(
        List<ToprakAnaliziSyncDto> dtos, List<Guid> accepted, List<Guid> rejected,
        Dictionary<Guid, string> errors, CancellationToken ct)
    {
        if (!dtos.Any()) return;
        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.ToprakAnalizleri.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id)).ToDictionaryAsync(a => a.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var server);
                if (server is not null && server.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await ParselSahibiMi(dto.ParselId, ct))
                {
                    errors[dto.Id] = BaskasininParseli;
                }
                else if (server is null)
                {
                    var yeni = new ToprakAnalizi { Id = dto.Id, CreatedAtUtc = dto.CreatedAtUtc };
                    ToprakAnaliziUygula(yeni, dto);
                    _db.ToprakAnalizleri.Add(yeni);
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > server.LastModifiedUtc)
                {
                    ToprakAnaliziUygula(server, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private static void ToprakAnaliziUygula(ToprakAnalizi a, ToprakAnaliziSyncDto dto)
    {
        a.ParselId        = dto.ParselId;
        a.AnalizTarihi    = dto.AnalizTarihi;
        a.Laboratuvar     = dto.Laboratuvar ?? "";
        a.Saturasyon      = dto.Saturasyon;
        a.Ph              = dto.Ph;
        a.TuzYuzde        = dto.TuzYuzde;
        a.Ec              = dto.Ec;
        a.KirecYuzde      = dto.KirecYuzde;
        a.OrganikMadde    = dto.OrganikMadde;
        a.Fosfor          = dto.Fosfor;
        a.Potasyum        = dto.Potasyum;
        a.Cinko           = dto.Cinko;
        a.Not             = dto.Not ?? "";
        a.LastModifiedUtc = dto.LastModifiedUtc;
        a.IsDeleted       = dto.IsDeleted;
    }

    private static void HatirlatmaUygula(Hatirlatma h, HatirlatmaSyncDto dto)
    {
        h.Baslik          = dto.Baslik ?? "";
        h.Tur             = string.IsNullOrWhiteSpace(dto.Tur) ? "Diger" : dto.Tur;
        h.Tarih           = dto.Tarih;
        h.KacGunOnce      = Math.Clamp(dto.KacGunOnce, 0, 365);
        h.HerYil          = dto.HerYil;
        h.Tamamlandi      = dto.Tamamlandi;
        h.Not             = dto.Not ?? "";
        h.LastModifiedUtc = dto.LastModifiedUtc;
        h.IsDeleted       = dto.IsDeleted;
    }

    // ════════════════════════════════════════════════════════════════════════
    // İş Günlüğü Sync
    // ════════════════════════════════════════════════════════════════════════
    private async Task SyncIsKayitlari(
        List<IsKaydiSyncDto> dtos,
        List<Guid> accepted,
        List<Guid> rejected,
        Dictionary<Guid, string> errors,
        CancellationToken ct)
    {
        if (!dtos.Any()) return;

        var ids = dtos.Select(d => d.Id).ToList();
        var existing = await _db.IsKayitlari
            .IgnoreQueryFilters()
            .Where(i => ids.Contains(i.Id))
            .ToDictionaryAsync(i => i.Id, ct);

        foreach (var dto in dtos)
        {
            try
            {
                existing.TryGetValue(dto.Id, out var serverRecord);
                if (serverRecord is not null && serverRecord.KullaniciId != KullaniciId)
                {
                    errors[dto.Id] = BaskasininKaydi;
                }
                else if (!await ParselSahibiMi(dto.ParselId, ct))
                {
                    errors[dto.Id] = BaskasininParseli;
                }
                else if (serverRecord is null)
                {
                    _db.IsKayitlari.Add(MapToIsKaydi(dto));
                    accepted.Add(dto.Id);
                }
                else if (dto.LastModifiedUtc > serverRecord.LastModifiedUtc)
                {
                    ApplyIsKaydiUpdate(serverRecord, dto);
                    accepted.Add(dto.Id);
                }
                else
                {
                    rejected.Add(dto.Id);
                }
            }
            catch (Exception ex)
            {
                errors[dto.Id] = ex.Message;
            }
        }
    }

    private static IsKaydi MapToIsKaydi(IsKaydiSyncDto dto) => new()
    {
        Id               = dto.Id,
        ParselId         = dto.ParselId,
        IslemTarihi      = dto.IslemTarihi,
        IslemTuru        = string.IsNullOrWhiteSpace(dto.IslemTuru) ? "Diger" : dto.IslemTuru,
        UrunAdi          = dto.UrunAdi ?? string.Empty,
        Miktar           = dto.Miktar ?? string.Empty,
        HasatBeklemeGun  = dto.HasatBeklemeGun,
        HasatKg          = dto.HasatKg,
        Not              = dto.Not ?? string.Empty,
        CreatedAtUtc     = dto.CreatedAtUtc,
        LastModifiedUtc  = dto.LastModifiedUtc,
        IsDeleted        = dto.IsDeleted,
    };

    private static void ApplyIsKaydiUpdate(IsKaydi entity, IsKaydiSyncDto dto)
    {
        entity.ParselId        = dto.ParselId;
        entity.IslemTarihi     = dto.IslemTarihi;
        entity.IslemTuru       = string.IsNullOrWhiteSpace(dto.IslemTuru) ? entity.IslemTuru : dto.IslemTuru;
        entity.UrunAdi         = dto.UrunAdi ?? string.Empty;
        entity.Miktar          = dto.Miktar ?? string.Empty;
        entity.HasatBeklemeGun = dto.HasatBeklemeGun;
        entity.HasatKg         = dto.HasatKg;
        entity.Not             = dto.Not ?? string.Empty;
        entity.LastModifiedUtc = dto.LastModifiedUtc;
        entity.IsDeleted       = dto.IsDeleted;
    }

    // ════════════════════════════════════════════════════════════════════════
    // DTO → Entity Mapper'ları (yeni kayıt)
    // ════════════════════════════════════════════════════════════════════════

    private static Domain.Entities.Parsel MapToParsel(ParselSyncDto dto) => new()
    {
        Id                        = dto.Id,
        Ad                        = dto.Ad,
        EkilmisUrun               = string.IsNullOrWhiteSpace(dto.EkilmisUrun) ? "Buğday" : dto.EkilmisUrun,
        ToprakTuru                = string.IsNullOrWhiteSpace(dto.ToprakTuru) ? "Tınlı" : dto.ToprakTuru,
        Sulu                      = dto.Sulu,
        SulamaYontemi             = Kisalt(dto.SulamaYontemi),
        SuKaynagi                 = Kisalt(dto.SuKaynagi),
        SuEc                      = GecerliEc(dto.SuEc),
        EkimTarihi                = dto.EkimTarihi,
        Konum                     = dto.Konum,
        PoligonKoordinatlariJson  = dto.PoligonKoordinatlariJson,
        AlanDonumCinsinden        = dto.AlanDonumCinsinden,
        MerkezLat                 = dto.MerkezLat,
        MerkezLng                 = dto.MerkezLng,
        CreatedAtUtc              = dto.CreatedAtUtc,
        LastModifiedUtc           = dto.LastModifiedUtc,
        IsDeleted                 = dto.IsDeleted,
    };

    /// <summary>Boş → null; en fazla 20 karakter (sütun sınırı).</summary>
    private static string? Kisalt(string? s) =>
        string.IsNullOrWhiteSpace(s) ? null : (s.Length > 20 ? s[..20] : s);

    /// <summary>Sulama suyu EC'si 0–20 dS/m aralığında değilse saklanmaz.</summary>
    private static double? GecerliEc(double? ec) => ec is >= 0 and <= 20 ? ec : null;

    private static void ApplyParselUpdate(Domain.Entities.Parsel entity, ParselSyncDto dto)
    {
        entity.Ad                        = dto.Ad;
        entity.EkilmisUrun               = string.IsNullOrWhiteSpace(dto.EkilmisUrun) ? entity.EkilmisUrun : dto.EkilmisUrun;
        entity.ToprakTuru                = string.IsNullOrWhiteSpace(dto.ToprakTuru) ? entity.ToprakTuru : dto.ToprakTuru;
        if (dto.SemaSurumu >= 2)
        {
            entity.Sulu          = dto.Sulu;
            entity.SulamaYontemi = Kisalt(dto.SulamaYontemi);
            entity.SuKaynagi     = Kisalt(dto.SuKaynagi);
            entity.SuEc          = dto.SuEc is null ? null : GecerliEc(dto.SuEc) ?? entity.SuEc;
        }
        else
        {
            // Eski sürüm (alanları göndermeyen) güncellemesi sulama bilgisini silmesin.
            entity.Sulu          = dto.Sulu ?? entity.Sulu;
            entity.SulamaYontemi = Kisalt(dto.SulamaYontemi) ?? entity.SulamaYontemi;
            entity.SuKaynagi     = Kisalt(dto.SuKaynagi) ?? entity.SuKaynagi;
            entity.SuEc          = GecerliEc(dto.SuEc) ?? entity.SuEc;
        }
        entity.EkimTarihi                = dto.EkimTarihi;
        entity.Konum                     = dto.Konum;
        entity.PoligonKoordinatlariJson  = dto.PoligonKoordinatlariJson;
        entity.AlanDonumCinsinden        = dto.AlanDonumCinsinden;
        entity.MerkezLat                 = dto.MerkezLat;
        entity.MerkezLng                 = dto.MerkezLng;
        entity.LastModifiedUtc           = dto.LastModifiedUtc;
        entity.IsDeleted                 = dto.IsDeleted;
    }

    private static YagisSulamaKayit MapToYagisSulama(YagisSulamaKayitSyncDto dto) => new()
    {
        Id                   = dto.Id,
        ParselId             = dto.ParselId,
        KayitTarihi          = dto.KayitTarihi,
        YagisMillimetre      = dto.YagisMillimetre,
        ToprakNemiYuzde      = dto.ToprakNemiYuzde,
        KayitTuru            = dto.KayitTuru,
        ManuelSulamaLitre    = dto.ManuelSulamaLitre,
        AciliyetSeviyesi     = dto.AciliyetSeviyesi,
        HawaApiHamVeriJson   = dto.HawaApiHamVeriJson,
        CreatedAtUtc         = dto.CreatedAtUtc,
        LastModifiedUtc      = dto.LastModifiedUtc,
        IsDeleted            = dto.IsDeleted,
    };

    private static void ApplyYagisSulamaUpdate(YagisSulamaKayit entity, YagisSulamaKayitSyncDto dto)
    {
        entity.YagisMillimetre    = dto.YagisMillimetre;
        entity.ToprakNemiYuzde    = dto.ToprakNemiYuzde;
        entity.KayitTuru          = dto.KayitTuru;
        entity.ManuelSulamaLitre  = dto.ManuelSulamaLitre;
        entity.AciliyetSeviyesi   = dto.AciliyetSeviyesi;
        entity.HawaApiHamVeriJson = dto.HawaApiHamVeriJson;
        entity.LastModifiedUtc    = dto.LastModifiedUtc;
        entity.IsDeleted          = dto.IsDeleted;
    }

    private static MuhasebeGider MapToMuhasebeGider(MuhasebeGiderSyncDto dto) => new()
    {
        Id              = dto.Id,
        ParselId        = dto.ParselId,
        IslemTuru       = string.IsNullOrWhiteSpace(dto.IslemTuru) ? "Gider" : dto.IslemTuru,
        Kategori        = dto.Kategori,
        AltKategori     = dto.AltKategori,
        Tutar           = dto.Tutar,
        ParaBirimi      = dto.ParaBirimi,
        GiderTarihi     = dto.GiderTarihi,
        Not             = dto.Not,
        CreatedAtUtc    = dto.CreatedAtUtc,
        LastModifiedUtc = dto.LastModifiedUtc,
        IsDeleted       = dto.IsDeleted,
    };

    private static void ApplyMuhasebeGiderUpdate(MuhasebeGider entity, MuhasebeGiderSyncDto dto)
    {
        entity.ParselId        = dto.ParselId;
        entity.IslemTuru       = string.IsNullOrWhiteSpace(dto.IslemTuru) ? entity.IslemTuru : dto.IslemTuru;
        entity.Kategori        = dto.Kategori;
        entity.AltKategori     = dto.AltKategori;
        entity.Tutar           = dto.Tutar;
        entity.ParaBirimi      = dto.ParaBirimi;
        entity.GiderTarihi     = dto.GiderTarihi;
        entity.Not             = dto.Not;
        entity.LastModifiedUtc = dto.LastModifiedUtc;
        entity.IsDeleted       = dto.IsDeleted;
    }

    private static HastalikTarama MapToHastalikTarama(HastalikTaramaSyncDto dto) => new()
    {
        Id                        = dto.Id,
        ParselId                  = dto.ParselId,
        TaramaTarihi              = dto.TaramaTarihi,
        TeshisAdi                 = dto.TeshisAdi,
        GüvenYüzdesi             = dto.GuvenYuzdesi,
        TumSinifOlasiliklariJson  = dto.TumSinifOlasiliklariJson,
        FotografYerelYolu         = dto.FotografYerelYolu,
        ModelVersionu             = dto.ModelVersionu,
        AciliyetSeviyesi          = dto.AciliyetSeviyesi,
        CevrimdisiAnalizYapildi   = dto.CevrimdisiAnalizYapildi,
        CreatedAtUtc              = dto.CreatedAtUtc,
        LastModifiedUtc           = dto.LastModifiedUtc,
        IsDeleted                 = dto.IsDeleted,
    };

    private static void ApplyHastalikTaramaUpdate(HastalikTarama entity, HastalikTaramaSyncDto dto)
    {
        entity.ParselId                 = dto.ParselId;
        entity.TaramaTarihi             = dto.TaramaTarihi;
        entity.TeshisAdi                = dto.TeshisAdi;
        entity.GüvenYüzdesi            = dto.GuvenYuzdesi;
        entity.TumSinifOlasiliklariJson = dto.TumSinifOlasiliklariJson;
        entity.FotografYerelYolu        = dto.FotografYerelYolu;
        entity.ModelVersionu            = dto.ModelVersionu;
        entity.AciliyetSeviyesi         = dto.AciliyetSeviyesi;
        entity.LastModifiedUtc          = dto.LastModifiedUtc;
        entity.IsDeleted                = dto.IsDeleted;
    }
}
