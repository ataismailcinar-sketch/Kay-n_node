using System.Security.Claims;
using System.Text;
using KayinBackend.Application.Features.Auth;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace KayinBackend.WebApi.Guvenlik;

/// <summary>appsettings "Jwt" bölümü.</summary>
public class JwtAyarlari
{
    public const string Bolum = "Jwt";

    /// <summary>En az 32 bayt (256 bit) gizli anahtar. Üretimde ortam değişkeninden verilir: Jwt__Anahtar.</summary>
    public string Anahtar { get; set; } = string.Empty;
    public string Yayinci { get; set; } = "KayinTarim";
    public string Hedef { get; set; } = "KayinTarimMobil";

    /// <summary>Çiftçi haftalarca çevrimdışı kalabildiği için uzun tutulur.</summary>
    public int GecerlilikGun { get; set; } = 90;

    public SymmetricSecurityKey ImzaAnahtari() => new(Encoding.UTF8.GetBytes(Anahtar));

    public void Dogrula()
    {
        if (Encoding.UTF8.GetByteCount(Anahtar) < 32)
            throw new InvalidOperationException(
                "Jwt:Anahtar ayarlanmamış ya da 32 bayttan kısa. Üretimde 'Jwt__Anahtar' ortam değişkenini verin.");
    }
}

public class TokenUretici(JwtAyarlari ayarlar)
{
    public (string Token, DateTime BitisUtc) Uret(KullaniciDto kullanici)
    {
        var bitis = DateTime.UtcNow.AddDays(ayarlar.GecerlilikGun);
        var token = new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(
            [
                new Claim(JwtRegisteredClaimNames.Sub, kullanici.Id.ToString()),
                new Claim("telefon", kullanici.Telefon),
            ]),
            Issuer = ayarlar.Yayinci,
            Audience = ayarlar.Hedef,
            Expires = bitis,
            SigningCredentials = new SigningCredentials(ayarlar.ImzaAnahtari(), SecurityAlgorithms.HmacSha256),
        });
        return (token, bitis);
    }
}
