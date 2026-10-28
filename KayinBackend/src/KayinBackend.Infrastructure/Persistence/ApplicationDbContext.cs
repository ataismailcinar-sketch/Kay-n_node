using KayinBackend.Application.Common.Interfaces;
using KayinBackend.Domain.Common;
using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using System.Reflection;

namespace KayinBackend.Infrastructure.Persistence;

/// <summary>
/// EF Core DbContext implementasyonu.
/// IApplicationDbContext arayüzünü uygular (Dependency Inversion prensibi).
/// </summary>
public class ApplicationDbContext : DbContext, IApplicationDbContext
{
    private readonly IAktifKullanici? _aktifKullanici;

    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options, IAktifKullanici? aktifKullanici = null)
        : base(options)
    {
        _aktifKullanici = aktifKullanici;
    }

    /// <summary>
    /// Sorgu filtresinin kullandığı kullanıcı. Girişsiz istekte ve arka plan servislerinde
    /// Guid.Empty olur, yani hiçbir kayıt görünmez (arka plan servisleri IgnoreQueryFilters kullanır).
    /// EF Core bu özelliği her sorguda yeniden okur; filtre bağlam örneğine göre çalışır.
    /// </summary>
    private Guid FiltreKullaniciId => _aktifKullanici?.KullaniciId ?? Guid.Empty;

    // ── DbSet'ler ──────────────────────────────────────────────────────────
    public DbSet<Parsel> Parseller => Set<Parsel>();
    public DbSet<YagisSulamaKayit> YagisSulamaKayitlari => Set<YagisSulamaKayit>();
    public DbSet<MuhasebeGider> MuhasebeGiderler => Set<MuhasebeGider>();
    public DbSet<HastalikTarama> HastalikTaramalar => Set<HastalikTarama>();
    public DbSet<Kullanici> Kullanicilar => Set<Kullanici>();
    public DbSet<IsKaydi> IsKayitlari => Set<IsKaydi>();
    public DbSet<Cari> Cariler => Set<Cari>();
    public DbSet<CariHareket> CariHareketleri => Set<CariHareket>();
    public DbSet<StokKalemi> StokKalemleri => Set<StokKalemi>();
    public DbSet<StokHareketi> StokHareketleri => Set<StokHareketi>();
    public DbSet<Hatirlatma> Hatirlatmalar => Set<Hatirlatma>();
    public DbSet<ToprakAnalizi> ToprakAnalizleri => Set<ToprakAnalizi>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        // Configurations klasöründeki tüm IEntityTypeConfiguration<T> sınıflarını otomatik yükle
        builder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());

        // ── Kullanıcıya göre veri ayrımı ─────────────────────────────────────
        // Her sorgu otomatik olarak yalnızca giriş yapan kullanıcının kayıtlarını görür.
        builder.Entity<Parsel>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<YagisSulamaKayit>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<MuhasebeGider>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<HastalikTarama>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<IsKaydi>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<Cari>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<CariHareket>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<StokKalemi>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<StokHareketi>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<Hatirlatma>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);
        builder.Entity<ToprakAnalizi>().HasQueryFilter(e => e.KullaniciId == FiltreKullaniciId);

        // Pull sorgusu: kullanıcı + değişiklik zamanı
        foreach (var tip in builder.Model.GetEntityTypes().Where(t => typeof(BaseEntity).IsAssignableFrom(t.ClrType)))
        {
            builder.Entity(tip.ClrType)
                   .HasIndex(nameof(BaseEntity.KullaniciId), nameof(BaseEntity.LastModifiedUtc));
        }

        base.OnModelCreating(builder);
    }

    /// <summary>
    /// SaveChanges interceptor — her kayıtta LastModifiedUtc'yi otomatik günceller.
    /// Bu sayede CQRS Handler'larında manuel atama gerekmez.
    /// </summary>
    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;

        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    if (entry.Entity.CreatedAtUtc == default)
                        entry.Entity.CreatedAtUtc = now;
                    if (entry.Entity.LastModifiedUtc == default)
                        entry.Entity.LastModifiedUtc = now;
                    // Sahibi atanmamış yeni kayıt giriş yapan kullanıcıya ait olur;
                    // kullanıcı yoksa (ör. arka plan servisi atamayı unuttuysa) sahipsiz kayıt yazılmaz.
                    if (entry.Entity.KullaniciId == Guid.Empty)
                        entry.Entity.KullaniciId = _aktifKullanici?.KullaniciId
                            ?? throw new InvalidOperationException(
                                $"{entry.Entity.GetType().Name} kaydının sahibi (KullaniciId) yok.");
                    break;

                case EntityState.Modified:
                    // Kaydın sahibi sonradan değiştirilemez.
                    entry.Property(e => e.KullaniciId).IsModified = false;
                    var lastModifiedProp = entry.Property(e => e.LastModifiedUtc);
                    if (!lastModifiedProp.IsModified || entry.Entity.LastModifiedUtc == default)
                    {
                        entry.Entity.LastModifiedUtc = now;
                    }
                    break;
            }
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}
