namespace KayinBackend.Application.Common.Guvenlik;

/// <summary>
/// Türkiye cep telefonu numarasını tek biçime getirir: "0532 123 45 67", "+90 532 123 4567",
/// "905321234567" → "5321234567". Geçersizse null.
/// </summary>
public static class TelefonNumarasi
{
    public static string? Normalize(string? girdi)
    {
        if (string.IsNullOrWhiteSpace(girdi)) return null;

        var rakamlar = new string(girdi.Where(char.IsAsciiDigit).ToArray());
        if (rakamlar.StartsWith("90") && rakamlar.Length == 12) rakamlar = rakamlar[2..];
        else if (rakamlar.StartsWith('0') && rakamlar.Length == 11) rakamlar = rakamlar[1..];

        return rakamlar.Length == 10 && rakamlar[0] == '5' ? rakamlar : null;
    }
}
