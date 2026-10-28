using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KayinBackend.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ParselSulu : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "Sulu",
                table: "Parseller",
                type: "INTEGER",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Sulu",
                table: "Parseller");
        }
    }
}
