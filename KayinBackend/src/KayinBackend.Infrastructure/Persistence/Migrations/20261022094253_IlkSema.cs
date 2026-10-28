using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class IlkSema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Kullanicilar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Telefon = table.Column<string>(type: "TEXT", maxLength: 10, nullable: false),
                    SifreOzeti = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    AdSoyad = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Kullanicilar", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "MuhasebeGiderler",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParselId = table.Column<Guid>(type: "TEXT", nullable: true),
                    IslemTuru = table.Column<string>(type: "TEXT", nullable: false),
                    Kategori = table.Column<string>(type: "TEXT", maxLength: 50, nullable: false),
                    AltKategori = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    Tutar = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    ParaBirimi = table.Column<string>(type: "TEXT", maxLength: 5, nullable: false, defaultValue: "TRY"),
                    GiderTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Not = table.Column<string>(type: "TEXT", maxLength: 1000, nullable: true),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MuhasebeGiderler", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Parseller",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Ad = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    Konum = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    PoligonKoordinatlariJson = table.Column<string>(type: "TEXT", maxLength: 50000, nullable: false, defaultValue: "[]"),
                    EkilmisUrun = table.Column<string>(type: "TEXT", nullable: false),
                    ToprakTuru = table.Column<string>(type: "TEXT", nullable: false),
                    EkimTarihi = table.Column<DateTime>(type: "TEXT", nullable: true),
                    AlanDonumCinsinden = table.Column<double>(type: "decimal(18,4)", nullable: false),
                    MerkezLat = table.Column<double>(type: "decimal(10,7)", nullable: false),
                    MerkezLng = table.Column<double>(type: "decimal(10,7)", nullable: false),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Parseller", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "HastalikTaramalar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParselId = table.Column<Guid>(type: "TEXT", nullable: true),
                    TaramaTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    TeshisAdi = table.Column<string>(type: "TEXT", maxLength: 200, nullable: false),
                    GüvenYüzdesi = table.Column<double>(type: "decimal(5,2)", nullable: false, defaultValue: 0.0),
                    TumSinifOlasiliklariJson = table.Column<string>(type: "TEXT", maxLength: 5000, nullable: false, defaultValue: "[]"),
                    FotografYerelYolu = table.Column<string>(type: "TEXT", maxLength: 500, nullable: false),
                    ModelVersionu = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    AciliyetSeviyesi = table.Column<string>(type: "TEXT", maxLength: 30, nullable: false, defaultValue: "Düşük"),
                    CevrimdisiAnalizYapildi = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: true),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HastalikTaramalar", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HastalikTaramalar_Parseller_ParselId",
                        column: x => x.ParselId,
                        principalTable: "Parseller",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "YagisSulamaKayitlari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParselId = table.Column<Guid>(type: "TEXT", nullable: false),
                    KayitTarihi = table.Column<DateTime>(type: "TEXT", nullable: false),
                    YagisMillimetre = table.Column<double>(type: "decimal(8,2)", nullable: false, defaultValue: 0.0),
                    ToprakNemiYuzde = table.Column<double>(type: "decimal(5,2)", nullable: false, defaultValue: 0.0),
                    KayitTuru = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false, defaultValue: "Otomatik"),
                    ManuelSulamaLitre = table.Column<double>(type: "decimal(10,2)", nullable: false, defaultValue: 0.0),
                    AciliyetSeviyesi = table.Column<string>(type: "TEXT", maxLength: 20, nullable: false, defaultValue: "Normal"),
                    HawaApiHamVeriJson = table.Column<string>(type: "TEXT", maxLength: 10000, nullable: false, defaultValue: "{}"),
                    KullaniciId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    LastModifiedUtc = table.Column<DateTime>(type: "TEXT", nullable: false),
                    IsDeleted = table.Column<bool>(type: "INTEGER", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_YagisSulamaKayitlari", x => x.Id);
                    table.ForeignKey(
                        name: "FK_YagisSulamaKayitlari_Parseller_ParselId",
                        column: x => x.ParselId,
                        principalTable: "Parseller",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HastalikTarama_LastModifiedUtc",
                table: "HastalikTaramalar",
                column: "LastModifiedUtc");

            migrationBuilder.CreateIndex(
                name: "IX_HastalikTarama_ParselId_TaramaTarihi",
                table: "HastalikTaramalar",
                columns: new[] { "ParselId", "TaramaTarihi" });

            migrationBuilder.CreateIndex(
                name: "IX_HastalikTaramalar_KullaniciId_LastModifiedUtc",
                table: "HastalikTaramalar",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Kullanicilar_Telefon",
                table: "Kullanicilar",
                column: "Telefon",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MuhasebeGider_Kategori_GiderTarihi",
                table: "MuhasebeGiderler",
                columns: new[] { "Kategori", "GiderTarihi" });

            migrationBuilder.CreateIndex(
                name: "IX_MuhasebeGider_LastModifiedUtc",
                table: "MuhasebeGiderler",
                column: "LastModifiedUtc");

            migrationBuilder.CreateIndex(
                name: "IX_MuhasebeGiderler_KullaniciId_LastModifiedUtc",
                table: "MuhasebeGiderler",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Parseller_IsDeleted",
                table: "Parseller",
                column: "IsDeleted");

            migrationBuilder.CreateIndex(
                name: "IX_Parseller_KullaniciId_LastModifiedUtc",
                table: "Parseller",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Parseller_LastModifiedUtc",
                table: "Parseller",
                column: "LastModifiedUtc");

            migrationBuilder.CreateIndex(
                name: "IX_YagisSulama_LastModifiedUtc",
                table: "YagisSulamaKayitlari",
                column: "LastModifiedUtc");

            migrationBuilder.CreateIndex(
                name: "IX_YagisSulama_ParselId_KayitTarihi",
                table: "YagisSulamaKayitlari",
                columns: new[] { "ParselId", "KayitTarihi" });

            migrationBuilder.CreateIndex(
                name: "IX_YagisSulamaKayitlari_KullaniciId_LastModifiedUtc",
                table: "YagisSulamaKayitlari",
                columns: new[] { "KullaniciId", "LastModifiedUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HastalikTaramalar");

            migrationBuilder.DropTable(
                name: "Kullanicilar");

            migrationBuilder.DropTable(
                name: "MuhasebeGiderler");

            migrationBuilder.DropTable(
                name: "YagisSulamaKayitlari");

            migrationBuilder.DropTable(
                name: "Parseller");
        }
    }
}
