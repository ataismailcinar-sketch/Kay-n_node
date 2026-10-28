namespace KayinBackend.Application.Features.Sync.Dtos;

// ════════════════════════════════════════════════════════════════════════════
// PUSH — Mobilden sunucuya gönderilen kayıtlar
// ════════════════════════════════════════════════════════════════════════════

/// <summary>
/// Flutter'ın sunucuya Push ettiği tek bir Parsel kaydı.
/// </summary>
public record ParselSyncDto(
    Guid Id,
    string Ad,
    string EkilmisUrun,
    string ToprakTuru,
    DateTime? EkimTarihi,
    string Konum,
    string PoligonKoordinatlariJson,
    double AlanDonumCinsinden,
    double MerkezLat,
    double MerkezLng,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted,
    // Sulu/kuru bilgisinden önceki uygulama sürümleri bunu göndermez (null).
    bool? Sulu = null,
    string? SulamaYontemi = null,
    string? SuKaynagi = null,
    double? SuEc = null,
    // 2+: istemci sulama alanlarını her zaman gönderir; null "boşaltıldı" demektir.
    // Yoksa (eski sürüm) null "gönderilmedi" sayılır ve sunucudaki değer korunur.
    int? SemaSurumu = null
);

/// <summary>
/// Flutter'ın sunucuya Push ettiği tek bir YagisSulamaKayit.
/// </summary>
public record YagisSulamaKayitSyncDto(
    Guid Id,
    Guid ParselId,
    DateTime KayitTarihi,
    double YagisMillimetre,
    double ToprakNemiYuzde,
    string KayitTuru,
    double ManuelSulamaLitre,
    string AciliyetSeviyesi,
    string HawaApiHamVeriJson,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>
/// Flutter'ın sunucuya Push ettiği tek bir MuhasebeGider.
/// </summary>
public record MuhasebeGiderSyncDto(
    Guid Id,
    Guid? ParselId,
    string IslemTuru,
    string Kategori,
    string AltKategori,
    decimal Tutar,
    string ParaBirimi,
    DateTime GiderTarihi,
    string? Not,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>
/// Flutter'ın sunucuya Push ettiği tek bir HastalikTarama.
/// NOT: Fotoğraf binary'si gönderilmez — sadece meta veri.
/// </summary>
public record HastalikTaramaSyncDto(
    Guid Id,
    Guid? ParselId,
    DateTime TaramaTarihi,
    string TeshisAdi,
    double GuvenYuzdesi,
    string TumSinifOlasiliklariJson,
    string FotografYerelYolu,
    string ModelVersionu,
    string AciliyetSeviyesi,
    bool CevrimdisiAnalizYapildi,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted,
    // Yalnızca pull'da anlamlı; push'ta gönderilse de yok sayılır.
    bool FotografVar = false
);

/// <summary>
/// İş günlüğü kaydı.
/// </summary>
public record IsKaydiSyncDto(
    Guid Id,
    Guid ParselId,
    DateTime IslemTarihi,
    string IslemTuru,
    string UrunAdi,
    string Miktar,
    int? HasatBeklemeGun,
    string Not,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted,
    // Hasat miktarından önceki uygulama sürümleri göndermez.
    double? HasatKg = null
);

/// <summary>Veresiye hesabı (bayi/tüccar/kişi).</summary>
public record CariSyncDto(
    Guid Id,
    string Ad,
    string Tur,
    string Telefon,
    string Not,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>Veresiye hareketi.</summary>
public record CariHareketSyncDto(
    Guid Id,
    Guid CariId,
    DateTime IslemTarihi,
    string Tur,
    decimal Tutar,
    DateTime? VadeTarihi,
    string Aciklama,
    Guid? MuhasebeKaydiId,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>Depo kalemi.</summary>
public record StokKalemiSyncDto(
    Guid Id,
    string Ad,
    string Kategori,
    string Birim,
    double? KritikSeviye,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>Depo hareketi.</summary>
public record StokHareketiSyncDto(
    Guid Id,
    Guid KalemId,
    DateTime IslemTarihi,
    string Tur,
    double Miktar,
    string Aciklama,
    Guid? IsKaydiId,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>Tarlanın toprak analizi.</summary>
public record ToprakAnaliziSyncDto(
    Guid Id,
    Guid ParselId,
    DateTime AnalizTarihi,
    string Laboratuvar,
    double? Saturasyon,
    double? Ph,
    double? TuzYuzde,
    double? Ec,
    double? KirecYuzde,
    double? OrganikMadde,
    double? Fosfor,
    double? Potasyum,
    double? Cinko,
    string Not,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

/// <summary>Tarihli hatırlatma (ÇKS, destek, TARSİM...).</summary>
public record HatirlatmaSyncDto(
    Guid Id,
    string Baslik,
    string Tur,
    DateTime Tarih,
    int KacGunOnce,
    bool HerYil,
    bool Tamamlandi,
    string Not,
    DateTime CreatedAtUtc,
    DateTime LastModifiedUtc,
    bool IsDeleted
);

// ════════════════════════════════════════════════════════════════════════════
// PUSH — Sunucunun mobil'e döndürdüğü yanıt
// ════════════════════════════════════════════════════════════════════════════

/// <summary>
/// Push işlemi sonrası sunucunun döndürdüğü sonuç raporu.
/// Mobil bu raporla hangi kayıtların IsSynced=1 yapılacağını bilir.
/// </summary>
public record PushSyncResultDto(
    /// <summary>Başarıyla kaydedilen kayıt ID'leri.</summary>
    List<Guid> AcceptedIds,
    /// <summary>Sunucunun daha yeni versiyonu nedeniyle reddedilen ID'ler (LWW kaybetti).</summary>
    List<Guid> RejectedIds,
    /// <summary>Hata oluşan ID'ler ve sebebi.</summary>
    Dictionary<Guid, string> Errors
);

// ════════════════════════════════════════════════════════════════════════════
// PULL — Sunucudan mobil'e gelen güncel kayıtlar
// ════════════════════════════════════════════════════════════════════════════

/// <summary>
/// Pull işlemi yanıtı — sunucu bu paketi mobilin son sync zamanından
/// sonra değişen tüm kayıtları içerecek şekilde gönderir.
/// </summary>
public record PullSyncResponseDto(
    List<ParselSyncDto> Parseller,
    List<YagisSulamaKayitSyncDto> YagisSulamaKayitlari,
    List<MuhasebeGiderSyncDto> MuhasebeGiderler,
    List<HastalikTaramaSyncDto> HastalikTaramalar,
    List<IsKaydiSyncDto> IsKayitlari,
    List<CariSyncDto> Cariler,
    List<CariHareketSyncDto> CariHareketleri,
    List<StokKalemiSyncDto> StokKalemleri,
    List<StokHareketiSyncDto> StokHareketleri,
    List<HatirlatmaSyncDto> Hatirlatmalar,
    List<ToprakAnaliziSyncDto> ToprakAnalizleri,
    /// <summary>
    /// Bu Pull'un zaman damgası. Mobil, bir sonraki Pull isteğinde
    /// bunu SinceUtc olarak gönderir.
    /// </summary>
    DateTime ServerSyncTimestamp
);
