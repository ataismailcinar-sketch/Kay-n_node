using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — StokKalemleri (depo) tablosu yapılandırması.
/// </summary>
public class StokKalemiConfiguration : IEntityTypeConfiguration<StokKalemi>
{
    public void Configure(EntityTypeBuilder<StokKalemi> builder)
    {
        builder.ToTable("StokKalemleri");
        builder.HasKey(k => k.Id);
        builder.Property(k => k.Id).ValueGeneratedNever();

        builder.Property(k => k.Ad).IsRequired().HasMaxLength(200);
        builder.Property(k => k.Kategori).IsRequired().HasMaxLength(30);
        builder.Property(k => k.Birim).IsRequired().HasMaxLength(20);

        builder.Property(k => k.CreatedAtUtc).IsRequired();
        builder.Property(k => k.LastModifiedUtc).IsRequired();
        builder.Property(k => k.IsDeleted).IsRequired().HasDefaultValue(false);
    }
}

/// <summary>
/// EF Core Fluent API — StokHareketleri tablosu yapılandırması.
/// </summary>
public class StokHareketiConfiguration : IEntityTypeConfiguration<StokHareketi>
{
    public void Configure(EntityTypeBuilder<StokHareketi> builder)
    {
        builder.ToTable("StokHareketleri");
        builder.HasKey(h => h.Id);
        builder.Property(h => h.Id).ValueGeneratedNever();

        builder.HasOne(h => h.Kalem)
               .WithMany()
               .HasForeignKey(h => h.KalemId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.Property(h => h.IslemTarihi).IsRequired();
        builder.Property(h => h.Tur).IsRequired().HasMaxLength(20);
        builder.Property(h => h.Aciklama).HasMaxLength(500);

        builder.Property(h => h.CreatedAtUtc).IsRequired();
        builder.Property(h => h.LastModifiedUtc).IsRequired();
        builder.Property(h => h.IsDeleted).IsRequired().HasDefaultValue(false);

        builder.HasIndex(h => new { h.KalemId, h.IslemTarihi })
               .HasDatabaseName("IX_StokHareketleri_KalemId_IslemTarihi");
    }
}
