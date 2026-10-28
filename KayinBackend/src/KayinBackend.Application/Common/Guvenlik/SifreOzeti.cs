using System.Security.Cryptography;

namespace KayinBackend.Application.Common.Guvenlik;

/// <summary>
/// Şifre özeti: PBKDF2-SHA256, kullanıcı başına rastgele tuz.
/// Biçim: "pbkdf2-sha256${iterasyon}${tuz-base64}${özet-base64}" — iterasyon sayısı
/// ileride artırılırsa eski özetler yine doğrulanabilsin diye özetle birlikte saklanır.
/// </summary>
public static class SifreOzeti
{
    private const string Onek = "pbkdf2-sha256";
    private const int Iterasyon = 210_000; // OWASP 2023 önerisi (PBKDF2-HMAC-SHA256)
    private const int TuzBoyu = 16;
    private const int OzetBoyu = 32;

    public static string Olustur(string sifre)
    {
        var tuz = RandomNumberGenerator.GetBytes(TuzBoyu);
        var ozet = Rfc2898DeriveBytes.Pbkdf2(sifre, tuz, Iterasyon, HashAlgorithmName.SHA256, OzetBoyu);
        return $"{Onek}${Iterasyon}${Convert.ToBase64String(tuz)}${Convert.ToBase64String(ozet)}";
    }

    public static bool Dogrula(string sifre, string kayitliOzet)
    {
        var parcalar = kayitliOzet.Split('$');
        if (parcalar.Length != 4 || parcalar[0] != Onek || !int.TryParse(parcalar[1], out var iterasyon))
            return false;

        try
        {
            var tuz = Convert.FromBase64String(parcalar[2]);
            var beklenen = Convert.FromBase64String(parcalar[3]);
            var ozet = Rfc2898DeriveBytes.Pbkdf2(sifre, tuz, iterasyon, HashAlgorithmName.SHA256, beklenen.Length);
            return CryptographicOperations.FixedTimeEquals(ozet, beklenen);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
