using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class VeresiyeDefteri : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Cariler",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Ad = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    Tur = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                    Telefon = table.Column<string>(type: "TEXT", maxLength: 30, nullable: false),
                    Not = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: false),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Cariler", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CariHareketleri",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    CariId = table.Column<Guid>(type: "TEXT", nullable: false),
                    IslemTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Tur = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false),
                    Tutar = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    VadeTarihi = table.Column<DateTime>(type: "TEXT", nullable: true),
                    Aciklama = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    MuhasebeKaydiId = table.Column<Guid>(type: "TEXT", nullable: true),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CariHareketleri", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CariHareketleri_Cariler_CariId",
                        column: x => x.CariId,
                        principalTable: "Cariler",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CariHareketleri_CariId_IslemTarihi",
                table: "CariHareketleri",
                columns: new[] { "CariId", "IslemTarihi" });

            migrationBuilder.CreateIndex(
                name: "IX_CariHareketleri_KullaniciId_LastModifiedUtc",
                table: "CariHareketleri",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Cariler_KullaniciId_LastModifiedUtc",
                table: "Cariler",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CariHareketleri");

            migrationBuilder.DropTable(
                name: "Cariler");
        }
    }
}
