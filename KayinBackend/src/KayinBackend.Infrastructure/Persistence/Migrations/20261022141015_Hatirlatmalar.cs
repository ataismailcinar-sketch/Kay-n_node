using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Hatirlatmalar : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Hatirlatmalar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Baslik = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    Tur = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                    Tarih = table.Column<DateTime>(type: "TEXT", nullable: false),
                    KacGunOnce = table.Column<int>(type: "INTEGER", nullable: false),
                    HerYil = table.Column<bool>(type: "INTEGER", nullable: false),
                    Tamamlandi = table.Column<bool>(type: "INTEGER", nullable: false),
                    Not = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Hatirlatmalar", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Hatirlatmalar_KullaniciId_LastModifiedUtc",
                table: "Hatirlatmalar",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Hatirlatmalar");
        }
    }
}
