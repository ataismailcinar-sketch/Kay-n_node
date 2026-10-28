using KayinBackend.Application.Features.HastalikTaramaFeature.Commands;
using KayinBackend.Application.Features.HastalikTaramaFeature.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace KayinBackend.WebApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HastalikTaramaController : ControllerBase
{
    private readonly IMediator _mediator;
    public HastalikTaramaController(IMediator mediator) => _mediator = mediator;

    [HttpGet]
    [ProducesResponseType(typeof(List<HastalikTaramaDto>), 200)]
    public async Task<IActionResult> GetAll([FromQuery] Guid? parselId, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetHastalikTaramalarQuery(parselId), ct);
        return Ok(result);
    }

    [HttpPost]
    [ProducesResponseType(typeof(Guid), 201)]
    public async Task<IActionResult> Create([FromBody] CreateHastalikTaramaCommand command, CancellationToken ct)
    {
        var id = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetAll), new { id }, id);
    }

    /// <summary>
    /// Taramanın fotoğrafını yükler (multipart, alan adı "dosya"). Tarama önce sync ile
    /// gönderilmiş olmalı; yoksa 404 döner ve istemci sonraki turda tekrar dener.
    /// </summary>
    [HttpPut("{id:guid}/fotograf")]
    [RequestSizeLimit(TaramaFotografi.MaksBayt + 64 * 1024)] // multipart başlıkları için pay
    [ProducesResponseType(204)]
    [ProducesResponseType(400)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> FotografYukle(Guid id, IFormFile dosya, CancellationToken ct)
    {
        if (dosya.Length > TaramaFotografi.MaksBayt)
            return Problem(statusCode: 400, title: "Fotoğraf 5 MB'tan büyük.");

        using var bellek = new MemoryStream((int)dosya.Length);
        await dosya.CopyToAsync(bellek, ct);
        await _mediator.Send(new TaramaFotografiYukleCommand(id, bellek.ToArray()), ct);
        return NoContent();
    }

    [HttpGet("{id:guid}/fotograf")]
    [ProducesResponseType(200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> FotografGetir(Guid id, CancellationToken ct)
    {
        var foto = await _mediator.Send(new TaramaFotografiGetirQuery(id), ct);
        return foto is null ? NotFound() : File(foto.Icerik, foto.IcerikTuru);
    }
}
