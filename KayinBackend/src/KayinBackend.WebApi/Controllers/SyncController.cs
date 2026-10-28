using KayinBackend.Application.Features.Sync.Commands;
using KayinBackend.Application.Features.Sync.Dtos;
using KayinBackend.Application.Features.Sync.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace KayinBackend.WebApi.Controllers;

/// <summary>
/// Senkronizasyon API Controller.
///
/// Endpoints:
///   POST /api/sync/push  — Mobil → Sunucu (IsSynced=0 kayıtları yükle)
///   GET  /api/sync/pull  — Sunucu → Mobil (delta değişiklikler indir)
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class SyncController : ControllerBase
{
    private readonly IMediator _mediator;

    public SyncController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>
    /// Flutter'dan gelen tüm senkronize edilmemiş kayıtları sunucuya yazar.
    /// Last-Write-Wins kuralı uygulanır.
    ///
    /// Başarılı response'da:
    ///   - AcceptedIds → Flutter bu ID'leri IsSynced=1 yapmalı
    ///   - RejectedIds → Sunucu daha güncel, Flutter sunucu verisini Pull etmeli
    ///   - Errors → İşlem hatası, Flutter tekrar deneyebilir
    /// </summary>
    [HttpPost("push")]
    [ProducesResponseType(typeof(PushSyncResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Push(
        [FromBody] PushSyncCommand command,
        CancellationToken cancellationToken)
    {
        if (command is null)
            return BadRequest("Boş istek gönderildi.");

        var result = await _mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Mobilin son sync zamanından bu yana sunucuda değişen tüm kayıtları döndürür.
    ///
    /// sinceUtc parametresi:
    ///   - İlk sync: "0001-01-01T00:00:00Z" (tüm kayıtlar gelir)
    ///   - Sonraki syncler: Önceki pull yanıtındaki ServerSyncTimestamp
    /// </summary>
    [HttpGet("pull")]
    [ProducesResponseType(typeof(PullSyncResponseDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> Pull(
        [FromQuery] DateTime sinceUtc,
        CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new PullSyncQuery(sinceUtc), cancellationToken);
        return Ok(result);
    }
}
