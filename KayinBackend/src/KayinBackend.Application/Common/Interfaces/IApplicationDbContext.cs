using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.Application.Common.Interfaces;

/// <summary>
/// Application katmanının veritabanına erişim sözleşmesi.
/// Infrastructure katmanından bağımsızlığı sağlar — Onion Architecture prensibi.
/// </summary>
public interface IApplicationDbContext
{
    DbSet<Parsel> Parseller { get; }
    DbSet<YagisSulamaKayit> YagisSulamaKayitlari { get; }
    DbSet<MuhasebeGider> MuhasebeGiderler { get; }
    DbSet<HastalikTarama> HastalikTaramalar { get; }
    DbSet<Kullanici> Kullanicilar { get; }
    DbSet<IsKaydi> IsKayitlari { get; }
    DbSet<Cari> Cariler { get; }
    DbSet<CariHareket> CariHareketleri { get; }
    DbSet<StokKalemi> StokKalemleri { get; }
    DbSet<Hatirlatma> Hatirlatmalar { get; }
    DbSet<ToprakAnalizi> ToprakAnalizleri { get; }
    DbSet<StokHareketi> StokHareketleri { get; }

    /// <summary>
    /// Değişiklikleri veritabanına kaydeder.
    /// </summary>
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
