using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ToprakAnalizleri : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ToprakAnalizleri",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParselId = table.Column<Guid>(type: "TEXT", nullable: false),
                    AnalizTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Laboratuvar = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    Saturasyon = table.Column<double>(type: "REAL", nullable: true),
                    Ph = table.Column<double>(type: "REAL", nullable: true),
                    TuzYuzde = table.Column<double>(type: "REAL", nullable: true),
                    Ec = table.Column<double>(type: "REAL", nullable: true),
                    KirecYuzde = table.Column<double>(type: "REAL", nullable: true),
                    OrganikMadde = table.Column<double>(type: "REAL", nullable: true),
                    Fosfor = table.Column<double>(type: "REAL", nullable: true),
                    Potasyum = table.Column<double>(type: "REAL", nullable: true),
                    Cinko = table.Column<double>(type: "REAL", nullable: true),
                    Not = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ToprakAnalizleri", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ToprakAnalizleri_Parseller_ParselId",
                        column: x => x.ParselId,
                        principalTable: "Parseller",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ToprakAnalizleri_KullaniciId_LastModifiedUtc",
                table: "ToprakAnalizleri",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_ToprakAnalizleri_ParselId_AnalizTarihi",
                table: "ToprakAnalizleri",
                columns: new[] { "ParselId", "AnalizTarihi" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ToprakAnalizleri");
        }
    }
}
