using KayinBackend.Application.Features.Muhasebe.Commands;
using KayinBackend.Application.Features.Muhasebe.Queries;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace KayinBackend.WebApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MuhasebeController : ControllerBase
{
    private readonly IMediator _mediator;
    public MuhasebeController(IMediator mediator) => _mediator = mediator;

    [HttpGet]
    [ProducesResponseType(typeof(List<MuhasebeGiderDto>), 200)]
    public async Task<IActionResult> GetAll([FromQuery] Guid? parselId, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetMuhasebeGiderlerQuery(parselId), ct);
        return Ok(result);
    }

    [HttpPost]
    [ProducesResponseType(typeof(Guid), 201)]
    public async Task<IActionResult> Create([FromBody] CreateMuhasebeGiderCommand command, CancellationToken ct)
    {
        var id = await _mediator.Send(command, ct);
        return CreatedAtAction(nameof(GetAll), new { id }, id);
    }
}
