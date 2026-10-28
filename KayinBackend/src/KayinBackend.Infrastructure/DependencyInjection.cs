using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Infrastructure.Depolama;
using KayinBackend.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace KayinBackend.Infrastructure;

/// <summary>
/// Infrastructure katmanı DI kaydı.
/// WebApi'deki Program.cs buraya tek bir çağrı yapar.
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── EF Core — veritabanı seçimi (appsettings.json'dan okunur: "SQLite", "PostgreSQL", "MSSQL") ──────
        var dbProvider = configuration.GetValue<string>("DatabaseProvider") ?? "SQLite";

        if (dbProvider == "PostgreSQL")
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseNpgsql(
                    configuration.GetConnectionString("DefaultConnection"),
                    b => b.MigrationsAssembly("KayinBackend.Infrastructure")));
        }
        else if (dbProvider == "MSSQL")
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlServer(
                    configuration.GetConnectionString("DefaultConnection"),
                    b => b.MigrationsAssembly("KayinBackend.Infrastructure")));
        }
        else // SQLite (Varsayılan - Harici veritabanı kurulumu gerektirmez)
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlite(
                    configuration.GetConnectionString("DefaultConnection") ?? "Data Source=KayinBackend.db",
                    b => b.MigrationsAssembly("KayinBackend.Infrastructure")));
        }

        // IApplicationDbContext → ApplicationDbContext bağlantısı
        services.AddScoped<IApplicationDbContext>(
            provider => provider.GetRequiredService<ApplicationDbContext>());

        // ── Tarama fotoğrafları (disk) ───────────────────────────────────────
        var fotografKlasoru = configuration.GetValue<string>("Fotograflar:Klasor")
            ?? Path.Combine("App_Data", "fotograflar");
        services.AddSingleton<IFotografDeposu>(new DiskFotografDeposu(Path.GetFullPath(fotografKlasoru)));

        // Not: Günlük hava/yağış kayıtları ("Otomatik") yalnızca mobil uygulamada üretilir
        // (parsel + gün başına tek kayıt, UUID v5) ve sync ile gelir. Sunucuda ayrıca
        // üretilmesi aynı gün için ikinci, farklı biçimde bir kayıt doğuruyordu.

        return services;
    }
}
