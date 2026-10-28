using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — Cariler (veresiye hesapları) tablosu yapılandırması.
/// </summary>
public class CariConfiguration : IEntityTypeConfiguration<Cari>
{
    public void Configure(EntityTypeBuilder<Cari> builder)
    {
        builder.ToTable("Cariler");
        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedNever();

        builder.Property(c => c.Ad).IsRequired().HasMaxLength(200);
        builder.Property(c => c.Tur).IsRequired().HasMaxLength(20);
        builder.Property(c => c.Telefon).HasMaxLength(30);
        builder.Property(c => c.Not).HasMaxLength(1000);

        builder.Property(c => c.CreatedAtUtc).IsRequired();
        builder.Property(c => c.LastModifiedUtc).IsRequired();
        builder.Property(c => c.IsDeleted).IsRequired().HasDefaultValue(false);
    }
}

/// <summary>
/// EF Core Fluent API — CariHareketleri tablosu yapılandırması.
/// </summary>
public class CariHareketConfiguration : IEntityTypeConfiguration<CariHareket>
{
    public void Configure(EntityTypeBuilder<CariHareket> builder)
    {
        builder.ToTable("CariHareketleri");
        builder.HasKey(h => h.Id);
        builder.Property(h => h.Id).ValueGeneratedNever();

        builder.HasOne(h => h.Cari)
               .WithMany()
               .HasForeignKey(h => h.CariId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.Property(h => h.IslemTarihi).IsRequired();
        builder.Property(h => h.Tur).IsRequired().HasMaxLength(20);
        builder.Property(h => h.Tutar).IsRequired().HasColumnType("decimal(18,2)");
        builder.Property(h => h.Aciklama).HasMaxLength(500);

        builder.Property(h => h.CreatedAtUtc).IsRequired();
        builder.Property(h => h.LastModifiedUtc).IsRequired();
        builder.Property(h => h.IsDeleted).IsRequired().HasDefaultValue(false);

        builder.HasIndex(h => new { h.CariId, h.IslemTarihi })
               .HasDatabaseName("IX_CariHareketleri_CariId_IslemTarihi");
    }
}
