using System.Security.Claims;
using KayinBackend.Application.Common.Interfaces;
using Microsoft.IdentityModel.JsonWebTokens;

namespace KayinBackend.WebApi.Guvenlik;

/// <summary>JWT'deki "sub" alanından kullanıcıyı okur. HTTP isteği dışında (arka plan servisleri) null döner.</summary>
public class HttpAktifKullanici(IHttpContextAccessor erisim) : IAktifKullanici
{
    public Guid? KullaniciId
    {
        get
        {
            var kullanici = erisim.HttpContext?.User;
            if (kullanici?.Identity?.IsAuthenticated != true) return null;
            // JwtBearer varsayılan olarak "sub"u NameIdentifier'a çevirir; ikisine de bakılır.
            var deger = kullanici.FindFirstValue(JwtRegisteredClaimNames.Sub)
                        ?? kullanici.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(deger, out var id) ? id : null;
        }
    }
}
