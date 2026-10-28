using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Application.Features.Auth;
using KayinBackend.WebApi.Guvenlik;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.WebApi.Controllers;

public record GirisIstegi(string Telefon, string Sifre);
public record KayitIstegi(string AdSoyad, string Telefon, string Sifre);
public record OturumYaniti(string Token, DateTime BitisUtc, KullaniciDto Kullanici);

/// <summary>
/// Kayıt ve giriş. Endpoints:
///   POST /api/auth/kayit  — yeni kullanıcı, token döner
///   POST /api/auth/giris  — telefon + şifre, token döner
///   GET  /api/auth/ben    — token geçerli mi, kullanıcı bilgisi
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AuthController(IMediator mediator, TokenUretici tokenUretici) : ControllerBase
{
    [AllowAnonymous]
    [EnableRateLimiting(Program.GirisSinirPolitikasi)]
    [HttpPost("kayit")]
    [ProducesResponseType(typeof(OturumYaniti), 200)]
    [ProducesResponseType(400)]
    public async Task<IActionResult> Kayit([FromBody] KayitIstegi istek, CancellationToken ct)
    {
        var kullanici = await mediator.Send(new KayitOlCommand(istek.AdSoyad, istek.Telefon, istek.Sifre), ct);
        return Ok(Yanit(kullanici));
    }

    [AllowAnonymous]
    [EnableRateLimiting(Program.GirisSinirPolitikasi)]
    [HttpPost("giris")]
    [ProducesResponseType(typeof(OturumYaniti), 200)]
    [ProducesResponseType(401)]
    public async Task<IActionResult> Giris([FromBody] GirisIstegi istek, CancellationToken ct)
    {
        var kullanici = await mediator.Send(new GirisYapCommand(istek.Telefon, istek.Sifre), ct);
        return kullanici is null
            ? Problem(statusCode: 401, title: "Telefon numarası veya şifre hatalı.")
            : Ok(Yanit(kullanici));
    }

    [HttpGet("ben")]
    [ProducesResponseType(typeof(KullaniciDto), 200)]
    public async Task<IActionResult> Ben([FromServices] IAktifKullanici aktif, [FromServices] IApplicationDbContext db, CancellationToken ct)
    {
        var k = await db.Kullanicilar.AsNoTracking().FirstOrDefaultAsync(x => x.Id == aktif.KullaniciId, ct);
        // Token geçerli ama kullanıcı silinmiş → yeniden giriş gerekir.
        return k is null ? Unauthorized() : Ok(new KullaniciDto(k.Id, k.Telefon, k.AdSoyad));
    }

    private OturumYaniti Yanit(KullaniciDto kullanici)
    {
        var (token, bitis) = tokenUretici.Uret(kullanici);
        return new OturumYaniti(token, bitis, kullanici);
    }
}
