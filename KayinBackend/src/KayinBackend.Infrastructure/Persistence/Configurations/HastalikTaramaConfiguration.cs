using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — HastalikTarama tablosu yapılandırması.
/// Fotoğraf sunucuya yüklenmez — yalnızca yerel yol saklanır.
/// </summary>
public class HastalikTaramaConfiguration : IEntityTypeConfiguration<HastalikTarama>
{
    public void Configure(EntityTypeBuilder<HastalikTarama> builder)
    {
        builder.ToTable("HastalikTaramalar");

        builder.HasKey(h => h.Id);
        builder.Property(h => h.Id).ValueGeneratedNever();

        builder.Property(h => h.ParselId).IsRequired(false);

        builder.Property(h => h.TaramaTarihi).IsRequired();

        builder.Property(h => h.TeshisAdi)
               .IsRequired()
               .HasMaxLength(200);

        builder.Property(h => h.GüvenYüzdesi)
               .HasColumnType("decimal(5,2)")
               .HasDefaultValue(0.0);

        // Tüm model output olasılıkları — JSON dizisi
        builder.Property(h => h.TumSinifOlasiliklariJson)
               .HasMaxLength(5_000)
               .HasDefaultValue("[]");

        // Sadece cihaz üzerindeki yol — veri tasarrufu
        builder.Property(h => h.FotografYerelYolu)
               .HasMaxLength(500);

        builder.Property(h => h.ModelVersionu)
               .HasMaxLength(100);

        builder.Property(h => h.AciliyetSeviyesi)
               .IsRequired()
               .HasMaxLength(30)
               .HasDefaultValue("Düşük");

        builder.Property(h => h.CevrimdisiAnalizYapildi)
               .IsRequired()
               .HasDefaultValue(true);

        // Sync alanları
        builder.Property(h => h.CreatedAtUtc).IsRequired();
        builder.Property(h => h.LastModifiedUtc).IsRequired();
        builder.Property(h => h.IsDeleted).IsRequired().HasDefaultValue(false);

        // Tarih + aciliyet sorgularına destek
        builder.HasIndex(h => new { h.ParselId, h.TaramaTarihi })
               .HasDatabaseName("IX_HastalikTarama_ParselId_TaramaTarihi");

        builder.HasIndex(h => h.LastModifiedUtc)
               .HasDatabaseName("IX_HastalikTarama_LastModifiedUtc");
    }
}
