using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ParselSulamaYontemi : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SuKaynagi",
                table: "Parseller",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SulamaYontemi",
                table: "Parseller",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SuKaynagi",
                table: "Parseller");

            migrationBuilder.DropColumn(
                name: "SulamaYontemi",
                table: "Parseller");
        }
    }
}
