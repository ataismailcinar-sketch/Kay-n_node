using KayinBackend.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KayinBackend.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core Fluent API — ToprakAnalizleri tablosu yapılandırması.
/// </summary>
public class ToprakAnaliziConfiguration : IEntityTypeConfiguration<ToprakAnalizi>
{
    public void Configure(EntityTypeBuilder<ToprakAnalizi> builder)
    {
        builder.ToTable("ToprakAnalizleri");
        builder.HasKey(a => a.Id);
        builder.Property(a => a.Id).ValueGeneratedNever();

        builder.HasOne(a => a.Parsel)
               .WithMany()
               .HasForeignKey(a => a.ParselId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.Property(a => a.AnalizTarihi).IsRequired();
        builder.Property(a => a.Laboratuvar).HasMaxLength(200);
        builder.Property(a => a.Not).HasMaxLength(500);

        builder.Property(a => a.CreatedAtUtc).IsRequired();
        builder.Property(a => a.LastModifiedUtc).IsRequired();
        builder.Property(a => a.IsDeleted).IsRequired().HasDefaultValue(false);

        builder.HasIndex(a => new { a.ParselId, a.AnalizTarihi })
               .HasDatabaseName("IX_ToprakAnalizleri_ParselId_AnalizTarihi");
    }
}
