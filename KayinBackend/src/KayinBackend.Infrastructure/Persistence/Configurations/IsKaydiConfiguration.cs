using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — IsKayitlari (iş günlüğü) tablosu yapılandırması.
/// </summary>
public class IsKaydiConfiguration : IEntityTypeConfiguration<IsKaydi>
{
    public void Configure(EntityTypeBuilder<IsKaydi> builder)
    {
        builder.ToTable("IsKayitlari");

        builder.HasKey(i => i.Id);
        builder.Property(i => i.Id).ValueGeneratedNever();

        builder.HasOne(i => i.Parsel)
               .WithMany()
               .HasForeignKey(i => i.ParselId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.Property(i => i.IslemTarihi).IsRequired();
        builder.Property(i => i.IslemTuru).IsRequired().HasMaxLength(30);
        builder.Property(i => i.UrunAdi).HasMaxLength(200);
        builder.Property(i => i.Miktar).HasMaxLength(100);
        builder.Property(i => i.Not).HasMaxLength(1000);

        builder.Property(i => i.CreatedAtUtc).IsRequired();
        builder.Property(i => i.LastModifiedUtc).IsRequired();
        builder.Property(i => i.IsDeleted).IsRequired().HasDefaultValue(false);

        builder.HasIndex(i => new { i.ParselId, i.IslemTarihi })
               .HasDatabaseName("IX_IsKayitlari_ParselId_IslemTarihi");
    }
}
