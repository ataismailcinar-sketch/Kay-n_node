using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Depo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "StokKalemleri",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Ad = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    Kategori = table.Column<string>(type: "TEXT", maxLength: 30, nullable: false),
                    Birim = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                    KritikSeviye = table.Column<double>(type: "REAL", nullable: true),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StokKalemleri", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "StokHareketleri",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    KalemId = table.Column<Guid>(type: "TEXT", nullable: false),
                    IslemTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Tur = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                    Miktar = table.Column<double>(type: "REAL", nullable: false),
                    Aciklama = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    IsKaydiId = table.Column<Guid>(type: "TEXT", nullable: true),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StokHareketleri", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StokHareketleri_StokKalemleri_KalemId",
                        column: x => x.KalemId,
                        principalTable: "StokKalemleri",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StokHareketleri_KalemId_IslemTarihi",
                table: "StokHareketleri",
                columns: new[] { "KalemId", "IslemTarihi" });

            migrationBuilder.CreateIndex(
                name: "IX_StokHareketleri_KullaniciId_LastModifiedUtc",
                table: "StokHareketleri",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_StokKalemleri_KullaniciId_LastModifiedUtc",
                table: "StokKalemleri",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StokHareketleri");

            migrationBuilder.DropTable(
                name: "StokKalemleri");
        }
    }
}
