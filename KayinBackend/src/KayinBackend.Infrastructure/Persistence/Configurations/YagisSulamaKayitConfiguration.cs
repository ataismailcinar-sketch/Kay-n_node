using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — YagisSulamaKayit tablosu yapılandırması.
/// </summary>
public class YagisSulamaKayitConfiguration : IEntityTypeConfiguration<YagisSulamaKayit>
{
    public void Configure(EntityTypeBuilder<YagisSulamaKayit> builder)
    {
        builder.ToTable("YagisSulamaKayitlari");

        builder.HasKey(y => y.Id);
        builder.Property(y => y.Id).ValueGeneratedNever();

        builder.Property(y => y.ParselId).IsRequired();

        builder.Property(y => y.KayitTarihi).IsRequired();

        builder.Property(y => y.YagisMillimetre)
               .HasColumnType("decimal(8,2)")
               .HasDefaultValue(0.0);

        builder.Property(y => y.ToprakNemiYuzde)
               .HasColumnType("decimal(5,2)")
               .HasDefaultValue(0.0);

        builder.Property(y => y.KayitTuru)
               .IsRequired()
               .HasMaxLength(20)
               .HasDefaultValue("Otomatik");

        builder.Property(y => y.ManuelSulamaLitre)
               .HasColumnType("decimal(10,2)")
               .HasDefaultValue(0.0);

        builder.Property(y => y.AciliyetSeviyesi)
               .IsRequired()
               .HasMaxLength(20)
               .HasDefaultValue("Normal");

        builder.Property(y => y.HawaApiHamVeriJson)
               .HasMaxLength(10_000)
               .HasDefaultValue("{}");

        // Sync alanları
        builder.Property(y => y.CreatedAtUtc).IsRequired();
        builder.Property(y => y.LastModifiedUtc).IsRequired();
        builder.Property(y => y.IsDeleted).IsRequired().HasDefaultValue(false);

        // ParselId + KayitTarihi bileşik index — sık kullanılan sorgu kalıbı
        builder.HasIndex(y => new { y.ParselId, y.KayitTarihi })
               .HasDatabaseName("IX_YagisSulama_ParselId_KayitTarihi");

        builder.HasIndex(y => y.LastModifiedUtc)
               .HasDatabaseName("IX_YagisSulama_LastModifiedUtc");
    }
}
