using KayinBackend.Infrastructure.Persistence;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace KayinBackend.WebApi.Guvenlik;

/// <summary>
/// Günde bir kez veritabanının tutarlı bir kopyasını (SQLite <c>VACUUM INTO</c>; sunucu çalışırken de güvenli)
/// ve fotoğraf klasörünü <c>Yedek:Klasor</c> altına alır. Son <c>Yedek:SaklananGun</c> (varsayılan 14) gün tutulur.
/// Ayar yoksa çalışmaz (geliştirme). Fotoğraflar yalnızca yeni/değişenler kopyalanarak aynalanır.
/// </summary>
public sealed class GunlukYedek(IServiceProvider servisler, IConfiguration ayarlar, ILogger<GunlukYedek> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken iptal)
    {
        var klasor = ayarlar.GetValue<string>("Yedek:Klasor");
        if (string.IsNullOrWhiteSpace(klasor)) return;
        var saklanan = ayarlar.GetValue("Yedek:SaklananGun", 14);

        // Açılıştan kısa süre sonra bir kez, sonra günde bir.
        await Task.Delay(TimeSpan.FromMinutes(1), iptal);
        while (!iptal.IsCancellationRequested)
        {
            try
            {
                await YedekAl(klasor, saklanan, iptal);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogError(ex, "Günlük yedek alınamadı");
            }
            await Task.Delay(TimeSpan.FromHours(24), iptal);
        }
    }

    public async Task YedekAl(string klasor, int saklanan, CancellationToken iptal = default)
    {
        Directory.CreateDirectory(klasor);
        var hedef = Path.Combine(klasor, $"kayin-{DateTime.Now:yyyyMMdd}.db");
        if (File.Exists(hedef)) File.Delete(hedef); // aynı gün ikinci yedek öncekinin yerine geçer

        using (var scope = servisler.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            if (!db.Database.IsSqlite())
            {
                log.LogWarning("Günlük yedek yalnız SQLite için; bu veritabanının kendi yedeği kullanılmalı.");
                return;
            }
            await db.Database.ExecuteSqlRawAsync("VACUUM INTO {0}", [hedef], iptal);
        }

        var fotoKaynak = Path.GetFullPath(ayarlar.GetValue<string>("Fotograflar:Klasor") ?? Path.Combine("App_Data", "fotograflar"));
        var fotoHedef = Path.Combine(klasor, "fotograflar");
        var kopyalanan = 0;
        if (Directory.Exists(fotoKaynak))
        {
            foreach (var dosya in Directory.EnumerateFiles(fotoKaynak, "*", SearchOption.AllDirectories))
            {
                var h = Path.Combine(fotoHedef, Path.GetRelativePath(fotoKaynak, dosya));
                if (File.Exists(h) && File.GetLastWriteTimeUtc(h) >= File.GetLastWriteTimeUtc(dosya)) continue;
                Directory.CreateDirectory(Path.GetDirectoryName(h)!);
                File.Copy(dosya, h, overwrite: true);
                kopyalanan++;
            }
        }

        foreach (var eski in Directory.GetFiles(klasor, "kayin-*.db").OrderByDescending(f => f).Skip(saklanan))
        {
            File.Delete(eski);
        }
        SqliteConnection.ClearAllPools();
        log.LogInformation("Yedek alındı: {Dosya} ({Boyut} KB), {Foto} yeni fotoğraf", hedef, new FileInfo(hedef).Length / 1024, kopyalanan);
    }
}
