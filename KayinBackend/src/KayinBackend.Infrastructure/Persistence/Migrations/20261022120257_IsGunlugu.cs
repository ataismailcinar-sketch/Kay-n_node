using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class IsGunlugu : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "IsKayitlari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParselId = table.Column<Guid>(type: "TEXT", nullable: false),
                    IslemTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IslemTuru = table.Column<string>(type: "TEXT", maxLength: 30, nullable: false),
                    UrunAdi = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    Miktar = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    HasatBeklemeGun = table.Column<int>(type: "INTEGER", nullable: true),
                    Not = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: false),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IsKayitlari", x => x.Id);
                    table.ForeignKey(
                        name: "FK_IsKayitlari_Parseller_ParselId",
                        column: x => x.ParselId,
                        principalTable: "Parseller",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_IsKayitlari_KullaniciId_LastModifiedUtc",
                table: "IsKayitlari",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_IsKayitlari_ParselId_IslemTarihi",
                table: "IsKayitlari",
                columns: new[] { "ParselId", "IslemTarihi" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "IsKayitlari");
        }
    }
}
