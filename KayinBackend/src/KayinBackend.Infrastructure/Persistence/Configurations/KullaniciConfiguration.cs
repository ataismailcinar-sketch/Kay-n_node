using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — Kullanicilar tablosu yapılandırması.
/// </summary>
public class KullaniciConfiguration : IEntityTypeConfiguration<Kullanici>
{
    public void Configure(EntityTypeBuilder<Kullanici> builder)
    {
        builder.ToTable("Kullanicilar");

        builder.HasKey(k => k.Id);
        builder.Property(k => k.Id).ValueGeneratedNever();

        builder.Property(k => k.Telefon).IsRequired().HasMaxLength(10);
        builder.HasIndex(k => k.Telefon)
               .IsUnique()
               .HasDatabaseName("IX_Kullanicilar_Telefon");

        builder.Property(k => k.SifreOzeti).IsRequired().HasMaxLength(200);
        builder.Property(k => k.AdSoyad).IsRequired().HasMaxLength(100);
        builder.Property(k => k.CreatedAtUtc).IsRequired();
    }
}
