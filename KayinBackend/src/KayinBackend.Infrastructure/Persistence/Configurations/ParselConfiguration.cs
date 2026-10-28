using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — Parsel tablosu yapılandırması.
/// </summary>
public class ParselConfiguration : IEntityTypeConfiguration<Parsel>
{
    public void Configure(EntityTypeBuilder<Parsel> builder)
    {
        builder.ToTable("Parseller");

        // PK — Guid, veritabanı tarafından üretilmez (client-side generation)
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id)
               .ValueGeneratedNever(); // Auto-increment YASAK

        // Zorunlu alanlar
        builder.Property(p => p.Ad)
               .IsRequired()
               .HasMaxLength(200);

        builder.Property(p => p.Konum)
               .HasMaxLength(500);

        // Poligon JSON — büyük metin olabilir (max 50.000 karakter ~ ~500 nokta)
        builder.Property(p => p.PoligonKoordinatlariJson)
               .IsRequired()
               .HasMaxLength(50_000)
               .HasDefaultValue("[]");

        builder.Property(p => p.AlanDonumCinsinden)
               .HasColumnType("decimal(18,4)");

        builder.Property(p => p.MerkezLat)
               .HasColumnType("decimal(10,7)");

        builder.Property(p => p.MerkezLng)
               .HasColumnType("decimal(10,7)");

        // Sync alanları — index ile hızlı sorgu
        builder.Property(p => p.CreatedAtUtc).IsRequired();
        builder.Property(p => p.LastModifiedUtc).IsRequired();
        builder.Property(p => p.IsDeleted).IsRequired().HasDefaultValue(false);

        // Soft delete için index — senkronizasyon sorguları hızlanır
        builder.HasIndex(p => p.LastModifiedUtc)
               .HasDatabaseName("IX_Parseller_LastModifiedUtc");

        builder.HasIndex(p => p.IsDeleted)
               .HasDatabaseName("IX_Parseller_IsDeleted");

        // Navigation — One-to-Many
        builder.HasMany(p => p.SulamaKayitlari)
               .WithOne(s => s.Parsel)
               .HasForeignKey(s => s.ParselId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.HastalıkTaramalari)
               .WithOne(h => h.Parsel)
               .HasForeignKey(h => h.ParselId)
               .OnDelete(DeleteBehavior.Cascade);
    }
}
