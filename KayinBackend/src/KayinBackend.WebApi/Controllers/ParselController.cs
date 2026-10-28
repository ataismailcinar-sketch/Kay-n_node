using KayinBackend.Application.Features.Parsel.Commands;
using KayinBackend.Application.Features.Parsel.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace KayinBackend.WebApi.Controllers;

/// <summary>
/// Parsel (Tarla) CRUD API Controller.
/// Tüm operasyonlar MediatR pipeline'ından geçer.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class ParselController : ControllerBase
{
    private readonly IMediator _mediator;
    public ParselController(IMediator mediator) => _mediator = mediator;

    /// <summary>Tüm aktif parselleri listeler.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<ParselDto>), 200)]
    public async Task<IActionResult> GetAll(CancellationToken ct)
        => Ok(await _mediator.Send(new GetParsellerQuery(), ct));

    /// <summary>ID ile tek parsel getirir.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ParselDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetParselByIdQuery(id), ct);
        return result is null ? NotFound() : Ok(result);
    }

    /// <summary>
    /// Yeni parsel oluşturur.
    /// ID Flutter tarafında üretilir (Guid/UUID) ve body'de gönderilir.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(Guid), 201)]
    public async Task<IActionResult> Create(
        [FromBody] CreateParselCommand command, CancellationToken ct)
    {
        var id = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetById), new { id }, id);
    }

    /// <summary>Mevcut parseli günceller.</summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(204)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> Update(
        Guid id, [FromBody] UpdateParselCommand command, CancellationToken ct)
    {
        if (id != command.Id) return BadRequest("URL ID ile body ID eşleşmiyor.");
        try
        {
            await _mediator.Send(command, ct);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    /// <summary>Parseli soft-delete yapar (IsDeleted=true).</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(204)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new DeleteParselCommand(id), ct);
            return NoContent();
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }
}
