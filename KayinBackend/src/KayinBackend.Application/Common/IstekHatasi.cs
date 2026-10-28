namespace KayinBackend.Application.Common;

/// <summary>Kullanıcıya olduğu gibi gösterilebilecek geçersiz istek hatası (HTTP 400).</summary>
public class IstekHatasi(string mesaj) : Exception(mesaj);
