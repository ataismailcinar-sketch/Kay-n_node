using KayinBackend.Application.Features.Sync.Dtos;
using MediatR;

namespace KayinBackend.Application.Features.Sync.Queries;

/// <summary>
/// Pull Sync Sorgusu — Mobil son sync zamanından bu yana değişen tüm
/// kayıtları sunucudan çeker.
///
/// SinceUtc: Mobilin son başarılı Pull zamanı (UTC).
///   - İlk kez sync yapılıyorsa → DateTime.MinValue gönderin (tüm kayıtlar gelir).
///   - Sonraki sync'lerde → önceki PullSyncResponse.ServerSyncTimestamp kullanın.
///
/// IsDeleted kayıtlar da döndürülür — mobil soft-delete'i yerel DB'ye uygular.
/// </summary>
public record PullSyncQuery(DateTime SinceUtc) : IRequest<PullSyncResponseDto>;
