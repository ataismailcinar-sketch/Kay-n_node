using KayinBackend.Application.Features.AkilliSulama.Commands;
using KayinBackend.Application.Features.AkilliSulama.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace KayinBackend.WebApi.Controllers;

/// <summary>Akıllı Sulama API Controller.</summary>
[ApiController]
[Route("api/[controller]")]
public class SulamaController : ControllerBase
{
    private readonly IMediator _mediator;
    public SulamaController(IMediator mediator) => _mediator = mediator;

    /// <summary>Tüm parsellerin güncel nem ve aciliyet durumunu döndürür (dashboard).</summary>
    [HttpGet("dashboard")]
    [ProducesResponseType(typeof(List<ParselNemDurumuDto>), 200)]
    public async Task<IActionResult> GetDashboard(CancellationToken ct)
        => Ok(await _mediator.Send(new GetTumParsellerNemDurumuQuery(), ct));

    /// <summary>Belirli parselin son N günlük yağış/nem geçmişi.</summary>
    [HttpGet("gecmis/{parselId:guid}")]
    [ProducesResponseType(typeof(List<SulamaKayitDto>), 200)]
    public async Task<IActionResult> GetGecmis(
        Guid parselId,
        [FromQuery] int gunSayisi = 7,
        CancellationToken ct = default)
        => Ok(await _mediator.Send(new GetSulamaOzetiQuery(parselId, gunSayisi), ct));

    /// <summary>Kullanıcı manuel sulama kaydeder.</summary>
    [HttpPost("manuel")]
    [ProducesResponseType(typeof(Guid), 201)]
    public async Task<IActionResult> KaydetManuel(
        [FromBody] ManuelSulamaKaydetCommand command,
        CancellationToken ct)
    {
        var id = await _mediator.Send(command, ct);
        return Created(string.Empty, id);
    }
}
