using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — MuhasebeGider tablosu yapılandırması.
/// </summary>
public class MuhasebeGiderConfiguration : IEntityTypeConfiguration<MuhasebeGider>
{
    public void Configure(EntityTypeBuilder<MuhasebeGider> builder)
    {
        builder.ToTable("MuhasebeGiderler");

        builder.HasKey(m => m.Id);
        builder.Property(m => m.Id).ValueGeneratedNever();

        // ParselId isteğe bağlı (null = genel gider)
        builder.Property(m => m.ParselId).IsRequired(false);

        builder.Property(m => m.Kategori)
               .IsRequired()
               .HasMaxLength(50);

        builder.Property(m => m.AltKategori)
               .HasMaxLength(100);

        builder.Property(m => m.Tutar)
               .IsRequired()
               .HasColumnType("decimal(18,2)");

        builder.Property(m => m.ParaBirimi)
               .IsRequired()
               .HasMaxLength(5)
               .HasDefaultValue("TRY");

        builder.Property(m => m.GiderTarihi).IsRequired();

        builder.Property(m => m.Not)
               .HasMaxLength(1000);

        // Sync alanları
        builder.Property(m => m.CreatedAtUtc).IsRequired();
        builder.Property(m => m.LastModifiedUtc).IsRequired();
        builder.Property(m => m.IsDeleted).IsRequired().HasDefaultValue(false);

        // Raporlama sorgularına destek
        builder.HasIndex(m => new { m.Kategori, m.GiderTarihi })
               .HasDatabaseName("IX_MuhasebeGider_Kategori_GiderTarihi");

        builder.HasIndex(m => m.LastModifiedUtc)
               .HasDatabaseName("IX_MuhasebeGider_LastModifiedUtc");
    }
}
