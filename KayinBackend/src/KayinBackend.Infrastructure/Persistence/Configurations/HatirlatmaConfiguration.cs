using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — Hatirlatmalar tablosu yapılandırması.
/// </summary>
public class HatirlatmaConfiguration : IEntityTypeConfiguration<Hatirlatma>
{
    public void Configure(EntityTypeBuilder<Hatirlatma> builder)
    {
        builder.ToTable("Hatirlatmalar");
        builder.HasKey(h => h.Id);
        builder.Property(h => h.Id).ValueGeneratedNever();

        builder.Property(h => h.Baslik).IsRequired().HasMaxLength(200);
        builder.Property(h => h.Tur).IsRequired().HasMaxLength(20);
        builder.Property(h => h.Tarih).IsRequired();
        builder.Property(h => h.Not).HasMaxLength(500);

        builder.Property(h => h.CreatedAtUtc).IsRequired();
        builder.Property(h => h.LastModifiedUtc).IsRequired();
        builder.Property(h => h.IsDeleted).IsRequired().HasDefaultValue(false);
    }
}
