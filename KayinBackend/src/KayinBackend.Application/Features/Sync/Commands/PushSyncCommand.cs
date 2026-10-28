using KayinBackend.Application.Features.Sync.Dtos;
using MediatR;

namespace KayinBackend.Application.Features.Sync.Commands;

/// <summary>
/// Push Sync Komutu — Flutter'dan gelen tüm senkronize edilmemiş kayıtları
/// tek bir toplu işlemde sunucuya yazar.
///
/// Last-Write-Wins (LWW) Kuralı:
///   - Her kayıt için: client.LastModifiedUtc vs server.LastModifiedUtc karşılaştırılır.
///   - Client daha yeniyse → sunucu güncellenir (client kazanır).
///   - Sunucu daha yeniyse → kayıt reddedilir (server kazanır), mobil'e RejectedIds'te döner.
///   - Kayıt sunucuda yoksa → yeni kayıt olarak eklenir (insert).
/// </summary>
public record PushSyncCommand(
    List<ParselSyncDto> Parseller,
    List<YagisSulamaKayitSyncDto> YagisSulamaKayitlari,
    List<MuhasebeGiderSyncDto> MuhasebeGiderler,
    List<HastalikTaramaSyncDto> HastalikTaramalar,
    // İş günlüğünden önceki uygulama sürümleri bu alanı göndermez.
    List<IsKaydiSyncDto>? IsKayitlari = null,
    // Veresiye defterinden önceki uygulama sürümleri bunları göndermez.
    List<CariSyncDto>? Cariler = null,
    List<CariHareketSyncDto>? CariHareketleri = null,
    // Depodan önceki uygulama sürümleri bunları göndermez.
    List<StokKalemiSyncDto>? StokKalemleri = null,
    List<StokHareketiSyncDto>? StokHareketleri = null,
    // Bildirimlerden önceki uygulama sürümleri bunu göndermez.
    List<HatirlatmaSyncDto>? Hatirlatmalar = null,
    // Toprak analizinden önceki uygulama sürümleri bunu göndermez.
    List<ToprakAnaliziSyncDto>? ToprakAnalizleri = null
) : IRequest<PushSyncResultDto>;
